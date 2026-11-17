using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Doctor
{
    public Guid UserId { get; set; }

    public string FullName { get; set; } = null!;

    public string? FullNameEn { get; set; }

    public string Title { get; set; } = null!;

    public string? TitleEn { get; set; }

    public string? DegreesAr { get; set; }

    public string? DegreesEn { get; set; }

    public Guid SpecialtyId { get; set; }

    public string LicenseNumber { get; set; } = null!;

    public string LicenseDocPath { get; set; } = null!;

    public Guid? DefaultBranchId { get; set; }

    public int? ExaminationPricePiasters { get; set; }

    public int? ConsultationPricePiasters { get; set; }

    public string? RxLogoPath { get; set; }

    public string? RxSignaturePath { get; set; }

    public string? RxFooterText { get; set; }

    public string RxLanguage { get; set; } = "ar";

    public string RxAccentColor { get; set; } = "#0B5C8E";

    public string RxPaperSize { get; set; } = "A5";

    public decimal? RxCustomWidthMm { get; set; }

    public decimal? RxCustomHeightMm { get; set; }

    public bool RxPreprinted { get; set; }

    public decimal? RxMarginTopMm { get; set; }

    public decimal? RxMarginBottomMm { get; set; }

    public string Status { get; set; } = "pendingApproval";

    public string? StatusReason { get; set; }

    public DateTime? StatusChangedAt { get; set; }

    public DateTime? ApprovedAt { get; set; }

    public Guid? ApprovedBy { get; set; }

    /// <summary>
    /// When the free trial ends (UTC, spec 6.16 BR-T1): the approval time plus AppSettings.TrialDays. Null when
    /// there is no trial: the service is active (approved before the trial existed, or activated by an admin).
    /// </summary>
    public DateTime? TrialEndsAt { get; set; }

    public int NextFileNumber { get; set; } = 1;

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();

    public virtual User? ApprovedByNavigation { get; set; }

    public virtual ICollection<Assistant> Assistants { get; set; } = new List<Assistant>();

    public virtual ICollection<AuditLog> AuditLogs { get; set; } = new List<AuditLog>();

    /// <summary>Every branch of the doctor (BR-BR1). One of them is <see cref="DefaultBranch"/>.</summary>
    public virtual ICollection<Branch> Branches { get; set; } = new List<Branch>();

    public virtual ICollection<BranchClosure> BranchClosures { get; set; } = new List<BranchClosure>();

    public virtual ICollection<CatalogReport> CatalogReports { get; set; } = new List<CatalogReport>();

    public virtual ICollection<Chat> Chats { get; set; } = new List<Chat>();

    public virtual ICollection<DailyStat> DailyStats { get; set; } = new List<DailyStat>();

    public virtual Branch? DefaultBranch { get; set; }

    public virtual ICollection<DoctorAdminNote> DoctorAdminNotes { get; set; } = new List<DoctorAdminNote>();

    public virtual ICollection<DoctorDailyMetric> DoctorDailyMetrics { get; set; } = new List<DoctorDailyMetric>();

    public virtual ICollection<DoctorItemHistory> DoctorItemHistories { get; set; } = new List<DoctorItemHistory>();

    public virtual ICollection<DoctorPatient> DoctorPatients { get; set; } = new List<DoctorPatient>();

    public virtual ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();

    public virtual ICollection<MedicalRecord> MedicalRecords { get; set; } = new List<MedicalRecord>();

    public virtual ICollection<MonthlyStat> MonthlyStats { get; set; } = new List<MonthlyStat>();

    public virtual ICollection<Patient> Patients { get; set; } = new List<Patient>();

    public virtual ICollection<Payment> Payments { get; set; } = new List<Payment>();

    public virtual ICollection<PrescriptionTemplate> PrescriptionTemplates { get; set; } = new List<PrescriptionTemplate>();

    public virtual ICollection<Prescription> Prescriptions { get; set; } = new List<Prescription>();

    public virtual ICollection<PriceHistory> PriceHistories { get; set; } = new List<PriceHistory>();

    public virtual ICollection<Session> Sessions { get; set; } = new List<Session>();

    public virtual Specialty Specialty { get; set; } = null!;

    public virtual User User { get; set; } = null!;

    public virtual ICollection<Specialty> Specialties { get; set; } = new List<Specialty>();
}
