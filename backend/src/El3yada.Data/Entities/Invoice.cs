using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Invoice
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public string MonthKey { get; set; } = null!;

    public DateOnly PeriodStart { get; set; }

    public DateOnly PeriodEnd { get; set; }

    public int ExamCount { get; set; }

    public int ConsultationCount { get; set; }

    public int ExamAmountPiasters { get; set; }

    public int ConsultationAmountPiasters { get; set; }

    public int AdjustmentsPiasters { get; set; }

    public int TotalDuePiasters { get; set; }

    public DateOnly DueDate { get; set; }

    public string Status { get; set; } = "unpaid";

    public DateTime? PaidAt { get; set; }

    public string? PaidMethod { get; set; }

    public Guid? ClosedBy { get; set; }

    /// <summary>
    /// A final invoice: the month closed early because the doctor asked to delete their account (BR-DEL8).
    /// <see cref="PeriodEnd"/> is that day. Fees of the month's sessions saved after it are carried into the doctor's
    /// next invoice as an adjustment (<see cref="InvoiceAdjustment.CarriedMonthKey"/>, BR-DEL10).
    /// </summary>
    public bool IsFinal { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual User? ClosedByNavigation { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual ICollection<InvoiceAdjustment> InvoiceAdjustments { get; set; } = new List<InvoiceAdjustment>();

    public virtual ICollection<InvoiceBranchBreakdown> InvoiceBranchBreakdowns { get; set; } = new List<InvoiceBranchBreakdown>();

    public virtual ICollection<InvoiceStatusHistory> InvoiceStatusHistories { get; set; } = new List<InvoiceStatusHistory>();

    public virtual ICollection<Payment> Payments { get; set; } = new List<Payment>();
}
