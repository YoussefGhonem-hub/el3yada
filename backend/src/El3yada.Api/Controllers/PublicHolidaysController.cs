using El3yada.Api.Audit;
using El3yada.Api.Common;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

public sealed record PublicHolidayView(Guid Id, DateOnly Date, string NameAr, string NameEn);

public sealed record CreatePublicHolidayRequest(DateOnly? Date, string? NameAr, string? NameEn);

public sealed class CreatePublicHolidayRequestValidator : AbstractValidator<CreatePublicHolidayRequest>
{
    public CreatePublicHolidayRequestValidator()
    {
        RuleFor(x => x.Date).NotNull().WithErrorCode(ErrorCodes.Required).WithMessage("Choose the date.");
        RuleFor(x => x.NameAr).Required().MaxChars(100);
        RuleFor(x => x.NameEn).Required().MaxChars(100);
    }
}

public sealed record DeletePublicHolidayRequest(Guid? Id);

public sealed class DeletePublicHolidayRequestValidator : AbstractValidator<DeletePublicHolidayRequest>
{
    public DeletePublicHolidayRequestValidator() => RuleFor(x => x.Id).Required();
}

/// <summary>
/// AD13 [C]: the Egyptian public holidays the admin manages (BR-AP13). Clinics see the coming ones as
/// suggestions in D29's Special dates tab (<c>holidays</c> in <c>GET /api/staff/branches/{id}/schedule</c>): a
/// branch closes on one only if the doctor or an assistant with <c>scheduleManage</c> adds the closure, through
/// the conflicts check (BR-AP12). Nothing closes by itself.
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class PublicHolidaysController(AppDbContext db, Auditor auditor, TimeProvider time) : ControllerBase
{
    /// <summary>Every holiday from a month ago on, earliest first.</summary>
    [HttpGet("publicHolidays")]
    public async Task<IActionResult> List(CancellationToken cancellationToken)
    {
        var from = CairoTime.Today(time).AddDays(-31);
        return Ok(await db.PublicHolidays.AsNoTracking()
            .Where(h => h.Date >= from)
            .OrderBy(h => h.Date)
            .Select(h => new PublicHolidayView(h.Id, h.Date, h.NameAr, h.NameEn))
            .ToListAsync(cancellationToken));
    }

    /// <summary>One date, once (409 <c>PUBLIC_HOLIDAY_EXISTS</c>). <b>201</b> with the holiday.</summary>
    [HttpPost("createPublicHoliday")]
    public async Task<IActionResult> Create(CreatePublicHolidayRequest request, CancellationToken cancellationToken)
    {
        var date = request.Date!.Value;
        if (await db.PublicHolidays.AnyAsync(h => h.Date == date, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.PublicHolidayExists, "That date is already a public holiday.");
        }

        var holiday = new PublicHoliday { Id = Guid.NewGuid(), Date = date, NameAr = request.NameAr!.Trim(), NameEn = request.NameEn!.Trim() };
        db.PublicHolidays.Add(holiday);
        auditor.Add(AuditActions.PublicHolidayCreated, AuditTargets.Settings, holiday.Id, new { date, holiday.NameAr });
        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (ex.IsUniqueViolation())
        {
            return this.ConflictProblem(ErrorCodes.PublicHolidayExists, "That date is already a public holiday.");
        }

        return StatusCode(StatusCodes.Status201Created, new PublicHolidayView(holiday.Id, holiday.Date, holiday.NameAr, holiday.NameEn));
    }

    /// <summary>Removes it from the suggestions. Closures clinics already added stay.</summary>
    [HttpPost("deletePublicHoliday")]
    public async Task<IActionResult> Delete(DeletePublicHolidayRequest request, CancellationToken cancellationToken)
    {
        var holiday = await db.PublicHolidays.SingleOrDefaultAsync(h => h.Id == request.Id, cancellationToken);
        if (holiday is null)
        {
            return this.NotFoundProblem();
        }

        db.PublicHolidays.Remove(holiday);
        auditor.Add(AuditActions.PublicHolidayDeleted, AuditTargets.Settings, holiday.Id, new { date = holiday.Date, holiday.NameAr });
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }
}
