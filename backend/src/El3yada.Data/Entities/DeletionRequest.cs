using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

/// <summary>
/// One account deletion (spec 6.17, BR-DEL1 to BR-DEL12), for any role. The account is disabled when the row is
/// made and erased by the daily job once <see cref="ScheduledFor"/> has passed (and, for a doctor, every invoice is
/// paid). Status: <c>scheduled</c>, then <c>waitingPayment</c> (a doctor whose grace period ended with invoices to
/// pay), then <c>completed</c>; or <c>restored</c> when the user or an admin cancels it. Rows are kept after erasure.
/// </summary>
public partial class DeletionRequest
{
    public Guid Id { get; set; }

    /// <summary>The account being deleted.</summary>
    public Guid UserId { get; set; }

    /// <summary>Users.Role of <see cref="UserId"/> when the deletion started.</summary>
    public string Role { get; set; } = null!;

    /// <summary>Set for a patient account (Patients.Id).</summary>
    public Guid? PatientId { get; set; }

    /// <summary>Set for a doctor account (Doctors.UserId).</summary>
    public Guid? DoctorId { get; set; }

    /// <summary>Set for an assistant account (Assistants.UserId).</summary>
    public Guid? AssistantId { get; set; }

    /// <summary>The user's optional reason, or the admin's reason for a deletion they started.</summary>
    public string? Reason { get; set; }

    public string Status { get; set; } = "scheduled";

    /// <summary>Who started it: the user themself, or an admin (a support case).</summary>
    public Guid RequestedBy { get; set; }

    public DateTime RequestedAt { get; set; }

    /// <summary>When the identity may be erased: <see cref="RequestedAt"/> plus AppSettings.AccountDeletionGraceDays.</summary>
    public DateTime ScheduledFor { get; set; }

    public DateTime? RestoredAt { get; set; }

    public Guid? RestoredBy { get; set; }

    /// <summary>The admin's reason when they cancelled the deletion.</summary>
    public string? RestoreReason { get; set; }

    public DateTime? CompletedAt { get; set; }

    /// <summary>A doctor's final invoice, issued when the deletion started (BR-DEL8), when there were fees to bill.</summary>
    public Guid? FinalInvoiceId { get; set; }

    public virtual User User { get; set; } = null!;

    public virtual User RequestedByNavigation { get; set; } = null!;

    public virtual User? RestoredByNavigation { get; set; }

    public virtual Patient? Patient { get; set; }

    public virtual Doctor? Doctor { get; set; }

    public virtual Assistant? Assistant { get; set; }

    public virtual Invoice? FinalInvoice { get; set; }
}
