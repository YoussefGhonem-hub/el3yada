using System;
using System.Collections.Generic;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Data;

public partial class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<AppSetting> AppSettings { get; set; }

    public virtual DbSet<Appointment> Appointments { get; set; }

    public virtual DbSet<AppointmentHistory> AppointmentHistories { get; set; }

    public virtual DbSet<Assistant> Assistants { get; set; }

    public virtual DbSet<AuditLog> AuditLogs { get; set; }

    public virtual DbSet<Branch> Branches { get; set; }

    public virtual DbSet<BranchClosure> BranchClosures { get; set; }

    public virtual DbSet<BranchDateOverride> BranchDateOverrides { get; set; }

    public virtual DbSet<BranchDateOverridePeriod> BranchDateOverridePeriods { get; set; }

    public virtual DbSet<BranchDayState> BranchDayStates { get; set; }

    public virtual DbSet<BranchPeriod> BranchPeriods { get; set; }

    public virtual DbSet<BranchPhone> BranchPhones { get; set; }

    public virtual DbSet<BranchPhoto> BranchPhotos { get; set; }

    public virtual DbSet<CatalogCustomItem> CatalogCustomItems { get; set; }

    public virtual DbSet<CatalogReport> CatalogReports { get; set; }

    public virtual DbSet<CatalogVersion> CatalogVersions { get; set; }

    public virtual DbSet<Chat> Chats { get; set; }

    public virtual DbSet<ChatMessage> ChatMessages { get; set; }

    public virtual DbSet<ChatReadState> ChatReadStates { get; set; }

    public virtual DbSet<DailyStat> DailyStats { get; set; }

    public virtual DbSet<DeletionRequest> DeletionRequests { get; set; }

    public virtual DbSet<Doctor> Doctors { get; set; }

    public virtual DbSet<DoctorAdminNote> DoctorAdminNotes { get; set; }

    public virtual DbSet<DoctorDailyMetric> DoctorDailyMetrics { get; set; }

    public virtual DbSet<DoctorItemHistory> DoctorItemHistories { get; set; }

    public virtual DbSet<DoctorPatient> DoctorPatients { get; set; }

    public virtual DbSet<Invoice> Invoices { get; set; }

    public virtual DbSet<InvoiceAdjustment> InvoiceAdjustments { get; set; }

    public virtual DbSet<InvoiceBranchBreakdown> InvoiceBranchBreakdowns { get; set; }

    public virtual DbSet<InvoiceStatusHistory> InvoiceStatusHistories { get; set; }

    public virtual DbSet<MedicalRecord> MedicalRecords { get; set; }

    public virtual DbSet<MedicalRecordAttachment> MedicalRecordAttachments { get; set; }

    public virtual DbSet<MonthlyStat> MonthlyStats { get; set; }

    public virtual DbSet<Notification> Notifications { get; set; }

    public virtual DbSet<Patient> Patients { get; set; }

    public virtual DbSet<PatientMedicalProfileItem> PatientMedicalProfileItems { get; set; }

    public virtual DbSet<Payment> Payments { get; set; }

    public virtual DbSet<PaymentScreenshot> PaymentScreenshots { get; set; }

    public virtual DbSet<Prescription> Prescriptions { get; set; }

    public virtual DbSet<PrescriptionInvestigationItem> PrescriptionInvestigationItems { get; set; }

    public virtual DbSet<PrescriptionMedicationItem> PrescriptionMedicationItems { get; set; }

    public virtual DbSet<PrescriptionTemplate> PrescriptionTemplates { get; set; }

    public virtual DbSet<PriceHistory> PriceHistories { get; set; }

    public virtual DbSet<PublicHoliday> PublicHolidays { get; set; }

    public virtual DbSet<RefreshToken> RefreshTokens { get; set; }

    public virtual DbSet<Session> Sessions { get; set; }

    public virtual DbSet<SessionPrivateNote> SessionPrivateNotes { get; set; }

    public virtual DbSet<SettingsHistory> SettingsHistories { get; set; }

    public virtual DbSet<Specialty> Specialties { get; set; }

    public virtual DbSet<SpecialtyProfileItem> SpecialtyProfileItems { get; set; }

    public virtual DbSet<User> Users { get; set; }

    public virtual DbSet<UserDevice> UserDevices { get; set; }

    public virtual DbSet<UserToken> UserTokens { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AppSetting>(entity =>
        {
            entity.Property(e => e.ConsultationFeePiasters).HasDefaultValue(1500);
            entity.Property(e => e.ExamFeePiasters).HasDefaultValue(3000);
            entity.Property(e => e.GracePeriodDays).HasDefaultValue(7);
            entity.Property(e => e.TrialDays).HasDefaultValue(14);
            entity.Property(e => e.InstapayAccountName).HasMaxLength(100);
            entity.Property(e => e.InstapayAddress).HasMaxLength(200);
            entity.Property(e => e.InstapayInstructionsAr).HasMaxLength(2000);
            entity.Property(e => e.InstapayInstructionsEn).HasMaxLength(2000);
            entity.Property(e => e.MaintenanceMessageAr).HasMaxLength(500);
            entity.Property(e => e.MaintenanceMessageEn).HasMaxLength(500);
            entity.Property(e => e.MaxAssistantsPerDoctor).HasDefaultValue(5);
            entity.Property(e => e.MaxBranchesPerDoctor).HasDefaultValue(5);
            entity.Property(e => e.MaxConsecutiveConsultations).HasDefaultValue(2);
            entity.Property(e => e.MaxUploadMb).HasDefaultValue(50);
            entity.Property(e => e.MinVersionAndroid)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("0.0.0");
            entity.Property(e => e.MinVersionIos)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("0.0.0");
            entity.Property(e => e.MinVersionMacos)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("0.0.0");
            entity.Property(e => e.MinVersionWindows)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("0.0.0");
            entity.Property(e => e.SupportEmail).HasMaxLength(254);
            entity.Property(e => e.SupportPhone)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.SupportWhatsapp)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.CurrentCatalogVersion).WithMany(p => p.AppSettings)
                .HasForeignKey(d => d.CurrentCatalogVersionId)
                .HasConstraintName("FK_AppSettings_CurrentCatalogVersionId");

            entity.HasOne(d => d.UpdatedByNavigation).WithMany(p => p.AppSettings)
                .HasForeignKey(d => d.UpdatedBy)
                .HasConstraintName("FK_AppSettings_UpdatedBy");
        });

        modelBuilder.Entity<Appointment>(entity =>
        {
            entity.HasIndex(e => new { e.BranchId, e.LocalDate, e.Status }, "IX_Appointments_Branch_Date_Status");

            entity.HasIndex(e => new { e.DoctorId, e.LocalDate, e.Status }, "IX_Appointments_Doctor_Date_Status");

            entity.HasIndex(e => e.StartUtc, "IX_Appointments_Due_Reminders").HasFilter("([Status]='confirmed')");

            entity.HasIndex(e => e.GuestPhone, "IX_Appointments_GuestPhone").HasFilter("([GuestPhone] IS NOT NULL)");

            entity.HasIndex(e => new { e.PatientId, e.StartUtc }, "IX_Appointments_Patient_Start")
                .IsDescending(false, true)
                .HasFilter("([PatientId] IS NOT NULL)");

            entity.HasIndex(e => e.CreatedAt, "IX_Appointments_Pending").HasFilter("([Status]='pending')");

            entity.HasIndex(e => new { e.BranchId, e.LocalDate, e.PeriodStartLocal, e.QueueNumber }, "UQ_Appointments_QueueNumber")
                .IsUnique()
                .HasFilter("([QueueNumber] IS NOT NULL)");

            entity.HasIndex(e => new { e.BranchId, e.StartUtc }, "UQ_Appointments_TimedSlot")
                .IsUnique()
                .HasFilter("([Mode]='timed' AND [Overbooked]=(0) AND ([Status] IN ('pending', 'confirmed', 'checkedIn', 'withDoctor')))");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.AttendanceConfirmedAt).HasPrecision(3);
            entity.Property(e => e.BookedByRole)
                .HasMaxLength(9)
                .IsUnicode(false);
            entity.Property(e => e.CalledAt).HasPrecision(3);
            entity.Property(e => e.CancelReason).HasMaxLength(300);
            entity.Property(e => e.CancelledAt).HasPrecision(3);
            entity.Property(e => e.CancelledByRole)
                .HasMaxLength(7)
                .IsUnicode(false);
            entity.Property(e => e.CheckedInAt).HasPrecision(3);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.EndUtc).HasPrecision(0);
            entity.Property(e => e.GuestName).HasMaxLength(60);
            entity.Property(e => e.GuestPhone)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.Mode)
                .HasMaxLength(5)
                .IsUnicode(false);
            entity.Property(e => e.NoShowAt).HasPrecision(3);
            entity.Property(e => e.PeriodStartLocal).HasPrecision(0);
            entity.Property(e => e.PriorityReason).HasMaxLength(200);
            entity.Property(e => e.Reason).HasMaxLength(200);
            entity.Property(e => e.RejectReason).HasMaxLength(300);
            entity.Property(e => e.RemindersSentJson)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasDefaultValue("[]");
            entity.Property(e => e.RowVersion)
                .IsRowVersion()
                .IsConcurrencyToken();
            entity.Property(e => e.Source)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.StaffNotes).HasMaxLength(1000);
            entity.Property(e => e.StartUtc).HasPrecision(0);
            entity.Property(e => e.Status)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.VisitType)
                .HasMaxLength(12)
                .IsUnicode(false);

            entity.HasOne(d => d.BookedByNavigation).WithMany(p => p.Appointments)
                .HasForeignKey(d => d.BookedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Appointments_BookedBy");

            entity.HasOne(d => d.Branch).WithMany(p => p.Appointments)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Appointments_BranchId");

            entity.HasOne(d => d.Doctor).WithMany(p => p.Appointments)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Appointments_DoctorId");

            entity.HasOne(d => d.Patient).WithMany(p => p.Appointments)
                .HasForeignKey(d => d.PatientId)
                .HasConstraintName("FK_Appointments_PatientId");

            entity.HasOne(d => d.Session).WithMany(p => p.Appointments)
                .HasForeignKey(d => d.SessionId)
                .HasConstraintName("FK_Appointments_SessionId");
        });

        modelBuilder.Entity<AppointmentHistory>(entity =>
        {
            entity.ToTable("AppointmentHistory");

            entity.HasIndex(e => new { e.AppointmentId, e.At }, "IX_AppointmentHistory_Appointment");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Action)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.At)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.ByRole)
                .HasMaxLength(9)
                .IsUnicode(false);
            entity.Property(e => e.FromValue).HasMaxLength(200);
            entity.Property(e => e.Reason).HasMaxLength(300);
            entity.Property(e => e.ToValue).HasMaxLength(200);

            entity.HasOne(d => d.Appointment).WithMany(p => p.AppointmentHistories)
                .HasForeignKey(d => d.AppointmentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_AppointmentHistory_AppointmentId");

            entity.HasOne(d => d.ByUser).WithMany(p => p.AppointmentHistories)
                .HasForeignKey(d => d.ByUserId)
                .HasConstraintName("FK_AppointmentHistory_ByUserId");
        });

        modelBuilder.Entity<Assistant>(entity =>
        {
            entity.HasKey(e => e.UserId);

            entity.HasIndex(e => new { e.DoctorId, e.Status }, "IX_Assistants_DoctorId");

            entity.HasIndex(e => e.Phone, "UQ_Assistants_Phone")
                .IsUnique()
                .HasFilter("([Status] IN ('active', 'disabled'))");

            entity.Property(e => e.UserId).ValueGeneratedNever();
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.FullName).HasMaxLength(60);
            entity.Property(e => e.LastActiveAt).HasPrecision(3);
            entity.Property(e => e.Phone)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.Preset)
                .HasMaxLength(13)
                .IsUnicode(false)
                .HasDefaultValue("custom");
            entity.Property(e => e.RemovedAt).HasPrecision(3);
            entity.Property(e => e.Status)
                .HasMaxLength(8)
                .IsUnicode(false)
                .HasDefaultValue("active");
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.AssistantCreatedByNavigations)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Assistants_CreatedBy");

            entity.HasOne(d => d.Doctor).WithMany(p => p.Assistants)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Assistants_DoctorId");

            entity.HasOne(d => d.User).WithOne(p => p.AssistantUser)
                .HasForeignKey<Assistant>(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Assistants_UserId");

            entity.HasMany(d => d.Branches).WithMany(p => p.Assistants)
                .UsingEntity<Dictionary<string, object>>(
                    "AssistantBranch",
                    r => r.HasOne<Branch>().WithMany()
                        .HasForeignKey("BranchId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK_AssistantBranches_BranchId"),
                    l => l.HasOne<Assistant>().WithMany()
                        .HasForeignKey("AssistantId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK_AssistantBranches_AssistantId"),
                    j =>
                    {
                        j.HasKey("AssistantId", "BranchId");
                        j.ToTable("AssistantBranches");
                    });
        });

        modelBuilder.Entity<AuditLog>(entity =>
        {
            entity.HasIndex(e => new { e.ActorUserId, e.At }, "IX_AuditLogs_Actor_At").IsDescending(false, true);

            entity.HasIndex(e => e.At, "IX_AuditLogs_At").IsDescending();

            entity.HasIndex(e => new { e.DoctorId, e.At }, "IX_AuditLogs_Doctor_At")
                .IsDescending(false, true)
                .HasFilter("([DoctorId] IS NOT NULL)");

            entity.HasIndex(e => new { e.TargetType, e.TargetId }, "IX_AuditLogs_Target");

            entity.Property(e => e.Action)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.ActorRole)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.At)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.TargetId)
                .HasMaxLength(64)
                .IsUnicode(false);
            entity.Property(e => e.TargetType)
                .HasMaxLength(30)
                .IsUnicode(false);

            entity.HasOne(d => d.ActorUser).WithMany(p => p.AuditLogs)
                .HasForeignKey(d => d.ActorUserId)
                .HasConstraintName("FK_AuditLogs_ActorUserId");

            entity.HasOne(d => d.Doctor).WithMany(p => p.AuditLogs)
                .HasForeignKey(d => d.DoctorId)
                .HasConstraintName("FK_AuditLogs_DoctorId");

            entity.HasOne(d => d.Patient).WithMany(p => p.AuditLogs)
                .HasForeignKey(d => d.PatientId)
                .HasConstraintName("FK_AuditLogs_PatientId");
        });

        modelBuilder.Entity<Branch>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.Status }, "IX_Branches_DoctorId");

            entity.HasIndex(e => e.DoctorId, "UQ_Branches_OneDefault")
                .IsUnique()
                .HasFilter("([IsDefault]=(1))");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.AddressDetails).HasMaxLength(300);
            entity.Property(e => e.AmenitiesJson).HasMaxLength(300);
            entity.Property(e => e.Area).HasMaxLength(60);
            entity.Property(e => e.AutoConfirm).HasDefaultValue(true);
            entity.Property(e => e.AvgVisitMinutes).HasDefaultValue(10);
            entity.Property(e => e.BookingMode)
                .HasMaxLength(5)
                .IsUnicode(false)
                .HasDefaultValue("queue");
            entity.Property(e => e.City).HasMaxLength(60);
            entity.Property(e => e.ClosedMessage).HasMaxLength(300);
            entity.Property(e => e.ConsultationSlots).HasDefaultValue((byte)1);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.DefaultCapacity).HasDefaultValue(30);
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.Property(e => e.Email).HasMaxLength(254);
            entity.Property(e => e.ExamSlots).HasDefaultValue((byte)1);
            entity.Property(e => e.FreeCancelMinutes).HasDefaultValue(120);
            entity.Property(e => e.Governorate).HasMaxLength(50);
            entity.Property(e => e.Landmark).HasMaxLength(150);
            entity.Property(e => e.MapUrl).HasMaxLength(500);
            entity.Property(e => e.MaxReschedules).HasDefaultValue(2);
            entity.Property(e => e.MaxUpcomingPerPatient).HasDefaultValue(1);
            entity.Property(e => e.MinNoticeMinutes).HasDefaultValue(60);
            entity.Property(e => e.NameAr).HasMaxLength(60);
            entity.Property(e => e.NameEn).HasMaxLength(60);
            entity.Property(e => e.NoShowLimitCount).HasDefaultValue(3);
            entity.Property(e => e.NoShowLimitDays).HasDefaultValue(90);
            entity.Property(e => e.PaymentMethodsJson)
                .HasMaxLength(200)
                .HasDefaultValue("[\"cash\"]");
            entity.Property(e => e.ReminderMinutesJson)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasDefaultValue("[1440,120]");
            entity.Property(e => e.SameDay).HasDefaultValue(true);
            entity.Property(e => e.SelfBooking).HasDefaultValue(true);
            entity.Property(e => e.SlotMinutes).HasDefaultValue(15);
            entity.Property(e => e.StaffOverbooking).HasDefaultValue(true);
            entity.Property(e => e.Status)
                .HasMaxLength(17)
                .IsUnicode(false)
                .HasDefaultValue("active");
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.WaitAmberMinutes).HasDefaultValue(20);
            entity.Property(e => e.WaitRedMinutes).HasDefaultValue(40);
            entity.Property(e => e.WindowDays).HasDefaultValue(30);

<<<<<<< HEAD
            // One doctor has many branches (BR-BR1). The scaffolder read the filtered unique index
            // UQ_Branches_OneDefault as a one-to-one, which would stop a second branch being added.
=======
            // One doctor, many branches. UQ_Branches_OneDefault is filtered (IsDefault = 1),
            // so it limits the default branch only, not the relationship.
>>>>>>> phase-6/appointments-live-board
            entity.HasOne(d => d.Doctor).WithMany(p => p.Branches)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Branches_DoctorId");
        });

        modelBuilder.Entity<BranchClosure>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.BranchId, e.FromLocal }, "IX_BranchClosures_Doctor_Branch_From");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.FromLocal).HasPrecision(0);
            entity.Property(e => e.Reason).HasMaxLength(300);
            entity.Property(e => e.ToLocal).HasPrecision(0);

            entity.HasOne(d => d.Branch).WithMany(p => p.BranchClosures)
                .HasForeignKey(d => d.BranchId)
                .HasConstraintName("FK_BranchClosures_BranchId");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.BranchClosures)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchClosures_CreatedBy");

            entity.HasOne(d => d.Doctor).WithMany(p => p.BranchClosures)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchClosures_DoctorId");
        });

        modelBuilder.Entity<BranchDateOverride>(entity =>
        {
            entity.HasIndex(e => new { e.BranchId, e.Date }, "UQ_BranchDateOverrides_Branch_Date").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Branch).WithMany(p => p.BranchDateOverrides)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchDateOverrides_BranchId");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.BranchDateOverrides)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchDateOverrides_CreatedBy");
        });

        modelBuilder.Entity<BranchDateOverridePeriod>(entity =>
        {
            entity.HasIndex(e => e.OverrideId, "IX_BranchDateOverridePeriods_OverrideId");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.EndLocal).HasPrecision(0);
            entity.Property(e => e.Label).HasMaxLength(30);
            entity.Property(e => e.StartLocal).HasPrecision(0);

            entity.HasOne(d => d.Override).WithMany(p => p.BranchDateOverridePeriods)
                .HasForeignKey(d => d.OverrideId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchDateOverridePeriods_OverrideId");
        });

        modelBuilder.Entity<BranchDayState>(entity =>
        {
            entity.HasKey(e => new { e.BranchId, e.LocalDate, e.PeriodStartLocal });

            entity.Property(e => e.PeriodStartLocal).HasPrecision(0);
            entity.Property(e => e.DelayNoticeSentAt).HasPrecision(3);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Branch).WithMany(p => p.BranchDayStates)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchDayStates_BranchId");
        });

        modelBuilder.Entity<BranchPeriod>(entity =>
        {
            entity.HasIndex(e => new { e.BranchId, e.Weekday }, "IX_BranchPeriods_Branch_Weekday");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.EndLocal).HasPrecision(0);
            entity.Property(e => e.Label).HasMaxLength(30);
            entity.Property(e => e.StartLocal).HasPrecision(0);

            entity.HasOne(d => d.Branch).WithMany(p => p.BranchPeriods)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchPeriods_BranchId");
        });

        modelBuilder.Entity<BranchPhone>(entity =>
        {
            entity.HasIndex(e => e.BranchId, "IX_BranchPhones_BranchId");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Label)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("reception");
            entity.Property(e => e.Number)
                .HasMaxLength(16)
                .IsUnicode(false);

            entity.HasOne(d => d.Branch).WithMany(p => p.BranchPhones)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchPhones_BranchId");
        });

        modelBuilder.Entity<BranchPhoto>(entity =>
        {
            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Path).HasMaxLength(400);

            entity.HasOne(d => d.Branch).WithMany(p => p.BranchPhotos)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_BranchPhotos_BranchId");
        });

        modelBuilder.Entity<CatalogCustomItem>(entity =>
        {
            entity.HasIndex(e => e.UpdatedAt, "IX_CatalogCustomItems_UpdatedAt");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.ActiveIngredient).HasMaxLength(300);
            entity.Property(e => e.AliasesJson).HasMaxLength(2000);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.DrugGroupId)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.LoincCode)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.NameAr).HasMaxLength(200);
            entity.Property(e => e.NameEn).HasMaxLength(200);
            entity.Property(e => e.Route)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.Type)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.CatalogCustomItems)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_CatalogCustomItems_CreatedBy");
        });

        modelBuilder.Entity<CatalogReport>(entity =>
        {
            entity.HasIndex(e => new { e.Status, e.CreatedAt }, "IX_CatalogReports_Status");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.HandledAt).HasPrecision(3);
            entity.Property(e => e.ItemRef)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.Status)
                .HasMaxLength(4)
                .IsUnicode(false)
                .HasDefaultValue("open");
            entity.Property(e => e.Text).HasMaxLength(1000);
            entity.Property(e => e.Type)
                .HasMaxLength(10)
                .IsUnicode(false);

            entity.HasOne(d => d.Doctor).WithMany(p => p.CatalogReports)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_CatalogReports_DoctorId");

            entity.HasOne(d => d.HandledByNavigation).WithMany(p => p.CatalogReports)
                .HasForeignKey(d => d.HandledBy)
                .HasConstraintName("FK_CatalogReports_HandledBy");
        });

        modelBuilder.Entity<CatalogVersion>(entity =>
        {
            entity.HasIndex(e => e.VersionNumber, "UQ_CatalogVersions_VersionNumber").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.LoincRelease)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.PublishedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Sha256)
                .HasMaxLength(64)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.StoragePath).HasMaxLength(400);

            entity.HasOne(d => d.PublishedByNavigation).WithMany(p => p.CatalogVersions)
                .HasForeignKey(d => d.PublishedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_CatalogVersions_PublishedBy");
        });

        modelBuilder.Entity<Chat>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.LastMessageAt }, "IX_Chats_Doctor_LastMessage").IsDescending(false, true);

            entity.HasIndex(e => new { e.PatientId, e.LastMessageAt }, "IX_Chats_Patient_LastMessage").IsDescending(false, true);

            entity.HasIndex(e => e.LinkId, "UQ_Chats_LinkId").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Enabled).HasDefaultValue(true);
            entity.Property(e => e.LastMessageAt).HasPrecision(3);
            entity.Property(e => e.LastMessageText).HasMaxLength(200);
            entity.Property(e => e.LastMessageType)
                .HasMaxLength(5)
                .IsUnicode(false);

            entity.HasOne(d => d.Doctor).WithMany(p => p.Chats)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Chats_DoctorId");

            entity.HasOne(d => d.LastMessageSender).WithMany(p => p.Chats)
                .HasForeignKey(d => d.LastMessageSenderId)
                .HasConstraintName("FK_Chats_LastMessageSenderId");

            entity.HasOne(d => d.Link).WithOne(p => p.Chat)
                .HasForeignKey<Chat>(d => d.LinkId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Chats_LinkId");

            entity.HasOne(d => d.Patient).WithMany(p => p.Chats)
                .HasForeignKey(d => d.PatientId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Chats_PatientId");
        });

        modelBuilder.Entity<ChatMessage>(entity =>
        {
            entity.HasIndex(e => new { e.ChatId, e.CreatedAt }, "IX_ChatMessages_Chat_CreatedAt").IsDescending(false, true);

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.AttachmentFileName).HasMaxLength(255);
            entity.Property(e => e.AttachmentMimeType)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.AttachmentPath).HasMaxLength(400);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.ReadAt).HasPrecision(3);
            entity.Property(e => e.SenderName).HasMaxLength(60);
            entity.Property(e => e.SenderRole)
                .HasMaxLength(9)
                .IsUnicode(false);
            entity.Property(e => e.Text).HasMaxLength(4000);
            entity.Property(e => e.Type)
                .HasMaxLength(5)
                .IsUnicode(false);

            entity.HasOne(d => d.Chat).WithMany(p => p.ChatMessages)
                .HasForeignKey(d => d.ChatId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatMessages_ChatId");

            entity.HasOne(d => d.Sender).WithMany(p => p.ChatMessages)
                .HasForeignKey(d => d.SenderId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatMessages_SenderId");
        });

        modelBuilder.Entity<ChatReadState>(entity =>
        {
            entity.HasKey(e => new { e.ChatId, e.UserId });

            entity.HasIndex(e => e.UserId, "IX_ChatReadStates_User_Unread").HasFilter("([UnreadCount]>(0))");

            entity.Property(e => e.LastReadAt).HasPrecision(3);

            entity.HasOne(d => d.Chat).WithMany(p => p.ChatReadStates)
                .HasForeignKey(d => d.ChatId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatReadStates_ChatId");

            entity.HasOne(d => d.User).WithMany(p => p.ChatReadStates)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ChatReadStates_UserId");
        });

        modelBuilder.Entity<DailyStat>(entity =>
        {
            entity.HasKey(e => new { e.DoctorId, e.DayKey });

            entity.Property(e => e.MonthKey)
                .HasMaxLength(7)
                .IsUnicode(false)
                .IsFixedLength();

            entity.HasOne(d => d.Doctor).WithMany(p => p.DailyStats)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DailyStats_DoctorId");
        });

        modelBuilder.Entity<DeletionRequest>(entity =>
        {
            entity.HasIndex(e => new { e.Status, e.CreatedAt }, "IX_DeletionRequests_Status");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Reason).HasMaxLength(500);
            entity.Property(e => e.ReviewNote).HasMaxLength(500);
            entity.Property(e => e.ReviewedAt).HasPrecision(3);
            entity.Property(e => e.Status)
                .HasMaxLength(8)
                .IsUnicode(false)
                .HasDefaultValue("pending");

            entity.HasOne(d => d.Patient).WithMany(p => p.DeletionRequests)
                .HasForeignKey(d => d.PatientId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DeletionRequests_PatientId");

            entity.HasOne(d => d.ReviewedByNavigation).WithMany(p => p.DeletionRequests)
                .HasForeignKey(d => d.ReviewedBy)
                .HasConstraintName("FK_DeletionRequests_ReviewedBy");
        });

        modelBuilder.Entity<Doctor>(entity =>
        {
            entity.HasKey(e => e.UserId);

            entity.HasIndex(e => e.SpecialtyId, "IX_Doctors_SpecialtyId");

            entity.HasIndex(e => new { e.Status, e.CreatedAt }, "IX_Doctors_Status");

            entity.Property(e => e.UserId).ValueGeneratedNever();
            entity.Property(e => e.ApprovedAt).HasPrecision(3);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.DegreesAr).HasMaxLength(300);
            entity.Property(e => e.DegreesEn).HasMaxLength(300);
            entity.Property(e => e.FullName).HasMaxLength(60);
            entity.Property(e => e.FullNameEn).HasMaxLength(60);
            entity.Property(e => e.LicenseDocPath).HasMaxLength(400);
            entity.Property(e => e.LicenseNumber)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.NextFileNumber).HasDefaultValue(1);
            entity.Property(e => e.RxAccentColor)
                .HasMaxLength(7)
                .IsUnicode(false)
                .HasDefaultValue("#0F4C45")
                .IsFixedLength();
            entity.Property(e => e.RxCustomHeightMm).HasColumnType("decimal(5, 1)");
            entity.Property(e => e.RxCustomWidthMm).HasColumnType("decimal(5, 1)");
            entity.Property(e => e.RxFooterText).HasMaxLength(300);
            entity.Property(e => e.RxLanguage)
                .HasMaxLength(2)
                .IsUnicode(false)
                .HasDefaultValue("ar");
            entity.Property(e => e.RxLogoPath).HasMaxLength(400);
            entity.Property(e => e.RxMarginBottomMm).HasColumnType("decimal(5, 1)");
            entity.Property(e => e.RxMarginTopMm).HasColumnType("decimal(5, 1)");
            entity.Property(e => e.RxPaperSize)
                .HasMaxLength(6)
                .IsUnicode(false)
                .HasDefaultValue("A5");
            entity.Property(e => e.RxSignaturePath).HasMaxLength(400);
            entity.Property(e => e.Status)
                .HasMaxLength(16)
                .IsUnicode(false)
                .HasDefaultValue("pendingApproval");
            entity.Property(e => e.StatusChangedAt).HasPrecision(3);
            entity.Property(e => e.StatusReason).HasMaxLength(500);
            entity.Property(e => e.TrialEndsAt).HasPrecision(3);
            entity.Property(e => e.Title).HasMaxLength(40);
            entity.Property(e => e.TitleEn).HasMaxLength(40);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.ApprovedByNavigation).WithMany(p => p.DoctorApprovedByNavigations)
                .HasForeignKey(d => d.ApprovedBy)
                .HasConstraintName("FK_Doctors_ApprovedBy");

            entity.HasOne(d => d.DefaultBranch).WithMany(p => p.Doctors)
                .HasForeignKey(d => d.DefaultBranchId)
                .HasConstraintName("FK_Doctors_DefaultBranchId");

            entity.HasOne(d => d.Specialty).WithMany(p => p.Doctors)
                .HasForeignKey(d => d.SpecialtyId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Doctors_SpecialtyId");

            entity.HasOne(d => d.User).WithOne(p => p.DoctorUser)
                .HasForeignKey<Doctor>(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Doctors_UserId");

            entity.HasMany(d => d.Specialties).WithMany(p => p.DoctorsNavigation)
                .UsingEntity<Dictionary<string, object>>(
                    "DoctorExtraSpecialty",
                    r => r.HasOne<Specialty>().WithMany()
                        .HasForeignKey("SpecialtyId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK_DoctorExtraSpecialties_SpecialtyId"),
                    l => l.HasOne<Doctor>().WithMany()
                        .HasForeignKey("DoctorId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK_DoctorExtraSpecialties_DoctorId"),
                    j =>
                    {
                        j.HasKey("DoctorId", "SpecialtyId");
                        j.ToTable("DoctorExtraSpecialties");
                    });
        });

        modelBuilder.Entity<DoctorAdminNote>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.CreatedAt }, "IX_DoctorAdminNotes_DoctorId").IsDescending(false, true);

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Text).HasMaxLength(2000);

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.DoctorAdminNotes)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DoctorAdminNotes_CreatedBy");

            entity.HasOne(d => d.Doctor).WithMany(p => p.DoctorAdminNotes)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DoctorAdminNotes_DoctorId");
        });

        modelBuilder.Entity<DoctorDailyMetric>(entity =>
        {
            entity.HasKey(e => new { e.DoctorId, e.BranchId, e.Date });

            entity.Property(e => e.AvgWaitMinutes).HasColumnType("decimal(6, 1)");
            entity.Property(e => e.BuiltAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.VisitsByHourJson)
                .HasMaxLength(200)
                .IsUnicode(false)
                .HasDefaultValue("[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]");

            entity.HasOne(d => d.Branch).WithMany(p => p.DoctorDailyMetrics)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DoctorDailyMetrics_BranchId");

            entity.HasOne(d => d.Doctor).WithMany(p => p.DoctorDailyMetrics)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DoctorDailyMetrics_DoctorId");
        });

        modelBuilder.Entity<DoctorItemHistory>(entity =>
        {
            entity.ToTable("DoctorItemHistory");

            entity.HasIndex(e => new { e.DoctorId, e.Kind, e.Name, e.Form, e.Strength }, "UQ_DoctorItemHistory").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CatalogId)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.Form)
                .HasMaxLength(50)
                .HasDefaultValue("");
            entity.Property(e => e.Kind)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.LastUsedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.Strength)
                .HasMaxLength(50)
                .HasDefaultValue("");
            entity.Property(e => e.UseCount).HasDefaultValue(1);

            entity.HasOne(d => d.Doctor).WithMany(p => p.DoctorItemHistories)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DoctorItemHistory_DoctorId");
        });

        modelBuilder.Entity<DoctorPatient>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.Archived, e.LastSessionAt }, "IX_DoctorPatients_Doctor_LastSession").IsDescending(false, false, true);

            entity.HasIndex(e => new { e.DoctorId, e.PatientPhone }, "IX_DoctorPatients_Doctor_Phone");

            entity.HasIndex(e => new { e.DoctorId, e.SearchName }, "IX_DoctorPatients_Doctor_SearchName");

            entity.HasIndex(e => e.PatientId, "IX_DoctorPatients_PatientId");

            entity.HasIndex(e => new { e.DoctorId, e.FileNumber }, "UQ_DoctorPatients_Doctor_File").IsUnique();

            entity.HasIndex(e => new { e.DoctorId, e.PatientId }, "UQ_DoctorPatients_Doctor_Patient").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.ArchivedAt).HasPrecision(3);
            entity.Property(e => e.FamilyHistory).HasMaxLength(2000);
            entity.Property(e => e.FirstSessionAt).HasPrecision(3);
            entity.Property(e => e.LastSessionAt).HasPrecision(3);
            entity.Property(e => e.LastSessionType)
                .HasMaxLength(12)
                .IsUnicode(false);
            entity.Property(e => e.LinkedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.PatientName).HasMaxLength(60);
            entity.Property(e => e.PatientPhone)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.ProfileNotes).HasMaxLength(2000);
            entity.Property(e => e.SearchName).HasMaxLength(120);
            entity.Property(e => e.SelfBookingBlockedReason).HasMaxLength(300);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Doctor).WithMany(p => p.DoctorPatients)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DoctorPatients_DoctorId");

            entity.HasOne(d => d.LastSessionBranch).WithMany(p => p.DoctorPatients)
                .HasForeignKey(d => d.LastSessionBranchId)
                .HasConstraintName("FK_DoctorPatients_LastSessionBranchId");

            entity.HasOne(d => d.LastSession).WithMany(p => p.DoctorPatients)
                .HasForeignKey(d => d.LastSessionId)
                .HasConstraintName("FK_DoctorPatients_LastSessionId");

            entity.HasOne(d => d.LinkedByNavigation).WithMany(p => p.DoctorPatients)
                .HasForeignKey(d => d.LinkedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DoctorPatients_LinkedBy");

            entity.HasOne(d => d.Patient).WithMany(p => p.DoctorPatients)
                .HasForeignKey(d => d.PatientId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DoctorPatients_PatientId");
        });

        modelBuilder.Entity<Invoice>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.MonthKey }, "IX_Invoices_Doctor_Month").IsDescending(false, true);

            entity.HasIndex(e => new { e.Status, e.DueDate }, "IX_Invoices_Status_DueDate");

            entity.HasIndex(e => new { e.DoctorId, e.MonthKey }, "UQ_Invoices_Doctor_Month").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.MonthKey)
                .HasMaxLength(7)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.PaidAt).HasPrecision(3);
            entity.Property(e => e.PaidMethod).HasMaxLength(50);
            entity.Property(e => e.Status)
                .HasMaxLength(13)
                .IsUnicode(false)
                .HasDefaultValue("unpaid");
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.ClosedByNavigation).WithMany(p => p.Invoices)
                .HasForeignKey(d => d.ClosedBy)
                .HasConstraintName("FK_Invoices_ClosedBy");

            entity.HasOne(d => d.Doctor).WithMany(p => p.Invoices)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Invoices_DoctorId");
        });

        modelBuilder.Entity<InvoiceAdjustment>(entity =>
        {
            entity.HasIndex(e => e.InvoiceId, "IX_InvoiceAdjustments_InvoiceId");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Reason).HasMaxLength(500);

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.InvoiceAdjustments)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_InvoiceAdjustments_CreatedBy");

            entity.HasOne(d => d.Invoice).WithMany(p => p.InvoiceAdjustments)
                .HasForeignKey(d => d.InvoiceId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_InvoiceAdjustments_InvoiceId");
        });

        modelBuilder.Entity<InvoiceBranchBreakdown>(entity =>
        {
            entity.HasKey(e => new { e.InvoiceId, e.BranchId });

            entity.ToTable("InvoiceBranchBreakdown");

            entity.HasOne(d => d.Branch).WithMany(p => p.InvoiceBranchBreakdowns)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_InvoiceBranchBreakdown_BranchId");

            entity.HasOne(d => d.Invoice).WithMany(p => p.InvoiceBranchBreakdowns)
                .HasForeignKey(d => d.InvoiceId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_InvoiceBranchBreakdown_InvoiceId");
        });

        modelBuilder.Entity<InvoiceStatusHistory>(entity =>
        {
            entity.ToTable("InvoiceStatusHistory");

            entity.HasIndex(e => new { e.InvoiceId, e.ChangedAt }, "IX_InvoiceStatusHistory_InvoiceId");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.ChangedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Note).HasMaxLength(500);
            entity.Property(e => e.Status)
                .HasMaxLength(13)
                .IsUnicode(false);

            entity.HasOne(d => d.ChangedByNavigation).WithMany(p => p.InvoiceStatusHistories)
                .HasForeignKey(d => d.ChangedBy)
                .HasConstraintName("FK_InvoiceStatusHistory_ChangedBy");

            entity.HasOne(d => d.Invoice).WithMany(p => p.InvoiceStatusHistories)
                .HasForeignKey(d => d.InvoiceId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_InvoiceStatusHistory_InvoiceId");
        });

        modelBuilder.Entity<MedicalRecord>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.PatientId, e.Category, e.Deleted, e.DocumentDate }, "IX_MedicalRecords_Doctor_Patient_Category").IsDescending(false, false, false, false, true);

            entity.HasIndex(e => new { e.PatientId, e.Category, e.Deleted, e.DocumentDate }, "IX_MedicalRecords_Patient_Category").IsDescending(false, false, false, true);

            entity.HasIndex(e => e.SessionId, "IX_MedicalRecords_SessionId").HasFilter("([SessionId] IS NOT NULL)");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Category)
                .HasMaxLength(12)
                .IsUnicode(false);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.CreatedByRole)
                .HasMaxLength(9)
                .IsUnicode(false);
            entity.Property(e => e.DeletedAt).HasPrecision(3);
            entity.Property(e => e.Notes).HasMaxLength(1000);
            entity.Property(e => e.OtherType)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.OtherTypeText).HasMaxLength(60);
            entity.Property(e => e.PatientSeenAt).HasPrecision(3);
            entity.Property(e => e.Source)
                .HasMaxLength(6)
                .IsUnicode(false);
            entity.Property(e => e.Title).HasMaxLength(150);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.MedicalRecordCreatedByNavigations)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_MedicalRecords_CreatedBy");

            entity.HasOne(d => d.DeletedByNavigation).WithMany(p => p.MedicalRecordDeletedByNavigations)
                .HasForeignKey(d => d.DeletedBy)
                .HasConstraintName("FK_MedicalRecords_DeletedBy");

            entity.HasOne(d => d.Doctor).WithMany(p => p.MedicalRecords)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_MedicalRecords_DoctorId");

            entity.HasOne(d => d.Patient).WithMany(p => p.MedicalRecords)
                .HasForeignKey(d => d.PatientId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_MedicalRecords_PatientId");

            entity.HasOne(d => d.Session).WithMany(p => p.MedicalRecords)
                .HasForeignKey(d => d.SessionId)
                .HasConstraintName("FK_MedicalRecords_SessionId");

            entity.HasOne(d => d.SourceChatMessage).WithMany(p => p.MedicalRecords)
                .HasForeignKey(d => d.SourceChatMessageId)
                .HasConstraintName("FK_MedicalRecords_SourceChatMessageId");
        });

        modelBuilder.Entity<MedicalRecordAttachment>(entity =>
        {
            entity.HasIndex(e => e.RecordId, "IX_MedicalRecordAttachments_RecordId");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.FileName).HasMaxLength(255);
            entity.Property(e => e.MimeType)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.Path).HasMaxLength(400);
            entity.Property(e => e.ThumbPath).HasMaxLength(400);

            entity.HasOne(d => d.Record).WithMany(p => p.MedicalRecordAttachments)
                .HasForeignKey(d => d.RecordId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_MedicalRecordAttachments_RecordId");
        });

        modelBuilder.Entity<MonthlyStat>(entity =>
        {
            entity.HasKey(e => new { e.DoctorId, e.MonthKey });

            entity.Property(e => e.MonthKey)
                .HasMaxLength(7)
                .IsUnicode(false)
                .IsFixedLength();

            entity.HasOne(d => d.Doctor).WithMany(p => p.MonthlyStats)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_MonthlyStats_DoctorId");
        });

        modelBuilder.Entity<Notification>(entity =>
        {
            entity.HasIndex(e => new { e.RecipientUserId, e.CreatedAt }, "IX_Notifications_Recipient").IsDescending(false, true);

            entity.HasIndex(e => e.RecipientUserId, "IX_Notifications_Recipient_Unread").HasFilter("([IsRead]=(0))");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.BodyAr).HasMaxLength(500);
            entity.Property(e => e.BodyEn).HasMaxLength(500);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.DataJson).HasMaxLength(1000);
            entity.Property(e => e.ReadAt).HasPrecision(3);
            entity.Property(e => e.Route)
                .HasMaxLength(200)
                .IsUnicode(false);
            entity.Property(e => e.TitleAr).HasMaxLength(150);
            entity.Property(e => e.TitleEn).HasMaxLength(150);
            entity.Property(e => e.Type)
                .HasMaxLength(50)
                .IsUnicode(false);

            entity.HasOne(d => d.RecipientUser).WithMany(p => p.Notifications)
                .HasForeignKey(d => d.RecipientUserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Notifications_RecipientUserId");
        });

        modelBuilder.Entity<Patient>(entity =>
        {
            entity.HasIndex(e => e.Phone, "UQ_Patients_Phone").IsUnique();

            entity.HasIndex(e => e.UserId, "UQ_Patients_UserId").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Address).HasMaxLength(300);
            entity.Property(e => e.BloodType)
                .HasMaxLength(3)
                .IsUnicode(false);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.DeletedAt).HasPrecision(3);
            entity.Property(e => e.EmergencyContactName).HasMaxLength(60);
            entity.Property(e => e.EmergencyContactPhone)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.FullName).HasMaxLength(60);
            entity.Property(e => e.Gender)
                .HasMaxLength(6)
                .IsUnicode(false);
            entity.Property(e => e.NationalId)
                .HasMaxLength(14)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.Phone)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.Status)
                .HasMaxLength(8)
                .IsUnicode(false)
                .HasDefaultValue("active");
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.CreatedByDoctor).WithMany(p => p.Patients)
                .HasForeignKey(d => d.CreatedByDoctorId)
                .HasConstraintName("FK_Patients_CreatedByDoctorId");

            entity.HasOne(d => d.User).WithOne(p => p.Patient)
                .HasForeignKey<Patient>(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Patients_UserId");
        });

        modelBuilder.Entity<PatientMedicalProfileItem>(entity =>
        {
            entity.HasIndex(e => new { e.LinkId, e.Kind }, "IX_PatientMedicalProfileItems_Link_Kind");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Kind)
                .HasMaxLength(17)
                .IsUnicode(false);
            entity.Property(e => e.Text).HasMaxLength(200);

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.PatientMedicalProfileItems)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PatientMedicalProfileItems_CreatedBy");

            entity.HasOne(d => d.Link).WithMany(p => p.PatientMedicalProfileItems)
                .HasForeignKey(d => d.LinkId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PatientMedicalProfileItems_LinkId");
        });

        modelBuilder.Entity<Payment>(entity =>
        {
            entity.HasIndex(e => e.InvoiceId, "IX_Payments_InvoiceId");

            entity.HasIndex(e => new { e.Status, e.SubmittedAt }, "IX_Payments_Status_SubmittedAt");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Note).HasMaxLength(500);
            entity.Property(e => e.Reference).HasMaxLength(100);
            entity.Property(e => e.RejectionReason).HasMaxLength(500);
            entity.Property(e => e.ReviewedAt).HasPrecision(3);
            entity.Property(e => e.SenderName).HasMaxLength(60);
            entity.Property(e => e.Status)
                .HasMaxLength(13)
                .IsUnicode(false)
                .HasDefaultValue("pendingReview");
            entity.Property(e => e.SubmittedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Doctor).WithMany(p => p.Payments)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Payments_DoctorId");

            entity.HasOne(d => d.Invoice).WithMany(p => p.Payments)
                .HasForeignKey(d => d.InvoiceId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Payments_InvoiceId");

            entity.HasOne(d => d.ReviewedByNavigation).WithMany(p => p.PaymentReviewedByNavigations)
                .HasForeignKey(d => d.ReviewedBy)
                .HasConstraintName("FK_Payments_ReviewedBy");

            entity.HasOne(d => d.SubmittedByNavigation).WithMany(p => p.PaymentSubmittedByNavigations)
                .HasForeignKey(d => d.SubmittedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Payments_SubmittedBy");
        });

        modelBuilder.Entity<PaymentScreenshot>(entity =>
        {
            entity.HasIndex(e => new { e.PaymentId, e.SortOrder }, "UQ_PaymentScreenshots_Payment_Order").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Path).HasMaxLength(400);

            entity.HasOne(d => d.Payment).WithMany(p => p.PaymentScreenshots)
                .HasForeignKey(d => d.PaymentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PaymentScreenshots_PaymentId");
        });

        modelBuilder.Entity<Prescription>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.PatientId, e.CreatedAt }, "IX_Prescriptions_Doctor_Patient").IsDescending(false, false, true);

            entity.HasIndex(e => new { e.DoctorId, e.Status }, "IX_Prescriptions_Doctor_Review").HasFilter("([Status]='readyForReview')");

            entity.HasIndex(e => new { e.PatientId, e.Status, e.CreatedAt }, "IX_Prescriptions_Patient_Status").IsDescending(false, false, true);

            entity.HasIndex(e => e.SessionId, "IX_Prescriptions_SessionId");

            entity.HasIndex(e => e.QrShortCode, "UQ_Prescriptions_QrShortCode").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Advice).HasMaxLength(2000);
            entity.Property(e => e.CancelReason).HasMaxLength(500);
            entity.Property(e => e.CancelledAt).HasPrecision(3);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Diagnosis).HasMaxLength(1000);
            entity.Property(e => e.Kind)
                .HasMaxLength(14)
                .IsUnicode(false);
            entity.Property(e => e.PatientSeenAt).HasPrecision(3);
            entity.Property(e => e.PdfPath).HasMaxLength(400);
            entity.Property(e => e.PreparedByRole)
                .HasMaxLength(9)
                .IsUnicode(false);
            entity.Property(e => e.QrShortCode)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.SentAt).HasPrecision(3);
            entity.Property(e => e.Status)
                .HasMaxLength(14)
                .IsUnicode(false)
                .HasDefaultValue("draft");
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Doctor).WithMany(p => p.Prescriptions)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Prescriptions_DoctorId");

            entity.HasOne(d => d.Patient).WithMany(p => p.Prescriptions)
                .HasForeignKey(d => d.PatientId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Prescriptions_PatientId");

            entity.HasOne(d => d.PreparedByNavigation).WithMany(p => p.Prescriptions)
                .HasForeignKey(d => d.PreparedBy)
                .HasConstraintName("FK_Prescriptions_PreparedBy");

            entity.HasOne(d => d.ReplacesRx).WithMany(p => p.InverseReplacesRx)
                .HasForeignKey(d => d.ReplacesRxId)
                .HasConstraintName("FK_Prescriptions_ReplacesRxId");

            entity.HasOne(d => d.Session).WithMany(p => p.Prescriptions)
                .HasForeignKey(d => d.SessionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Prescriptions_SessionId");
        });

        modelBuilder.Entity<PrescriptionInvestigationItem>(entity =>
        {
            entity.HasIndex(e => new { e.PrescriptionId, e.SortOrder }, "IX_PrescriptionInvestigationItems_Rx");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Category)
                .HasMaxLength(9)
                .IsUnicode(false);
            entity.Property(e => e.LoincCode)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.Notes).HasMaxLength(500);

            entity.HasOne(d => d.Prescription).WithMany(p => p.PrescriptionInvestigationItems)
                .HasForeignKey(d => d.PrescriptionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PrescriptionInvestigationItems_PrescriptionId");
        });

        modelBuilder.Entity<PrescriptionMedicationItem>(entity =>
        {
            entity.HasIndex(e => new { e.PrescriptionId, e.SortOrder }, "IX_PrescriptionMedicationItems_Rx");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.ActiveIngredient).HasMaxLength(300);
            entity.Property(e => e.CatalogId)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.Dose).HasMaxLength(100);
            entity.Property(e => e.DrugName).HasMaxLength(200);
            entity.Property(e => e.Duration).HasMaxLength(100);
            entity.Property(e => e.Form).HasMaxLength(50);
            entity.Property(e => e.Frequency).HasMaxLength(100);
            entity.Property(e => e.Instructions).HasMaxLength(500);
            entity.Property(e => e.Strength).HasMaxLength(50);
            entity.Property(e => e.Timing).HasMaxLength(100);

            entity.HasOne(d => d.Prescription).WithMany(p => p.PrescriptionMedicationItems)
                .HasForeignKey(d => d.PrescriptionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PrescriptionMedicationItems_PrescriptionId");
        });

        modelBuilder.Entity<PrescriptionTemplate>(entity =>
        {
            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Advice).HasMaxLength(2000);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Kind)
                .HasMaxLength(14)
                .IsUnicode(false);
            entity.Property(e => e.Name).HasMaxLength(100);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Doctor).WithMany(p => p.PrescriptionTemplates)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PrescriptionTemplates_DoctorId");
        });

        modelBuilder.Entity<PriceHistory>(entity =>
        {
            entity.ToTable("PriceHistory");

            entity.HasIndex(e => new { e.DoctorId, e.ChangedAt }, "IX_PriceHistory_Doctor").IsDescending(false, true);

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.ChangedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.ChangedByRole)
                .HasMaxLength(9)
                .IsUnicode(false);

            entity.HasOne(d => d.Branch).WithMany(p => p.PriceHistories)
                .HasForeignKey(d => d.BranchId)
                .HasConstraintName("FK_PriceHistory_BranchId");

            entity.HasOne(d => d.ChangedByNavigation).WithMany(p => p.PriceHistories)
                .HasForeignKey(d => d.ChangedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PriceHistory_ChangedBy");

            entity.HasOne(d => d.Doctor).WithMany(p => p.PriceHistories)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PriceHistory_DoctorId");
        });

        modelBuilder.Entity<PublicHoliday>(entity =>
        {
            entity.HasIndex(e => e.Date, "UQ_PublicHolidays_Date").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.NameAr).HasMaxLength(100);
            entity.Property(e => e.NameEn).HasMaxLength(100);
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasIndex(e => e.UserId, "IX_RefreshTokens_User_Active").HasFilter("([RevokedAt] IS NULL)");

            entity.HasIndex(e => e.TokenHash, "UQ_RefreshTokens_TokenHash").IsUnique();

            // Reuse of a rotated token revokes the whole family in one statement.
            entity.HasIndex(e => e.FamilyId, "IX_RefreshTokens_FamilyId");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.CreatedByIp)
                .HasMaxLength(45)
                .IsUnicode(false);
            entity.Property(e => e.DeviceId)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.ExpiresAt).HasPrecision(3);
            entity.Property(e => e.RevokedAt).HasPrecision(3);
            entity.Property(e => e.TokenHash)
                .HasMaxLength(32)
                .IsFixedLength();

            entity.HasOne(d => d.User).WithMany(p => p.RefreshTokens)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_RefreshTokens_UserId");
        });

        modelBuilder.Entity<Session>(entity =>
        {
            entity.HasIndex(e => new { e.DoctorId, e.DayKey, e.CreatedAt }, "IX_Sessions_Doctor_Day").IsDescending(false, false, true);

            entity.HasIndex(e => new { e.DoctorId, e.MonthKey, e.Deleted }, "IX_Sessions_Doctor_Month");

            entity.HasIndex(e => new { e.DoctorId, e.PatientId, e.Deleted, e.CreatedAt }, "IX_Sessions_Doctor_Patient").IsDescending(false, false, false, true);

            entity.HasIndex(e => new { e.PatientId, e.Deleted, e.CreatedAt }, "IX_Sessions_Patient").IsDescending(false, false, true);

            entity.HasIndex(e => e.AppointmentId, "UQ_Sessions_AppointmentId")
                .IsUnique()
                .HasFilter("([AppointmentId] IS NOT NULL)");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.ChiefComplaint).HasMaxLength(1000);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.CreatedByRole)
                .HasMaxLength(9)
                .IsUnicode(false);
            entity.Property(e => e.DeleteReason).HasMaxLength(500);
            entity.Property(e => e.DeletedAt).HasPrecision(3);
            entity.Property(e => e.Diagnosis).HasMaxLength(1000);
            entity.Property(e => e.HeightCm).HasColumnType("decimal(4, 1)");
            entity.Property(e => e.MonthKey)
                .HasMaxLength(7)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.PatientSeenAt).HasPrecision(3);
            entity.Property(e => e.PaymentMethod)
                .HasMaxLength(8)
                .IsUnicode(false);
            entity.Property(e => e.TempC).HasColumnType("decimal(3, 1)");
            entity.Property(e => e.Type)
                .HasMaxLength(12)
                .IsUnicode(false);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.WeightKg).HasColumnType("decimal(5, 2)");

            entity.HasOne(d => d.Appointment).WithOne(p => p.SessionNavigation)
                .HasForeignKey<Session>(d => d.AppointmentId)
                .HasConstraintName("FK_Sessions_AppointmentId");

            entity.HasOne(d => d.Branch).WithMany(p => p.Sessions)
                .HasForeignKey(d => d.BranchId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Sessions_BranchId");

            entity.HasOne(d => d.CreatedByNavigation).WithMany(p => p.SessionCreatedByNavigations)
                .HasForeignKey(d => d.CreatedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Sessions_CreatedBy");

            entity.HasOne(d => d.DeletedByNavigation).WithMany(p => p.SessionDeletedByNavigations)
                .HasForeignKey(d => d.DeletedBy)
                .HasConstraintName("FK_Sessions_DeletedBy");

            entity.HasOne(d => d.Doctor).WithMany(p => p.Sessions)
                .HasForeignKey(d => d.DoctorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Sessions_DoctorId");

            entity.HasOne(d => d.Link).WithMany(p => p.Sessions)
                .HasForeignKey(d => d.LinkId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Sessions_LinkId");

            entity.HasOne(d => d.Patient).WithMany(p => p.Sessions)
                .HasForeignKey(d => d.PatientId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Sessions_PatientId");
        });

        modelBuilder.Entity<SessionPrivateNote>(entity =>
        {
            entity.HasKey(e => e.SessionId);

            entity.Property(e => e.SessionId).ValueGeneratedNever();
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.Session).WithOne(p => p.SessionPrivateNote)
                .HasForeignKey<SessionPrivateNote>(d => d.SessionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_SessionPrivateNotes_SessionId");
        });

        modelBuilder.Entity<SettingsHistory>(entity =>
        {
            entity.ToTable("SettingsHistory");

            entity.HasIndex(e => new { e.Field, e.ChangedAt }, "IX_SettingsHistory_Field_ChangedAt").IsDescending(false, true);

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.ChangedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.Field)
                .HasMaxLength(100)
                .IsUnicode(false);

            entity.HasOne(d => d.ChangedByNavigation).WithMany(p => p.SettingsHistories)
                .HasForeignKey(d => d.ChangedBy)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_SettingsHistory_ChangedBy");
        });

        modelBuilder.Entity<Specialty>(entity =>
        {
            entity.HasIndex(e => e.NameAr, "UQ_Specialties_NameAr").IsUnique();

            entity.HasIndex(e => e.NameEn, "UQ_Specialties_NameEn").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.Active).HasDefaultValue(true);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.IncludeGeneral).HasDefaultValue(true);
            entity.Property(e => e.NameAr).HasMaxLength(100);
            entity.Property(e => e.NameEn).HasMaxLength(100);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
        });

        modelBuilder.Entity<SpecialtyProfileItem>(entity =>
        {
            entity.HasIndex(e => new { e.SpecialtyId, e.ItemType, e.Value }, "UQ_SpecialtyProfileItems").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.ItemType)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.Value)
                .HasMaxLength(100)
                .IsUnicode(false);

            entity.HasOne(d => d.Specialty).WithMany(p => p.SpecialtyProfileItems)
                .HasForeignKey(d => d.SpecialtyId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_SpecialtyProfileItems_SpecialtyId");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(e => e.Phone, "IX_Users_Phone").HasFilter("([Phone] IS NOT NULL)");

            entity.HasIndex(e => e.Email, "UQ_Users_Email")
                .IsUnique()
                .HasFilter("([Email] IS NOT NULL)");

            entity.HasIndex(e => e.Phone, "UQ_Users_PatientPhone")
                .IsUnique()
                .HasFilter("([Role]='patient' AND [Phone] IS NOT NULL)");

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.AcceptedTermsAt).HasPrecision(3);
            entity.Property(e => e.AdminRole)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.DisplayName).HasMaxLength(60);
            entity.Property(e => e.Email).HasMaxLength(254);
            entity.Property(e => e.EmailVerifiedAt).HasPrecision(3);
            entity.Property(e => e.LastLoginAt).HasPrecision(3);
            entity.Property(e => e.Locale)
                .HasMaxLength(2)
                .IsUnicode(false)
                .HasDefaultValue("ar");
            entity.Property(e => e.LockoutEndAt).HasPrecision(3);
            entity.Property(e => e.NotifyChat).HasDefaultValue(true);
            entity.Property(e => e.NotifyReminders).HasDefaultValue(true);
            entity.Property(e => e.PasswordHash).HasMaxLength(256);
            entity.Property(e => e.Phone)
                .HasMaxLength(16)
                .IsUnicode(false);
            entity.Property(e => e.Role)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.SecurityStamp).HasDefaultValueSql("(newid())");
            entity.Property(e => e.Status)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("active");
            entity.Property(e => e.ThemeMode)
                .HasMaxLength(6)
                .IsUnicode(false)
                .HasDefaultValue("system");
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
        });

        modelBuilder.Entity<UserDevice>(entity =>
        {
            entity.HasIndex(e => new { e.UserId, e.DeviceId }, "UQ_UserDevices_User_Device").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.AppVersion)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.DeviceId)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.FcmToken)
                .HasMaxLength(512)
                .IsUnicode(false);
            entity.Property(e => e.Platform)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.UpdatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");

            entity.HasOne(d => d.User).WithMany(p => p.UserDevices)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_UserDevices_UserId");
        });

        modelBuilder.Entity<UserToken>(entity =>
        {
            entity.HasIndex(e => e.TokenHash, "UQ_UserTokens_TokenHash").IsUnique();

            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())");
            entity.Property(e => e.ExpiresAt).HasPrecision(3);
            entity.Property(e => e.Purpose)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.TokenHash)
                .HasMaxLength(32)
                .IsFixedLength();
            entity.Property(e => e.UsedAt).HasPrecision(3);

            entity.HasOne(d => d.User).WithMany(p => p.UserTokens)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_UserTokens_UserId");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
