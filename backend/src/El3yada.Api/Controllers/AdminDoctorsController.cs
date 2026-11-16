using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// spec 9.1 <c>setDoctorStatus</c> (BR-G4, AD5 Suspend / Reactivate). <c>status</c>: <c>suspended</c>, or
/// <c>active</c> to reactivate. <c>reason</c> (3–500 characters) is required both ways.
/// </summary>
public sealed record SetDoctorStatusRequest(Guid? DoctorId, string? Status, string? Reason);

public sealed class SetDoctorStatusRequestValidator : AbstractValidator<SetDoctorStatusRequest>
{
    public SetDoctorStatusRequestValidator()
    {
        RuleFor(x => x.DoctorId).Required();
        RuleFor(x => x.Status).Required().OneOf(DoctorStatuses.Suspended, DoctorStatuses.Active);
        RuleFor(x => x.Reason)
            .Must(reason => reason?.Trim().Length >= 3)
            .WithErrorCode(ErrorCodes.ReasonRequired).WithMessage("Write the reason (at least 3 characters).")
            .MaxChars(500);
    }
}

/// <summary>The doctor's status after <c>setDoctorStatus</c>. <c>statusReason</c> is the suspension reason, null once active.</summary>
public sealed record DoctorStatusView(Guid DoctorId, string FullName, string Status, string? StatusReason, DateTime? StatusChangedAt);

/// <summary>
/// The admin's actions on a doctor account (AD5). Phase 7 brings the doctors list and details; <c>setDoctorStatus</c>
/// came early so a suspension can be tested end to end. Any admin.
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminDoctorsController(
    AppDbContext db, NotificationWriter notifications, Auditor auditor, AccountStateCache stateCache, TimeProvider time)
    : ControllerBase
{
    /// <summary>
    /// BR-G4: suspends an active doctor, or reactivates a suspended one, with a reason. Clinic endpoints read the
    /// doctor's status from the database on every request (spec 9.4), so the doctor and every assistant meet it on
    /// their next request: while suspended, the BR-G5 actions answer 403 <c>DOCTOR_SUSPENDED</c> and the rest works.
    /// Notifies the doctor and their active assistants and writes a <c>doctorSuspended</c> or
    /// <c>doctorReactivated</c> audit row. Asking for the status the doctor already has changes nothing.
    /// </summary>
    [HttpPost("setDoctorStatus")]
    public async Task<IActionResult> SetDoctorStatus(SetDoctorStatusRequest request, CancellationToken cancellationToken)
    {
        var doctorId = request.DoctorId!.Value;
        var target = request.Status!;
        var suspend = target == DoctorStatuses.Suspended;
        var reason = Text.CollapseSpaces(request.Reason!);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        // Two admins at the same moment: the second waits here, then sees the first one's change.
        await ClinicLocks.LockDoctorAsync(db, doctorId, cancellationToken);
        var doctor = await db.Doctors.SingleOrDefaultAsync(d => d.UserId == doctorId, cancellationToken);
        if (doctor is null)
        {
            return this.NotFoundProblem();
        }

        if (doctor.Status == target)
        {
            return Ok(View(doctor));
        }

        if (doctor.Status is not (DoctorStatuses.Active or DoctorStatuses.Suspended))
        {
            return this.ConflictProblem(
                    ErrorCodes.DoctorStatusNotChangeable, "Only an active doctor can be suspended, and only a suspended one reactivated.")
                .WithFields(("status", doctor.Status));
        }

        var before = doctor.Status;
        var now = time.GetUtcNow().UtcDateTime;
        doctor.Status = target;
        doctor.StatusReason = suspend ? reason : null;
        doctor.StatusChangedAt = now;
        doctor.UpdatedAt = now;

        var assistants = await db.Assistants
            .Where(a => a.DoctorId == doctorId && a.Status == AssistantStatuses.Active && a.User.Status == AccountStatuses.Active)
            .Select(a => a.UserId)
            .ToListAsync(cancellationToken);
        var data = new { doctorId };
        notifications.Add(doctorId, suspend ? NotificationTexts.Suspended(reason) : NotificationTexts.Reactivated(), "/home", data);
        var assistantText = suspend
            ? NotificationTexts.SuspendedForAssistant(doctor.FullName)
            : NotificationTexts.ReactivatedForAssistant(doctor.FullName);
        foreach (var assistantId in assistants)
        {
            notifications.Add(assistantId, assistantText, "/home", data);
        }

        auditor.Add(
            suspend ? AuditActions.DoctorSuspended : AuditActions.DoctorReactivated,
            AuditTargets.Doctor, doctorId, new { before, after = target, reason }, doctorId: doctorId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        // The session's doctorStatus (auth/me, refresh) comes from the cached account state.
        stateCache.Invalidate(doctorId);
        foreach (var assistantId in assistants)
        {
            stateCache.Invalidate(assistantId);
        }

        return Ok(View(doctor));
    }

    private static DoctorStatusView View(Doctor doctor) =>
        new(doctor.UserId, doctor.FullName, doctor.Status, doctor.StatusReason, doctor.StatusChangedAt);
}
