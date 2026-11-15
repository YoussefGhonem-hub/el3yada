using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Session
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public Guid PatientId { get; set; }

    public Guid LinkId { get; set; }

    public Guid BranchId { get; set; }

    public Guid? AppointmentId { get; set; }

    public string Type { get; set; } = null!;

    public int FeePiasters { get; set; }

    public int PatientFeePiasters { get; set; }

    public int? ListPricePiasters { get; set; }

    public string? PaymentMethod { get; set; }

    public DateOnly DayKey { get; set; }

    public string MonthKey { get; set; } = null!;

    public Guid CreatedBy { get; set; }

    public string CreatedByRole { get; set; } = null!;

    public bool AwaitingDoctor { get; set; }

    public string? ChiefComplaint { get; set; }

    public string? Findings { get; set; }

    public short? BpSys { get; set; }

    public short? BpDia { get; set; }

    public short? Pulse { get; set; }

    public decimal? TempC { get; set; }

    public decimal? WeightKg { get; set; }

    public decimal? HeightCm { get; set; }

    public short? Glucose { get; set; }

    public string? Diagnosis { get; set; }

    public string? PatientNotes { get; set; }

    public DateOnly? FollowUpDate { get; set; }

    public DateTime? PatientSeenAt { get; set; }

    public bool Deleted { get; set; }

    public DateTime? DeletedAt { get; set; }

    public Guid? DeletedBy { get; set; }

    public string? DeleteReason { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual Appointment? Appointment { get; set; }

    public virtual ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();

    public virtual Branch Branch { get; set; } = null!;

    public virtual User CreatedByNavigation { get; set; } = null!;

    public virtual User? DeletedByNavigation { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual ICollection<DoctorPatient> DoctorPatients { get; set; } = new List<DoctorPatient>();

    public virtual DoctorPatient Link { get; set; } = null!;

    public virtual ICollection<MedicalRecord> MedicalRecords { get; set; } = new List<MedicalRecord>();

    public virtual Patient Patient { get; set; } = null!;

    public virtual ICollection<Prescription> Prescriptions { get; set; } = new List<Prescription>();

    public virtual SessionPrivateNote? SessionPrivateNote { get; set; }
}
