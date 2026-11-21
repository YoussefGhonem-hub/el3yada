using El3yada.Api.Auth;
using El3yada.Api.Billing;
using El3yada.Api.Infrastructure.Paging;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.AccountDeletion;

/// <summary>
/// The deletion in progress, in the session (<c>pendingDeletion</c>) and in <c>getAccountDeletion</c>. For a doctor,
/// <c>unpaidInvoices</c> and <c>outstandingPiasters</c> are what still holds the erasure back (BR-DEL9).
/// </summary>
public sealed record PendingDeletionView(
    Guid RequestId,
    string Status,
    DateTime RequestedAt,
    DateTime ScheduledFor,
    string? Reason,
    bool RequestedByAdmin,
    int UnpaidInvoices,
    int OutstandingPiasters)
{
    /// <summary>The erasure waits until every invoice is paid, even after <see cref="ScheduledFor"/>.</summary>
    public bool WaitsForPayment => UnpaidInvoices > 0;

    /// <summary>The account's open deletion, or null.</summary>
    public static async Task<PendingDeletionView?> LoadAsync(AppDbContext db, Guid userId, string role, CancellationToken cancellationToken)
    {
        var request = await db.DeletionRequests.AsNoTracking()
            .Where(r => r.UserId == userId && DeletionStatuses.Open.Contains(r.Status))
            .OrderByDescending(r => r.RequestedAt)
            .Select(r => new { r.Id, r.Status, r.RequestedAt, r.ScheduledFor, r.Reason, ByAdmin = r.RequestedBy != r.UserId })
            .FirstOrDefaultAsync(cancellationToken);
        if (request is null)
        {
            return null;
        }

        var (count, outstanding) = role == Roles.Doctor ? await OutstandingAsync(db, userId, cancellationToken) : (0, 0);
        return new PendingDeletionView(
            request.Id, request.Status, request.RequestedAt, request.ScheduledFor, request.Reason, request.ByAdmin, count, outstanding);
    }

    /// <summary>How many of the doctor's invoices still have to be paid, and their total.</summary>
    public static async Task<(int Count, int Piasters)> OutstandingAsync(AppDbContext db, Guid doctorId, CancellationToken cancellationToken)
    {
        var totals = await db.Invoices.AsNoTracking()
            .Where(i => i.DoctorId == doctorId && InvoiceStatuses.Outstanding.Contains(i.Status))
            .Select(i => i.TotalDuePiasters)
            .ToListAsync(cancellationToken);
        return (totals.Count, totals.Sum());
    }
}

/// <summary>An invoice that refuses a doctor's deletion (<c>UNPAID_INVOICES</c>) or holds the erasure back.</summary>
public sealed record UnpaidInvoiceView(Guid Id, string MonthKey, int TotalDuePiasters, string Status, DateOnly DueDate);

/// <summary>One invoice that deleting a doctor's account would issue now (BR-DEL8).</summary>
public sealed record FinalInvoiceLine(
    string MonthKey, DateOnly PeriodStart, DateOnly PeriodEnd, DateOnly DueDate, int AmountPiasters, bool IsFinal);

/// <summary>What a doctor's deletion would bill: the final invoice and any past month not invoiced yet.</summary>
public sealed record FinalInvoicePreview(int AmountPiasters, IReadOnlyList<FinalInvoiceLine> Invoices);

/// <summary>
/// <c>getAccountDeletion</c> (P14, D24, AS12, AD18 and A16): what deleting the account does now, or the deletion in
/// progress. <c>refusal</c> is why it can't start (<c>UNPAID_INVOICES</c>, <c>LAST_SUPER_ADMIN</c>,
/// <c>ACCOUNT_DELETION_SCHEDULED</c>), or null.
/// </summary>
public sealed record AccountDeletionStateView(
    string Role,
    int GraceDays,
    DateTime ScheduledForIfNow,
    PendingDeletionView? Pending,
    IReadOnlyList<UnpaidInvoiceView> UnpaidInvoices,
    FinalInvoicePreview? FinalInvoice,
    string? Refusal);

/// <summary><c>requestAccountDeletion</c>: the current password (checked) and an optional reason.</summary>
public sealed record RequestAccountDeletionRequest(string? CurrentPassword, string? Reason);

/// <summary>The deletion that just started. Every session of the account is already signed out.</summary>
public sealed record AccountDeletionStartedView(
    Guid RequestId,
    string Status,
    DateTime RequestedAt,
    DateTime ScheduledFor,
    int CancelledBookings,
    FinalInvoicePreview? FinalInvoice);

/// <summary><c>adminScheduleAccountDeletion</c> (AD5, AD11, AD14): any role, with the admin's reason.</summary>
public sealed record AdminScheduleAccountDeletionRequest(Guid? UserId, string? Reason);

/// <summary><c>adminCancelAccountDeletion</c>: the deletion is cancelled and the account restored, with a reason.</summary>
public sealed record AdminCancelAccountDeletionRequest(string? Reason);

/// <summary>AD12 filters. <c>role</c>: patient, doctor, assistant, admin or all. <c>status</c>: one of DeletionStatuses, open or all.</summary>
public sealed record AccountDeletionsQuery : PageQuery
{
    public string Role { get; init; } = "all";

    public string Status { get; init; } = "all";

    /// <summary>One account's deletions (AD5, AD11), newest first.</summary>
    public Guid? UserId { get; init; }
}

/// <summary>
/// One row of AD12. <c>displayName</c>, <c>phone</c> and <c>email</c> are the account's as they are now: after erasure the
/// name is the role's «… محذوف» and the phone and email are null. <c>waitingPayment</c> rows carry what is owed.
/// </summary>
public sealed record AccountDeletionItem(
    Guid Id,
    Guid UserId,
    string Role,
    string DisplayName,
    string? Phone,
    string? Email,
    string Status,
    string? Reason,
    DateTime RequestedAt,
    bool RequestedByAdmin,
    string? RequestedByName,
    DateTime ScheduledFor,
    DateTime? RestoredAt,
    string? RestoredByName,
    string? RestoreReason,
    DateTime? CompletedAt,
    Guid? PatientId,
    Guid? DoctorId,
    Guid? AssistantId,
    int UnpaidInvoices,
    int OutstandingPiasters);

public sealed class RequestAccountDeletionRequestValidator : AbstractValidator<RequestAccountDeletionRequest>
{
    public RequestAccountDeletionRequestValidator()
    {
        RuleFor(x => x.CurrentPassword).Required().MaxChars(Passwords.MaxLength);
        RuleFor(x => x.Reason).MaxChars(500);
    }
}

public sealed class AdminScheduleAccountDeletionRequestValidator : AbstractValidator<AdminScheduleAccountDeletionRequest>
{
    public AdminScheduleAccountDeletionRequestValidator()
    {
        RuleFor(x => x.UserId).NotNull().WithErrorCode(ErrorCodes.Required);
        RuleFor(x => x.Reason).Required().MaxChars(500);
    }
}

public sealed class AdminCancelAccountDeletionRequestValidator : AbstractValidator<AdminCancelAccountDeletionRequest>
{
    public AdminCancelAccountDeletionRequestValidator()
    {
        RuleFor(x => x.Reason).Required().MaxChars(500);
    }
}

public sealed class AccountDeletionsQueryValidator : AbstractValidator<AccountDeletionsQuery>
{
    public AccountDeletionsQueryValidator()
    {
        RuleFor(x => x.Role).Must(r => r is "all" or Roles.Patient or Roles.Doctor or Roles.Assistant or Roles.Admin)
            .WithErrorCode(ErrorCodes.InvalidValue);
        RuleFor(x => x.Status).Must(s => s is "all" or "open" || DeletionStatuses.All.Contains(s))
            .WithErrorCode(ErrorCodes.InvalidValue);
    }
}
