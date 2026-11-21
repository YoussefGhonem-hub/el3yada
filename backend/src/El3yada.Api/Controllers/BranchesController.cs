using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Common;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// Branches (D28, D29, AS17; spec 9.1 <c>createBranch</c>, <c>updateBranch</c>, <c>setBranchStatus</c>, BR-BR1–BR10).
/// Any clinic caller reads every branch of the doctor. Identity, address, contact, status and the default are
/// doctor only (BR-AS5). Working hours, special dates and booking settings are not here: they change only through
/// <c>updateBranchSchedule</c> (<c>PUT /api/staff/branches/{id}/schedule</c>, Features/Appointments/ScheduleService.cs),
/// which lists the bookings a change affects first (BR-AP12). There is no delete: a branch with history is
/// archived (BR-BR9).
/// </summary>
[ApiController]
[Route("api/branches")]
[Clinic]
public sealed class BranchesController(AppDbContext db, Auditor auditor, TimeProvider time) : ControllerBase
{
    /// <summary>How many BR-BR9 bookings a refusal lists; <c>totalCount</c> has the full number.</summary>
    private const int BookingsListed = 100;

    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>D28 cards: every branch, default first, archived last.</summary>
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var today = CairoTime.Today(time);
        var weekday = (byte)WeeklyHours.IsoWeekday(today);
        var rows = await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == caller.DoctorId)
            .OrderByDescending(b => b.IsDefault)
            .ThenBy(b => b.Status == BranchStatuses.Archived)
            .ThenBy(b => b.CreatedAt)
            .Select(b => new
            {
                b.Id, b.NameAr, b.NameEn, b.Governorate, b.City, b.Area, b.Status, b.ClosedMessage, b.ReopenDate, b.IsDefault,
                Periods = b.BranchPeriods.Where(p => p.Weekday == weekday).OrderBy(p => p.StartLocal).ToList(),
                Upcoming = b.Appointments.Count(a => BranchBookings.OpenStatuses.Contains(a.Status) && a.LocalDate >= today),
            })
            .ToListAsync(cancellationToken);
        var limit = await db.AppSettings.AsNoTracking().Select(s => s.MaxBranchesPerDoctor).SingleAsync(cancellationToken);
        var count = rows.Count(b => b.Status != BranchStatuses.Archived);

        return Ok(new BranchListView(
            rows.Select(b => new BranchCardView(
                b.Id, b.NameAr, b.NameEn, b.Governorate, b.City, b.Area, b.Status, b.ClosedMessage, b.ReopenDate, b.IsDefault,
                caller.CanUseBranch(b.Id), b.Periods.Select(BranchPeriodView.Of).ToList(), b.Upcoming)).ToList(),
            count, limit, count < limit, today, weekday));
    }

    /// <summary>D29 (AS17 read-only for assistants).</summary>
    [HttpGet("{branchId:guid}")]
    public async Task<IActionResult> Get(Guid branchId, CancellationToken cancellationToken)
    {
        var view = await BranchQueries.LoadDetailsAsync(db, HttpContext.Clinic(), branchId, cancellationToken);
        return view is null ? this.NotFoundProblem() : Ok(view);
    }

    /// <summary>
    /// Adds a branch, up to maxBranchesPerDoctor that are not archived (BR-BR1). It is active and not the
    /// default. No admin approval is needed.
    /// </summary>
    [HttpPost("createBranch")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> CreateBranch(CreateBranchRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await ClinicLocks.LockDoctorAsync(db, caller.DoctorId, cancellationToken);
        if (await LimitReachedAsync(caller.DoctorId, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.BranchLimitReached, "The clinic has the most branches allowed.");
        }

        var now = Now;
        var branch = new Branch
        {
            Id = Guid.NewGuid(), DoctorId = caller.DoctorId, IsDefault = false, Status = BranchStatuses.Active,
            CreatedAt = now, UpdatedAt = now,
        };
        BranchFields.ApplyInfo(branch, request.Info!);
        BranchFields.ApplyAddress(branch, request.Address!);
        BranchFields.ApplyContact(branch, request.Contact!);
        BranchFields.ApplyClinicInfo(branch, request.ClinicInfo ?? new BranchClinicInfoInput(["cash"], null));
        db.Branches.Add(branch);
        auditor.AddClinic(caller, AuditActions.BranchCreated, AuditTargets.Branch, branch.Id, new { nameAr = branch.NameAr });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return StatusCode(StatusCodes.Status201Created, await BranchQueries.LoadDetailsAsync(db, caller, branch.Id, cancellationToken));
    }

    /// <summary>Saves one or more D29 tabs (info, address, contact, clinicInfo). Each group sent replaces that group.</summary>
    [HttpPost("updateBranch")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> UpdateBranch(UpdateBranchRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var branch = await db.Branches.Include(b => b.BranchPhones)
            .SingleOrDefaultAsync(b => b.Id == request.BranchId && b.DoctorId == caller.DoctorId, cancellationToken);
        if (branch is null)
        {
            return this.NotFoundProblem();
        }

        var groups = new List<string>();
        if (request.Info is { } info)
        {
            BranchFields.ApplyInfo(branch, info);
            groups.Add("info");
        }

        if (request.Address is { } address)
        {
            BranchFields.ApplyAddress(branch, address);
            groups.Add("address");
        }

        if (request.Contact is { } contact)
        {
            db.BranchPhones.RemoveRange(branch.BranchPhones);
            branch.BranchPhones.Clear();
            BranchFields.ApplyContact(branch, contact);
            groups.Add("contact");
        }

        if (request.ClinicInfo is { } clinicInfo)
        {
            BranchFields.ApplyClinicInfo(branch, clinicInfo);
            groups.Add("clinicInfo");
        }

        branch.UpdatedAt = Now;
        auditor.AddClinic(caller, AuditActions.BranchUpdated, AuditTargets.Branch, branch.Id, new { groups });
        await db.SaveChangesAsync(cancellationToken);
        return Ok(await BranchQueries.LoadDetailsAsync(db, caller, branch.Id, cancellationToken));
    }

    /// <summary>
    /// Active, temporarily closed (message and optional reopening date, BR-BR10) or archived. Refused for the
    /// default branch (archive), for the last active branch (close or archive), while the branch has bookings
    /// from today on (BR-BR9, listed in the answer), and when reactivating an archived branch would go over
    /// maxBranchesPerDoctor.
    /// </summary>
    [HttpPost("setBranchStatus")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> SetBranchStatus(SetBranchStatusRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await ClinicLocks.LockDoctorAsync(db, caller.DoctorId, cancellationToken);
        var branch = await db.Branches
            .SingleOrDefaultAsync(b => b.Id == request.BranchId && b.DoctorId == caller.DoctorId, cancellationToken);
        if (branch is null)
        {
            return this.NotFoundProblem();
        }

        var target = request.Status!;
        var closing = target == BranchStatuses.TemporarilyClosed;
        if (target == branch.Status && !closing)
        {
            return Ok(await BranchQueries.LoadDetailsAsync(db, caller, branch.Id, cancellationToken));
        }

        if (target == BranchStatuses.Archived && branch.IsDefault)
        {
            return this.ConflictProblem(ErrorCodes.CannotArchiveDefaultBranch, "Choose another default branch before archiving this one.");
        }

        if (target != BranchStatuses.Active && branch.Status == BranchStatuses.Active
            && !await db.Branches.AnyAsync(b => b.DoctorId == caller.DoctorId && b.Id != branch.Id && b.Status == BranchStatuses.Active, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.LastActiveBranch, "The clinic needs at least one active branch.");
        }

        if (target != BranchStatuses.Active)
        {
            // BR-BR9: bookings from today on must be moved or cancelled first. A closure with a reopening date
            // only affects the bookings before that date.
            var bookings = BranchBookings.Open(db, branch.Id, CairoTime.Today(time), closing ? request.ReopenDate : null);
            var total = await bookings.CountAsync(cancellationToken);
            if (total > 0)
            {
                var problem = this.ConflictProblem(ErrorCodes.BranchHasBookings, "Move or cancel this branch's bookings first.");
                var details = (ProblemDetails)problem.Value!;
                details.Extensions["totalCount"] = total;
                details.Extensions["bookings"] = await BranchBookings.ListAsync(db, bookings, caller.DoctorId, BookingsListed, cancellationToken);
                return problem;
            }
        }

        if (target == BranchStatuses.Active && branch.Status == BranchStatuses.Archived
            && await LimitReachedAsync(caller.DoctorId, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.BranchLimitReached, "The clinic has the most branches allowed.");
        }

        var before = branch.Status;
        branch.Status = target;
        branch.ClosedMessage = closing ? request.ClosedMessage!.Trim() : null;
        branch.ReopenDate = closing ? request.ReopenDate : null;
        branch.UpdatedAt = Now;
        auditor.AddClinic(
            caller, AuditActions.BranchStatusChanged, AuditTargets.Branch, branch.Id,
            new { before, after = target, reopenDate = branch.ReopenDate });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Ok(await BranchQueries.LoadDetailsAsync(db, caller, branch.Id, cancellationToken));
    }

    /// <summary>Makes an active branch the default (BR-BR3). The previous default stays as it is.</summary>
    [HttpPost("setDefaultBranch")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> SetDefaultBranch(SetDefaultBranchRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await ClinicLocks.LockDoctorAsync(db, caller.DoctorId, cancellationToken);
        var branch = await db.Branches
            .SingleOrDefaultAsync(b => b.Id == request.BranchId && b.DoctorId == caller.DoctorId, cancellationToken);
        if (branch is null)
        {
            return this.NotFoundProblem();
        }

        if (!branch.IsDefault)
        {
            if (branch.Status != BranchStatuses.Active)
            {
                return this.ConflictProblem(ErrorCodes.BranchNotActive, "Only an active branch can be the default.");
            }

            var before = await db.Branches.Where(b => b.DoctorId == caller.DoctorId && b.IsDefault)
                .Select(b => (Guid?)b.Id).SingleOrDefaultAsync(cancellationToken);

            // UQ_Branches_OneDefault allows one default per doctor, so the old one is cleared before the new one is set.
            await db.Branches.Where(b => b.DoctorId == caller.DoctorId && b.IsDefault)
                .ExecuteUpdateAsync(set => set.SetProperty(b => b.IsDefault, false), cancellationToken);
            var now = Now;
            branch.IsDefault = true;
            branch.UpdatedAt = now;
            await db.Doctors.Where(d => d.UserId == caller.DoctorId)
                .ExecuteUpdateAsync(set => set.SetProperty(d => d.DefaultBranchId, branch.Id).SetProperty(d => d.UpdatedAt, now), cancellationToken);
            auditor.AddClinic(caller, AuditActions.DefaultBranchChanged, AuditTargets.Branch, branch.Id, new { before, after = branch.Id });
            await db.SaveChangesAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return Ok(await BranchQueries.LoadDetailsAsync(db, caller, branch.Id, cancellationToken));
    }

    private async Task<bool> LimitReachedAsync(Guid doctorId, CancellationToken cancellationToken)
    {
        var limit = await db.AppSettings.AsNoTracking().Select(s => s.MaxBranchesPerDoctor).SingleAsync(cancellationToken);
        return await BranchQueries.CountTowardLimitAsync(db, doctorId, cancellationToken) >= limit;
    }
}
