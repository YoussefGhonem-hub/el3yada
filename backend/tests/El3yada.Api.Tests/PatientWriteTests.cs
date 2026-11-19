using System.Net;
using System.Net.Http.Json;
using El3yada.Api.Features.Account;
using El3yada.Api.Features.Admin;
using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Infrastructure.Paging;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests;

/// <summary>"New" badges, preferences, the deletion flow (P14 → AD12) and accounts support (AD11).</summary>
public sealed class PatientWriteTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task Mark_seen_clears_badges_and_ignores_foreign_ids()
    {
        var client = await api.ClientForAsync(api.Demo.PatientUserId);
        var before = await client.GetFromJsonAsync<VisitDetailDto>($"/api/patient/visits/{api.Demo.OtherDoctorSessionId}");
        Assert.True(before!.IsNew);

        var response = await client.PostAsJsonAsync("/api/patient/seen", new MarkSeenRequest(
            Visits: [api.Demo.OtherDoctorSessionId, api.Demo.OtherPatientSessionId],
            Prescriptions: [api.Demo.DraftRxId],
            Files: null));
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        var after = await client.GetFromJsonAsync<VisitDetailDto>($"/api/patient/visits/{api.Demo.OtherDoctorSessionId}");
        Assert.False(after!.IsNew);

        // Another patient's session and a draft were not touched.
        var untouched = await api.WithDbAsync(async db => (
            await db.Sessions.Where(s => s.Id == api.Demo.OtherPatientSessionId).Select(s => s.PatientSeenAt).SingleAsync(),
            await db.Prescriptions.Where(p => p.Id == api.Demo.DraftRxId).Select(p => p.PatientSeenAt).SingleAsync()));
        Assert.Null(untouched.Item1);
        Assert.Null(untouched.Item2);
    }

    [Fact]
    public async Task Preferences_update_only_what_is_sent()
    {
        var client = await api.ClientForAsync(api.Demo.PatientUserId);

        var updated = await (await client.PatchAsJsonAsync("/api/me/preferences",
            new UpdatePreferencesRequest("en", null, null, null, true))).Content.ReadFromJsonAsync<PreferencesDto>();
        Assert.Equal("en", updated!.Locale);
        Assert.Equal("system", updated.ThemeMode);
        Assert.True(updated.NotifyShowPreview);
        Assert.True(updated.NotifyChat);

        var invalid = await client.PatchAsJsonAsync("/api/me/preferences", new UpdatePreferencesRequest("fr", null, null, null, null));
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);

        Assert.Equal(HttpStatusCode.NoContent, (await client.PostAsync("/api/me/accept-terms", null)).StatusCode);
        var account = await client.GetFromJsonAsync<PatientAccountDto>("/api/patient/account");
        Assert.NotNull(account!.AcceptedTermsAt);
    }

    [Fact]
    public async Task Deletion_request_flow_disables_the_account_on_approval()
    {
        // Uses the second patient, so the main demo patient stays signed in for the other tests.
        var otherUserId = await api.WithDbAsync(db =>
            db.Patients.Where(p => p.Id == api.Demo.OtherPatientId).Select(p => p.UserId).SingleAsync());
        var patient = await api.ClientForAsync(otherUserId);
        var admin = await api.ClientForAsync(api.Demo.AdminUserId);

        var created = await patient.PostAsJsonAsync("/api/patient/deletion-request", new RequestAccountDeletionRequest("لم أعد أحتاج التطبيق"));
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var request = await created.Content.ReadFromJsonAsync<DeletionRequestDto>();
        Assert.Equal("pending", request!.Status);

        var duplicate = await patient.PostAsJsonAsync("/api/patient/deletion-request", new RequestAccountDeletionRequest(null));
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
        Assert.Contains("DELETION_ALREADY_REQUESTED", await duplicate.Content.ReadAsStringAsync());

        // Admins were notified, and the request is in the AD12 queue.
        var notified = await api.WithDbAsync(db => db.Notifications.AnyAsync(n => n.RecipientUserId == api.Demo.AdminUserId && n.Type == "deletionRequest"));
        Assert.True(notified);
        var queue = await admin.GetFromJsonAsync<PagedResult<AdminDeletionRequestDto>>("/api/admin/deletion-requests");
        Assert.Contains(queue!.Items, r => r.Id == request.Id);

        // Rejecting needs a note.
        var noNote = await admin.PostAsJsonAsync($"/api/admin/deletion-requests/{request.Id}/review", new ReviewDeletionRequest("reject", null));
        Assert.Equal(HttpStatusCode.BadRequest, noNote.StatusCode);

        var approved = await admin.PostAsJsonAsync($"/api/admin/deletion-requests/{request.Id}/review", new ReviewDeletionRequest("approve", null));
        approved.EnsureSuccessStatusCode();
        Assert.Equal("approved", (await approved.Content.ReadFromJsonAsync<DeletionRequestDto>())!.Status);

        var again = await admin.PostAsJsonAsync($"/api/admin/deletion-requests/{request.Id}/review", new ReviewDeletionRequest("approve", null));
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);

        // The old token stops working at once (new SecurityStamp), and login is disabled.
        Assert.Equal(HttpStatusCode.Forbidden, (await patient.GetAsync("/api/patient/home")).StatusCode);
        var state = await api.WithDbAsync(async db => (
            await db.Users.Where(u => u.Id == otherUserId).Select(u => u.Status).SingleAsync(),
            await db.Patients.Where(p => p.Id == api.Demo.OtherPatientId).Select(p => p.Status).SingleAsync(),
            await db.AuditLogs.AnyAsync(a => a.Action == "deletionRequest.approved" && a.TargetId == request.Id.ToString())));
        Assert.Equal(("disabled", "deleted", true), state);

        // Medical records are kept (retention is open question Q16).
        Assert.True(await api.WithDbAsync(db => db.Sessions.AnyAsync(s => s.PatientId == api.Demo.OtherPatientId)));

        // AD11 can't turn a deleted patient back on.
        var enable = await admin.PostAsJsonAsync($"/api/admin/accounts/{otherUserId}/status", new SetLoginStatusRequest("active", null));
        Assert.Equal(HttpStatusCode.Conflict, enable.StatusCode);
    }

    [Fact]
    public async Task Accounts_support_finds_by_phone_and_toggles_login()
    {
        var admin = await api.ClientForAsync(api.Demo.AdminUserId);

        var patient = await admin.GetFromJsonAsync<AccountSearchResultDto>("/api/admin/accounts?phone=010%2000000002");
        var found = Assert.Single(patient!.Patients);
        Assert.Equal("+201000000002", patient.Phone);
        Assert.Equal(2, found.Doctors.Count);
        Assert.Empty(patient.Assistants);

        var assistant = await admin.GetFromJsonAsync<AccountSearchResultDto>("/api/admin/accounts?phone=%2B201000000001");
        Assert.Equal(api.Demo.AssistantUserId, Assert.Single(assistant!.Assistants).UserId);

        Assert.Equal(HttpStatusCode.BadRequest, (await admin.GetAsync("/api/admin/accounts?phone=123")).StatusCode);

        // Disabling signs the assistant out at once; enabling lets a new token in again.
        var assistantClient = await api.ClientForAsync(api.Demo.AssistantUserId);
        Assert.Equal(HttpStatusCode.NoContent,
            (await admin.PostAsJsonAsync($"/api/admin/accounts/{api.Demo.AssistantUserId}/status", new SetLoginStatusRequest("disabled", "support ticket"))).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await assistantClient.GetAsync("/api/me/preferences")).StatusCode);

        Assert.Equal(HttpStatusCode.NoContent,
            (await admin.PostAsJsonAsync($"/api/admin/accounts/{api.Demo.AssistantUserId}/status", new SetLoginStatusRequest("active", null))).StatusCode);
        var fresh = await api.ClientForAsync(api.Demo.AssistantUserId);
        Assert.Equal(HttpStatusCode.OK, (await fresh.GetAsync("/api/me/preferences")).StatusCode);

        // Doctors and admins are managed elsewhere (AD5, AD14).
        var doctor = await admin.PostAsJsonAsync($"/api/admin/accounts/{api.Demo.DoctorAUserId}/status", new SetLoginStatusRequest("disabled", null));
        Assert.Equal(HttpStatusCode.BadRequest, doctor.StatusCode);
    }
}
