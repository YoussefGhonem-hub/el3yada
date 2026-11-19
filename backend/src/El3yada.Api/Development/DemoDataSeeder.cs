using System.Text;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Files;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Development;

/// <summary>Ids of the demo rows, for tests and the dev token endpoint.</summary>
public sealed record DemoData(
    Guid AdminUserId,
    Guid DoctorAUserId,
    Guid DoctorBUserId,
    Guid AssistantUserId,
    Guid PatientUserId,
    Guid PatientId,
    Guid VisibleSessionId,
    Guid DeletedSessionId,
    Guid OtherDoctorSessionId,
    Guid SentRxId,
    Guid CancelledRxId,
    Guid ReplacementRxId,
    Guid DraftRxId,
    Guid ReviewRxId,
    Guid VisibleRecordId,
    Guid VisibleAttachmentId,
    Guid DeletedRecordId,
    Guid OtherPatientId,
    Guid OtherPatientSessionId,
    string PrivateNoteText);

/// <summary>
/// Demo data for development and the API tests, until Phases 1–3 can create it through the API:
/// an admin, two doctors (A and B) who share one patient, an assistant, and visits, prescriptions
/// and files in every state the patient app must handle (visible, deleted, draft, cancelled,
/// another patient's). Idempotent: it does nothing when the demo admin already exists.
/// Never registered outside Development.
/// </summary>
public sealed class DemoDataSeeder(AppDbContext db, IFileStorage storage, TimeProvider clock)
{
    public const string AdminEmail = "admin@el3yada.dev";
    public const string DoctorAEmail = "doctor@el3yada.dev";
    public const string DoctorBEmail = "doctor.b@el3yada.dev";
    public const string AssistantPhone = "+201000000001";
    public const string PatientPhone = "+201000000002";
    public const string OtherPatientPhone = "+201000000003";

    private const string PrivateNote = "PRIVATE-NOTE: suspect non-compliance, do not share";

    // A 1×1 PNG and a one-page PDF, enough for the viewers and downloads.
    private static readonly byte[] Png = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==");

    private static readonly byte[] Pdf = Encoding.ASCII.GetBytes(
        "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n" +
        "3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 420 595]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n");

    public async Task<DemoData> SeedAsync(CancellationToken ct = default)
    {
        var existing = await db.Users.AsNoTracking().AnyAsync(u => u.Email == AdminEmail, ct);
        if (existing) return await LoadAsync(ct);

        var now = clock.GetUtcNow().UtcDateTime;
        var today = DateOnly.FromDateTime(now);
        var specialtyId = await db.Specialties.OrderBy(s => s.SortOrder).Select(s => s.Id).FirstAsync(ct);

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var admin = NewUser(Roles.Admin, "مدير تجريبي", email: AdminEmail, adminRole: "superAdmin");
        var doctorAUser = NewUser(Roles.Doctor, "د. أحمد سامي", email: DoctorAEmail);
        var doctorBUser = NewUser(Roles.Doctor, "د. منى حسن", email: DoctorBEmail);
        var assistantUser = NewUser(Roles.Assistant, "سارة علي", phone: AssistantPhone);
        var patientUser = NewUser(Roles.Patient, "محمد إبراهيم", phone: PatientPhone);
        var otherPatientUser = NewUser(Roles.Patient, "خالد يوسف", phone: OtherPatientPhone);
        db.Users.AddRange(admin, doctorAUser, doctorBUser, assistantUser, patientUser, otherPatientUser);

        var doctorA = NewDoctor(doctorAUser, "د. أحمد سامي", "Dr. Ahmed Samy", "استشاري", "Consultant", specialtyId, 30000, 15000);
        var doctorB = NewDoctor(doctorBUser, "د. منى حسن", "Dr. Mona Hassan", "أخصائي", "Specialist", specialtyId, 25000, null);
        db.Doctors.AddRange(doctorA, doctorB);
        await db.SaveChangesAsync(ct);

        var branchA1 = NewBranch(doctorA.UserId, "فرع المعادي", "Maadi branch", "القاهرة", "المعادي", "شارع 9", isDefault: true);
        branchA1.ExaminationPricePiasters = 35000; // its own price; consultation falls back to the doctor's
        branchA1.PaymentMethodsJson = "[\"cash\",\"instapay\"]";
        branchA1.AmenitiesJson = "[\"elevator\",\"parking\"]";
        var branchA2 = NewBranch(doctorA.UserId, "فرع مدينة نصر", "Nasr City branch", "القاهرة", "مدينة نصر", "عباس العقاد", isDefault: false);
        branchA2.Status = "temporarilyClosed";
        branchA2.ClosedMessage = "مغلق للتجديد";
        branchA2.ReopenDate = today.AddDays(14);
        var branchArchived = NewBranch(doctorA.UserId, "فرع قديم", null, "الجيزة", "الدقي", "التحرير", isDefault: false);
        branchArchived.Status = "archived";
        var branchB = NewBranch(doctorB.UserId, "عيادة الزمالك", "Zamalek clinic", "القاهرة", "الزمالك", "26 يوليو", isDefault: true);
        db.Branches.AddRange(branchA1, branchA2, branchArchived, branchB);
        await db.SaveChangesAsync(ct);

        doctorA.DefaultBranchId = branchA1.Id;
        doctorB.DefaultBranchId = branchB.Id;
        db.BranchPhones.AddRange(
            new BranchPhone { Id = NewId.Next(), BranchId = branchA1.Id, Number = "+201011111111", Label = "reception", IsWhatsapp = true, SortOrder = 0 },
            new BranchPhone { Id = NewId.Next(), BranchId = branchA1.Id, Number = "+201022222222", Label = "mobile", SortOrder = 1 },
            new BranchPhone { Id = NewId.Next(), BranchId = branchB.Id, Number = "+201033333333", Label = "reception", IsWhatsapp = true });
        foreach (var weekday in new byte[] { 6, 7, 1, 2, 3 })   // Saturday … Wednesday
        {
            db.BranchPeriods.Add(new BranchPeriod { Id = NewId.Next(), BranchId = branchA1.Id, Weekday = weekday, StartLocal = new(17, 0), EndLocal = new(22, 0), Label = "مساءً", Capacity = 30 });
        }
        db.BranchPeriods.Add(new BranchPeriod { Id = NewId.Next(), BranchId = branchB.Id, Weekday = 4, StartLocal = new(11, 0), EndLocal = new(15, 0), Capacity = 20 });

        var assistant = new Assistant
        {
            UserId = assistantUser.Id, DoctorId = doctorA.UserId, FullName = "سارة علي", Phone = AssistantPhone,
            Preset = "reception", AllBranches = true, PatientsManage = true, SessionsCreate = true,
            AppointmentsView = true, AppointmentsManage = true,
            CreatedBy = doctorAUser.Id, CreatedAt = now, UpdatedAt = now, LastActiveAt = now,
        };
        db.Assistants.Add(assistant);

        var patient = NewPatient(patientUser, "محمد إبراهيم", PatientPhone, doctorA.UserId);
        patient.BloodType = "O+";
        var otherPatient = NewPatient(otherPatientUser, "خالد يوسف", OtherPatientPhone, doctorA.UserId);
        db.Patients.AddRange(patient, otherPatient);
        await db.SaveChangesAsync(ct);

        var linkA = NewLink(doctorA, patient, doctorAUser.Id);
        linkA.FamilyHistory = "السكر في العائلة";
        linkA.ProfileNotes = "يفضل المواعيد المسائية";
        var linkB = NewLink(doctorB, patient, doctorBUser.Id);
        var linkOther = NewLink(doctorA, otherPatient, doctorAUser.Id);
        db.DoctorPatients.AddRange(linkA, linkB, linkOther);
        await db.SaveChangesAsync(ct);

        db.PatientMedicalProfileItems.AddRange(
            new PatientMedicalProfileItem { Id = NewId.Next(), LinkId = linkA.Id, Kind = "allergy", Text = "البنسلين", CreatedBy = doctorAUser.Id, CreatedAt = now },
            new PatientMedicalProfileItem { Id = NewId.Next(), LinkId = linkA.Id, Kind = "chronicDisease", Text = "ضغط الدم", SortOrder = 1, CreatedBy = doctorAUser.Id, CreatedAt = now },
            new PatientMedicalProfileItem { Id = NewId.Next(), LinkId = linkA.Id, Kind = "currentMedication", Text = "Concor 5 mg", CreatedBy = doctorAUser.Id, CreatedAt = now },
            new PatientMedicalProfileItem { Id = NewId.Next(), LinkId = linkB.Id, Kind = "surgery", Text = "استئصال الزائدة 2015", CreatedBy = doctorBUser.Id, CreatedAt = now });

        // Doctor A: an examination 10 days ago, then a consultation that was deleted the same day.
        var visible = NewSession(linkA, branchA1.Id, "examination", now.AddDays(-10), doctorAUser.Id);
        visible.ChiefComplaint = "صداع متكرر";
        visible.Findings = "ضغط 150/95";
        visible.BpSys = 150; visible.BpDia = 95; visible.Pulse = 84;
        visible.Diagnosis = "ارتفاع ضغط الدم الأولي";
        visible.PatientNotes = "قلل الملح وامش 30 دقيقة يومياً";
        visible.FollowUpDate = today.AddDays(20);
        var deleted = NewSession(linkA, branchA1.Id, "consultation", now.AddDays(-2), doctorAUser.Id);
        deleted.Diagnosis = "DELETED-SESSION";
        deleted.Deleted = true; deleted.DeletedAt = now.AddDays(-2); deleted.DeletedBy = doctorAUser.Id; deleted.DeleteReason = "تسجيل بالخطأ";
        // Doctor B: one examination yesterday.
        var otherDoctor = NewSession(linkB, branchB.Id, "examination", now.AddDays(-1), doctorBUser.Id);
        otherDoctor.Diagnosis = "التهاب الحلق";
        // Another patient's session must never show up.
        var otherPatientSession = NewSession(linkOther, branchA1.Id, "examination", now.AddDays(-3), doctorAUser.Id);
        otherPatientSession.Diagnosis = "OTHER-PATIENT";
        db.Sessions.AddRange(visible, deleted, otherDoctor, otherPatientSession);
        await db.SaveChangesAsync(ct);

        db.SessionPrivateNotes.Add(new SessionPrivateNote { SessionId = visible.Id, Text = PrivateNote, UpdatedAt = now });
        linkA.LastSessionId = visible.Id; linkA.LastSessionAt = visible.CreatedAt; linkA.LastSessionType = "examination";
        linkA.LastSessionBranchId = branchA1.Id; linkA.FirstSessionAt = visible.CreatedAt; linkA.SessionCount = 1; linkA.ExamCount = 1;
        linkB.LastSessionId = otherDoctor.Id; linkB.LastSessionAt = otherDoctor.CreatedAt; linkB.LastSessionType = "examination";
        linkB.LastSessionBranchId = branchB.Id; linkB.FirstSessionAt = otherDoctor.CreatedAt; linkB.SessionCount = 1; linkB.ExamCount = 1;

        var cancelled = NewRx(visible, "medication", "cancelled", now.AddDays(-10));
        cancelled.CancelledAt = now.AddDays(-9); cancelled.CancelReason = "تعديل الجرعة";
        cancelled.PrescriptionMedicationItems.Add(new PrescriptionMedicationItem { Id = NewId.Next(), DrugName = "Concor 10 mg", Form = "tablet", Dose = "1", Frequency = "1x1", Timing = "afterFood", Duration = "30d" });
        db.Prescriptions.Add(cancelled);
        await db.SaveChangesAsync(ct);

        var replacement = NewRx(visible, "medication", "sent", now.AddDays(-9));
        replacement.ReplacesRxId = cancelled.Id;
        replacement.Advice = "قِس الضغط يومياً";
        replacement.PrescriptionMedicationItems.Add(new PrescriptionMedicationItem { Id = NewId.Next(), SortOrder = 0, DrugName = "Concor 5 mg", ActiveIngredient = "bisoprolol", Form = "tablet", Strength = "5 mg", Dose = "1", Frequency = "1x1", Timing = "afterFood", Duration = "continuous" });
        replacement.PrescriptionMedicationItems.Add(new PrescriptionMedicationItem { Id = NewId.Next(), SortOrder = 1, DrugName = "Panadol", Form = "tablet", Strength = "500 mg", Dose = "1", Frequency = "when needed", Timing = "unspecified", Duration = "5d", Instructions = "عند الصداع فقط" });
        var sentInvestigations = NewRx(visible, "investigations", "sent", now.AddDays(-10));
        sentInvestigations.PrescriptionInvestigationItems.Add(new PrescriptionInvestigationItem { Id = NewId.Next(), Category = "lab", Name = "CBC" });
        sentInvestigations.PrescriptionInvestigationItems.Add(new PrescriptionInvestigationItem { Id = NewId.Next(), SortOrder = 1, Category = "radiology", Name = "Echocardiography", Notes = "صائم 4 ساعات" });
        var draft = NewRx(visible, "medication", "draft", null);
        draft.Diagnosis = "DRAFT-RX";
        draft.PrescriptionMedicationItems.Add(new PrescriptionMedicationItem { Id = NewId.Next(), DrugName = "DRAFT-DRUG" });
        var review = NewRx(visible, "investigations", "readyForReview", null);
        review.PreparedBy = assistantUser.Id; review.PreparedByRole = "assistant";
        db.Prescriptions.AddRange(replacement, sentInvestigations, draft, review);

        var record = NewRecord(visible, "lab", "تحليل صورة دم", today.AddDays(-9), doctorAUser.Id);
        var attachment = new MedicalRecordAttachment
        {
            Id = NewId.Next(),
            Path = $"medical/{doctorA.UserId}/{patient.Id}/{record.Id}/cbc.png",
            ThumbPath = $"medical/{doctorA.UserId}/{patient.Id}/{record.Id}/cbc.thumb.jpg",
            FileName = "cbc.png", MimeType = "image/png", SizeBytes = Png.Length,
        };
        record.MedicalRecordAttachments.Add(attachment);
        var deletedRecord = NewRecord(visible, "radiology", "DELETED-RECORD", today.AddDays(-9), doctorAUser.Id);
        deletedRecord.Deleted = true; deletedRecord.DeletedAt = now; deletedRecord.DeletedBy = doctorAUser.Id;
        var recordB = NewRecord(otherDoctor, "other", "تقرير طبي", today.AddDays(-1), doctorBUser.Id);
        recordB.OtherType = "report";
        db.MedicalRecords.AddRange(record, deletedRecord, recordB);
        await db.SaveChangesAsync(ct);

        await storage.SaveAsync(attachment.Path, new MemoryStream(Png), ct);
        await storage.SaveAsync(attachment.ThumbPath, new MemoryStream(Png), ct);
        foreach (var rx in new[] { cancelled, replacement, sentInvestigations })
            await storage.SaveAsync(rx.PdfPath!, new MemoryStream(Pdf), ct);

        await tx.CommitAsync(ct);
        return await LoadAsync(ct);

        // ---- builders ----

        User NewUser(string role, string name, string? email = null, string? phone = null, string? adminRole = null) => new()
        {
            Id = NewId.Next(), Role = role, AdminRole = adminRole, DisplayName = name, Email = email, Phone = phone,
            SecurityStamp = Guid.NewGuid(), CreatedAt = now, UpdatedAt = now,
        };

        Doctor NewDoctor(User user, string name, string nameEn, string title, string titleEn, Guid specialty, int? exam, int? consultation) => new()
        {
            UserId = user.Id, FullName = name, FullNameEn = nameEn, Title = title, TitleEn = titleEn,
            SpecialtyId = specialty, LicenseNumber = "DEV-" + user.Id.ToString("N")[..8], LicenseDocPath = $"doctors/{user.Id}/license/dev.png",
            ExaminationPricePiasters = exam, ConsultationPricePiasters = consultation,
            Status = "active", StatusChangedAt = now, ApprovedAt = now, ApprovedBy = admin.Id, NextFileNumber = 1,
            CreatedAt = now, UpdatedAt = now,
        };

        Branch NewBranch(Guid doctorId, string nameAr, string? nameEn, string governorate, string city, string street, bool isDefault) => new()
        {
            Id = NewId.Next(), DoctorId = doctorId, NameAr = nameAr, NameEn = nameEn, IsDefault = isDefault,
            Governorate = governorate, City = city, Area = city, Street = street, Landmark = "بجوار الصيدلية",
            CreatedAt = now, UpdatedAt = now,
        };

        Patient NewPatient(User user, string name, string phone, Guid createdBy) => new()
        {
            Id = NewId.Next(), UserId = user.Id, FullName = name, Phone = phone, Gender = "male",
            DateOfBirth = new DateOnly(1985, 3, 14), CreatedByDoctorId = createdBy, CreatedAt = now, UpdatedAt = now,
        };

        DoctorPatient NewLink(Doctor doctor, Patient p, Guid by) => new()
        {
            Id = NewId.Next(), DoctorId = doctor.UserId, PatientId = p.Id, FileNumber = doctor.NextFileNumber++,
            PatientName = p.FullName, PatientPhone = p.Phone, SearchName = p.FullName,
            LinkedAt = now, LinkedBy = by, UpdatedAt = now,
        };

        Session NewSession(DoctorPatient link, Guid branchId, string type, DateTime at, Guid by)
        {
            var day = DateOnly.FromDateTime(at);
            return new Session
            {
                Id = NewId.Next(), DoctorId = link.DoctorId, PatientId = link.PatientId, LinkId = link.Id, BranchId = branchId,
                Type = type, FeePiasters = type == "examination" ? 3000 : 1500, PatientFeePiasters = 30000, ListPricePiasters = 30000,
                DayKey = day, MonthKey = day.ToString("yyyy-MM"), CreatedBy = by, CreatedByRole = "doctor",
                CreatedAt = at, UpdatedAt = at,
            };
        }

        Prescription NewRx(Session session, string kind, string status, DateTime? sentAt)
        {
            var id = NewId.Next();
            var sent = status is "sent" or "cancelled";
            return new Prescription
            {
                Id = id, DoctorId = session.DoctorId, PatientId = session.PatientId, SessionId = session.Id, Kind = kind,
                Diagnosis = session.Diagnosis, Status = status, QrShortCode = Guid.NewGuid().ToString("N")[..12],
                PdfPath = sent ? $"prescriptions/{session.DoctorId}/{session.PatientId}/{id}.pdf" : null,
                SentAt = sent ? sentAt : null, CreatedAt = sentAt ?? now, UpdatedAt = sentAt ?? now,
            };
        }

        MedicalRecord NewRecord(Session session, string category, string title, DateOnly date, Guid by) => new()
        {
            Id = NewId.Next(), DoctorId = session.DoctorId, PatientId = session.PatientId, SessionId = session.Id,
            Category = category, Title = title, DocumentDate = date, Source = "upload",
            CreatedBy = by, CreatedByRole = "doctor", CreatedAt = now, UpdatedAt = now,
        };
    }

    private async Task<DemoData> LoadAsync(CancellationToken ct)
    {
        async Task<Guid> UserId(string? email = null, string? phone = null, string? role = null) =>
            await db.Users.Where(u => (email != null && u.Email == email) || (phone != null && u.Phone == phone && u.Role == role))
                .Select(u => u.Id).FirstAsync(ct);

        var patientUserId = await UserId(phone: PatientPhone, role: Roles.Patient);
        var patientId = await db.Patients.Where(p => p.UserId == patientUserId).Select(p => p.Id).FirstAsync(ct);
        var otherPatientId = await db.Patients.Where(p => p.Phone == OtherPatientPhone).Select(p => p.Id).FirstAsync(ct);
        var doctorA = await UserId(email: DoctorAEmail);
        var doctorB = await UserId(email: DoctorBEmail);

        var sessions = await db.Sessions.Where(s => s.PatientId == patientId || s.PatientId == otherPatientId)
            .Select(s => new { s.Id, s.PatientId, s.DoctorId, s.Deleted }).ToListAsync(ct);
        var rx = await db.Prescriptions.Where(p => p.PatientId == patientId)
            .Select(p => new { p.Id, p.Status, p.Kind, p.ReplacesRxId }).ToListAsync(ct);
        var records = await db.MedicalRecords.Where(r => r.PatientId == patientId && r.DoctorId == doctorA)
            .Select(r => new { r.Id, r.Deleted, Attachment = r.MedicalRecordAttachments.Select(a => a.Id).FirstOrDefault() }).ToListAsync(ct);
        var visibleRecord = records.First(r => !r.Deleted);
        var visibleSession = sessions.First(s => s.PatientId == patientId && s.DoctorId == doctorA && !s.Deleted).Id;

        return new DemoData(
            AdminUserId: await UserId(email: AdminEmail),
            DoctorAUserId: doctorA,
            DoctorBUserId: doctorB,
            AssistantUserId: await UserId(phone: AssistantPhone, role: Roles.Assistant),
            PatientUserId: patientUserId,
            PatientId: patientId,
            VisibleSessionId: visibleSession,
            DeletedSessionId: sessions.First(s => s.PatientId == patientId && s.Deleted).Id,
            OtherDoctorSessionId: sessions.First(s => s.PatientId == patientId && s.DoctorId == doctorB).Id,
            SentRxId: rx.First(p => p.Status == "sent" && p.Kind == "investigations").Id,
            CancelledRxId: rx.First(p => p.Status == "cancelled").Id,
            ReplacementRxId: rx.First(p => p.ReplacesRxId != null).Id,
            DraftRxId: rx.First(p => p.Status == "draft").Id,
            ReviewRxId: rx.First(p => p.Status == "readyForReview").Id,
            VisibleRecordId: visibleRecord.Id,
            VisibleAttachmentId: visibleRecord.Attachment,
            DeletedRecordId: records.First(r => r.Deleted).Id,
            OtherPatientId: otherPatientId,
            OtherPatientSessionId: sessions.First(s => s.PatientId == otherPatientId).Id,
            PrivateNoteText: PrivateNote);
    }
}
