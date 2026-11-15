using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class DoctorPatient
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public Guid PatientId { get; set; }

    public int FileNumber { get; set; }

    public string PatientName { get; set; } = null!;

    public string PatientPhone { get; set; } = null!;

    public string SearchName { get; set; } = null!;

    public string? FamilyHistory { get; set; }

    public string? ProfileNotes { get; set; }

    public DateTime? FirstSessionAt { get; set; }

    public Guid? LastSessionId { get; set; }

    public string? LastSessionType { get; set; }

    public DateTime? LastSessionAt { get; set; }

    public Guid? LastSessionBranchId { get; set; }

    public int SessionCount { get; set; }

    public int ExamCount { get; set; }

    public int ConsultationCount { get; set; }

    public int ConsultationsSinceExam { get; set; }

    public bool Archived { get; set; }

    public DateTime? ArchivedAt { get; set; }

    public bool SelfBookingBlocked { get; set; }

    public string? SelfBookingBlockedReason { get; set; }

    public DateTime LinkedAt { get; set; }

    public Guid LinkedBy { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual Chat? Chat { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual Session? LastSession { get; set; }

    public virtual Branch? LastSessionBranch { get; set; }

    public virtual User LinkedByNavigation { get; set; } = null!;

    public virtual Patient Patient { get; set; } = null!;

    public virtual ICollection<PatientMedicalProfileItem> PatientMedicalProfileItems { get; set; } = new List<PatientMedicalProfileItem>();

    public virtual ICollection<Session> Sessions { get; set; } = new List<Session>();
}
