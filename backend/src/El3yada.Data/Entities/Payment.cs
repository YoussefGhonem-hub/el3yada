using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Payment
{
    public Guid Id { get; set; }

    public Guid InvoiceId { get; set; }

    public Guid DoctorId { get; set; }

    public int AmountPiasters { get; set; }

    public DateOnly TransferDate { get; set; }

    public string? Reference { get; set; }

    public string? SenderName { get; set; }

    public string? Note { get; set; }

    public string Status { get; set; } = "pendingReview";

    public Guid SubmittedBy { get; set; }

    public DateTime SubmittedAt { get; set; }

    public Guid? ReviewedBy { get; set; }

    public DateTime? ReviewedAt { get; set; }

    public string? RejectionReason { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual Invoice Invoice { get; set; } = null!;

    public virtual ICollection<PaymentScreenshot> PaymentScreenshots { get; set; } = new List<PaymentScreenshot>();

    public virtual User? ReviewedByNavigation { get; set; }

    public virtual User SubmittedByNavigation { get; set; } = null!;
}
