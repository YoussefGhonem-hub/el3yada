using System.Globalization;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Billing;

// ---- Requests --------------------------------------------------------------------------------------------

public sealed class PaymentsQuery : IPagedQuery
{
    /// <summary><c>pendingReview</c> (default, the AD7 queue), <c>approved</c>, <c>rejected</c> or <c>all</c>.</summary>
    public string? Status { get; init; }

    /// <summary>One doctor's payments (AD5 Payments tab).</summary>
    public Guid? DoctorId { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class PaymentsQueryValidator : AbstractValidator<PaymentsQuery>
{
    public PaymentsQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Status).OneOf(PaymentStatuses.PendingReview, PaymentStatuses.Approved, PaymentStatuses.Rejected, "all")
            .When(x => x.Status is not null);
    }
}

public sealed class InvoicesQuery : IPagedQuery
{
    /// <summary>A Cairo month, <c>yyyy-MM</c>.</summary>
    public string? Month { get; init; }

    public string? Status { get; init; }

    public Guid? DoctorId { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class InvoicesQueryValidator : AbstractValidator<InvoicesQuery>
{
    public InvoicesQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Status).OneOf(InvoiceStatuses.All).When(x => x.Status is not null);
        RuleFor(x => x.Month)
            .Must(month => CairoTime.ParseMonthKey(month) is not null)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use the form 2026-10.")
            .When(x => x.Month is not null);
    }
}

/// <summary><c>reviewPayment</c> (BR-PAY3). <c>action</c> is <c>approve</c> or <c>reject</c>; a rejection needs a reason (preset or typed).</summary>
public sealed record ReviewPaymentRequest(Guid? PaymentId, string? Action, string? Reason);

public sealed class ReviewPaymentRequestValidator : AbstractValidator<ReviewPaymentRequest>
{
    public ReviewPaymentRequestValidator()
    {
        RuleFor(x => x.PaymentId).Required();
        RuleFor(x => x.Action).Required().OneOf("approve", "reject");
        RuleFor(x => x.Reason)
            .Must(reason => reason?.Trim().Length >= 3)
            .WithErrorCode(ErrorCodes.ReasonRequired).WithMessage("Write the reason (at least 3 characters).")
            .When(x => x.Action == "reject");
        RuleFor(x => x.Reason).MaxChars(500);
    }
}

public sealed record AdjustInvoiceRequest(Guid? InvoiceId, int? AmountPiasters, string? Reason);

public sealed class AdjustInvoiceRequestValidator : AbstractValidator<AdjustInvoiceRequest>
{
    public AdjustInvoiceRequestValidator()
    {
        RuleFor(x => x.InvoiceId).Required();
        RuleFor(x => x.AmountPiasters).Required();
        RuleFor(x => x.AmountPiasters)
            .Must(amount => amount != 0).WithErrorCode(ErrorCodes.AdjustmentInvalid).WithMessage("The adjustment can't be zero.")
            .Must(amount => Math.Abs(amount ?? 0) <= BillingLimits.MaxAmountPiasters)
            .WithErrorCode(ErrorCodes.OutOfRange).WithMessage("The amount is too large.")
            .When(x => x.AmountPiasters is not null);
        RuleFor(x => x.Reason).ReasonRules();
    }
}

public sealed record WaiveInvoiceRequest(Guid? InvoiceId, string? Reason);

public sealed class WaiveInvoiceRequestValidator : AbstractValidator<WaiveInvoiceRequest>
{
    public WaiveInvoiceRequestValidator()
    {
        RuleFor(x => x.InvoiceId).Required();
        RuleFor(x => x.Reason).ReasonRules();
    }
}

/// <summary><c>markInvoicePaid</c> (BR-PAY4): <c>method</c> is <c>instapay</c>, <c>cash</c>, <c>bankTransfer</c> or <c>other</c>.</summary>
public sealed record MarkInvoicePaidRequest(Guid? InvoiceId, string? Method, string? Note);

public sealed class MarkInvoicePaidRequestValidator : AbstractValidator<MarkInvoicePaidRequest>
{
    public MarkInvoicePaidRequestValidator()
    {
        RuleFor(x => x.InvoiceId).Required();
        RuleFor(x => x.Method).Required().OneOf(PaidMethods.Manual);
        RuleFor(x => x.Note).ReasonRules();
    }
}

public sealed record ExtendInvoiceDueDateRequest(Guid? InvoiceId, DateOnly? NewDueDate, string? Reason);

public sealed class ExtendInvoiceDueDateRequestValidator : AbstractValidator<ExtendInvoiceDueDateRequest>
{
    public ExtendInvoiceDueDateRequestValidator()
    {
        RuleFor(x => x.InvoiceId).Required();
        RuleFor(x => x.NewDueDate).Required();
        RuleFor(x => x.Reason).ReasonRules();
    }
}

public static class BillingRules
{
    /// <summary>A reason an admin types for a money action: 3 to 500 characters.</summary>
    public static IRuleBuilderOptions<T, string?> ReasonRules<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(reason => reason?.Trim().Length >= 3)
            .WithErrorCode(ErrorCodes.ReasonRequired).WithMessage("Write the reason (at least 3 characters).")
            .MaxChars(500);
}

// ---- Views ------------------------------------------------------------------------------------------------

/// <summary>A row of AD7. <c>mismatch</c> is true when the amount entered differs from the invoice total (BR-PAY3).</summary>
public sealed record PaymentQueueItem(
    Guid PaymentId,
    Guid InvoiceId,
    Guid DoctorId,
    string DoctorName,
    string? DoctorNameEn,
    string MonthKey,
    int InvoiceTotalPiasters,
    int AmountPiasters,
    bool Mismatch,
    DateTime SubmittedAt,
    string Status);

/// <summary>AD8: the payment, the invoice it pays, and the earlier attempts on that invoice.</summary>
public sealed record PaymentReviewView(
    PaymentLine Payment,
    InvoiceDoctorRef Doctor,
    InvoiceSummary Invoice,
    bool Mismatch,
    IReadOnlyList<PaymentLine> EarlierAttempts);

public sealed record InvoiceSummary(
    Guid Id, string MonthKey, int ExamCount, int ConsultationCount, int TotalDuePiasters, DateOnly DueDate, string Status);

/// <summary>A row of AD9.</summary>
public sealed record AdminInvoiceItem(
    Guid Id,
    Guid DoctorId,
    string DoctorName,
    string? DoctorNameEn,
    string MonthKey,
    int ExamCount,
    int ConsultationCount,
    int TotalDuePiasters,
    DateOnly DueDate,
    string Status);

public sealed record InvoiceTotals(int Count, int ExamCount, int ConsultationCount, int TotalDuePiasters);

public sealed record AdminInvoicesView(PagedResult<AdminInvoiceItem> Page, InvoiceTotals Totals);

public sealed record InvoiceStateView(Guid InvoiceId, string Status, int TotalDuePiasters, DateOnly DueDate);

// ---- Controller -------------------------------------------------------------------------------------------

/// <summary>
/// Payments and invoices for the admin (AD7–AD10; spec 6.6, 9.1). An admin sees fee snapshots and payment screenshots,
/// never the clinic's revenue or patient data (BR-REV1). Every change writes an audit row and notifies the doctor.
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminBillingController(
    AppDbContext db,
    IFileStorage storage,
    BillingService billing,
    NotificationWriter notifications,
    Auditor auditor,
    AccountStateCache stateCache,
    TimeProvider time) : ControllerBase
{
    private DateTime Now => time.GetUtcNow().UtcDateTime;

    private Guid AdminId => User.UserId();

    // -- AD7, AD8 --

    /// <summary>AD7: the payments waiting for review, oldest first (or the other statuses, newest first).</summary>
    [HttpGet("payments")]
    public async Task<IActionResult> Payments([FromQuery] PaymentsQuery query, CancellationToken cancellationToken)
    {
        var status = query.Status ?? PaymentStatuses.PendingReview;
        var payments = db.Payments.AsNoTracking().Where(p => status == "all" || p.Status == status);
        if (query.DoctorId is { } paymentsDoctor)
        {
            payments = payments.Where(p => p.DoctorId == paymentsDoctor);
        }

        var ordered = status == PaymentStatuses.PendingReview
            ? payments.OrderBy(p => p.SubmittedAt)
            : payments.OrderByDescending(p => p.SubmittedAt);
        return Ok(await ordered
            .Select(p => new PaymentQueueItem(
                p.Id, p.InvoiceId, p.DoctorId, p.Doctor.FullName, p.Doctor.FullNameEn, p.Invoice.MonthKey,
                p.Invoice.TotalDuePiasters, p.AmountPiasters, p.AmountPiasters != p.Invoice.TotalDuePiasters, p.SubmittedAt, p.Status))
            .ToPageAsync(query, cancellationToken));
    }

    /// <summary>AD8: one payment with the invoice summary and the earlier attempts on the same invoice.</summary>
    [HttpGet("payments/{paymentId:guid}")]
    public async Task<IActionResult> Payment(Guid paymentId, CancellationToken cancellationToken)
    {
        var payment = await db.Payments.AsNoTracking()
            .Where(p => p.Id == paymentId)
            .Select(p => new
            {
                p.InvoiceId,
                Line = new PaymentLine(
                    p.Id, p.AmountPiasters, p.TransferDate, p.Reference, p.SenderName, p.Note, p.Status, p.SubmittedAt,
                    p.ReviewedAt, p.RejectionReason, p.PaymentScreenshots.Count),
                Doctor = new InvoiceDoctorRef(p.DoctorId, p.Doctor.FullName, p.Doctor.FullNameEn, p.Doctor.Status),
                Invoice = new InvoiceSummary(
                    p.Invoice.Id, p.Invoice.MonthKey, p.Invoice.ExamCount, p.Invoice.ConsultationCount, p.Invoice.TotalDuePiasters,
                    p.Invoice.DueDate, p.Invoice.Status),
                p.SubmittedAt,
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (payment is null)
        {
            return this.NotFoundProblem();
        }

        var earlier = await db.Payments.AsNoTracking()
            .Where(p => p.InvoiceId == payment.InvoiceId && p.Id != paymentId && p.SubmittedAt < payment.SubmittedAt)
            .OrderByDescending(p => p.SubmittedAt)
            .Select(p => new PaymentLine(
                p.Id, p.AmountPiasters, p.TransferDate, p.Reference, p.SenderName, p.Note, p.Status, p.SubmittedAt,
                p.ReviewedAt, p.RejectionReason, p.PaymentScreenshots.Count))
            .ToListAsync(cancellationToken);
        return Ok(new PaymentReviewView(
            payment.Line, payment.Doctor, payment.Invoice, payment.Line.AmountPiasters != payment.Invoice.TotalDuePiasters, earlier));
    }

    /// <summary>One screenshot of a payment (AD8's viewer).</summary>
    [HttpGet("payments/{paymentId:guid}/screenshots/{number:int}")]
    public async Task<IActionResult> Screenshot(Guid paymentId, int number, CancellationToken cancellationToken)
    {
        var path = await db.PaymentScreenshots.AsNoTracking()
            .Where(s => s.PaymentId == paymentId && s.SortOrder == number)
            .Select(s => s.Path)
            .SingleOrDefaultAsync(cancellationToken);
        return await PaymentFiles.StreamAsync(this, storage, path, cancellationToken);
    }

    /// <summary>
    /// <c>reviewPayment</c> (BR-PAY3, BR-G2, BR-G3). Approve: the invoice is <c>paid</c> and the doctor is reactivated when
    /// none of their invoices is overdue. Reject: the invoice is <c>rejected</c>, or <c>overdue</c> with the doctor suspended
    /// at once when its due date has passed. A payment that was already reviewed answers 409 <c>PAYMENT_ALREADY_REVIEWED</c>.
    /// </summary>
    [HttpPost("reviewPayment")]
    public async Task<IActionResult> ReviewPayment(ReviewPaymentRequest request, CancellationToken cancellationToken)
    {
        var invoiceId = await db.Payments.AsNoTracking()
            .Where(p => p.Id == request.PaymentId)
            .Select(p => (Guid?)p.InvoiceId)
            .SingleOrDefaultAsync(cancellationToken);
        if (invoiceId is null)
        {
            return this.NotFoundProblem();
        }

        var approve = request.Action == "approve";
        var reason = approve ? null : Text.CollapseSpaces(request.Reason!);
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var invoice = (await billing.LockInvoiceAsync(invoiceId.Value, cancellationToken))!;
        var payment = await db.Payments.SingleAsync(p => p.Id == request.PaymentId, cancellationToken);
        if (payment.Status != PaymentStatuses.PendingReview)
        {
            return this.ConflictProblem(ErrorCodes.PaymentAlreadyReviewed, "This payment was already reviewed.")
                .WithFields(("status", payment.Status));
        }

        var now = Now;
        var admin = AdminId;
        payment.Status = approve ? PaymentStatuses.Approved : PaymentStatuses.Rejected;
        payment.ReviewedBy = admin;
        payment.ReviewedAt = now;
        payment.RejectionReason = reason;
        invoice.UpdatedAt = now;

        if (approve)
        {
            invoice.Status = InvoiceStatuses.Paid;
            invoice.PaidAt = now;
            invoice.PaidMethod = PaidMethods.InstaPay;
            invoice.ClosedBy = admin;
            billing.AddHistory(invoice, InvoiceStatuses.Paid, null, admin);
        }
        else if (invoice.DueDate < CairoTime.Today(time))
        {
            // BR-G2: rejected after the due date, so overdue and suspended straight away.
            billing.AddHistory(invoice, InvoiceStatuses.Rejected, reason, admin);
            await billing.MarkOverdueAsync(invoice, admin, cancellationToken);
        }
        else
        {
            invoice.Status = InvoiceStatuses.Rejected;
            billing.AddHistory(invoice, InvoiceStatuses.Rejected, reason, admin);
        }

        auditor.Add(
            approve ? AuditActions.PaymentApproved : AuditActions.PaymentRejected, AuditTargets.Payment, payment.Id,
            new { invoiceId = invoice.Id, monthKey = invoice.MonthKey, amountPiasters = payment.AmountPiasters, reason },
            doctorId: invoice.DoctorId);
        await NotifyClinicAsync(
            invoice.DoctorId,
            approve ? BillingNotifications.Approved(invoice.MonthKey) : BillingNotifications.Rejected(invoice.MonthKey, reason!),
            invoice.Id, cancellationToken);
        await db.SaveChangesAsync(cancellationToken);
        if (approve)
        {
            await billing.ReactivateIfClearAsync(invoice.DoctorId, cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        await InvalidateClinicAsync(invoice.DoctorId, cancellationToken);
        return Ok(State(invoice));
    }

    // -- AD9, AD10 --

    /// <summary>AD9: invoices by month, status and doctor, with the totals of the whole filtered set.</summary>
    [HttpGet("invoices")]
    public async Task<IActionResult> Invoices([FromQuery] InvoicesQuery query, CancellationToken cancellationToken)
    {
        var invoices = db.Invoices.AsNoTracking().AsQueryable();
        if (query.Month is not null)
        {
            invoices = invoices.Where(i => i.MonthKey == query.Month);
        }

        if (query.Status is not null)
        {
            invoices = invoices.Where(i => i.Status == query.Status);
        }

        if (query.DoctorId is { } doctorId)
        {
            invoices = invoices.Where(i => i.DoctorId == doctorId);
        }

        var totals = await invoices
            .GroupBy(_ => 1)
            .Select(g => new InvoiceTotals(g.Count(), g.Sum(i => i.ExamCount), g.Sum(i => i.ConsultationCount), g.Sum(i => i.TotalDuePiasters)))
            .SingleOrDefaultAsync(cancellationToken) ?? new InvoiceTotals(0, 0, 0, 0);
        var page = await invoices
            .OrderByDescending(i => i.MonthKey).ThenBy(i => i.Doctor.FullName)
            .Select(i => new AdminInvoiceItem(
                i.Id, i.DoctorId, i.Doctor.FullName, i.Doctor.FullNameEn, i.MonthKey, i.ExamCount, i.ConsultationCount,
                i.TotalDuePiasters, i.DueDate, i.Status))
            .ToPageAsync(query, cancellationToken);
        return Ok(new AdminInvoicesView(page, totals));
    }

    /// <summary>AD10: the breakdown, adjustments, payments and status history of one invoice.</summary>
    [HttpGet("invoices/{invoiceId:guid}")]
    public async Task<IActionResult> Invoice(Guid invoiceId, CancellationToken cancellationToken) =>
        await db.Invoices.AnyAsync(i => i.Id == invoiceId, cancellationToken)
            ? Ok(await InvoiceViews.DetailAsync(db, invoiceId, forAdmin: true, cancellationToken))
            : this.NotFoundProblem();

    /// <summary><c>adjustInvoice</c> (BR-PAY4): a signed amount and a reason; the total due must stay above zero.</summary>
    [HttpPost("adjustInvoice")]
    public Task<IActionResult> AdjustInvoice(AdjustInvoiceRequest request, CancellationToken cancellationToken) =>
        ChangeInvoiceAsync(
            request.InvoiceId!.Value,
            [InvoiceStatuses.Unpaid, InvoiceStatuses.Overdue, InvoiceStatuses.Rejected],
            async (invoice, now) =>
            {
                var amount = request.AmountPiasters!.Value;
                var total = (long)invoice.TotalDuePiasters + amount;
                if (total <= 0 || total > int.MaxValue)
                {
                    return this.Problem(StatusCodes.Status422UnprocessableEntity, ErrorCodes.AdjustmentInvalid, "The total due must stay above zero. Waive the invoice instead.");
                }

                var reason = Text.CollapseSpaces(request.Reason!);
                db.InvoiceAdjustments.Add(new InvoiceAdjustment
                {
                    Id = Guid.NewGuid(), InvoiceId = invoice.Id, AmountPiasters = amount, Reason = reason, CreatedBy = AdminId, CreatedAt = now,
                });
                invoice.AdjustmentsPiasters += amount;
                invoice.TotalDuePiasters = (int)total;
                billing.AddHistory(invoice, invoice.Status, $"adjusted {(amount > 0 ? "+" : "-")}{Money.Egp(Math.Abs(amount))}: {reason}", AdminId);
                auditor.Add(
                    AuditActions.InvoiceAdjusted, AuditTargets.Invoice, invoice.Id,
                    new { monthKey = invoice.MonthKey, amountPiasters = amount, totalDuePiasters = invoice.TotalDuePiasters, reason },
                    doctorId: invoice.DoctorId);
                await NotifyClinicAsync(invoice.DoctorId, BillingNotifications.Adjusted(invoice.MonthKey, invoice.TotalDuePiasters), invoice.Id, cancellationToken);
                return null;
            },
            cancellationToken);

    /// <summary><c>waiveInvoice</c> (BR-PAY4): the doctor owes nothing for the month. Reactivates a doctor suspended only for it.</summary>
    [HttpPost("waiveInvoice")]
    public Task<IActionResult> WaiveInvoice(WaiveInvoiceRequest request, CancellationToken cancellationToken) =>
        ChangeInvoiceAsync(
            request.InvoiceId!.Value,
            [InvoiceStatuses.Unpaid, InvoiceStatuses.Overdue, InvoiceStatuses.Rejected],
            async (invoice, now) =>
            {
                var reason = Text.CollapseSpaces(request.Reason!);
                invoice.Status = InvoiceStatuses.Waived;
                invoice.ClosedBy = AdminId;
                billing.AddHistory(invoice, InvoiceStatuses.Waived, reason, AdminId);
                auditor.Add(
                    AuditActions.InvoiceWaived, AuditTargets.Invoice, invoice.Id,
                    new { monthKey = invoice.MonthKey, totalDuePiasters = invoice.TotalDuePiasters, reason }, doctorId: invoice.DoctorId);
                await NotifyClinicAsync(invoice.DoctorId, BillingNotifications.Waived(invoice.MonthKey), invoice.Id, cancellationToken);
                return null;
            },
            cancellationToken,
            reactivate: true);

    /// <summary><c>markInvoicePaid</c> (BR-PAY4): money received outside the app (cash, bank transfer, InstaPay without a screenshot).</summary>
    [HttpPost("markInvoicePaid")]
    public Task<IActionResult> MarkInvoicePaid(MarkInvoicePaidRequest request, CancellationToken cancellationToken) =>
        ChangeInvoiceAsync(
            request.InvoiceId!.Value,
            [InvoiceStatuses.Unpaid, InvoiceStatuses.Overdue, InvoiceStatuses.Rejected],
            async (invoice, now) =>
            {
                var note = Text.CollapseSpaces(request.Note!);
                invoice.Status = InvoiceStatuses.Paid;
                invoice.PaidAt = now;
                invoice.PaidMethod = request.Method;
                invoice.ClosedBy = AdminId;
                billing.AddHistory(invoice, InvoiceStatuses.Paid, $"{request.Method}: {note}", AdminId);
                auditor.Add(
                    AuditActions.InvoiceMarkedPaid, AuditTargets.Invoice, invoice.Id,
                    new { monthKey = invoice.MonthKey, method = request.Method, totalDuePiasters = invoice.TotalDuePiasters, note },
                    doctorId: invoice.DoctorId);
                await NotifyClinicAsync(invoice.DoctorId, BillingNotifications.PaidManually(invoice.MonthKey), invoice.Id, cancellationToken);
                return null;
            },
            cancellationToken,
            reactivate: true);

    /// <summary>
    /// <c>extendInvoiceDueDate</c> (BR-B7, BR-PAY4): a later due date. An <c>overdue</c> invoice whose new date has not passed
    /// goes back to <c>unpaid</c>, and a doctor suspended only for it is reactivated.
    /// </summary>
    [HttpPost("extendInvoiceDueDate")]
    public Task<IActionResult> ExtendInvoiceDueDate(ExtendInvoiceDueDateRequest request, CancellationToken cancellationToken) =>
        ChangeInvoiceAsync(
            request.InvoiceId!.Value,
            [InvoiceStatuses.Unpaid, InvoiceStatuses.Overdue, InvoiceStatuses.Rejected],
            async (invoice, now) =>
            {
                var newDate = request.NewDueDate!.Value;
                var today = CairoTime.Today(time);
                if (newDate <= invoice.DueDate || newDate > today.AddDays(BillingLimits.MaxExtensionDays))
                {
                    return ValidationProblems.Field(HttpContext, "newDueDate", ErrorCodes.DueDateInvalid, "The new due date must be later than the current one, within a year.");
                }

                var reason = Text.CollapseSpaces(request.Reason!);
                var before = invoice.DueDate;
                invoice.DueDate = newDate;
                var note = $"due date {before:yyyy-MM-dd} → {newDate:yyyy-MM-dd}: {reason}";
                if (invoice.Status == InvoiceStatuses.Overdue && newDate >= today)
                {
                    invoice.Status = InvoiceStatuses.Unpaid;
                }

                billing.AddHistory(invoice, invoice.Status, note, AdminId);
                auditor.Add(
                    AuditActions.InvoiceDueDateExtended, AuditTargets.Invoice, invoice.Id,
                    new { monthKey = invoice.MonthKey, before, after = newDate, reason }, doctorId: invoice.DoctorId);
                await NotifyClinicAsync(invoice.DoctorId, BillingNotifications.DueDateExtended(invoice.MonthKey, newDate), invoice.Id, cancellationToken);
                return null;
            },
            cancellationToken,
            reactivate: true);

    // -- Helpers --

    /// <summary>
    /// One invoice action in a transaction: the invoice is locked, its status must be one of <paramref name="allowed"/>
    /// (409 <c>INVOICE_STATUS_INVALID</c> otherwise), <paramref name="change"/> changes it (or returns the problem to answer),
    /// and the doctor is reactivated when <paramref name="reactivate"/> and none of their invoices is still overdue.
    /// </summary>
    private async Task<IActionResult> ChangeInvoiceAsync(
        Guid invoiceId,
        string[] allowed,
        Func<Invoice, DateTime, Task<IActionResult?>> change,
        CancellationToken cancellationToken,
        bool reactivate = false)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var invoice = await billing.LockInvoiceAsync(invoiceId, cancellationToken);
        if (invoice is null)
        {
            return this.NotFoundProblem();
        }

        if (!allowed.Contains(invoice.Status))
        {
            return this.ConflictProblem(ErrorCodes.InvoiceStatusInvalid, "This invoice's status doesn't allow this action.")
                .WithFields(("status", invoice.Status));
        }

        var now = Now;
        if (await change(invoice, now) is { } problem)
        {
            return problem;
        }

        invoice.UpdatedAt = now;
        await db.SaveChangesAsync(cancellationToken);
        if (reactivate)
        {
            await billing.ReactivateIfClearAsync(invoice.DoctorId, cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        await InvalidateClinicAsync(invoice.DoctorId, cancellationToken);
        return Ok(State(invoice));
    }

    private static InvoiceStateView State(Invoice invoice) =>
        new(invoice.Id, invoice.Status, invoice.TotalDuePiasters, invoice.DueDate);

    /// <summary>The doctor and the assistants who see billing.</summary>
    private async Task NotifyClinicAsync(Guid doctorId, NotificationText text, Guid invoiceId, CancellationToken cancellationToken)
    {
        var data = new { invoiceId };
        notifications.Add(doctorId, text, "/billing", data);
        foreach (var assistantId in await billing.BillingAssistantsAsync(doctorId, cancellationToken))
        {
            notifications.Add(assistantId, text, "/billing", data);
        }
    }

    private async Task InvalidateClinicAsync(Guid doctorId, CancellationToken cancellationToken)
    {
        stateCache.Invalidate(doctorId);
        foreach (var assistantId in await billing.ActiveAssistantsAsync(doctorId, cancellationToken))
        {
            stateCache.Invalidate(assistantId);
        }
    }
}
