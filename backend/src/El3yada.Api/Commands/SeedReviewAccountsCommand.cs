using El3yada.Api.Analytics;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Api.Patients;
using El3yada.Api.Prescriptions;
using El3yada.Api.Sessions;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Commands;

/// <summary>
/// <c>dotnet run --project src/El3yada.Api -- seed-review-accounts --patient-phone 01XXXXXXXXX [--doctor-email …]</c>
/// <para>
/// The two accounts Apple's and Google's reviewers sign in with (App Review Information > Sign-in required): a
/// doctor and one of that doctor's patients, with a clinic that already has something in it. Both passwords are
/// printed once and never need changing, so a reviewer can sign in again later. Run it once on the server the
/// store build talks to, with that server's environment variables.
/// </para>
/// <para>
/// The doctor's free trial runs for <see cref="TrialYears"/> years: no platform fees (BR-T3), no "trial ends
/// soon" banner (it shows only in the last 3 days) and no A15, however long a review takes. The patient has two
/// visits, a medical profile, a chat and a booking. The medication and lab prescriptions are drafts: their PDF is
/// drawn by the app, so sign in as the doctor once and send them (patient > Prescriptions > Send).
/// </para>
/// <para>
/// Use a phone number the team owns for the patient. Whoever has that number signs in as this patient, and a
/// doctor who later adds the number is linked to this account (BR-P3).
/// </para>
/// </summary>
public static class SeedReviewAccountsCommand
{
    public const string Name = "seed-review-accounts";

    public const string DefaultDoctorEmail = "appreview@el3yada.app";

    public const int TrialYears = 10;

    public const int PasswordLength = 12;

    /// <summary>The 1×1 PNG stored as the license, so the admin's license viewer has a file to open.</summary>
    private static readonly byte[] LicensePng = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==");

    public static bool IsInvocation(string[] args) => args.Length > 0 && args[0] == Name;

    /// <summary>Runs the command with the app's services and returns the process exit code.</summary>
    public static async Task<int> RunAsync(IServiceProvider services, string[] args, TextWriter output)
    {
        await using var scope = services.CreateAsyncScope();
        var provider = scope.ServiceProvider;
        return await ExecuteAsync(
            provider.GetRequiredService<AppDbContext>(),
            provider.GetRequiredService<Passwords>(),
            provider.GetRequiredService<IFileStorage>(),
            provider.GetRequiredService<DailyMetricsBuilder>(),
            provider.GetRequiredService<TimeProvider>(),
            args,
            output);
    }

    /// <summary>The command itself, called directly by tests. <paramref name="args"/> starts with "seed-review-accounts".</summary>
    public static async Task<int> ExecuteAsync(
        AppDbContext db, Passwords passwords, IFileStorage storage, DailyMetricsBuilder metrics, TimeProvider time,
        string[] args, TextWriter output, CancellationToken cancellationToken = default)
    {
        if (!TryParse(args, out var doctorEmail, out var patientPhone, out var error))
        {
            await output.WriteLineAsync(error);
            await output.WriteLineAsync(
                $"Usage: dotnet run --project src/El3yada.Api -- {Name} --patient-phone 01XXXXXXXXX [--doctor-email {DefaultDoctorEmail}]");
            return 2;
        }

        if (await db.Users.AnyAsync(u => u.Email == doctorEmail, cancellationToken))
        {
            await output.WriteLineAsync($"An account with the email {doctorEmail} already exists. Nothing was changed.");
            return 1;
        }

        if (await db.Users.AnyAsync(u => u.Phone == patientPhone, cancellationToken))
        {
            await output.WriteLineAsync($"An account with the number {patientPhone} already exists. Nothing was changed.");
            return 1;
        }

        var now = time.GetUtcNow().UtcDateTime;
        var today = CairoTime.Today(time);
        var specialtyId = await db.Specialties.Where(s => s.NameEn == "Internal Medicine").Select(s => (Guid?)s.Id)
            .FirstOrDefaultAsync(cancellationToken)
            ?? await db.Specialties.OrderBy(s => s.SortOrder).Select(s => s.Id).FirstAsync(cancellationToken);
        var doctorPassword = Passwords.GenerateTemporary(PasswordLength);
        var patientPassword = Passwords.GenerateTemporary(PasswordLength);

        // ---- the doctor, with one branch open every day ----
        var doctorUser = new User
        {
            Id = Guid.NewGuid(), Role = Roles.Doctor, Status = AccountStatuses.Active, DisplayName = "د. سارة محمود",
            Email = doctorEmail, EmailVerifiedAt = now, SecurityStamp = Guid.NewGuid(), Locale = "ar",
            AcceptedTermsAt = now, CreatedAt = now, UpdatedAt = now,
        };
        doctorUser.PasswordHash = passwords.Hash(doctorUser, doctorPassword);
        var licensePath = StoragePath.DoctorLicense(doctorUser.Id, Guid.NewGuid(), FileTypes.Png);
        var doctor = new Doctor
        {
            UserId = doctorUser.Id, FullName = "د. سارة محمود", FullNameEn = "Dr. Sara Mahmoud",
            Title = "استشاري", TitleEn = "Consultant", DegreesAr = "دكتوراه الباطنة - جامعة القاهرة",
            DegreesEn = "MD Internal Medicine, Cairo University", SpecialtyId = specialtyId, LicenseNumber = "REVIEW-0001",
            LicenseDocPath = licensePath.Value, ExaminationPricePiasters = 40000, ConsultationPricePiasters = 20000,
            Status = DoctorStatuses.Active, StatusChangedAt = now, ApprovedAt = now, TrialEndsAt = now.AddYears(TrialYears),
            NextFileNumber = 2, CreatedAt = now, UpdatedAt = now,
        };
        var branch = new Branch
        {
            Id = Guid.NewGuid(), DoctorId = doctorUser.Id, NameAr = "عيادة مدينة نصر", NameEn = "Nasr City clinic",
            IsDefault = true, Governorate = "القاهرة", City = "مدينة نصر", Area = "مدينة نصر",
            AddressDetails = "15 شارع عباس العقاد، الدور الثالث، شقة 7", Landmark = "أمام مكتبة ألف",
            PaymentMethodsJson = "[\"cash\",\"instapay\"]", AmenitiesJson = "[\"elevator\",\"parking\"]",
            // A reviewer can book as the patient even though the patient already has a booking.
            MaxUpcomingPerPatient = 3,
            CreatedAt = now, UpdatedAt = now,
        };

        // ---- the patient ----
        var patientUser = new User
        {
            Id = Guid.NewGuid(), Role = Roles.Patient, Status = AccountStatuses.Active, DisplayName = "أحمد علي حسن",
            Phone = patientPhone, SecurityStamp = Guid.NewGuid(), Locale = "ar", AcceptedTermsAt = now,
            CreatedAt = now, UpdatedAt = now,
        };
        patientUser.PasswordHash = passwords.Hash(patientUser, patientPassword);
        var patient = new Patient
        {
            Id = Guid.NewGuid(), UserId = patientUser.Id, FullName = "أحمد علي حسن", Phone = patientPhone,
            Gender = Genders.Male, DateOfBirth = new DateOnly(1988, 5, 10), BloodType = "A+",
            CreatedByDoctorId = doctorUser.Id, Status = PatientStatuses.Active, CreatedAt = now, UpdatedAt = now,
        };
        var link = new DoctorPatient
        {
            Id = Guid.NewGuid(), DoctorId = doctorUser.Id, PatientId = patient.Id, FileNumber = 1,
            PatientName = patient.FullName, PatientPhone = patientPhone, SearchName = SearchText.Normalize(patient.FullName),
            FamilyHistory = "السكر في العائلة", LinkedAt = now.AddDays(-14), LinkedBy = doctorUser.Id, UpdatedAt = now,
        };

        // ---- two visits: an examination two weeks ago, a consultation three days ago ----
        var examination = NewSession(SessionTypes.Examination, now.AddDays(-14), 40000);
        examination.ChiefComplaint = "صداع متكرر ودوخة";
        examination.Findings = "الضغط 150/95، النبض منتظم";
        examination.BpSys = 150; examination.BpDia = 95; examination.Pulse = 84; examination.WeightKg = 86;
        examination.Diagnosis = "ارتفاع ضغط الدم";
        examination.PatientNotes = "قلل الملح وامشِ 30 دقيقة يومياً، وقِس الضغط كل يوم وسجّل القراءات.";
        var consultation = NewSession(SessionTypes.Consultation, now.AddDays(-3), 20000);
        consultation.ChiefComplaint = "متابعة الضغط";
        consultation.Findings = "الضغط 135/85 بعد العلاج";
        consultation.BpSys = 135; consultation.BpDia = 85; consultation.Pulse = 78;
        consultation.Diagnosis = "ارتفاع ضغط الدم - متابعة";
        consultation.PatientNotes = "استمر على نفس العلاج، والمتابعة بعد شهر.";
        consultation.FollowUpDate = today.AddDays(27);
        // ---- prescriptions: drafts, sent once from the app (it draws the PDF) ----
        var medication = NewDraft("medication", await PrescriptionStore.NewShortCodeAsync(db, cancellationToken));
        medication.Advice = "قِس الضغط يومياً وسجّل القراءات.";
        medication.PrescriptionMedicationItems.Add(new PrescriptionMedicationItem
        {
            Id = Guid.NewGuid(), SortOrder = 0, DrugName = "Concor 5 mg", ActiveIngredient = "bisoprolol", Form = "tablet",
            Strength = "5 mg", Dose = "قرص", Frequency = "مرة يومياً", Timing = "afterFood", Duration = "continuous",
        });
        medication.PrescriptionMedicationItems.Add(new PrescriptionMedicationItem
        {
            Id = Guid.NewGuid(), SortOrder = 1, DrugName = "Panadol 500 mg", ActiveIngredient = "paracetamol", Form = "tablet",
            Strength = "500 mg", Dose = "قرص", Frequency = "عند اللزوم", Timing = "unspecified", Duration = "5d",
            Instructions = "عند الصداع فقط",
        });
        var investigations = NewDraft("investigations", await PrescriptionStore.NewShortCodeAsync(db, cancellationToken));
        investigations.PrescriptionInvestigationItems.Add(new PrescriptionInvestigationItem { Id = Guid.NewGuid(), SortOrder = 0, Category = "lab", Name = "CBC" });
        investigations.PrescriptionInvestigationItems.Add(new PrescriptionInvestigationItem { Id = Guid.NewGuid(), SortOrder = 1, Category = "lab", Name = "Lipid profile", Notes = "صائم 12 ساعة" });
        investigations.PrescriptionInvestigationItems.Add(new PrescriptionInvestigationItem { Id = Guid.NewGuid(), SortOrder = 2, Category = "radiology", Name = "Echocardiography" });

        // ---- a chat, and a booking a week from now ----
        var chat = new Chat
        {
            Id = Guid.NewGuid(), LinkId = link.Id, DoctorId = doctorUser.Id, PatientId = patient.Id, CreatedAt = now.AddDays(-2),
        };
        var patientMessage = new ChatMessage
        {
            Id = Guid.NewGuid(), ChatId = chat.Id, SenderId = patientUser.Id, SenderRole = Roles.Patient, SenderName = patient.FullName,
            Type = "text", Text = "صباح الخير يا دكتورة، الضغط بقى 130/85 الحمد لله", ReadAt = now.AddDays(-2).AddHours(1),
            CreatedAt = now.AddDays(-2),
        };
        var doctorMessage = new ChatMessage
        {
            Id = Guid.NewGuid(), ChatId = chat.Id, SenderId = doctorUser.Id, SenderRole = Roles.Doctor, SenderName = doctor.FullName,
            Type = "text", Text = "ممتاز، كمّل على نفس العلاج ونشوفك في المتابعة.", CreatedAt = now.AddDays(-2).AddHours(1),
        };
        chat.LastMessageAt = doctorMessage.CreatedAt;
        chat.LastMessageType = doctorMessage.Type;
        chat.LastMessageText = doctorMessage.Text;
        chat.LastMessageSenderId = doctorUser.Id;
        var bookingDay = today.AddDays(7);
        var evening = new TimeOnly(17, 0);
        var booking = new Appointment
        {
            Id = Guid.NewGuid(), DoctorId = doctorUser.Id, BranchId = branch.Id, PatientId = patient.Id,
            VisitType = SessionTypes.Consultation, Mode = "queue", LocalDate = bookingDay, PeriodStartLocal = evening,
            StartUtc = TimeZoneInfo.ConvertTimeToUtc(bookingDay.ToDateTime(evening, DateTimeKind.Unspecified), CairoTime.Zone),
            Status = "confirmed", Source = "patientApp", BookedBy = patientUser.Id, BookedByRole = Roles.Patient,
            Reason = "متابعة الضغط", CreatedAt = now.AddDays(-1), UpdatedAt = now.AddDays(-1),
        };

        await using (var transaction = await db.Database.BeginTransactionAsync(cancellationToken))
        {
            db.Users.AddRange(doctorUser, patientUser);
            db.Doctors.Add(doctor);
            db.Branches.Add(branch);
            await db.SaveChangesAsync(cancellationToken);
            // Doctors.DefaultBranchId and Branches.DoctorId point at each other, so the default is set in a second save.
            doctor.DefaultBranchId = branch.Id;
            foreach (var weekday in Enumerable.Range(1, 7).Select(d => (byte)d))
            {
                db.BranchPeriods.Add(new BranchPeriod { Id = Guid.NewGuid(), BranchId = branch.Id, Weekday = weekday, StartLocal = new(10, 0), EndLocal = new(14, 0), Label = "صباحاً", Capacity = 30 });
                db.BranchPeriods.Add(new BranchPeriod { Id = Guid.NewGuid(), BranchId = branch.Id, Weekday = weekday, StartLocal = evening, EndLocal = new(22, 0), Label = "مساءً", Capacity = 30 });
            }

            db.Patients.Add(patient);
            db.DoctorPatients.Add(link);
            db.PatientMedicalProfileItems.AddRange(
                new PatientMedicalProfileItem { Id = Guid.NewGuid(), LinkId = link.Id, Kind = "allergy", Text = "البنسلين", CreatedBy = doctorUser.Id, CreatedAt = now },
                new PatientMedicalProfileItem { Id = Guid.NewGuid(), LinkId = link.Id, Kind = "chronicDisease", Text = "ارتفاع ضغط الدم", CreatedBy = doctorUser.Id, CreatedAt = now },
                new PatientMedicalProfileItem { Id = Guid.NewGuid(), LinkId = link.Id, Kind = "currentMedication", Text = "Concor 5 mg", CreatedBy = doctorUser.Id, CreatedAt = now });
            db.Sessions.AddRange(examination, consultation);
            db.SessionPrivateNotes.Add(new SessionPrivateNote { SessionId = examination.Id, Text = "متابعة الالتزام بالعلاج وقياس الضغط في البيت.", UpdatedAt = now });
            db.Prescriptions.AddRange(medication, investigations);
            db.Chats.Add(chat);
            db.ChatMessages.AddRange(patientMessage, doctorMessage);
            db.ChatReadStates.AddRange(
                new ChatReadState { ChatId = chat.Id, UserId = doctorUser.Id, UnreadCount = 0, LastReadAt = doctorMessage.CreatedAt },
                new ChatReadState { ChatId = chat.Id, UserId = patientUser.Id, UnreadCount = 1, LastReadAt = patientMessage.CreatedAt });
            db.Appointments.Add(booking);
            await db.SaveChangesAsync(cancellationToken);
            // The link's visit counters point at the last session, which points back at the link: a second save.
            var counters = LinkCounters.Of(link);
            foreach (var session in new[] { examination, consultation })
            {
                counters = counters.With(new SessionFact(session.Id, session.Type, session.CreatedAt, branch.Id));
            }

            counters.ApplyTo(link);
            await db.SaveChangesAsync(cancellationToken);
            foreach (var session in new[] { examination, consultation })
            {
                await FeeStats.AddAsync(db, doctor.UserId, session.DayKey, session.MonthKey, session.Type, session.FeePiasters, cancellationToken);
            }

            await using (var license = new MemoryStream(LicensePng))
            {
                await storage.SaveAsync(licensePath, license, FileTypes.Png, cancellationToken: cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
        }

        // The dashboard's charts read the daily metrics, which the nightly job builds; build the two days now.
        foreach (var day in new[] { examination.DayKey, consultation.DayKey })
        {
            await metrics.BuildDayAsync(day, doctor.UserId, cancellationToken);
        }

        await output.WriteLineAsync("Created the store review accounts. The passwords are shown once and never need changing.");
        await output.WriteLineAsync($"Doctor:  {doctorEmail}");
        await output.WriteLineAsync($"Doctor password: {doctorPassword}");
        await output.WriteLineAsync($"Patient: {Local(patientPhone)}");
        await output.WriteLineAsync($"Patient password: {patientPassword}");
        await output.WriteLineAsync("Next: sign in as the doctor and send the two draft prescriptions (patient > Prescriptions > Send).");
        return 0;

        Session NewSession(string type, DateTime at, int price)
        {
            var day = CairoTime.DayOf(at);
            return new Session
            {
                Id = Guid.NewGuid(), DoctorId = doctorUser.Id, PatientId = patient.Id, LinkId = link.Id, BranchId = branch.Id,
                // The free trial is running, so no platform fee (BR-T3).
                Type = type, FeePiasters = 0, PatientFeePiasters = price, ListPricePiasters = price, PaymentMethod = "cash",
                DayKey = day, MonthKey = CairoTime.MonthKey(day), CreatedBy = doctorUser.Id, CreatedByRole = Roles.Doctor,
                PatientSeenAt = at.AddHours(2), CreatedAt = at, UpdatedAt = at,
            };
        }

        Prescription NewDraft(string kind, string shortCode) => new()
        {
            Id = Guid.NewGuid(), DoctorId = doctorUser.Id, PatientId = patient.Id, SessionId = consultation.Id, Kind = kind,
            Diagnosis = consultation.Diagnosis, Status = PrescriptionStatuses.Draft, QrShortCode = shortCode,
            CreatedAt = now, UpdatedAt = now,
        };
    }

    /// <summary>+201012345678 → 01012345678, the way people type it on the login screen.</summary>
    private static string Local(string e164) => "0" + e164[3..];

    private static bool TryParse(string[] args, out string doctorEmail, out string patientPhone, out string error)
    {
        doctorEmail = DefaultDoctorEmail;
        patientPhone = "";
        error = "";
        string? rawPhone = null;
        for (var i = 1; i < args.Length; i++)
        {
            var value = i + 1 < args.Length ? args[i + 1] : null;
            switch (args[i])
            {
                case "--patient-phone" when value is not null:
                    rawPhone = value;
                    i++;
                    break;
                case "--doctor-email" when value is not null:
                    doctorEmail = value;
                    i++;
                    break;
                default:
                    error = $"Unknown or incomplete argument: {args[i]}";
                    return false;
            }
        }

        if (EgyptianMobile.Normalize(rawPhone) is not { } phone)
        {
            error = "Give the patient's Egyptian mobile number with --patient-phone (a number the team owns).";
            return false;
        }

        if (!RuleBuilderExtensions.IsEmail(doctorEmail))
        {
            error = "The --doctor-email is not an email address.";
            return false;
        }

        patientPhone = phone;
        doctorEmail = Text.NormalizeEmail(doctorEmail);
        return true;
    }
}
