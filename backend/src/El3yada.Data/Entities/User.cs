using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class User
{
    public Guid Id { get; set; }

    public string Role { get; set; } = null!;

    public string? AdminRole { get; set; }

    public string Status { get; set; } = "active";

    public string DisplayName { get; set; } = null!;

    public string? Phone { get; set; }

    public string? Email { get; set; }

    public DateTime? EmailVerifiedAt { get; set; }

    public string? PasswordHash { get; set; }

    public Guid SecurityStamp { get; set; }

    public bool MustChangePassword { get; set; }

    public int AccessFailedCount { get; set; }

    public DateTime? LockoutEndAt { get; set; }

    public string Locale { get; set; } = "ar";

    public string ThemeMode { get; set; } = "system";

    public bool NotifyChat { get; set; } = true;

    public bool NotifyReminders { get; set; } = true;

    public bool NotifyShowPreview { get; set; }

    public bool NotifyBookings { get; set; }

    public DateTime? AcceptedTermsAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public DateTime? LastLoginAt { get; set; }

    public virtual ICollection<AppSetting> AppSettings { get; set; } = new List<AppSetting>();

    public virtual ICollection<AppointmentHistory> AppointmentHistories { get; set; } = new List<AppointmentHistory>();

    public virtual ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();

    public virtual ICollection<Assistant> AssistantCreatedByNavigations { get; set; } = new List<Assistant>();

    public virtual Assistant? AssistantUser { get; set; }

    public virtual ICollection<AuditLog> AuditLogs { get; set; } = new List<AuditLog>();

    public virtual ICollection<BranchClosure> BranchClosures { get; set; } = new List<BranchClosure>();

    public virtual ICollection<BranchDateOverride> BranchDateOverrides { get; set; } = new List<BranchDateOverride>();

    public virtual ICollection<CatalogCustomItem> CatalogCustomItems { get; set; } = new List<CatalogCustomItem>();

    public virtual ICollection<CatalogReport> CatalogReports { get; set; } = new List<CatalogReport>();

    public virtual ICollection<CatalogVersion> CatalogVersions { get; set; } = new List<CatalogVersion>();

    public virtual ICollection<ChatMessage> ChatMessages { get; set; } = new List<ChatMessage>();

    public virtual ICollection<ChatReadState> ChatReadStates { get; set; } = new List<ChatReadState>();

    public virtual ICollection<Chat> Chats { get; set; } = new List<Chat>();

    public virtual ICollection<DeletionRequest> DeletionRequests { get; set; } = new List<DeletionRequest>();

    public virtual ICollection<DoctorAdminNote> DoctorAdminNotes { get; set; } = new List<DoctorAdminNote>();

    public virtual ICollection<Doctor> DoctorApprovedByNavigations { get; set; } = new List<Doctor>();

    public virtual ICollection<DoctorPatient> DoctorPatients { get; set; } = new List<DoctorPatient>();

    public virtual Doctor? DoctorUser { get; set; }

    public virtual ICollection<InvoiceAdjustment> InvoiceAdjustments { get; set; } = new List<InvoiceAdjustment>();

    public virtual ICollection<InvoiceStatusHistory> InvoiceStatusHistories { get; set; } = new List<InvoiceStatusHistory>();

    public virtual ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();

    public virtual ICollection<MedicalRecord> MedicalRecordCreatedByNavigations { get; set; } = new List<MedicalRecord>();

    public virtual ICollection<MedicalRecord> MedicalRecordDeletedByNavigations { get; set; } = new List<MedicalRecord>();

    public virtual ICollection<Notification> Notifications { get; set; } = new List<Notification>();

    public virtual Patient? Patient { get; set; }

    public virtual ICollection<PatientMedicalProfileItem> PatientMedicalProfileItems { get; set; } = new List<PatientMedicalProfileItem>();

    public virtual ICollection<Payment> PaymentReviewedByNavigations { get; set; } = new List<Payment>();

    public virtual ICollection<Payment> PaymentSubmittedByNavigations { get; set; } = new List<Payment>();

    public virtual ICollection<Prescription> Prescriptions { get; set; } = new List<Prescription>();

    public virtual ICollection<PriceHistory> PriceHistories { get; set; } = new List<PriceHistory>();

    public virtual ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();

    public virtual ICollection<Session> SessionCreatedByNavigations { get; set; } = new List<Session>();

    public virtual ICollection<Session> SessionDeletedByNavigations { get; set; } = new List<Session>();

    public virtual ICollection<SettingsHistory> SettingsHistories { get; set; } = new List<SettingsHistory>();

    public virtual ICollection<UserDevice> UserDevices { get; set; } = new List<UserDevice>();

    public virtual ICollection<UserToken> UserTokens { get; set; } = new List<UserToken>();
}
