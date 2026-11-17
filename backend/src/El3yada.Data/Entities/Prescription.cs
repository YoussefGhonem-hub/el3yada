using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Prescription
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public Guid PatientId { get; set; }

    public Guid SessionId { get; set; }

    public string Kind { get; set; } = null!;

    public string? Diagnosis { get; set; }

    public string? Advice { get; set; }

    /// <summary>
    /// Zone 6 of the printed page (spec 6.4.1): «موعد المتابعة» on a medication prescription, «إحضار النتائج في» on
    /// an investigations request. Optional.
    /// </summary>
    public DateOnly? FollowUpDate { get; set; }

    public string Status { get; set; } = "draft";

    public Guid? PreparedBy { get; set; }

    public string? PreparedByRole { get; set; }

    public string? PdfPath { get; set; }

    public DateTime? SentAt { get; set; }

    public DateTime? CancelledAt { get; set; }

    public string? CancelReason { get; set; }

    public Guid? ReplacesRxId { get; set; }

    public string QrShortCode { get; set; } = null!;

    public DateTime? PatientSeenAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual ICollection<Prescription> InverseReplacesRx { get; set; } = new List<Prescription>();

    public virtual Patient Patient { get; set; } = null!;

    public virtual User? PreparedByNavigation { get; set; }

    public virtual ICollection<PrescriptionInvestigationItem> PrescriptionInvestigationItems { get; set; } = new List<PrescriptionInvestigationItem>();

    public virtual ICollection<PrescriptionMedicationItem> PrescriptionMedicationItems { get; set; } = new List<PrescriptionMedicationItem>();

    public virtual Prescription? ReplacesRx { get; set; }

    public virtual Session Session { get; set; } = null!;
}
