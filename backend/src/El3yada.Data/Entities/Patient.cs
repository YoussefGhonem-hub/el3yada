using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Patient
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string FullName { get; set; } = null!;

    public string Phone { get; set; } = null!;

    public string Gender { get; set; } = null!;

    public DateOnly DateOfBirth { get; set; }

    public bool DateOfBirthEstimated { get; set; }

    public string? NationalId { get; set; }

    public string? Address { get; set; }

    public string? BloodType { get; set; }

    public string? EmergencyContactName { get; set; }

    public string? EmergencyContactPhone { get; set; }

    public Guid? CreatedByDoctorId { get; set; }

    public string Status { get; set; } = "active";

    public DateTime? DeletedAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();

    public virtual ICollection<AuditLog> AuditLogs { get; set; } = new List<AuditLog>();

    public virtual ICollection<Chat> Chats { get; set; } = new List<Chat>();

    public virtual Doctor? CreatedByDoctor { get; set; }

    public virtual ICollection<DeletionRequest> DeletionRequests { get; set; } = new List<DeletionRequest>();

    public virtual ICollection<DoctorPatient> DoctorPatients { get; set; } = new List<DoctorPatient>();

    public virtual ICollection<MedicalRecord> MedicalRecords { get; set; } = new List<MedicalRecord>();

    public virtual ICollection<Prescription> Prescriptions { get; set; } = new List<Prescription>();

    public virtual ICollection<Session> Sessions { get; set; } = new List<Session>();

    public virtual User User { get; set; } = null!;
}
