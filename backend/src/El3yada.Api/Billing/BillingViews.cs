using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Billing;

/// <summary>One row of the doctor's invoice list (D18). Amounts are piasters; dates are Cairo's.</summary>
public sealed record InvoiceListItem(
    Guid Id,
    string MonthKey,
    DateOnly PeriodStart,
    DateOnly PeriodEnd,
    int ExamCount,
    int ConsultationCount,
    int ExamAmountPiasters,
    int ConsultationAmountPiasters,
    int AdjustmentsPiasters,
    int TotalDuePiasters,
    DateOnly DueDate,
    string Status,
    bool CanPay,
    DateTime? PaidAt,
    bool IsFinal = false);

/// <summary>
/// D18 / D1 card. <c>attention</c> is the invoice to pay first, <c>underReview</c> the one with a payment waiting,
/// <c>outstandingPiasters</c> what is still owed, and <c>suspension</c> is set while the doctor is suspended (BR-G5):
/// <c>monthKey</c> is the unpaid month when the cause is billing.
/// </summary>
public sealed record InvoiceListView(
    IReadOnlyList<InvoiceListItem> Items,
    InvoiceListItem? Attention,
    InvoiceListItem? UnderReview,
    int OutstandingPiasters,
    SuspensionView? Suspension);

public sealed record SuspensionView(string? MonthKey, bool Billing);

public sealed record PaymentInfoView(string? InstapayAddress, string? InstapayAccountName, string? InstructionsAr, string? InstructionsEn);

public sealed record PaymentSubmittedView(Guid PaymentId, Guid InvoiceId, string InvoiceStatus);

public sealed record InvoiceBranchLine(Guid BranchId, string NameAr, string? NameEn, int ExamCount, int ConsultationCount, int AmountPiasters);

/// <summary>
/// An adjustment line. <c>carriedMonthKey</c> is set on a line the system added for sessions saved after a final invoice of
/// that month (BR-DEL10); the app shows its own text for it.
/// </summary>
public sealed record InvoiceAdjustmentLine(Guid Id, int AmountPiasters, string Reason, DateTime CreatedAt, string? CarriedMonthKey = null);

public sealed record InvoiceTimelineLine(string Status, string? Note, DateTime ChangedAt, string? ChangedByRole);

/// <summary>A payment attempt (D19, AD8). <c>screenshots</c> is how many images to fetch by number (1 to n).</summary>
public sealed record PaymentLine(
    Guid Id,
    int AmountPiasters,
    DateOnly TransferDate,
    string? Reference,
    string? SenderName,
    string? Note,
    string Status,
    DateTime SubmittedAt,
    DateTime? ReviewedAt,
    string? RejectionReason,
    int Screenshots);

/// <summary>
/// D19 (doctor) and AD10 (admin): the whole invoice. <c>doctor</c> is filled for the admin only. An invoice carries fee
/// snapshots, never patient data or the clinic's own revenue (BR-REV1).
/// </summary>
public sealed record InvoiceDetailView(
    Guid Id,
    string MonthKey,
    DateOnly PeriodStart,
    DateOnly PeriodEnd,
    int ExamCount,
    int ConsultationCount,
    int ExamAmountPiasters,
    int ConsultationAmountPiasters,
    int AdjustmentsPiasters,
    int TotalDuePiasters,
    DateOnly DueDate,
    string Status,
    bool CanPay,
    DateTime? PaidAt,
    string? PaidMethod,
    IReadOnlyList<InvoiceBranchLine> Branches,
    IReadOnlyList<InvoiceAdjustmentLine> Adjustments,
    IReadOnlyList<InvoiceTimelineLine> Timeline,
    IReadOnlyList<PaymentLine> Payments,
    InvoiceDoctorRef? Doctor,
    bool IsFinal = false);

public sealed record InvoiceDoctorRef(Guid Id, string Name, string? NameEn, string Status);

public static class InvoiceViews
{
    public static async Task<InvoiceDetailView> DetailAsync(AppDbContext db, Guid invoiceId, bool forAdmin, CancellationToken cancellationToken)
    {
        var invoice = await db.Invoices.AsNoTracking()
            .Where(i => i.Id == invoiceId)
            .Select(i => new
            {
                i.Id, i.MonthKey, i.PeriodStart, i.PeriodEnd, i.ExamCount, i.ConsultationCount, i.ExamAmountPiasters,
                i.ConsultationAmountPiasters, i.AdjustmentsPiasters, i.TotalDuePiasters, i.DueDate, i.Status, i.PaidAt, i.PaidMethod,
                i.IsFinal,
                Doctor = new InvoiceDoctorRef(i.DoctorId, i.Doctor.FullName, i.Doctor.FullNameEn, i.Doctor.Status),
            })
            .SingleAsync(cancellationToken);

        var branches = await db.InvoiceBranchBreakdowns.AsNoTracking()
            .Where(b => b.InvoiceId == invoiceId)
            .OrderByDescending(b => b.AmountPiasters)
            .Select(b => new InvoiceBranchLine(b.BranchId, b.Branch.NameAr, b.Branch.NameEn, b.ExamCount, b.ConsultationCount, b.AmountPiasters))
            .ToListAsync(cancellationToken);
        var adjustments = await db.InvoiceAdjustments.AsNoTracking()
            .Where(a => a.InvoiceId == invoiceId)
            .OrderBy(a => a.CreatedAt)
            .Select(a => new InvoiceAdjustmentLine(a.Id, a.AmountPiasters, a.Reason, a.CreatedAt, a.CarriedMonthKey))
            .ToListAsync(cancellationToken);
        var timeline = await db.InvoiceStatusHistories.AsNoTracking()
            .Where(h => h.InvoiceId == invoiceId)
            .OrderBy(h => h.ChangedAt).ThenBy(h => h.Id)
            .Select(h => new InvoiceTimelineLine(h.Status, h.Note, h.ChangedAt, h.ChangedByNavigation == null ? "system" : h.ChangedByNavigation.Role))
            .ToListAsync(cancellationToken);
        var payments = await db.Payments.AsNoTracking()
            .Where(p => p.InvoiceId == invoiceId)
            .OrderByDescending(p => p.SubmittedAt)
            .Select(p => new PaymentLine(
                p.Id, p.AmountPiasters, p.TransferDate, p.Reference, p.SenderName, p.Note, p.Status, p.SubmittedAt, p.ReviewedAt,
                p.RejectionReason, p.PaymentScreenshots.Count))
            .ToListAsync(cancellationToken);

        return new InvoiceDetailView(
            invoice.Id, invoice.MonthKey, invoice.PeriodStart, invoice.PeriodEnd, invoice.ExamCount, invoice.ConsultationCount,
            invoice.ExamAmountPiasters, invoice.ConsultationAmountPiasters, invoice.AdjustmentsPiasters, invoice.TotalDuePiasters,
            invoice.DueDate, invoice.Status, InvoiceStatuses.Payable(invoice.Status), invoice.PaidAt, invoice.PaidMethod,
            branches, adjustments, timeline, payments, forAdmin ? invoice.Doctor : null, invoice.IsFinal);
    }
}
