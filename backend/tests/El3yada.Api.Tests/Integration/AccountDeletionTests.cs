using System.Net;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Billing;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Features.AccountDeletion;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// Account deletion for every role (spec 6.17, api-account-deletion.md): the request and its password check, the
/// grace-period session that can only restore, sign out and pay, restore, the daily erasure and what it erases and
/// keeps, a doctor's unpaid invoices, final invoice and carried fees, and the admin's AD12 actions.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class AccountDeletionTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static DateOnly Today => CairoTime.Today(TimeProvider.System);

    private static string ThisMonth => CairoTime.MonthKey(Today);

    private static DateOnly FirstOfThisMonth => new(Today.Year, Today.Month, 1);

    // ---- Patients -------------------------------------------------------------------------------------------

    [Fact]
    public async Task A_patient_deletes_with_the_password_and_lands_on_a_session_that_can_only_restore()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var (patient, patientId) = await TestData.CreatePatientAsync(Factory);
        await TestData.LinkAsync(Factory, doctor.Id, patientId);
        var reception = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.AppointmentsView]);
        var booking = await AddBookingAsync(doctor.Id, patientId, Today.AddDays(3));
        var client = await Factory.SignedInClientAsync(patient);

        var (wrong, wrongBody) = await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = "Wrong-pass1" });
        Assert.Equal(HttpStatusCode.BadRequest, wrong);
        Assert.Equal(ErrorCodes.CurrentPasswordIncorrect, wrongBody.FieldCode("currentPassword"));
        Assert.Equal(AccountStatuses.Active, await UserStatusAsync(patient.Id));

        var (status, started) = await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = patient.Password, reason = "مش محتاج التطبيق" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("scheduled", started.Str("status"));
        Assert.Equal(1, started.GetProperty("cancelledBookings").GetInt32());
        var scheduledFor = started.GetProperty("scheduledFor").GetDateTime();
        Assert.InRange(scheduledFor, DateTime.UtcNow.AddDays(29.9), DateTime.UtcNow.AddDays(30.1));

        // Every device is out at once.
        var (afterStatus, _) = await client.GetJsonAsync("/api/patient/home");
        Assert.Equal(HttpStatusCode.Unauthorized, afterStatus);

        // BR-AP18: the future booking is cancelled, and the clinic gets the usual cancellation activity.
        var cancelled = await TestData.WithDbAsync(Factory, db => db.Appointments.SingleAsync(a => a.Id == booking));
        Assert.Equal("cancelled", cancelled.Status);
        Assert.Equal(AccountDeletionService.CancelReason, cancelled.CancelReason);
        Assert.Equal("patient", cancelled.CancelledByRole);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(
            n => n.RecipientUserId == reception.Id && n.Type == "staffBookingActivity" && n.DataJson!.Contains(booking.ToString()))));

        // Signing in with the right password opens the restore session (A16).
        var session = await Factory.LoginAsync(patient.Identifier, patient.Password);
        Assert.Equal(AccountStatuses.PendingDeletion, session.Str("accountStatus"));
        var pending = session.GetProperty("pendingDeletion");
        Assert.Equal("scheduled", pending.Str("status"));
        Assert.Equal("مش محتاج التطبيق", pending.Str("reason"));
        Assert.False(pending.GetProperty("requestedByAdmin").GetBoolean());
        var restoreOnly = Factory.Client(session.Str("accessToken"));

        // Only the restore screen's endpoints answer.
        var (home, homeBody) = await restoreOnly.GetJsonAsync("/api/patient/home");
        Assert.Equal(HttpStatusCode.Forbidden, home);
        Assert.Equal(ErrorCodes.AccountPendingDeletion, homeBody.Code());
        var (prefs, prefsBody) = await restoreOnly.GetJsonAsync("/api/me/preferences");
        Assert.Equal(HttpStatusCode.Forbidden, prefs);
        Assert.Equal(ErrorCodes.AccountPendingDeletion, prefsBody.Code());
        var (me, meBody) = await restoreOnly.GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.OK, me);
        Assert.Equal(AccountStatuses.PendingDeletion, meBody.Str("accountStatus"));
        var (state, stateBody) = await restoreOnly.GetJsonAsync("/api/me/accountDeletion");
        Assert.Equal(HttpStatusCode.OK, state);
        Assert.Equal(ErrorCodes.AccountDeletionScheduled, stateBody.Str("refusal"));
        var (again, againBody) = await restoreOnly.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = patient.Password });
        Assert.Equal(HttpStatusCode.Forbidden, again);
        Assert.Equal(ErrorCodes.AccountPendingDeletion, againBody.Code());

        // The clinic still has the patient: D6 shows the banner, the record is open, and the chat is closed.
        var staff = await Factory.SignedInClientAsync(doctor);
        var (_, profile) = await staff.GetJsonAsync($"/api/patients/{patientId}");
        Assert.Equal(AccountStatuses.PendingDeletion, profile.Str("accountStatus"));
        await TestData.RecordSessionAsync(staff, patientId, await TestData.DefaultBranchAsync(Factory, doctor.Id));
        var (_, chat) = await staff.PostAsync($"/api/staff/chats/by-patient/{patientId}");
        Assert.False(chat.GetProperty("canSend").GetBoolean());
        Assert.Equal(ErrorCodes.ChatClosed, chat.Str("unavailableReason"));
        var (send, sendBody) = await staff.PostAsync($"/api/staff/chats/{chat.Str("id")}/messages", new { text = "إزيك؟" });
        Assert.Equal(HttpStatusCode.Forbidden, send);
        Assert.Equal(ErrorCodes.ChatClosed, sendBody.Code());
        var (reset, resetBody) = await staff.PostAsync("/api/patients/resetPatientPassword", new { patientId });
        Assert.Equal(HttpStatusCode.Conflict, reset);
        Assert.Equal(ErrorCodes.AccountDeletionScheduled, resetBody.Code());

        // Restore brings everything back except the cancelled booking.
        var (restored, restoredBody) = await restoreOnly.PostAsync("/api/me/restoreAccount");
        Assert.Equal(HttpStatusCode.OK, restored);
        Assert.Equal(AccountStatuses.Active, restoredBody.Str("accountStatus"));
        Assert.Equal(JsonValueKind.Null, restoredBody.GetProperty("pendingDeletion").ValueKind);
        var (homeAgain, _) = await restoreOnly.GetJsonAsync("/api/patient/home");
        Assert.Equal(HttpStatusCode.OK, homeAgain);
        Assert.Equal("cancelled", await TestData.WithDbAsync(Factory, db => db.Appointments.Where(a => a.Id == booking).Select(a => a.Status).SingleAsync()));
        var (_, reopened) = await staff.GetJsonAsync($"/api/staff/chats/{chat.Str("id")}");
        Assert.True(reopened.GetProperty("chat").GetProperty("canSend").GetBoolean());

        var request = await LatestRequestAsync(patient.Id);
        Assert.Equal(DeletionStatuses.Restored, request.Status);
        Assert.Equal(patient.Id, request.RestoredBy);
        Assert.True(await AuditedAsync(patient.Id, "accountDeletionRequested"));
        Assert.True(await AuditedAsync(patient.Id, "accountRestored"));

        var (restoreTwice, restoreTwiceBody) = await restoreOnly.PostAsync("/api/me/restoreAccount");
        Assert.Equal(HttpStatusCode.Conflict, restoreTwice);
        Assert.Equal(ErrorCodes.AccountNotPendingDeletion, restoreTwiceBody.Code());
    }

    [Fact]
    public async Task Erasing_a_patient_keeps_the_records_and_frees_the_number_for_a_new_account()
    {
        var (doctor, staff, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var phone = TestData.Mobile();
        var patientId = await TestData.AddPatientViaApiAsync(staff, phone, "سمر عادل");
        await TestData.RecordSessionAsync(staff, patientId, branchId);
        var userId = await TestData.WithDbAsync(Factory, db => db.Patients.Where(p => p.Id == patientId).Select(p => p.UserId).SingleAsync());
        await TestData.WithDbAsync(Factory, async db =>
        {
            var p = await db.Patients.SingleAsync(x => x.Id == patientId);
            p.NationalId = "29001011234567";
            p.Address = "شارع التحرير";
            p.EmergencyContactName = "عادل محمود";
            p.EmergencyContactPhone = TestData.Mobile();
            p.BloodType = "A+";
            db.Notifications.Add(new Notification
            {
                Id = Guid.NewGuid(), RecipientUserId = userId, Type = "sessionRecorded", TitleAr = "x", TitleEn = "x", BodyAr = "x", BodyEn = "x",
                CreatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync();
        });
        var admin = await Factory.SignedInClientAsync(await TestData.CreateAdminAsync(Factory, AdminRoles.Admin));
        var (scheduled, item) = await admin.PostAsync("/api/admin/accountDeletions/schedule", new { userId, reason = "طلب بالتليفون" });
        Assert.Equal(HttpStatusCode.OK, scheduled);
        Assert.True(item.GetProperty("requestedByAdmin").GetBoolean());

        await DueNowAsync(userId);
        Assert.Equal(1, await RunErasureAsync());

        var erased = await TestData.WithDbAsync(Factory, async db => new
        {
            User = await db.Users.AsNoTracking().SingleAsync(u => u.Id == userId),
            Patient = await db.Patients.AsNoTracking().SingleAsync(p => p.Id == patientId),
            Link = await db.DoctorPatients.AsNoTracking().SingleAsync(l => l.PatientId == patientId),
            Sessions = await db.Sessions.CountAsync(s => s.PatientId == patientId),
            Notifications = await db.Notifications.CountAsync(n => n.RecipientUserId == userId),
            Tokens = await db.RefreshTokens.CountAsync(t => t.UserId == userId),
        });
        Assert.Equal(AccountStatuses.Deleted, erased.User.Status);
        Assert.Equal(Tombstones.PatientName, erased.User.DisplayName);
        Assert.Null(erased.User.Phone);
        Assert.Null(erased.User.PasswordHash);
        Assert.EndsWith("@deleted.invalid", erased.User.Email);
        Assert.Equal(Tombstones.PatientName, erased.Patient.FullName);
        Assert.True(Tombstones.IsPhone(erased.Patient.Phone));
        Assert.Null(erased.Patient.NationalId);
        Assert.Null(erased.Patient.Address);
        Assert.Null(erased.Patient.EmergencyContactName);
        Assert.Null(erased.Patient.EmergencyContactPhone);
        Assert.Equal("deleted", erased.Patient.Status);
        // Kept for the clinical record: gender, date of birth, blood type, and the sessions.
        Assert.Equal("female", erased.Patient.Gender);
        Assert.Equal(new DateOnly(1990, 5, 1), erased.Patient.DateOfBirth);
        Assert.Equal("A+", erased.Patient.BloodType);
        Assert.Equal(1, erased.Sessions);
        Assert.Equal(Tombstones.PatientName, erased.Link.PatientName);
        Assert.Equal(erased.Patient.Phone, erased.Link.PatientPhone);
        Assert.Equal(0, erased.Notifications);
        Assert.Equal(0, erased.Tokens);
        Assert.Equal(DeletionStatuses.Completed, (await LatestRequestAsync(userId)).Status);
        Assert.True(await AuditedAsync(userId, "accountErased"));

        // The number signs in to nothing, and can be a new patient with no trace of the old identity.
        var (login, _) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = phone, password = TestData.Password });
        Assert.Equal(HttpStatusCode.Unauthorized, login);
        var (lookup, lookupBody) = await staff.GetJsonAsync($"/api/patients/lookupPhone?phone={TestData.Local(phone)}");
        Assert.Equal(HttpStatusCode.OK, lookup);
        Assert.Equal("new", lookupBody.Str("status"));
        var (created, createdBody) = await staff.PostAsync("/api/patients/createPatient", TestData.PatientBody(phone, "هالة سمير"));
        Assert.Equal(HttpStatusCode.Created, created);
        Assert.False(createdBody.GetProperty("linked").GetBoolean());
        var newPatient = createdBody.GetProperty("patient");
        Assert.NotEqual(patientId.ToString(), newPatient.Str("patientId"));
        Assert.Equal("هالة سمير", newPatient.Str("fullName"));
        Assert.Equal(0, newPatient.GetProperty("visits").GetProperty("total").GetInt32());

        // The old file stays under «مريض محذوف», without a number; the register finds only the new patient by the number.
        var (_, old) = await staff.GetJsonAsync($"/api/patients/{patientId}");
        Assert.Equal(Tombstones.PatientName, old.Str("fullName"));
        Assert.Equal("", old.Str("phone"));
        Assert.Equal("deleted", old.Str("accountStatus"));
        Assert.Null(old.GetProperty("nationalId").GetString());
        var (_, register) = await staff.GetJsonAsync($"/api/patients/register?search={TestData.Local(phone)}");
        var found = Assert.Single(register.GetProperty("items").EnumerateArray());
        Assert.Equal("هالة سمير", found.Str("fullName"));
        var (edit, editBody) = await staff.PostAsync("/api/patients/updatePatient", new { patientId, fullName = "اسم جديد", gender = "female", ageYears = 30 });
        Assert.Equal(HttpStatusCode.Conflict, edit);
        Assert.Equal(ErrorCodes.AccountDeleted, editBody.Code());

        // Running the job again changes nothing.
        Assert.Equal(0, await RunErasureAsync());
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.AuditLogs.CountAsync(a => a.Action == "accountErased" && a.TargetId == userId.ToString())));
        _ = doctor;
    }

    // ---- Doctors: invoices ------------------------------------------------------------------------------------

    [Fact]
    public async Task A_doctor_who_owes_an_invoice_is_refused_then_gets_a_final_invoice_and_waits_for_its_payment()
    {
        var (doctor, patientId) = await TestData.CreateDoctorWithPatientAsync(Factory);
        var patientUserId = await TestData.WithDbAsync(Factory, db => db.Patients.Where(p => p.Id == patientId).Select(p => p.UserId).SingleAsync());
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        var lastMonth = FirstOfThisMonth.AddMonths(-1);
        await TestData.AddSessionAsync(Factory, doctor.Id, patientId, lastMonth.AddDays(4), feePiasters: 3000);
        await using (var scope = Factory.CreateScope())
        {
            await TestData.BillingAt(scope, DateTimeOffset.UtcNow).MonthlyCloseAsync(CairoTime.MonthKey(lastMonth), CancellationToken.None);
        }

        var owed = await TestData.InvoiceIdAsync(Factory, doctor.Id, CairoTime.MonthKey(lastMonth));
        var client = await Factory.SignedInClientAsync(doctor);
        var assistantClient = await Factory.SignedInClientAsync(assistant);

        var (_, refusedState) = await client.GetJsonAsync("/api/me/accountDeletion");
        Assert.Equal(ErrorCodes.UnpaidInvoices, refusedState.Str("refusal"));
        var (refused, refusedBody) = await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = doctor.Password });
        Assert.Equal(HttpStatusCode.Conflict, refused);
        Assert.Equal(ErrorCodes.UnpaidInvoices, refusedBody.Code());
        var listed = Assert.Single(refusedBody.GetProperty("details").GetProperty("invoices").EnumerateArray());
        Assert.Equal(owed.ToString(), listed.Str("id"));
        Assert.Equal(AccountStatuses.Active, await UserStatusAsync(doctor.Id));

        // Paid: the dialog shows the final invoice first (this month's sessions, closed today).
        await MarkPaidAsync(owed);
        await TestData.AddSessionAsync(Factory, doctor.Id, patientId, Today, feePiasters: 3000);
        await TestData.AddSessionAsync(Factory, doctor.Id, patientId, Today, type: "consultation", feePiasters: 1500);
        var booking = await AddBookingAsync(doctor.Id, patientId, Today.AddDays(2));
        var (_, preview) = await client.GetJsonAsync("/api/me/accountDeletion");
        Assert.Equal(JsonValueKind.Null, preview.GetProperty("refusal").ValueKind);
        Assert.Equal(4500, preview.GetProperty("finalInvoice").GetProperty("amountPiasters").GetInt32());

        var (status, started) = await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = doctor.Password, reason = "قفلت العيادة" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(4500, started.GetProperty("finalInvoice").GetProperty("amountPiasters").GetInt32());
        var final = await TestData.WithDbAsync(Factory, db => db.Invoices.AsNoTracking().SingleAsync(i => i.DoctorId == doctor.Id && i.MonthKey == ThisMonth));
        Assert.True(final.IsFinal);
        Assert.Equal(Today, final.PeriodEnd);
        Assert.Equal(FirstOfThisMonth, final.PeriodStart);
        Assert.Equal(InvoiceStatuses.Unpaid, final.Status);
        Assert.Equal(4500, final.TotalDuePiasters);
        Assert.Equal(final.Id, (await LatestRequestAsync(doctor.Id)).FinalInvoiceId);

        // The clinic stops: assistants are out (A10), bookings cancelled with the patient told, admins told.
        var (assistantNow, assistantBody) = await assistantClient.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.Forbidden, assistantNow);
        Assert.Equal(ErrorCodes.ClinicNotActive, assistantBody.Code());
        var (assistantLogin, assistantLoginBody) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = assistant.Identifier, password = assistant.Password });
        Assert.Equal(HttpStatusCode.Forbidden, assistantLogin);
        Assert.Equal(ErrorCodes.ClinicNotActive, assistantLoginBody.Code());
        Assert.Equal("cancelled", await TestData.WithDbAsync(Factory, db => db.Appointments.Where(a => a.Id == booking).Select(a => a.Status).SingleAsync()));
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(
            n => n.RecipientUserId == patientUserId && n.Type == "bookingCancelled" && n.BodyAr.Contains("العيادة أوقفت الخدمة"))));
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(
            n => n.Type == "deletionRequest" && n.DataJson!.Contains(doctor.Id.ToString()))));

        // The patient keeps their records; the doctor takes no new bookings.
        var patientClient = Factory.Client((await Factory.LoginAsync(
            await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == patientUserId).Select(u => u.Phone!).SingleAsync()), TestData.Password)).Str("accessToken"));
        var (_, myDoctors) = await patientClient.GetJsonAsync("/api/patient/doctors");
        var mine = myDoctors.EnumerateArray().Single(d => d.GetProperty("doctor").Str("id") == doctor.Id.ToString());
        Assert.Equal(DoctorStatuses.Disabled, mine.Str("doctorStatus"));

        // The doctor's restore session also pays: billing answers, the rest doesn't.
        var session = await Factory.LoginAsync(doctor.Identifier, doctor.Password);
        Assert.Equal(1, session.GetProperty("pendingDeletion").GetProperty("unpaidInvoices").GetInt32());
        Assert.True(session.GetProperty("pendingDeletion").GetProperty("waitsForPayment").GetBoolean());
        var restoreOnly = Factory.Client(session.Str("accessToken"));
        var (invoices, _) = await restoreOnly.GetJsonAsync("/api/billing/invoices");
        Assert.Equal(HttpStatusCode.OK, invoices);
        var (clinic, _) = await restoreOnly.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.OK, clinic);
        var (register, registerBody) = await restoreOnly.GetJsonAsync("/api/patients/register");
        Assert.Equal(HttpStatusCode.Forbidden, register);
        Assert.Equal(ErrorCodes.AccountPendingDeletion, registerBody.Code());

        // Past the grace period with the invoice unpaid: waiting for payment, not erased.
        await DueNowAsync(doctor.Id);
        Assert.Equal(0, await RunErasureAsync());
        Assert.Equal(DeletionStatuses.WaitingPayment, (await LatestRequestAsync(doctor.Id)).Status);
        Assert.Equal(AccountStatuses.PendingDeletion, await UserStatusAsync(doctor.Id));
        var admin = await Factory.SignedInClientAsync(await TestData.CreateAdminAsync(Factory, AdminRoles.Admin));
        var (_, waiting) = await admin.GetJsonAsync($"/api/admin/accountDeletions?status=waitingPayment&role=doctor&userId={doctor.Id}");
        var row = Assert.Single(waiting.GetProperty("items").EnumerateArray());
        Assert.Equal(4500, row.GetProperty("outstandingPiasters").GetInt32());

        // Paid: erased with the clinic's assistants; the patient's records stay, under «طبيب محذوف».
        await MarkPaidAsync(final.Id);
        Assert.Equal(1, await RunErasureAsync());
        var gone = await TestData.WithDbAsync(Factory, async db => new
        {
            User = await db.Users.AsNoTracking().SingleAsync(u => u.Id == doctor.Id),
            Doctor = await db.Doctors.AsNoTracking().SingleAsync(d => d.UserId == doctor.Id),
            Phones = await db.BranchPhones.CountAsync(p => p.Branch.DoctorId == doctor.Id),
            Assistant = await db.Assistants.AsNoTracking().Include(a => a.User).SingleAsync(a => a.UserId == assistant.Id),
            Invoices = await db.Invoices.CountAsync(i => i.DoctorId == doctor.Id),
        });
        Assert.Equal(AccountStatuses.Deleted, gone.User.Status);
        Assert.Null(gone.User.Phone);
        Assert.Equal(Tombstones.DoctorName, gone.Doctor.FullName);
        Assert.Equal(Tombstones.DoctorNameEn, gone.Doctor.FullNameEn);
        Assert.Equal(Tombstones.LicenseNumber, gone.Doctor.LicenseNumber);
        Assert.Equal(DoctorStatuses.Disabled, gone.Doctor.Status);
        Assert.Equal(0, gone.Phones);
        Assert.Equal(2, gone.Invoices);
        Assert.Equal(Tombstones.AssistantName, gone.Assistant.FullName);
        Assert.Equal("removed", gone.Assistant.Status);
        Assert.True(Tombstones.IsPhone(gone.Assistant.Phone));
        Assert.Equal(AccountStatuses.Deleted, gone.Assistant.User.Status);
        var (_, doctorsAfter) = await patientClient.GetJsonAsync("/api/patient/doctors");
        var deletedDoctor = doctorsAfter.EnumerateArray().Single(d => d.GetProperty("doctor").Str("id") == doctor.Id.ToString());
        Assert.Equal(Tombstones.DoctorName, deletedDoctor.GetProperty("doctor").Str("fullName"));
        var (visits, visitsBody) = await patientClient.GetJsonAsync($"/api/patient/visits?doctorId={doctor.Id}");
        Assert.Equal(HttpStatusCode.OK, visits);
        Assert.Equal(3, visitsBody.GetProperty("totalCount").GetInt32());
        Assert.Equal(0, await RunErasureAsync());
    }

    [Fact]
    public async Task Restoring_removes_an_unpaid_final_invoice_so_the_month_closes_as_usual()
    {
        var (doctor, patientId) = await TestData.CreateDoctorWithPatientAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        await TestData.AddSessionAsync(Factory, doctor.Id, patientId, Today, feePiasters: 3000);
        var client = await Factory.SignedInClientAsync(doctor);
        var (status, _) = await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = doctor.Password });
        Assert.Equal(HttpStatusCode.OK, status);
        var finalId = (await LatestRequestAsync(doctor.Id)).FinalInvoiceId!.Value;

        var restoreOnly = Factory.Client((await Factory.LoginAsync(doctor.Identifier, doctor.Password)).Str("accessToken"));
        var (restored, body) = await restoreOnly.PostAsync("/api/me/restoreAccount");
        Assert.Equal(HttpStatusCode.OK, restored);
        Assert.Equal(AccountStatuses.Active, body.Str("accountStatus"));

        Assert.False(await TestData.WithDbAsync(Factory, db => db.Invoices.AnyAsync(i => i.Id == finalId)));
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "finalInvoiceRemoved" && a.TargetId == finalId.ToString())));
        Assert.Null((await LatestRequestAsync(doctor.Id)).FinalInvoiceId);

        // The clinic is open again: the assistant signs in, and the doctor works.
        await Factory.LoginAsync(assistant.Identifier, assistant.Password);
        var (register, _) = await restoreOnly.GetJsonAsync("/api/patients/register");
        Assert.Equal(HttpStatusCode.OK, register);

        // Month close bills the whole month, the sessions after the restore too.
        await TestData.AddSessionAsync(Factory, doctor.Id, patientId, Today, type: "consultation", feePiasters: 1500);
        await using var scope = Factory.CreateScope();
        await TestData.BillingAt(scope, DateTimeOffset.UtcNow).MonthlyCloseAsync(ThisMonth, CancellationToken.None);
        var invoice = await TestData.WithDbAsync(Factory, db => db.Invoices.AsNoTracking().SingleAsync(i => i.DoctorId == doctor.Id && i.MonthKey == ThisMonth));
        Assert.False(invoice.IsFinal);
        Assert.Equal(4500, invoice.TotalDuePiasters);
    }

    [Fact]
    public async Task Restoring_after_paying_the_final_invoice_carries_later_fees_into_the_next_invoice_once()
    {
        var (doctor, patientId) = await TestData.CreateDoctorWithPatientAsync(Factory);
        await TestData.AddSessionAsync(Factory, doctor.Id, patientId, Today, feePiasters: 3000);
        var client = await Factory.SignedInClientAsync(doctor);
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = doctor.Password })).Status);
        var finalId = (await LatestRequestAsync(doctor.Id)).FinalInvoiceId!.Value;
        await MarkPaidAsync(finalId);

        var restoreOnly = Factory.Client((await Factory.LoginAsync(doctor.Identifier, doctor.Password)).Str("accessToken"));
        Assert.Equal(HttpStatusCode.OK, (await restoreOnly.PostAsync("/api/me/restoreAccount")).Status);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Invoices.AnyAsync(i => i.Id == finalId && i.Status == InvoiceStatuses.Paid)));

        // A session after the restore, in the month the final invoice closed.
        await TestData.AddSessionAsync(Factory, doctor.Id, patientId, Today, type: "consultation", feePiasters: 1500);
        var nextMonth = FirstOfThisMonth.AddMonths(1);
        var monthAfter = FirstOfThisMonth.AddMonths(2);
        await using (var scope = Factory.CreateScope())
        {
            var billing = TestData.BillingAt(scope, new DateTimeOffset(CairoTime.StartUtc(nextMonth).AddMinutes(5), TimeSpan.Zero));
            await billing.MonthlyCloseAsync(ThisMonth, CancellationToken.None);
        }

        // This month already has its invoice (UQ_Invoices_Doctor_Month): the fee waits for the next one.
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Invoices.CountAsync(i => i.DoctorId == doctor.Id)));

        for (var run = 0; run < 2; run++)
        {
            await using var scope = Factory.CreateScope();
            var billing = TestData.BillingAt(scope, new DateTimeOffset(CairoTime.StartUtc(monthAfter).AddMinutes(5), TimeSpan.Zero));
            await billing.MonthlyCloseAsync(CairoTime.MonthKey(nextMonth), CancellationToken.None);
        }

        var next = await TestData.WithDbAsync(Factory, db => db.Invoices.AsNoTracking().Include(i => i.InvoiceAdjustments)
            .SingleAsync(i => i.DoctorId == doctor.Id && i.MonthKey == CairoTime.MonthKey(nextMonth)));
        var carried = Assert.Single(next.InvoiceAdjustments);
        Assert.Equal(1500, carried.AmountPiasters);
        Assert.Equal(ThisMonth, carried.CarriedMonthKey);
        Assert.Null(carried.CreatedBy);
        Assert.Equal(1500, next.AdjustmentsPiasters);
        Assert.Equal(1500, next.TotalDuePiasters);
        Assert.Equal(0, next.ExamCount + next.ConsultationCount);
        Assert.Equal(InvoiceStatuses.Unpaid, next.Status);

        // The doctor's invoice detail marks the line as carried, and the month after carries nothing again.
        var (_, detail) = await restoreOnly.GetJsonAsync($"/api/billing/invoices/{next.Id}");
        Assert.Equal(ThisMonth, detail.GetProperty("adjustments")[0].Str("carriedMonthKey"));
        await using (var scope = Factory.CreateScope())
        {
            var billing = TestData.BillingAt(scope, new DateTimeOffset(CairoTime.StartUtc(monthAfter.AddMonths(1)).AddMinutes(5), TimeSpan.Zero));
            await billing.MonthlyCloseAsync(CairoTime.MonthKey(monthAfter), CancellationToken.None);
        }

        Assert.Equal(2, await TestData.WithDbAsync(Factory, db => db.Invoices.CountAsync(i => i.DoctorId == doctor.Id)));
    }

    [Fact]
    public async Task A_doctor_with_no_fees_this_month_gets_no_final_invoice()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var client = await Factory.SignedInClientAsync(doctor);
        var (_, preview) = await client.GetJsonAsync("/api/me/accountDeletion");
        Assert.Equal(JsonValueKind.Null, preview.GetProperty("finalInvoice").ValueKind);
        var (status, started) = await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = doctor.Password });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(JsonValueKind.Null, started.GetProperty("finalInvoice").ValueKind);
        Assert.Null((await LatestRequestAsync(doctor.Id)).FinalInvoiceId);

        await DueNowAsync(doctor.Id);
        Assert.Equal(1, await RunErasureAsync());
    }

    // ---- Assistants and the same number twice ---------------------------------------------------------------

    [Fact]
    public async Task A_patient_and_an_assistant_on_one_number_are_deleted_independently()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var phone = TestData.Mobile();
        var (patient, patientId) = await TestData.CreatePatientAsync(Factory, phone);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, phone: phone, name: "منى حسن");

        var assistantSession = await SelectAsync(phone, Roles.Assistant);
        var asAssistant = Factory.Client(assistantSession.Str("accessToken"));
        var (status, _) = await asAssistant.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = TestData.Password });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(
            n => n.RecipientUserId == doctor.Id && n.Type == "assistantDeletionRequest" && n.BodyAr.Contains("طلب حذف حسابه"))));
        var staff = await Factory.SignedInClientAsync(doctor);
        var (_, assistants) = await staff.GetJsonAsync("/api/assistants");
        var listed = assistants.GetProperty("items").EnumerateArray().Single(a => a.Str("userId") == assistant.Id.ToString());
        Assert.Equal(AccountStatuses.PendingDeletion, listed.Str("accountStatus"));

        // "Log in as" shows which account is being deleted; the patient account is untouched.
        var (_, choice) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = phone, password = TestData.Password });
        Assert.Equal("chooseAccount", choice.Str("result"));
        var accounts = choice.GetProperty("accounts").EnumerateArray().ToList();
        Assert.True(accounts.Single(a => a.Str("role") == Roles.Assistant).GetProperty("pendingDeletion").GetBoolean());
        Assert.False(accounts.Single(a => a.Str("role") == Roles.Patient).GetProperty("pendingDeletion").GetBoolean());
        var patientSession = await SelectAsync(phone, Roles.Patient);
        Assert.Equal(AccountStatuses.Active, patientSession.Str("accountStatus"));

        await DueNowAsync(assistant.Id);
        Assert.Equal(1, await RunErasureAsync());
        var after = await TestData.WithDbAsync(Factory, async db => new
        {
            Assistant = await db.Assistants.AsNoTracking().SingleAsync(a => a.UserId == assistant.Id),
            AssistantUser = await db.Users.AsNoTracking().SingleAsync(u => u.Id == assistant.Id),
            Patient = await db.Patients.AsNoTracking().SingleAsync(p => p.Id == patientId),
            PatientUser = await db.Users.AsNoTracking().SingleAsync(u => u.Id == patient.Id),
        });
        Assert.Equal(Tombstones.AssistantName, after.Assistant.FullName);
        Assert.Equal("removed", after.Assistant.Status);
        Assert.Equal(AccountStatuses.Deleted, after.AssistantUser.Status);
        Assert.Equal(phone, after.Patient.Phone);
        Assert.Equal("منى حسن", after.Patient.FullName);
        Assert.Equal(AccountStatuses.Active, after.PatientUser.Status);
        Assert.Equal(phone, after.PatientUser.Phone);

        // One account on the number now: it signs in directly.
        var direct = await Factory.LoginAsync(phone, TestData.Password);
        Assert.Equal(Roles.Patient, direct.Str("role"));

        // And deleting the patient later leaves the erased assistant as it is.
        var asPatient = Factory.Client(direct.Str("accessToken"));
        Assert.Equal(HttpStatusCode.OK, (await asPatient.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = TestData.Password })).Status);
        Assert.Equal(AccountStatuses.PendingDeletion, await UserStatusAsync(patient.Id));
        Assert.Equal(AccountStatuses.Deleted, await UserStatusAsync(assistant.Id));
    }

    [Fact]
    public async Task An_assistant_restores_and_acts_for_the_clinic_again()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.Chat]);
        var client = await Factory.SignedInClientAsync(assistant);
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = assistant.Password })).Status);
        Assert.True(await AuditedAsync(assistant.Id, "accountDeletionRequested"));
        Assert.Equal(doctor.Id, await TestData.WithDbAsync(Factory, db => db.AuditLogs
            .Where(a => a.Action == "accountDeletionRequested" && a.TargetId == assistant.Id.ToString()).Select(a => a.DoctorId).SingleAsync()));

        var restoreOnly = Factory.Client((await Factory.LoginAsync(assistant.Identifier, assistant.Password)).Str("accessToken"));
        var (clinic, clinicBody) = await restoreOnly.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.OK, clinic);
        var (chats, chatsBody) = await restoreOnly.GetJsonAsync("/api/staff/chats");
        Assert.Equal(HttpStatusCode.Forbidden, chats);
        Assert.Equal(ErrorCodes.AccountPendingDeletion, chatsBody.Code());
        _ = clinicBody;

        Assert.Equal(HttpStatusCode.OK, (await restoreOnly.PostAsync("/api/me/restoreAccount")).Status);
        var (chatsAgain, _) = await restoreOnly.GetJsonAsync("/api/staff/chats");
        Assert.Equal(HttpStatusCode.OK, chatsAgain);
        Assert.Equal(AccountStatuses.Active, await UserStatusAsync(assistant.Id));
        Assert.Equal("active", await TestData.WithDbAsync(Factory, db => db.Assistants.Where(a => a.UserId == assistant.Id).Select(a => a.Status).SingleAsync()));
    }

    // ---- Admins -----------------------------------------------------------------------------------------------

    [Fact]
    public async Task An_admin_deletes_their_own_account_and_the_daily_job_frees_the_email()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        var client = await Factory.SignedInClientAsync(admin);
        var (status, _) = await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = admin.Password, reason = "خلصت شغلي" });
        Assert.Equal(HttpStatusCode.OK, status);
        var session = await Factory.LoginAsync(admin.Identifier, admin.Password);
        Assert.Equal(AccountStatuses.PendingDeletion, session.Str("accountStatus"));
        var (dashboard, _) = await Factory.Client(session.Str("accessToken")).GetJsonAsync("/api/admin/accountDeletions");
        Assert.Equal(HttpStatusCode.Forbidden, dashboard);

        // The job runs from the daily host (BillingJobs).
        await DueNowAsync(admin.Id);
        await using (var scope = Factory.CreateScope())
        {
            Assert.Equal(1, await scope.ServiceProvider.GetRequiredService<BillingJobs>().AccountErasureAsync(CancellationToken.None));
        }

        var user = await TestData.WithDbAsync(Factory, db => db.Users.AsNoTracking().SingleAsync(u => u.Id == admin.Id));
        Assert.Equal(Tombstones.AdminName, user.DisplayName);
        Assert.Equal(AccountStatuses.Deleted, user.Status);
        Assert.NotEqual(admin.Identifier, user.Email);
        var (login, _) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = admin.Identifier, password = admin.Password });
        Assert.Equal(HttpStatusCode.Unauthorized, login);

        // The email is free for a new account (UQ_Users_Email).
        await TestData.WithDbAsync(Factory, async db =>
        {
            db.Users.Add(new User
            {
                Id = Guid.NewGuid(), Role = Roles.Admin, AdminRole = AdminRoles.Admin, DisplayName = "New Admin", Email = admin.Identifier,
                SecurityStamp = Guid.NewGuid(), CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync();
        });
    }

    [Fact]
    public async Task The_last_active_super_admin_can_never_be_deleted()
    {
        var a = await TestData.CreateAdminAsync(Factory);
        await DisableOtherSuperAdminsAsync(a.Id);
        var asA = await Factory.SignedInClientAsync(a);

        var (_, state) = await asA.GetJsonAsync("/api/me/accountDeletion");
        Assert.Equal(ErrorCodes.LastSuperAdmin, state.Str("refusal"));
        var (refused, refusedBody) = await asA.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = a.Password });
        Assert.Equal(HttpStatusCode.Conflict, refused);
        Assert.Equal(ErrorCodes.LastSuperAdmin, refusedBody.Code());

        // A plain admin can't delete another admin; a second super admin can, and then is the last one.
        var plain = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        var asPlain = await Factory.SignedInClientAsync(plain);
        var (forbidden, forbiddenBody) = await asPlain.PostAsync("/api/admin/accountDeletions/schedule", new { userId = a.Id, reason = "طلب" });
        Assert.Equal(HttpStatusCode.Forbidden, forbidden);
        Assert.Equal(ErrorCodes.Forbidden, forbiddenBody.Code());

        var b = await TestData.CreateAdminAsync(Factory);
        var asB = await Factory.SignedInClientAsync(b);
        var (scheduled, item) = await asB.PostAsync("/api/admin/accountDeletions/schedule", new { userId = a.Id, reason = "ترك العمل" });
        Assert.Equal(HttpStatusCode.OK, scheduled);
        Assert.Equal(Roles.Admin, item.Str("role"));
        Assert.Equal(AccountStatuses.PendingDeletion, await UserStatusAsync(a.Id));
        var (selfRefused, selfBody) = await asB.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = b.Password });
        Assert.Equal(HttpStatusCode.Conflict, selfRefused);
        Assert.Equal(ErrorCodes.LastSuperAdmin, selfBody.Code());

        // The deleted admin can't be switched back on from AD14; the super admin cancels it in AD12.
        var (enable, enableBody) = await asB.PostAsync("/api/admin/setAdminStatus", new { userId = a.Id, status = "active" });
        Assert.Equal(HttpStatusCode.Conflict, enable);
        Assert.Equal(ErrorCodes.AccountDeletionScheduled, enableBody.Code());
        var (cancelled, cancelledBody) = await asB.PostAsync($"/api/admin/accountDeletions/{item.Str("id")}/cancel", new { reason = "رجع" });
        Assert.Equal(HttpStatusCode.OK, cancelled);
        Assert.Equal(DeletionStatuses.Restored, cancelledBody.Str("status"));
        Assert.Equal(AccountStatuses.Active, await UserStatusAsync(a.Id));
    }

    [Fact]
    public async Task Admins_list_cancel_and_start_deletions_with_a_reason()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        var asAdmin = await Factory.SignedInClientAsync(admin);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);

        var (noReason, noReasonBody) = await asAdmin.PostAsync("/api/admin/accountDeletions/schedule", new { userId = patient.Id });
        Assert.Equal(HttpStatusCode.BadRequest, noReason);
        Assert.Equal(ErrorCodes.Required, noReasonBody.FieldCode("reason"));

        var (status, item) = await asAdmin.PostAsync("/api/admin/accountDeletions/schedule", new { userId = patient.Id, reason = "طلب بالبريد" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("Test Admin", item.Str("requestedByName"));
        Assert.Equal("طلب بالبريد", item.Str("reason"));
        var (twice, twiceBody) = await asAdmin.PostAsync("/api/admin/accountDeletions/schedule", new { userId = patient.Id, reason = "مرة تانية" });
        Assert.Equal(HttpStatusCode.Conflict, twice);
        Assert.Equal(ErrorCodes.AccountDeletionScheduled, twiceBody.Code());
        Assert.True(await AuditedAsync(patient.Id, "accountDeletionScheduledByAdmin"));

        var (_, open) = await asAdmin.GetJsonAsync("/api/admin/accountDeletions?role=patient&status=scheduled&pageSize=100");
        Assert.Contains(open.GetProperty("items").EnumerateArray(), i => i.Str("userId") == patient.Id.ToString());
        var (_, doctors) = await asAdmin.GetJsonAsync($"/api/admin/accountDeletions?role=doctor&userId={patient.Id}");
        Assert.Empty(doctors.GetProperty("items").EnumerateArray());
        var (badFilter, _) = await asAdmin.GetJsonAsync("/api/admin/accountDeletions?status=pending");
        Assert.Equal(HttpStatusCode.BadRequest, badFilter);

        var (noCancelReason, _) = await asAdmin.PostAsync($"/api/admin/accountDeletions/{item.Str("id")}/cancel", new { });
        Assert.Equal(HttpStatusCode.BadRequest, noCancelReason);
        var (cancelled, cancelledBody) = await asAdmin.PostAsync($"/api/admin/accountDeletions/{item.Str("id")}/cancel", new { reason = "المريض غيّر رأيه" });
        Assert.Equal(HttpStatusCode.OK, cancelled);
        Assert.Equal(DeletionStatuses.Restored, cancelledBody.Str("status"));
        Assert.Equal("المريض غيّر رأيه", cancelledBody.Str("restoreReason"));
        Assert.Equal("Test Admin", cancelledBody.Str("restoredByName"));
        Assert.True(await AuditedAsync(patient.Id, "accountDeletionCancelled"));
        await Factory.LoginAsync(patient.Identifier, patient.Password);

        var (again, againBody) = await asAdmin.PostAsync($"/api/admin/accountDeletions/{item.Str("id")}/cancel", new { reason = "تاني" });
        Assert.Equal(HttpStatusCode.Conflict, again);
        Assert.Equal(ErrorCodes.AccountNotPendingDeletion, againBody.Code());

        // Other roles can't use AD12.
        var asPatient = await Factory.SignedInClientAsync(patient);
        var (forbidden, _) = await asPatient.GetJsonAsync("/api/admin/accountDeletions");
        Assert.Equal(HttpStatusCode.Forbidden, forbidden);
    }

    [Fact]
    public async Task The_grace_period_is_an_admin_setting_from_7_to_90_days()
    {
        var superAdmin = await Factory.SignedInClientAsync(await TestData.CreateAdminAsync(Factory));
        var (tooShort, body) = await superAdmin.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?> { ["accountDeletionGraceDays"] = 6 });
        Assert.Equal(HttpStatusCode.BadRequest, tooShort);
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("accountDeletionGraceDays"));

        var (set, _) = await superAdmin.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?> { ["accountDeletionGraceDays"] = 45 });
        Assert.Equal(HttpStatusCode.OK, set);
        try
        {
            var (patient, _) = await TestData.CreatePatientAsync(Factory);
            var client = await Factory.SignedInClientAsync(patient);
            var (_, state) = await client.GetJsonAsync("/api/me/accountDeletion");
            Assert.Equal(45, state.GetProperty("graceDays").GetInt32());
            var (_, started) = await client.PostAsync("/api/me/requestAccountDeletion", new { currentPassword = patient.Password });
            Assert.InRange(started.GetProperty("scheduledFor").GetDateTime(), DateTime.UtcNow.AddDays(44.9), DateTime.UtcNow.AddDays(45.1));
        }
        finally
        {
            await superAdmin.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?> { ["accountDeletionGraceDays"] = 30 });
        }
    }

    // ---- Helpers --------------------------------------------------------------------------------------------

    private async Task<Guid> AddBookingAsync(Guid doctorId, Guid patientId, DateOnly day)
    {
        var id = Guid.NewGuid();
        var branchId = await TestData.DefaultBranchAsync(Factory, doctorId);
        await TestData.WithDbAsync(Factory, async db =>
        {
            var start = CairoTime.StartUtc(day).AddHours(18);
            db.Appointments.Add(new Appointment
            {
                Id = id, DoctorId = doctorId, BranchId = branchId, PatientId = patientId, VisitType = "examination", Mode = "queue",
                LocalDate = day, PeriodStartLocal = new TimeOnly(18, 0), StartUtc = start, EndUtc = start.AddHours(4),
                Status = "confirmed", Source = "patientApp", BookedBy = doctorId, BookedByRole = "doctor",
                CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync();
        });
        return id;
    }

    private async Task<JsonElement> SelectAsync(string phone, string role)
    {
        var (_, choice) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = phone, password = TestData.Password });
        Assert.Equal("chooseAccount", choice.Str("result"));
        var (status, session) = await Factory.Client().PostAsync("/api/auth/selectAccount", new { selectionToken = choice.Str("selectionToken"), role });
        Assert.Equal(HttpStatusCode.OK, status);
        return session;
    }

    private Task<string> UserStatusAsync(Guid userId) =>
        TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == userId).Select(u => u.Status).SingleAsync());

    private Task<DeletionRequest> LatestRequestAsync(Guid userId) =>
        TestData.WithDbAsync(Factory, db => db.DeletionRequests.AsNoTracking().Where(r => r.UserId == userId).OrderByDescending(r => r.RequestedAt).FirstAsync());

    private Task<bool> AuditedAsync(Guid userId, string action) =>
        TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == action && a.TargetId == userId.ToString()));

    /// <summary>Moves the account's open deletion to the past, as if the grace period had ended.</summary>
    private Task DueNowAsync(Guid userId) =>
        TestData.WithDbAsync(Factory, db => db.DeletionRequests
            .Where(r => r.UserId == userId && (r.Status == DeletionStatuses.Scheduled || r.Status == DeletionStatuses.WaitingPayment))
            .ExecuteUpdateAsync(set => set.SetProperty(r => r.ScheduledFor, DateTime.UtcNow.AddMinutes(-1))));

    /// <summary>
    /// The daily job, as BillingJobsHost runs it. Tests share one database, so each test makes one account due at a time
    /// and checks the count right after.
    /// </summary>
    private async Task<int> RunErasureAsync()
    {
        await using var scope = Factory.CreateScope();
        return await scope.ServiceProvider.GetRequiredService<AccountDeletionJob>().RunAsync(CancellationToken.None);
    }

    private Task MarkPaidAsync(Guid invoiceId) =>
        TestData.WithDbAsync(Factory, db => db.Invoices.Where(i => i.Id == invoiceId)
            .ExecuteUpdateAsync(set => set.SetProperty(i => i.Status, InvoiceStatuses.Paid).SetProperty(i => i.PaidAt, DateTime.UtcNow)));

    private Task DisableOtherSuperAdminsAsync(Guid keep) =>
        TestData.WithDbAsync(Factory, db => db.Users
            .Where(u => u.Role == Roles.Admin && u.AdminRole == AdminRoles.SuperAdmin && u.Status == AccountStatuses.Active && u.Id != keep)
            .ExecuteUpdateAsync(set => set.SetProperty(u => u.Status, AccountStatuses.Disabled)));
}
