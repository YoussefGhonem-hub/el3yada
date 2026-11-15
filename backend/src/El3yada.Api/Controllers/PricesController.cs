using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Common;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>The doctor's prices, or one branch's (<c>branchId</c>). Both prices are replaced; null means not set.</summary>
public sealed record UpdatePricesRequest(Guid? BranchId, int? ExaminationPricePiasters, int? ConsultationPricePiasters);

public sealed class UpdatePricesRequestValidator : AbstractValidator<UpdatePricesRequest>
{
    /// <summary>100,000 EGP (spec section 11, visit prices; the same limit as at sign-up).</summary>
    public const int MaxPrice = 10_000_000;

    public UpdatePricesRequestValidator()
    {
        RuleFor(x => x.ExaminationPricePiasters).InclusiveBetween(0, MaxPrice).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.ConsultationPricePiasters).InclusiveBetween(0, MaxPrice).WithErrorCode(ErrorCodes.OutOfRange);
    }
}

/// <summary>D37 history paging (newest first).</summary>
public sealed class PricesQuery : IPagedQuery
{
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class PricesQueryValidator : AbstractValidator<PricesQuery>
{
    public PricesQueryValidator() => this.AddPagingRules();
}

public sealed record PricePairView(int? ExaminationPricePiasters, int? ConsultationPricePiasters);

public sealed record BranchPriceRowView(
    Guid BranchId, string NameAr, string? NameEn, string Status, bool IsDefault, bool Assigned, BranchPricesView Prices);

public sealed record PriceChangedByView(Guid UserId, string? Name, string Role);

public sealed record PriceBranchView(Guid Id, string NameAr, string? NameEn);

/// <summary>One BR-PR5 row: who, when, which branch (null = the doctor's prices), old and new prices.</summary>
public sealed record PriceHistoryItemView(
    Guid Id, DateTime ChangedAt, PriceChangedByView ChangedBy, PriceBranchView? Branch, PricePairView Before, PricePairView After);

public sealed record PricesView(PricePairView Doctor, IReadOnlyList<BranchPriceRowView> Branches, PagedResult<PriceHistoryItemView> History);

/// <summary>
/// D37 and AS19 visit prices (section 6.15, BR-PR1–PR6): the doctor, or an assistant with <c>pricesManage</c>.
/// Not blocked while suspended (BR-G5). New prices apply to sessions saved afterwards (BR-PR4); saved sessions
/// keep their amounts, so nothing is recalculated.
/// </summary>
[ApiController]
[Route("api/prices")]
[Clinic(ClinicPermissions.PricesManage)]
public sealed class PricesController(AppDbContext db, Auditor auditor, TimeProvider time) : ControllerBase
{
    /// <summary>The doctor's prices, each branch's, and a page of the history (<c>?page=&amp;pageSize=</c>).</summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] PricesQuery query, CancellationToken cancellationToken) =>
        Ok(await LoadAsync(HttpContext.Clinic(), query, cancellationToken));

    /// <summary>
    /// Sets the doctor's prices (<c>branchId</c> null) or one branch's. An assistant may set a branch's prices only
    /// for their own branches (BR-AS13); doctor-level prices need only <c>pricesManage</c>. Writes a PriceHistory
    /// row and an audit row when something changed (BR-PR5).
    /// </summary>
    [HttpPost("updatePrices")]
    public async Task<IActionResult> UpdatePrices(UpdatePricesRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (request.BranchId is { } id && !caller.CanUseBranch(id))
        {
            return this.BranchNotAllowed();
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await ClinicLocks.LockDoctorAsync(db, caller.DoctorId, cancellationToken);
        PricePairView before;
        if (request.BranchId is { } branchId)
        {
            var branch = await db.Branches.SingleOrDefaultAsync(b => b.Id == branchId && b.DoctorId == caller.DoctorId, cancellationToken);
            if (branch is null)
            {
                return this.NotFoundProblem();
            }

            before = new PricePairView(branch.ExaminationPricePiasters, branch.ConsultationPricePiasters);
            branch.ExaminationPricePiasters = request.ExaminationPricePiasters;
            branch.ConsultationPricePiasters = request.ConsultationPricePiasters;
            branch.UpdatedAt = time.GetUtcNow().UtcDateTime;
        }
        else
        {
            var doctor = await db.Doctors.SingleAsync(d => d.UserId == caller.DoctorId, cancellationToken);
            before = new PricePairView(doctor.ExaminationPricePiasters, doctor.ConsultationPricePiasters);
            doctor.ExaminationPricePiasters = request.ExaminationPricePiasters;
            doctor.ConsultationPricePiasters = request.ConsultationPricePiasters;
            doctor.UpdatedAt = time.GetUtcNow().UtcDateTime;
        }

        var after = new PricePairView(request.ExaminationPricePiasters, request.ConsultationPricePiasters);
        if (after != before)
        {
            db.PriceHistories.Add(new PriceHistory
            {
                Id = Guid.NewGuid(),
                DoctorId = caller.DoctorId,
                BranchId = request.BranchId,
                BeforeExaminationPiasters = before.ExaminationPricePiasters,
                BeforeConsultationPiasters = before.ConsultationPricePiasters,
                AfterExaminationPiasters = after.ExaminationPricePiasters,
                AfterConsultationPiasters = after.ConsultationPricePiasters,
                ChangedBy = caller.UserId,
                ChangedByRole = caller.Role,
                ChangedAt = time.GetUtcNow().UtcDateTime,
            });
            auditor.AddClinic(
                caller, AuditActions.PricesUpdated,
                request.BranchId is null ? AuditTargets.Doctor : AuditTargets.Branch,
                request.BranchId ?? caller.DoctorId,
                new { branchId = request.BranchId, before, after });
            await db.SaveChangesAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return Ok(await LoadAsync(caller, new PricesQuery(), cancellationToken));
    }

    private async Task<PricesView> LoadAsync(ClinicCaller caller, PricesQuery query, CancellationToken cancellationToken)
    {
        var doctor = await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == caller.DoctorId)
            .Select(d => new PricePairView(d.ExaminationPricePiasters, d.ConsultationPricePiasters))
            .SingleAsync(cancellationToken);
        var branches = await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == caller.DoctorId)
            .OrderByDescending(b => b.IsDefault).ThenBy(b => b.Status == BranchStatuses.Archived).ThenBy(b => b.CreatedAt)
            .Select(b => new { b.Id, b.NameAr, b.NameEn, b.Status, b.IsDefault, b.ExaminationPricePiasters, b.ConsultationPricePiasters })
            .ToListAsync(cancellationToken);
        var history = await db.PriceHistories.AsNoTracking()
            .Where(h => h.DoctorId == caller.DoctorId)
            .OrderByDescending(h => h.ChangedAt).ThenByDescending(h => h.Id)
            .Select(h => new PriceHistoryItemView(
                h.Id, h.ChangedAt,
                new PriceChangedByView(h.ChangedBy, h.ChangedByNavigation.DisplayName, h.ChangedByRole),
                h.Branch == null ? null : new PriceBranchView(h.Branch.Id, h.Branch.NameAr, h.Branch.NameEn),
                new PricePairView(h.BeforeExaminationPiasters, h.BeforeConsultationPiasters),
                new PricePairView(h.AfterExaminationPiasters, h.AfterConsultationPiasters)))
            .ToPageAsync(query, cancellationToken);

        return new PricesView(
            doctor,
            branches.Select(b => new BranchPriceRowView(
                b.Id, b.NameAr, b.NameEn, b.Status, b.IsDefault, caller.CanUseBranch(b.Id),
                BranchPricesView.Of(b.ExaminationPricePiasters, b.ConsultationPricePiasters,
                    doctor.ExaminationPricePiasters, doctor.ConsultationPricePiasters))).ToList(),
            history);
    }
}
