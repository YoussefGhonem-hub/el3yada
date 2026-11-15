using System.Net;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>createSession and the consultation rule (BR-S1–S10; AC-1, AC-2, AC-3), newSessionInfo, D9 reads and edits.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class SessionsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private async Task<(HttpStatusCode Status, System.Text.Json.JsonElement Body)> Record(
        HttpClient client, Guid patientId, Guid branchId, string type) =>
        await client.PostAsync("/api/sessions/createSession", TestData.SessionBody(patientId, branchId, type));

    [Fact]
    public async Task AC1_after_two_consultations_in_a_row_the_next_session_must_be_an_examination()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, maxConsecutiveConsultations: 2);
        var scene = await PatientScene.CreateAsync(Factory);

        Assert.Equal(HttpStatusCode.Created, (await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation")).Status);
        var (_, info) = await scene.Client.GetJsonAsync($"/api/sessions/newSessionInfo?patientId={scene.PatientId}&branchId={scene.BranchId}");
        Assert.True(info.BoolAt("consultationAllowed"));
        Assert.Equal(1, info.IntAt("consultationsSinceExam"));
        Assert.Equal(HttpStatusCode.Created, (await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation")).Status);

        (_, info) = await scene.Client.GetJsonAsync($"/api/sessions/newSessionInfo?patientId={scene.PatientId}&branchId={scene.BranchId}");
        Assert.False(info.BoolAt("consultationAllowed"));
        Assert.Equal("limitReached", info.Str("consultationBlockedReason"));
        Assert.Equal(2, info.IntAt("consultationsSinceExam"));
        Assert.Equal(2, info.IntAt("maxConsecutiveConsultations"));
        Assert.False(info.BoolAt("consultation.allowed"));
        Assert.True(info.BoolAt("examination.allowed"));

        // A request that bypasses the UI is refused by the server.
        var (status, problem) = await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation");
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.ConsultationRequiresExam, problem.Code());
        Assert.Equal("limitReached", problem.Str("reason"));
        Assert.Equal(2, problem.IntAt("consultationsSinceExam"));
        Assert.Equal(2, problem.IntAt("maxConsecutiveConsultations"));

        // An examination resets the count; then one and two consultations are both accepted again.
        Assert.Equal(HttpStatusCode.Created, (await Record(scene.Client, scene.PatientId, scene.BranchId, "examination")).Status);
        (_, info) = await scene.Client.GetJsonAsync($"/api/sessions/newSessionInfo?patientId={scene.PatientId}&branchId={scene.BranchId}");
        Assert.Equal(0, info.IntAt("consultationsSinceExam"));
        Assert.True(info.BoolAt("consultationAllowed"));
        Assert.Equal(HttpStatusCode.Created, (await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation")).Status);
        Assert.Equal(HttpStatusCode.Created, (await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation")).Status);
    }

    [Fact]
    public async Task AC1_a_new_patients_first_session_cannot_be_a_consultation()
    {
        var (_, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);

        var (_, info) = await client.GetJsonAsync($"/api/sessions/newSessionInfo?patientId={patientId}&branchId={branchId}");
        var (status, problem) = await Record(client, patientId, branchId, "consultation");

        Assert.True(info.BoolAt("isFirstVisit"));
        Assert.True(info.IsNullAt("lastSession"));
        Assert.Equal("firstVisit", info.Str("consultationBlockedReason"));
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.ConsultationRequiresExam, problem.Code());
        Assert.Equal("firstVisit", problem.Str("reason"));
    }

    [Fact]
    public async Task AC1_with_the_limit_changed_to_one_a_second_consultation_in_a_row_is_refused()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, maxConsecutiveConsultations: 1);
        var scene = await PatientScene.CreateAsync(Factory);

        var first = await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation");
        var second = await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation");

        Assert.Equal(HttpStatusCode.Created, first.Status);
        Assert.Equal(HttpStatusCode.Conflict, second.Status);
        Assert.Equal(1, second.Body.IntAt("maxConsecutiveConsultations"));
        Assert.Equal(1, second.Body.IntAt("consultationsSinceExam"));
    }

    [Fact]
    public async Task AC1_the_rule_with_one_doctor_ignores_the_patients_sessions_with_another()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, maxConsecutiveConsultations: 2);
        var (_, clientA, branchA) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var (_, clientB, branchB) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var phone = TestData.Mobile();
        var patientId = await TestData.AddPatientViaApiAsync(clientB, phone);
        await TestData.AddPatientViaApiAsync(clientA, phone);
        await TestData.RecordSessionAsync(clientB, patientId, branchB);
        await TestData.RecordSessionAsync(clientB, patientId, branchB, "consultation");
        await TestData.RecordSessionAsync(clientB, patientId, branchB, "consultation");

        // Dr A has no examination yet, so Dr B's examination doesn't count for Dr A …
        Assert.Equal("firstVisit", (await Record(clientA, patientId, branchA, "consultation")).Body.Str("reason"));
        await TestData.RecordSessionAsync(clientA, patientId, branchA);
        // … and Dr B's two consultations don't count either.
        Assert.Equal(HttpStatusCode.Created, (await Record(clientA, patientId, branchA, "consultation")).Status);
        Assert.Equal(HttpStatusCode.Conflict, (await Record(clientB, patientId, branchB, "consultation")).Status);
    }

    [Fact]
    public async Task AC2_two_consultations_saved_at_the_same_moment_one_succeeds()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, maxConsecutiveConsultations: 2);
        for (var round = 0; round < 3; round++)
        {
            var scene = await PatientScene.CreateAsync(Factory);
            await TestData.RecordSessionAsync(scene.Client, scene.PatientId, scene.BranchId, "consultation");
            var assistant = await TestData.CreateAssistantAsync(Factory, scene.Doctor.Id, permissions: [ClinicPermissions.SessionsCreate]);
            using var assistantClient = await Factory.SignedInClientAsync(assistant);

            var results = await Task.WhenAll(
                Record(scene.Client, scene.PatientId, scene.BranchId, "consultation"),
                Record(assistantClient, scene.PatientId, scene.BranchId, "consultation"));

            Assert.Equal([HttpStatusCode.Created, HttpStatusCode.Conflict], results.Select(r => r.Status).Order());
            var link = await TestData.WithDbAsync(Factory, db => db.DoctorPatients.SingleAsync(l => l.PatientId == scene.PatientId));
            Assert.Equal(2, link.ConsultationsSinceExam);
            Assert.Equal(3, link.SessionCount);
        }
    }

    [Fact]
    public async Task AC3_a_fee_change_applies_only_to_sessions_saved_after_it()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, examFeePiasters: 3000);
        var scene = await PatientScene.CreateAsync(Factory);
        var billing = await TestData.CreateAssistantAsync(Factory, scene.Doctor.Id, permissions: [ClinicPermissions.BillingView]);
        using var billingClient = await Factory.SignedInClientAsync(billing);

        await TestData.SetFeeSettingsAsync(Factory, 4000, 1500, 2);
        var second = await TestData.AddPatientViaApiAsync(scene.Client);
        var later = await TestData.RecordSessionAsync(scene.Client, second, scene.BranchId);

        var fees = await TestData.WithDbAsync(Factory, db => db.Sessions
            .Where(s => s.Id == scene.SessionId || s.Id == later).ToDictionaryAsync(s => s.Id, s => s.FeePiasters));
        Assert.Equal(3000, fees[scene.SessionId]);
        Assert.Equal(4000, fees[later]);
        var (_, summary) = await billingClient.GetJsonAsync("/api/sessions/feeSummary");
        Assert.Equal(7000, summary.IntAt("today.totalPiasters"));
        Assert.Equal(7000, summary.IntAt("today.examinationFeePiasters"));
        Assert.Equal(7000, summary.IntAt("thisMonth.totalPiasters"));
        var (_, month) = await billingClient.GetJsonAsync("/api/sessions/month");
        Assert.Equal(7000, month.IntAt("totals.totalPiasters"));
        var stats = await TestData.WithDbAsync(Factory, db => db.MonthlyStats.SingleAsync(m => m.DoctorId == scene.Doctor.Id));
        Assert.Equal(7000, stats.AmountPiasters);
    }

    [Fact]
    public async Task A_session_keeps_the_fee_the_price_the_cairo_day_and_updates_the_link_stats_notification_and_audit()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, 3000, 1500, 2);
        var (doctor, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var phone = TestData.Mobile();
        var patientId = await TestData.AddPatientViaApiAsync(client, phone);
        await TestData.SetDoctorPricesInDbAsync(Factory, doctor.Id, 30_000, 15_000);
        await TestData.SetBranchPricesInDbAsync(Factory, branchId, 25_000, null);

        var (_, info) = await client.GetJsonAsync($"/api/sessions/newSessionInfo?patientId={patientId}&branchId={branchId}");
        Assert.Equal(25_000, info.IntAt("examination.visitPricePiasters"));
        Assert.Equal("branch", info.StrAt("examination.priceSource"));
        Assert.Equal(15_000, info.IntAt("consultation.visitPricePiasters"));
        Assert.Equal("doctor", info.StrAt("consultation.priceSource"));
        Assert.Equal(3000, info.IntAt("examination.platformFeePiasters"));
        Assert.Equal(1500, info.IntAt("consultation.platformFeePiasters"));

        var (status, session) = await client.PostAsync("/api/sessions/createSession", new
        {
            patientId, branchId, type = "examination", chiefComplaint = "صداع", diagnosis = "صداع نصفي",
            findings = "سليم", patientNotes = "راحة", privateNote = "سري", followUpDate = CairoTime.Today(TimeProvider.System).AddDays(7),
            vitals = new { bpSys = 120, bpDia = 80, pulse = 75, tempC = 37.25m, weightKg = 70.5m, heightCm = 170, glucose = 95 },
            paymentMethod = "cash",
        });

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal("examination", session.Str("type"));
        Assert.Equal(3000, session.IntAt("platformFeePiasters"));
        Assert.Equal(25_000, session.IntAt("amountChargedPiasters"));
        Assert.Equal(25_000, session.IntAt("listPricePiasters"));
        Assert.Equal("cash", session.Str("paymentMethod"));
        Assert.Equal(CairoTime.Today(TimeProvider.System).ToString("yyyy-MM-dd"), session.Str("day"));
        Assert.Equal("doctor", session.StrAt("recordedBy.role"));
        Assert.Equal(doctor.Id.ToString(), session.StrAt("recordedBy.userId"));
        Assert.False(session.BoolAt("awaitingDoctor"));
        Assert.Equal("صداع نصفي", session.StrAt("clinical.diagnosis"));
        Assert.Equal(37.3m, session.At("clinical.vitals.tempC").GetDecimal());
        Assert.True(session.BoolAt("hasPrivateNote"));
        Assert.DoesNotContain("سري", session.ToString());
        Assert.True(session.BoolAt("can.delete"));
        Assert.True(session.BoolAt("can.editAmount"));

        var sessionId = Guid.Parse(session.Str("sessionId"));
        var row = await TestData.WithDbAsync(Factory, db => db.Sessions.SingleAsync(s => s.Id == sessionId));
        Assert.Equal(CairoTime.DayOf(row.CreatedAt), row.DayKey);
        Assert.Equal(CairoTime.MonthKey(row.DayKey), row.MonthKey);
        var link = await TestData.WithDbAsync(Factory, db => db.DoctorPatients.SingleAsync(l => l.PatientId == patientId));
        Assert.Equal(sessionId, link.LastSessionId);
        Assert.Equal(row.CreatedAt, link.FirstSessionAt);
        Assert.Equal(1, link.ExamCount);
        Assert.Equal(branchId, link.LastSessionBranchId);
        var daily = await TestData.WithDbAsync(Factory, db => db.DailyStats.SingleAsync(d => d.DoctorId == doctor.Id));
        Assert.Equal((1, 0, 3000), (daily.ExamCount, daily.ConsultationCount, daily.AmountPiasters));

        var notification = await TestData.WithDbAsync(Factory, db => db.Notifications
            .SingleAsync(n => n.RecipientUser.Phone == phone && n.Type == NotificationTexts.SessionRecorded));
        Assert.Equal("تم تسجيل زيارة جديدة", notification.TitleAr);
        Assert.DoesNotContain("صداع", notification.BodyAr + notification.BodyEn + notification.DataJson);
        Assert.Contains(sessionId.ToString(), notification.Route);
        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == AuditActions.SessionCreated && a.TargetId == sessionId.ToString()));
        Assert.Equal(doctor.Id, audit.DoctorId);
        Assert.Equal(patientId, audit.PatientId);
        Assert.DoesNotContain("صداع", audit.DetailsJson);
    }

    [Fact]
    public async Task The_amount_charged_can_be_lowered_to_zero_and_is_required_when_there_is_no_price()
    {
        var (_, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);

        var (missingStatus, missing) = await client.PostAsync("/api/sessions/createSession", TestData.SessionBody(patientId, branchId, amountChargedPiasters: null));
        var (freeStatus, free) = await client.PostAsync("/api/sessions/createSession", TestData.SessionBody(patientId, branchId, amountChargedPiasters: 0));
        var (_, tooMuch) = await client.PostAsync("/api/sessions/createSession", TestData.SessionBody(patientId, branchId, amountChargedPiasters: 10_000_001));

        Assert.Equal(HttpStatusCode.BadRequest, missingStatus);
        Assert.Equal(ErrorCodes.AmountRequired, missing.FieldCode("amountChargedPiasters"));
        Assert.Equal(HttpStatusCode.Created, freeStatus);
        Assert.Equal(0, free.IntAt("amountChargedPiasters"));
        Assert.True(free.IsNullAt("listPricePiasters"));
        Assert.Equal(ErrorCodes.OutOfRange, tooMuch.FieldCode("amountChargedPiasters"));
    }

    [Fact]
    public async Task Session_input_is_checked()
    {
        var (_, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);

        async Task<string?> FieldError(string field, object body)
        {
            var (status, problem) = await client.PostAsync("/api/sessions/createSession", body);
            Assert.Equal(HttpStatusCode.BadRequest, status);
            return problem.FieldCode(field);
        }

        Assert.Equal(ErrorCodes.Required, await FieldError("type", new { patientId, branchId, amountChargedPiasters = 0 }));
        Assert.Equal(ErrorCodes.InvalidValue, await FieldError("type", new { patientId, branchId, type = "followUp", amountChargedPiasters = 0 }));
        Assert.Equal(ErrorCodes.Required, await FieldError("branchId", new { patientId, type = "examination", amountChargedPiasters = 0 }));
        Assert.Equal(ErrorCodes.OutOfRange, await FieldError("vitals.bpSys", new { patientId, branchId, type = "examination", amountChargedPiasters = 0, vitals = new { bpSys = 500, bpDia = 80 } }));
        Assert.Equal(ErrorCodes.InvalidValue, await FieldError("vitals.bpDia", new { patientId, branchId, type = "examination", amountChargedPiasters = 0, vitals = new { bpSys = 120 } }));
        Assert.Equal(ErrorCodes.OutOfRange, await FieldError("followUpDate", new { patientId, branchId, type = "examination", amountChargedPiasters = 0, followUpDate = "2001-01-01" }));
        Assert.Equal(ErrorCodes.InvalidValue, await FieldError("paymentMethod", new { patientId, branchId, type = "examination", amountChargedPiasters = 0, paymentMethod = "cheque" }));
        // Unusual but possible values are accepted: the app only warns (spec section 11).
        var (status, _) = await client.PostAsync("/api/sessions/createSession", new
        {
            patientId, branchId, type = "examination", amountChargedPiasters = 0, vitals = new { bpSys = 270, bpDia = 140, tempC = 43.5m },
        });
        Assert.Equal(HttpStatusCode.Created, status);
    }

    [Fact]
    public async Task Patients_branches_and_archived_branches_of_other_clinics_are_refused()
    {
        var scene = await PatientScene.CreateAsync(Factory);
        var (otherDoctor, otherClient, otherBranch) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var archived = await TestData.AddBranchAsync(Factory, scene.Doctor.Id, "فرع قديم");
        await TestData.SetBranchStatusInDbAsync(Factory, archived, "archived");
        var closed = await TestData.AddBranchAsync(Factory, scene.Doctor.Id, "فرع مغلق");
        await TestData.SetBranchStatusInDbAsync(Factory, closed, "temporarilyClosed");

        var (notLinkedStatus, notLinked) = await Record(otherClient, scene.PatientId, otherBranch, "examination");
        var (foreignBranchStatus, foreignBranch) = await Record(scene.Client, scene.PatientId, otherBranch, "examination");
        var (archivedStatus, archivedBody) = await Record(scene.Client, scene.PatientId, archived, "examination");
        var (closedStatus, _) = await Record(scene.Client, scene.PatientId, closed, "examination");
        var (infoStatus, info) = await otherClient.GetJsonAsync($"/api/sessions/newSessionInfo?patientId={scene.PatientId}&branchId={otherBranch}");

        Assert.Equal(HttpStatusCode.NotFound, notLinkedStatus);
        Assert.Equal(ErrorCodes.NotLinked, notLinked.Code());
        Assert.Equal(HttpStatusCode.NotFound, foreignBranchStatus);
        Assert.Equal(ErrorCodes.NotFound, foreignBranch.Code());
        Assert.Equal(HttpStatusCode.Conflict, archivedStatus);
        Assert.Equal(ErrorCodes.SessionBranchArchived, archivedBody.Code());
        Assert.Equal(HttpStatusCode.Created, closedStatus);
        Assert.Equal(HttpStatusCode.NotFound, infoStatus);
        Assert.Equal(ErrorCodes.NotFound, info.Code());
        _ = otherDoctor;
    }

    [Fact]
    public async Task An_archived_patient_seen_again_is_unarchived()
    {
        var scene = await PatientScene.CreateAsync(Factory);
        await scene.Client.PostAsync("/api/patients/setArchived", new { patientId = scene.PatientId, archived = true });

        await TestData.RecordSessionAsync(scene.Client, scene.PatientId, scene.BranchId);

        var (_, patient) = await scene.Client.GetJsonAsync($"/api/patients/{scene.PatientId}");
        Assert.False(patient.BoolAt("archived"));
    }

    [Fact]
    public async Task The_doctor_edits_clinical_fields_but_never_the_type_or_time()
    {
        var scene = await PatientScene.CreateAsync(Factory);
        var (_, before) = await scene.Client.GetJsonAsync($"/api/sessions/{scene.SessionId}");
        var followUp = CairoTime.Today(TimeProvider.System).AddDays(14).ToString("yyyy-MM-dd");

        var (status, after) = await scene.Client.PostAsync("/api/sessions/updateClinical", new
        {
            sessionId = scene.SessionId, type = "consultation", at = "2020-01-01T00:00:00Z",
            chiefComplaint = "كحة", diagnosis = "التهاب شعبي", findings = "صفير", patientNotes = "مضاد حيوي", followUpDate = followUp,
            vitals = new { tempC = 38.2m },
        });
        var (badStatus, bad) = await scene.Client.PostAsync("/api/sessions/updateClinical", new
        {
            sessionId = scene.SessionId, followUpDate = "2001-01-01",
        });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("examination", after.Str("type"));
        Assert.Equal(before.Str("at"), after.Str("at"));
        Assert.Equal("التهاب شعبي", after.StrAt("clinical.diagnosis"));
        Assert.Equal(followUp, after.StrAt("clinical.followUpDate"));
        Assert.Equal(38.2m, after.At("clinical.vitals.tempC").GetDecimal());
        Assert.True(after.IsNullAt("clinical.vitals.bpSys"));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.OutOfRange, bad.FieldCode("followUpDate"));
        var details = await TestData.WithDbAsync(Factory, db => db.AuditLogs
            .Where(a => a.Action == AuditActions.SessionClinicalUpdated && a.TargetId == scene.SessionId.ToString()).Select(a => a.DetailsJson!).SingleAsync());
        Assert.Contains("diagnosis", details);
        Assert.DoesNotContain("التهاب", details);
    }

    [Fact]
    public async Task The_amount_is_edited_on_the_same_day_by_the_doctor_or_the_recorder_and_logged()
    {
        var scene = await PatientScene.CreateAsync(Factory);
        var recorder = await TestData.CreateAssistantAsync(Factory, scene.Doctor.Id, permissions: [ClinicPermissions.SessionsCreate]);
        using var recorderClient = await Factory.SignedInClientAsync(recorder);
        var other = await TestData.CreateAssistantAsync(Factory, scene.Doctor.Id, permissions: [ClinicPermissions.SessionsCreate]);
        using var otherClient = await Factory.SignedInClientAsync(other);
        var patient2 = await TestData.AddPatientViaApiAsync(scene.Client);
        var assistantSession = await TestData.RecordSessionAsync(recorderClient, patient2, scene.BranchId, amountChargedPiasters: 20_000);
        var feeBefore = await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.Id == scene.SessionId).Select(s => s.FeePiasters).SingleAsync());

        var (doctorStatus, doctorEdit) = await scene.Client.PostAsync("/api/sessions/updateAmountCharged", new
        {
            sessionId = scene.SessionId, amountChargedPiasters = 15_000, paymentMethod = "card",
        });
        var (recorderStatus, recorderEdit) = await recorderClient.PostAsync("/api/sessions/updateAmountCharged", new
        {
            sessionId = assistantSession, amountChargedPiasters = 0,
        });
        var (otherStatus, otherEdit) = await otherClient.PostAsync("/api/sessions/updateAmountCharged", new
        {
            sessionId = assistantSession, amountChargedPiasters = 5_000,
        });
        await TestData.MoveSessionToDayAsync(Factory, scene.SessionId, CairoTime.Today(TimeProvider.System).AddDays(-1));
        var (lateStatus, late) = await scene.Client.PostAsync("/api/sessions/updateAmountCharged", new
        {
            sessionId = scene.SessionId, amountChargedPiasters = 10_000,
        });
        var (_, otherView) = await otherClient.GetJsonAsync($"/api/sessions/{assistantSession}");

        Assert.Equal(HttpStatusCode.OK, doctorStatus);
        Assert.Equal(15_000, doctorEdit.IntAt("amountChargedPiasters"));
        Assert.Equal("card", doctorEdit.Str("paymentMethod"));
        Assert.Equal(HttpStatusCode.OK, recorderStatus);
        Assert.Equal(0, recorderEdit.IntAt("amountChargedPiasters"));
        Assert.Equal(HttpStatusCode.Forbidden, otherStatus);
        Assert.Equal("doctorOnly", otherEdit.Str("permission"));
        Assert.Equal(HttpStatusCode.Conflict, lateStatus);
        Assert.Equal(ErrorCodes.AmountNotEditable, late.Code());
        // Without revenueView, an assistant sees amounts only on sessions they recorded.
        Assert.True(otherView.IsNullAt("amountChargedPiasters"));
        Assert.False(otherView.BoolAt("can.editAmount"));

        var logs = await TestData.WithDbAsync(Factory, db => db.AuditLogs
            .Where(a => a.Action == AuditActions.SessionAmountChanged && (a.TargetId == scene.SessionId.ToString() || a.TargetId == assistantSession.ToString()))
            .OrderBy(a => a.Id).Select(a => a.DetailsJson!).ToListAsync());
        Assert.Equal(2, logs.Count);
        Assert.Contains("\"before\":20000", logs[0]);
        Assert.Contains("\"after\":15000", logs[0]);
        // The platform fee never changes with the amount (BR-S10).
        Assert.Equal(feeBefore, await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.Id == scene.SessionId).Select(s => s.FeePiasters).SingleAsync()));
    }

    [Fact]
    public async Task AC11_private_notes_are_for_the_doctor_only()
    {
        var (doctor, doctorClient, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var (patient, patientId) = await TestData.CreatePatientAsync(Factory);
        await TestData.LinkAsync(Factory, doctor.Id, patientId);
        var scene = new PatientScene(doctor, doctorClient, branchId, patientId, await TestData.RecordSessionAsync(doctorClient, patientId, branchId));
        using var patientClient = await Factory.SignedInClientAsync(patient);
        var admin = await TestData.CreateAdminAsync(Factory);
        using var adminClient = await Factory.SignedInClientAsync(admin);
        var assistant = await TestData.CreateAssistantAsync(Factory, scene.Doctor.Id, permissions: ClinicPermissions.All);
        using var assistantClient = await Factory.SignedInClientAsync(assistant);

        var (setStatus, set) = await scene.Client.PostAsync("/api/sessions/setPrivateNote", new { sessionId = scene.SessionId, text = "  يشك في الالتزام بالعلاج " });
        var (getStatus, note) = await scene.Client.GetJsonAsync($"/api/sessions/{scene.SessionId}/privateNote");
        var (_, detail) = await scene.Client.GetJsonAsync($"/api/sessions/{scene.SessionId}");

        Assert.Equal(HttpStatusCode.OK, setStatus);
        Assert.Equal("يشك في الالتزام بالعلاج", set.Str("text"));
        Assert.Equal(HttpStatusCode.OK, getStatus);
        Assert.Equal("يشك في الالتزام بالعلاج", note.Str("text"));
        Assert.DoesNotContain("الالتزام", detail.ToString());

        foreach (var (client, code) in new[] { (patientClient, ErrorCodes.Forbidden), (adminClient, ErrorCodes.Forbidden), (assistantClient, ErrorCodes.PermissionDenied) })
        {
            var (readStatus, read) = await client.GetJsonAsync($"/api/sessions/{scene.SessionId}/privateNote");
            var (writeStatus, write) = await client.PostAsync("/api/sessions/setPrivateNote", new { sessionId = scene.SessionId, text = "x" });
            Assert.Equal(HttpStatusCode.Forbidden, readStatus);
            Assert.Equal(code, read.Code());
            Assert.Equal(HttpStatusCode.Forbidden, writeStatus);
            Assert.Equal(code, write.Code());
        }

        var (_, assistantDetail) = await assistantClient.GetJsonAsync($"/api/sessions/{scene.SessionId}");
        Assert.True(assistantDetail.IsNullAt("hasPrivateNote"));
        Assert.DoesNotContain("الالتزام", assistantDetail.ToString());

        var (clearStatus, cleared) = await scene.Client.PostAsync("/api/sessions/setPrivateNote", new { sessionId = scene.SessionId, text = "" });
        Assert.Equal(HttpStatusCode.OK, clearStatus);
        Assert.True(cleared.IsNullAt("text"));
        Assert.False(await TestData.WithDbAsync(Factory, db => db.SessionPrivateNotes.AnyAsync(n => n.SessionId == scene.SessionId)));
    }

    [Fact]
    public async Task AC5_only_the_latest_session_of_the_day_is_deleted_with_a_reason_and_everything_is_recalculated()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, 3000, 1500, 2);
        var scene = await PatientScene.CreateAsync(Factory);
        var consultation = await TestData.RecordSessionAsync(scene.Client, scene.PatientId, scene.BranchId, "consultation");
        var admin = await TestData.CreateAdminAsync(Factory);
        using var adminClient = await Factory.SignedInClientAsync(admin);

        var (noReasonStatus, noReason) = await scene.Client.PostAsync("/api/sessions/deleteSession", new { sessionId = consultation });
        var (notLatestStatus, notLatest) = await scene.Client.PostAsync("/api/sessions/deleteSession", new { sessionId = scene.SessionId, reason = "خطأ" });
        var (_, detail) = await scene.Client.GetJsonAsync($"/api/sessions/{scene.SessionId}");

        Assert.Equal(HttpStatusCode.BadRequest, noReasonStatus);
        Assert.Equal(ErrorCodes.ReasonRequired, noReason.FieldCode("reason"));
        Assert.Equal(HttpStatusCode.Conflict, notLatestStatus);
        Assert.Equal(ErrorCodes.SessionNotDeletable, notLatest.Code());
        Assert.Equal("notLatest", notLatest.Str("reason"));
        Assert.False(detail.BoolAt("can.delete"));
        Assert.Equal("notLatest", detail.StrAt("can.deleteBlockedReason"));

        var (_, before) = await scene.Client.GetJsonAsync("/api/sessions/feeSummary");
        var (status, deleted) = await scene.Client.PostAsync("/api/sessions/deleteSession", new { sessionId = consultation, reason = "سجلت للمريض الخطأ" });
        var (_, after) = await scene.Client.GetJsonAsync("/api/sessions/feeSummary");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(consultation.ToString(), deleted.Str("sessionId"));
        Assert.Equal(before.IntAt("today.totalPiasters") - 1500, after.IntAt("today.totalPiasters"));
        Assert.Equal(0, after.IntAt("today.consultationCount"));
        var link = await TestData.WithDbAsync(Factory, db => db.DoctorPatients.SingleAsync(l => l.PatientId == scene.PatientId));
        Assert.Equal(0, link.ConsultationsSinceExam);
        Assert.Equal(1, link.SessionCount);
        Assert.Equal(scene.SessionId, link.LastSessionId);
        Assert.Equal("examination", link.LastSessionType);
        var stats = await TestData.WithDbAsync(Factory, db => db.DailyStats.SingleAsync(d => d.DoctorId == scene.Doctor.Id));
        Assert.Equal((1, 0, 3000), (stats.ExamCount, stats.ConsultationCount, stats.AmountPiasters));
        Assert.Equal(HttpStatusCode.NotFound, (await scene.Client.GetJsonAsync($"/api/sessions/{consultation}")).Status);
        Assert.Single((await scene.Client.GetJsonAsync($"/api/patients/{scene.PatientId}/sessions")).Body.Items());

        // The deletion is in the admin audit log, with the reason.
        var (_, audit) = await adminClient.GetJsonAsync($"/api/admin/auditLogs?action=sessionDeleted&doctorId={scene.Doctor.Id}");
        var row = Assert.Single(audit.Items());
        Assert.Equal(consultation.ToString(), row.Str("targetId"));
        Assert.Equal("سجلت للمريض الخطأ", row.StrAt("details.reason"));

        // The examination is now the latest, but from another day: not deletable.
        await TestData.MoveSessionToDayAsync(Factory, scene.SessionId, CairoTime.Today(TimeProvider.System).AddDays(-1));
        var (oldStatus, old) = await scene.Client.PostAsync("/api/sessions/deleteSession", new { sessionId = scene.SessionId, reason = "خطأ" });
        Assert.Equal(HttpStatusCode.Conflict, oldStatus);
        Assert.Equal("notSameDay", old.Str("reason"));
    }

    [Fact]
    public async Task Deleting_a_consultation_brings_the_count_back_so_a_consultation_is_allowed_again()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, maxConsecutiveConsultations: 2);
        var scene = await PatientScene.CreateAsync(Factory);
        await TestData.RecordSessionAsync(scene.Client, scene.PatientId, scene.BranchId, "consultation");
        var second = await TestData.RecordSessionAsync(scene.Client, scene.PatientId, scene.BranchId, "consultation");
        Assert.Equal(HttpStatusCode.Conflict, (await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation")).Status);

        await scene.Client.PostAsync("/api/sessions/deleteSession", new { sessionId = second, reason = "مكرر" });

        Assert.Equal(HttpStatusCode.Created, (await Record(scene.Client, scene.PatientId, scene.BranchId, "consultation")).Status);
    }
}
