using System.Net;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Doctors;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// The free trial (spec 6.16, backend/docs/api-free-trial.md): approval starts it (BR-T1), sessions in it are free
/// (BR-T3), its end closes the clinic but not sign-in (BR-T4), and the admin activates the service or extends it (BR-T5).
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class TrialTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static DateTime Now => DateTime.UtcNow;

    private Task SetTrialAsync(Guid doctorId, DateTime? endsAt) =>
        TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctorId)
            .ExecuteUpdateAsync(set => set.SetProperty(d => d.TrialEndsAt, endsAt)));

    private Task<DateTime?> TrialEndsAtAsync(Guid doctorId) =>
        TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctorId).Select(d => d.TrialEndsAt).SingleAsync());

    private async Task<IAsyncDisposable> UseTrialDaysAsync(int days)
    {
        var old = await TestData.WithDbAsync(Factory, db => db.AppSettings.Select(s => s.TrialDays).SingleAsync());
        await TestData.WithDbAsync(Factory, db => db.AppSettings.ExecuteUpdateAsync(set => set.SetProperty(s => s.TrialDays, days)));
        return new Restore(() => TestData.WithDbAsync(Factory, db => db.AppSettings.ExecuteUpdateAsync(set => set.SetProperty(s => s.TrialDays, old))));
    }

    private sealed class Restore(Func<Task> restore) : IAsyncDisposable
    {
        public async ValueTask DisposeAsync() => await restore();
    }

    [Fact]
    public async Task Approval_starts_the_trial_with_the_setting_and_says_so()
    {
        await using var restoreDays = await UseTrialDaysAsync(10);
        var admin = await TestData.CreateAdminAsync(Factory);
        var doctor = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.PendingApproval);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        var (pendingStatus, pending) = await asDoctor.GetJsonAsync("/api/auth/me");
        var before = Now;
        var (status, approved) = await asAdmin.PostAsync("/api/admin/reviewDoctorRegistration", new { doctorId = doctor.Id, decision = "approve" });

        Assert.Equal(HttpStatusCode.OK, pendingStatus);
        Assert.Equal(JsonValueKind.Null, pending.GetProperty("trial").ValueKind);
        Assert.Equal(HttpStatusCode.OK, status);
        var endsAt = (await TrialEndsAtAsync(doctor.Id))!.Value;
        Assert.InRange(endsAt, before.AddDays(10).AddSeconds(-5), Now.AddDays(10).AddSeconds(5));
        var trial = approved.GetProperty("trial");
        Assert.False(trial.GetProperty("ended").GetBoolean());
        Assert.Equal(10, trial.GetProperty("daysLeft").GetInt32());

        var (_, session) = await asDoctor.GetJsonAsync("/api/auth/me");
        Assert.Equal(10, session.GetProperty("trial").GetProperty("daysLeft").GetInt32());
        Assert.False(session.GetProperty("trial").GetProperty("ended").GetBoolean());
        var notification = await TestData.WithDbAsync(Factory, db => db.Notifications
            .SingleAsync(n => n.RecipientUserId == doctor.Id && n.Type == "doctorRegistrationApproved"));
        Assert.Contains("فترة تجريبية مجانية لمدة 10 أيام", notification.BodyAr);
        Assert.Contains("free trial of 10 days", notification.BodyEn);
        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == "doctorRegistrationApproved" && a.TargetId == doctor.Id.ToString()));
        Assert.True(JsonDocument.Parse(audit.DetailsJson!).RootElement.TryGetProperty("trialEndsAt", out _));
    }

    [Fact]
    public async Task Sessions_in_a_running_trial_are_free_and_the_clinic_shows_it()
    {
        await using var fees = await TestData.UseFeeSettingsAsync(Factory, examFeePiasters: 3000, consultationFeePiasters: 1500);
        var (doctor, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        await SetTrialAsync(doctor.Id, Now.AddDays(2).AddHours(-6));
        var patientId = await TestData.AddPatientViaApiAsync(client);

        var (_, me) = await client.GetJsonAsync("/api/clinic/me");
        var (_, info) = await client.GetJsonAsync($"/api/sessions/newSessionInfo?patientId={patientId}&branchId={branchId}");
        var sessionId = await TestData.RecordSessionAsync(client, patientId, branchId);

        Assert.Equal(0, me.GetProperty("fees").GetProperty("examinationFeePiasters").GetInt32());
        Assert.Equal(0, me.GetProperty("fees").GetProperty("consultationFeePiasters").GetInt32());
        Assert.Equal(2, me.GetProperty("trial").GetProperty("daysLeft").GetInt32());
        Assert.Equal(0, info.GetProperty("examination").GetProperty("platformFeePiasters").GetInt32());
        Assert.Equal(0, await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.Id == sessionId).Select(s => s.FeePiasters).SingleAsync()));
        var today = await TestData.WithDbAsync(Factory, db => db.DailyStats.SingleAsync(d => d.DoctorId == doctor.Id));
        Assert.Equal(1, today.ExamCount);
        Assert.Equal(0, today.AmountPiasters);

        // Activated: the fees apply to the next session.
        var admin = await TestData.CreateAdminAsync(Factory);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        await asAdmin.PostAsync("/api/admin/activateDoctorService", new { doctorId = doctor.Id });
        var paid = await TestData.RecordSessionAsync(client, patientId, branchId);
        var (_, after) = await client.GetJsonAsync("/api/clinic/me");
        Assert.Equal(3000, await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.Id == paid).Select(s => s.FeePiasters).SingleAsync()));
        Assert.Equal(3000, after.GetProperty("fees").GetProperty("examinationFeePiasters").GetInt32());
        Assert.Equal(JsonValueKind.Null, after.GetProperty("trial").ValueKind);
    }

    [Fact]
    public async Task An_ended_trial_closes_every_clinic_endpoint_but_clinic_me_and_sign_in_still_works()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        await SetTrialAsync(doctor.Id, Now.AddMinutes(-1));

        // Signing in is never refused for it (BR-T4); the session says the trial ended.
        var doctorLogin = await Factory.LoginAsync(doctor.Identifier, doctor.Password);
        var assistantLogin = await Factory.LoginAsync(assistant.Identifier, assistant.Password);
        Assert.Equal("signedIn", doctorLogin.Str("result"));
        Assert.True(doctorLogin.GetProperty("trial").GetProperty("ended").GetBoolean());
        Assert.Equal(0, doctorLogin.GetProperty("trial").GetProperty("daysLeft").GetInt32());
        Assert.True(assistantLogin.GetProperty("trial").GetProperty("ended").GetBoolean());

        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);
        foreach (var client in new[] { asDoctor, asAssistant })
        {
            var (meStatus, me) = await client.GetJsonAsync("/api/clinic/me");
            var (registerStatus, register) = await client.GetJsonAsync("/api/patients/register");
            var (createStatus, create) = await client.PostAsync("/api/patients/createPatient", TestData.PatientBody(TestData.Local(TestData.Mobile())));
            var (feesStatus, fees) = await client.GetJsonAsync("/api/sessions/feeSummary");

            Assert.Equal(HttpStatusCode.OK, meStatus);
            Assert.True(me.GetProperty("trial").GetProperty("ended").GetBoolean());
            Assert.Equal(HttpStatusCode.Forbidden, registerStatus);
            Assert.Equal(ErrorCodes.TrialEnded, register.Code());
            Assert.Equal(HttpStatusCode.Forbidden, createStatus);
            Assert.Equal(ErrorCodes.TrialEnded, create.Code());
            Assert.Equal(HttpStatusCode.Forbidden, feesStatus);
            Assert.Equal(ErrorCodes.TrialEnded, fees.Code());
        }

        // Doctor-only endpoints and missing permissions answer the trial first, so the app always opens A15.
        var (branchesStatus, branches) = await asAssistant.PostAsync("/api/branches/createBranch", new { });
        Assert.Equal(HttpStatusCode.Forbidden, branchesStatus);
        Assert.Equal(ErrorCodes.TrialEnded, branches.Code());
    }

    [Fact]
    public async Task Activating_the_service_opens_the_clinic_for_everyone_at_once()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        await SetTrialAsync(doctor.Id, Now.AddDays(-3));
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);
        var (blocked, _) = await asAssistant.GetJsonAsync("/api/patients/register");

        var (status, body) = await asAdmin.PostAsync("/api/admin/activateDoctorService", new { doctorId = doctor.Id });

        Assert.Equal(HttpStatusCode.Forbidden, blocked);
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(doctor.Id, body.GetProperty("doctorId").GetGuid());
        Assert.Equal(DoctorStatuses.Active, body.Str("status"));
        Assert.Equal(JsonValueKind.Null, body.GetProperty("trial").ValueKind);
        Assert.Null(await TrialEndsAtAsync(doctor.Id));
        foreach (var client in new[] { asDoctor, asAssistant })
        {
            var (registerStatus, _) = await client.GetJsonAsync("/api/patients/register");
            var (_, session) = await client.GetJsonAsync("/api/auth/me");
            Assert.Equal(HttpStatusCode.OK, registerStatus);
            Assert.Equal(JsonValueKind.Null, session.GetProperty("trial").ValueKind);
        }

        var notified = await TestData.WithDbAsync(Factory, db => db.Notifications
            .Where(n => n.Type == "doctorServiceActivated" && (n.RecipientUserId == doctor.Id || n.RecipientUserId == assistant.Id))
            .ToListAsync());
        Assert.Equal(2, notified.Count);
        Assert.Equal("تم تفعيل الخدمة", notified.Single(n => n.RecipientUserId == doctor.Id).TitleAr);
        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == "doctorServiceActivated" && a.TargetId == doctor.Id.ToString()));
        Assert.Equal(admin.Id, audit.ActorUserId);
        Assert.True(JsonDocument.Parse(audit.DetailsJson!).RootElement.TryGetProperty("trialEndsAtBefore", out _));

        // Again: nothing changes.
        var (againStatus, again) = await asAdmin.PostAsync("/api/admin/activateDoctorService", new { doctorId = doctor.Id });
        Assert.Equal(HttpStatusCode.OK, againStatus);
        Assert.Equal(JsonValueKind.Null, again.GetProperty("trial").ValueKind);
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.AuditLogs.CountAsync(a => a.Action == "doctorServiceActivated" && a.TargetId == doctor.Id.ToString())));
    }

    [Fact]
    public async Task Extending_restarts_an_ended_trial_from_today_and_lengthens_a_running_one()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var ended = await TestData.CreateDoctorAsync(Factory);
        var running = await TestData.CreateDoctorAsync(Factory);
        var runningEnd = Now.AddDays(5);
        await SetTrialAsync(ended.Id, Now.AddDays(-20));
        await SetTrialAsync(running.Id, runningEnd);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        using var asEnded = await Factory.SignedInClientAsync(ended);

        var before = Now;
        var (endedStatus, endedBody) = await asAdmin.PostAsync("/api/admin/extendDoctorTrial", new { doctorId = ended.Id, days = 7 });
        var (runningStatus, runningBody) = await asAdmin.PostAsync("/api/admin/extendDoctorTrial", new { doctorId = running.Id, days = 7 });

        Assert.Equal(HttpStatusCode.OK, endedStatus);
        Assert.Equal(7, endedBody.GetProperty("trial").GetProperty("daysLeft").GetInt32());
        Assert.False(endedBody.GetProperty("trial").GetProperty("ended").GetBoolean());
        Assert.InRange((await TrialEndsAtAsync(ended.Id))!.Value, before.AddDays(7).AddSeconds(-5), Now.AddDays(7).AddSeconds(5));
        Assert.Equal(HttpStatusCode.OK, runningStatus);
        Assert.Equal(12, runningBody.GetProperty("trial").GetProperty("daysLeft").GetInt32());
        Assert.Equal(runningEnd.AddDays(7), (await TrialEndsAtAsync(running.Id))!.Value, TimeSpan.FromMilliseconds(5));

        var (registerStatus, _) = await asEnded.GetJsonAsync("/api/patients/register");
        Assert.Equal(HttpStatusCode.OK, registerStatus);
        var notification = await TestData.WithDbAsync(Factory, db => db.Notifications.SingleAsync(n => n.RecipientUserId == ended.Id && n.Type == "doctorTrialExtended"));
        Assert.Contains("حتى", notification.BodyAr);
        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == "doctorTrialExtended" && a.TargetId == running.Id.ToString()));
        Assert.Equal(7, JsonDocument.Parse(audit.DetailsJson!).RootElement.GetProperty("days").GetInt32());
    }

    [Fact]
    public async Task Extending_needs_a_trial_an_approved_doctor_and_1_to_90_days()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var active = await TestData.CreateDoctorAsync(Factory);
        var pending = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.PendingApproval);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var (activeStatus, activeBody) = await asAdmin.PostAsync("/api/admin/extendDoctorTrial", new { doctorId = active.Id, days = 7 });
        var (pendingStatus, pendingBody) = await asAdmin.PostAsync("/api/admin/extendDoctorTrial", new { doctorId = pending.Id, days = 7 });
        var (activatePendingStatus, activatePending) = await asAdmin.PostAsync("/api/admin/activateDoctorService", new { doctorId = pending.Id });
        var (zeroStatus, zero) = await asAdmin.PostAsync("/api/admin/extendDoctorTrial", new { doctorId = active.Id, days = 0 });
        var (tooManyStatus, tooMany) = await asAdmin.PostAsync("/api/admin/extendDoctorTrial", new { doctorId = active.Id, days = 91 });
        var (missingStatus, missing) = await asAdmin.PostAsync("/api/admin/extendDoctorTrial", new { doctorId = active.Id });
        var (unknownStatus, _) = await asAdmin.PostAsync("/api/admin/activateDoctorService", new { doctorId = Guid.NewGuid() });

        Assert.Equal(HttpStatusCode.Conflict, activeStatus);
        Assert.Equal(ErrorCodes.ServiceAlreadyActive, activeBody.Code());
        Assert.Equal(HttpStatusCode.Conflict, pendingStatus);
        Assert.Equal(ErrorCodes.DoctorStatusNotChangeable, pendingBody.Code());
        Assert.Equal(DoctorStatuses.PendingApproval, pendingBody.Str("status"));
        Assert.Equal(HttpStatusCode.Conflict, activatePendingStatus);
        Assert.Equal(ErrorCodes.DoctorStatusNotChangeable, activatePending.Code());
        Assert.Equal(HttpStatusCode.BadRequest, zeroStatus);
        Assert.Equal(ErrorCodes.OutOfRange, zero.FieldCode("days"));
        Assert.Equal(HttpStatusCode.BadRequest, tooManyStatus);
        Assert.Equal(ErrorCodes.OutOfRange, tooMany.FieldCode("days"));
        Assert.Equal(HttpStatusCode.BadRequest, missingStatus);
        Assert.Equal(ErrorCodes.Required, missing.FieldCode("days"));
        Assert.Equal(HttpStatusCode.NotFound, unknownStatus);
    }

    [Theory]
    [InlineData("/api/admin/activateDoctorService")]
    [InlineData("/api/admin/extendDoctorTrial")]
    public async Task Only_admins_change_a_trial(string url)
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        await SetTrialAsync(doctor.Id, Now.AddDays(-1));
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var anonymous = Factory.Client();

        var (doctorStatus, _) = await asDoctor.PostAsync(url, new { doctorId = doctor.Id, days = 7 });
        var (anonymousStatus, _) = await anonymous.PostAsync(url, new { doctorId = doctor.Id, days = 7 });

        Assert.Equal(HttpStatusCode.Forbidden, doctorStatus);
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousStatus);
        Assert.NotNull(await TrialEndsAtAsync(doctor.Id));
    }

    [Fact]
    public async Task The_admin_finds_doctors_by_trial_state()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var ended = await TestData.CreateDoctorAsync(Factory);
        var running = await TestData.CreateDoctorAsync(Factory);
        var active = await TestData.CreateDoctorAsync(Factory);
        await SetTrialAsync(ended.Id, Now.AddDays(-1));
        await SetTrialAsync(running.Id, Now.AddDays(3));
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        static IEnumerable<Guid> Ids(JsonElement page) =>
            page.GetProperty("items").EnumerateArray().Select(i => i.GetProperty("doctorId").GetGuid());

        var (endedStatus, endedPage) = await asAdmin.GetJsonAsync("/api/admin/doctorRegistrations?status=all&trial=ended&pageSize=100&sort=newest");
        var (_, runningPage) = await asAdmin.GetJsonAsync("/api/admin/doctorRegistrations?status=all&trial=running&pageSize=100&sort=newest");
        var (badStatus, bad) = await asAdmin.GetJsonAsync("/api/admin/doctorRegistrations?trial=soon");
        var (_, detail) = await asAdmin.GetJsonAsync($"/api/admin/doctorRegistrations/{ended.Id}");

        Assert.Equal(HttpStatusCode.OK, endedStatus);
        Assert.Contains(ended.Id, Ids(endedPage));
        Assert.DoesNotContain(running.Id, Ids(endedPage));
        Assert.DoesNotContain(active.Id, Ids(endedPage));
        Assert.Contains(running.Id, Ids(runningPage));
        Assert.DoesNotContain(ended.Id, Ids(runningPage));
        var item = endedPage.GetProperty("items").EnumerateArray().Single(i => i.GetProperty("doctorId").GetGuid() == ended.Id);
        Assert.True(item.GetProperty("trial").GetProperty("ended").GetBoolean());
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("trial"));
        Assert.True(detail.GetProperty("registration").GetProperty("trial").GetProperty("ended").GetBoolean());
    }

    [Fact]
    public async Task Trial_days_is_an_AD13_setting_from_1_to_90()
    {
        await using var restoreDays = await UseTrialDaysAsync(14);
        var admin = await TestData.CreateAdminAsync(Factory);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var (_, settings) = await asAdmin.GetJsonAsync("/api/admin/settings");
        var (okStatus, updated) = await asAdmin.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?> { ["trialDays"] = 30 });
        var (lowStatus, low) = await asAdmin.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?> { ["trialDays"] = 0 });
        var (highStatus, high) = await asAdmin.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?> { ["trialDays"] = 91 });

        Assert.Equal(14, settings.GetProperty("trialDays").GetInt32());
        Assert.Equal(HttpStatusCode.OK, okStatus);
        Assert.Equal(30, updated.GetProperty("trialDays").GetInt32());
        Assert.Equal(HttpStatusCode.BadRequest, lowStatus);
        Assert.Equal(ErrorCodes.OutOfRange, low.FieldCode("trialDays"));
        Assert.Equal(HttpStatusCode.BadRequest, highStatus);
        Assert.Equal(ErrorCodes.OutOfRange, high.FieldCode("trialDays"));
        Assert.True(await TestData.WithDbAsync(Factory, db => db.SettingsHistories.AnyAsync(h => h.Field == "trialDays" && h.ChangedBy == admin.Id)));
    }

    [Fact]
    public void Days_left_round_up_and_end_at_zero()
    {
        var now = new DateTime(2026, 11, 17, 10, 0, 0, DateTimeKind.Utc);

        Assert.Null(TrialView.Of(null, now));
        Assert.Equal(2, TrialView.Of(now.AddHours(30), now)!.DaysLeft);
        Assert.Equal(1, TrialView.Of(now.AddMinutes(1), now)!.DaysLeft);
        Assert.Equal(14, TrialView.Of(now.AddDays(14), now)!.DaysLeft);
        Assert.True(TrialView.Of(now, now)!.Ended);
        Assert.Equal(0, TrialView.Of(now.AddDays(-2), now)!.DaysLeft);
        Assert.Equal(now.AddDays(7), Trial.Extend(now.AddDays(-30), now, 7));
        Assert.Equal(now.AddDays(10), Trial.Extend(now.AddDays(3), now, 7));
    }
}
