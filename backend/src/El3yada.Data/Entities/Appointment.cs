using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Appointment
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public Guid BranchId { get; set; }

    public Guid? PatientId { get; set; }

    public string? GuestName { get; set; }

    public string? GuestPhone { get; set; }

    public string VisitType { get; set; } = null!;

    public string Mode { get; set; } = null!;

    public DateOnly LocalDate { get; set; }

    public TimeOnly PeriodStartLocal { get; set; }

    public DateTime StartUtc { get; set; }

    public DateTime? EndUtc { get; set; }

    public int? QueueNumber { get; set; }

    public string Status { get; set; } = null!;

    public int BoardOrder { get; set; }

    public bool IsPriority { get; set; }

    public string? PriorityReason { get; set; }

    public string Source { get; set; } = null!;

    public Guid BookedBy { get; set; }

    public string BookedByRole { get; set; } = null!;

    public string? Reason { get; set; }

    public string? StaffNotes { get; set; }

    public bool Overbooked { get; set; }

    public int RescheduleCount { get; set; }

    public DateTime? CheckedInAt { get; set; }

    public DateTime? CalledAt { get; set; }

    public Guid? SessionId { get; set; }

    public string? RejectReason { get; set; }

    public DateTime? CancelledAt { get; set; }

    public string? CancelledByRole { get; set; }

    public string? CancelReason { get; set; }

    public DateTime? NoShowAt { get; set; }

    public bool FlaggedNoSession { get; set; }

    public string RemindersSentJson { get; set; } = "[]";

    public DateTime? AttendanceConfirmedAt { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual ICollection<AppointmentHistory> AppointmentHistories { get; set; } = new List<AppointmentHistory>();

    public virtual User BookedByNavigation { get; set; } = null!;

    public virtual Branch Branch { get; set; } = null!;

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual Patient? Patient { get; set; }

    public virtual Session? Session { get; set; }

    public virtual Session? SessionNavigation { get; set; }
}
