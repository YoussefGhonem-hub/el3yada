using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using El3yada.Api.Features.Chat;
using El3yada.Api.Features.Notifications;
using El3yada.Api.Infrastructure.Paging;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests;

/// <summary>Phase 5 chat (spec 6.8) and AC-13 on the API side.</summary>
public sealed class ChatTests(FeaturesApiFactory api) : IClassFixture<FeaturesApiFactory>
{
    private async Task<ChatSummaryDto> PatientChatWithAsync(HttpClient patient, Guid doctorId)
    {
        var chats = await patient.GetFromJsonAsync<List<ChatSummaryDto>>("/api/patient/chats");
        return chats!.Single(c => c.DoctorId == doctorId);
    }

    [Fact]
    public async Task Patient_has_one_chat_per_doctor_created_on_demand()
    {
        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        var chats = await patient.GetFromJsonAsync<List<ChatSummaryDto>>("/api/patient/chats");

        Assert.Equal(2, chats!.Count);                                   // doctor B's chat was created (BR-C1)
        Assert.All(chats, c => Assert.True(c.CanSend));
        Assert.Null(chats.Single(c => c.DoctorId == api.Demo.DoctorAUserId).FileNumber);   // staff-only field

        // Asking again doesn't create duplicates.
        Assert.Equal(2, (await patient.GetFromJsonAsync<List<ChatSummaryDto>>("/api/patient/chats"))!.Count);
    }

    [Fact]
    public async Task Messages_flow_both_ways_with_unread_counts_and_read_ticks()
    {
        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        var doctor = await api.ClientForAsync(api.Demo.DoctorAUserId);
        var chat = await PatientChatWithAsync(patient, api.Demo.DoctorAUserId);

        var sent = await patient.PostAsJsonAsync($"/api/patient/chats/{chat.Id}/messages", new SendTextRequest("  عندي سؤال عن الجرعة  "));
        sent.EnsureSuccessStatusCode();
        var message = await sent.Content.ReadFromJsonAsync<ChatMessageDto>();
        Assert.Equal("عندي سؤال عن الجرعة", message!.Text);
        Assert.Equal("patient", message.SenderRole);

        // The doctor sees it unread, in the inbox and in the thread.
        var inbox = await doctor.GetFromJsonAsync<List<ChatSummaryDto>>("/api/staff/chats");
        var row = inbox!.Single(c => c.Id == chat.Id);
        Assert.True(row.UnreadCount >= 1);
        Assert.Equal("عندي سؤال عن الجرعة", row.LastMessage!.Text);
        Assert.True(await api.WithDbAsync(db => db.Notifications.AnyAsync(n => n.RecipientUserId == api.Demo.DoctorAUserId && n.Type == "chatMessage")));

        Assert.Equal(HttpStatusCode.NoContent, (await doctor.PostAsync($"/api/staff/chats/{chat.Id}/read", null)).StatusCode);
        var thread = await patient.GetFromJsonAsync<ChatThreadDto>($"/api/patient/chats/{chat.Id}");
        Assert.NotNull(thread!.Messages.First(m => m.Id == message.Id).ReadAt);   // read tick (BR-C3)
        Assert.Equal(0, (await doctor.GetFromJsonAsync<List<ChatSummaryDto>>("/api/staff/chats"))!.Single(c => c.Id == chat.Id).UnreadCount);

        // The doctor replies; now the patient has an unread message.
        (await doctor.PostAsJsonAsync($"/api/staff/chats/{chat.Id}/messages", new SendTextRequest("خذ قرصاً بعد الأكل"))).EnsureSuccessStatusCode();
        var patientInbox = await patient.GetFromJsonAsync<List<ChatSummaryDto>>("/api/patient/chats");
        Assert.Equal(1, patientInbox!.Single(c => c.Id == chat.Id).UnreadCount);
        var unread = await patient.GetFromJsonAsync<Dictionary<string, int>>("/api/patient/chats/unread-count");
        Assert.Equal(1, unread!["count"]);
    }

    [Fact]
    public async Task Thread_pages_backwards()
    {
        var doctor = await api.ClientForAsync(api.Demo.DoctorAUserId);
        var open = await (await doctor.PostAsync($"/api/staff/chats/by-patient/{api.Demo.PatientId}", null)).Content.ReadFromJsonAsync<ChatSummaryDto>();
        for (var i = 0; i < 5; i++)
            (await doctor.PostAsJsonAsync($"/api/staff/chats/{open!.Id}/messages", new SendTextRequest($"msg {i}"))).EnsureSuccessStatusCode();

        var first = await doctor.GetFromJsonAsync<ChatThreadDto>($"/api/staff/chats/{open!.Id}?limit=3");
        Assert.True(first!.HasMore);
        Assert.Equal(3, first.Messages.Count);
        var older = await doctor.GetFromJsonAsync<ChatThreadDto>($"/api/staff/chats/{open.Id}?limit=3&before={first.Messages[^1].Id}");
        Assert.DoesNotContain(older!.Messages, m => first.Messages.Any(f => f.Id == m.Id));
        Assert.True(older.Messages[0].CreatedAt <= first.Messages[^1].CreatedAt);
    }

    [Fact]
    public async Task Attachment_can_be_downloaded_and_saved_to_the_patient_file()
    {
        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        var doctor = await api.ClientForAsync(api.Demo.DoctorAUserId);
        var chat = await PatientChatWithAsync(patient, api.Demo.DoctorAUserId);

        using var form = new MultipartFormDataContent();
        var png = TestImages.Encode(2, 2, SkiaSharp.SKEncodedImageFormat.Png);
        var bytes = new ByteArrayContent(png);
        bytes.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(bytes, "file", "../../lab result.png");
        var upload = await patient.PostAsync($"/api/patient/chats/{chat.Id}/attachments", form);
        upload.EnsureSuccessStatusCode();
        var message = await upload.Content.ReadFromJsonAsync<ChatMessageDto>();
        Assert.Equal("image", message!.Type);
        Assert.Equal("lab result.png", message.Attachment!.FileName);   // path parts are stripped

        var download = await doctor.GetAsync($"/api/staff/chats/{chat.Id}/messages/{message.Id}/attachment");
        download.EnsureSuccessStatusCode();
        Assert.Equal(png.Length, (await download.Content.ReadAsByteArrayAsync()).Length);

        var saved = await doctor.PostAsJsonAsync($"/api/staff/chats/{chat.Id}/messages/{message.Id}/save-to-file",
            new SaveToFileRequest("lab", null, null, "CBC from chat", null, null));
        saved.EnsureSuccessStatusCode();
        var recordId = (await saved.Content.ReadFromJsonAsync<Dictionary<string, Guid>>())!["recordId"];

        // The patient sees it in P8 with a notification (BR-F9).
        var records = await patient.GetFromJsonAsync<PagedResult<El3yada.Api.Features.PatientPortal.RecordListItemDto>>("/api/patient/records?kind=lab");
        Assert.Contains(records!.Items, r => r.Id == recordId && r.Title == "CBC from chat");
        Assert.True(await api.WithDbAsync(db => db.MedicalRecords.AnyAsync(r => r.Id == recordId && r.Source == "chat" && r.SourceChatMessageId == message.Id)));

        // Saving twice returns the same record.
        var again = await doctor.PostAsJsonAsync($"/api/staff/chats/{chat.Id}/messages/{message.Id}/save-to-file",
            new SaveToFileRequest("lab", null, null, null, null, null));
        Assert.Equal(recordId, (await again.Content.ReadFromJsonAsync<Dictionary<string, Guid>>())!["recordId"]);
    }

    [Fact]
    public async Task Access_rules()
    {
        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        var chatA = await PatientChatWithAsync(patient, api.Demo.DoctorAUserId);

        // The reception assistant has no `chat` permission; the admin never reads chats (AC-12).
        var assistant = await api.ClientForAsync(api.Demo.AssistantUserId);
        var denied = await assistant.GetAsync("/api/staff/chats");
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
        Assert.Contains("PERMISSION_DENIED", await denied.Content.ReadAsStringAsync());
        var admin = await api.ClientForAsync(api.Demo.AdminUserId);
        Assert.Equal(HttpStatusCode.Forbidden, (await admin.GetAsync("/api/staff/chats")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await admin.GetAsync("/api/patient/chats")).StatusCode);

        // Doctor B can't reach doctor A's conversation.
        var doctorB = await api.ClientForAsync(api.Demo.DoctorBUserId);
        Assert.Equal(HttpStatusCode.NotFound, (await doctorB.GetAsync($"/api/staff/chats/{chatA.Id}")).StatusCode);

        // Empty and over-long messages are refused.
        Assert.Equal(HttpStatusCode.BadRequest, (await patient.PostAsJsonAsync($"/api/patient/chats/{chatA.Id}/messages", new SendTextRequest("   "))).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await patient.PostAsJsonAsync($"/api/patient/chats/{chatA.Id}/messages", new SendTextRequest(new string('x', 2001)))).StatusCode);
    }

    [Fact]
    public async Task Suspended_doctor_blocks_sending_on_both_sides()
    {
        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        var chatB = await PatientChatWithAsync(patient, api.Demo.DoctorBUserId);
        await api.WithDbAsync(db => db.Doctors.Where(d => d.UserId == api.Demo.DoctorBUserId).ExecuteUpdateAsync(u => u.SetProperty(d => d.Status, "suspended")));
        try
        {
            var fromPatient = await patient.PostAsJsonAsync($"/api/patient/chats/{chatB.Id}/messages", new SendTextRequest("hello"));
            Assert.Equal(HttpStatusCode.Forbidden, fromPatient.StatusCode);
            Assert.Contains("CHAT_UNAVAILABLE", await fromPatient.Content.ReadAsStringAsync());

            var doctorB = await api.ClientForAsync(api.Demo.DoctorBUserId);
            var fromDoctor = await doctorB.PostAsJsonAsync($"/api/staff/chats/{chatB.Id}/messages", new SendTextRequest("hello"));
            Assert.Contains("DOCTOR_SUSPENDED", await fromDoctor.Content.ReadAsStringAsync());

            // Reading still works (D7: read-only).
            Assert.Equal(HttpStatusCode.OK, (await doctorB.GetAsync($"/api/staff/chats/{chatB.Id}")).StatusCode);
            var summary = (await patient.GetFromJsonAsync<List<ChatSummaryDto>>("/api/patient/chats"))!.Single(c => c.Id == chatB.Id);
            Assert.False(summary.CanSend);
        }
        finally
        {
            await api.WithDbAsync(db => db.Doctors.Where(d => d.UserId == api.Demo.DoctorBUserId).ExecuteUpdateAsync(u => u.SetProperty(d => d.Status, "active")));
        }
    }

    [Fact]
    public async Task Doctor_can_switch_chat_off_for_a_patient()
    {
        var doctorB = await api.ClientForAsync(api.Demo.DoctorBUserId);
        var open = await (await doctorB.PostAsync($"/api/staff/chats/by-patient/{api.Demo.PatientId}", null)).Content.ReadFromJsonAsync<ChatSummaryDto>();
        var off = await doctorB.PatchAsJsonAsync($"/api/staff/chats/{open!.Id}", new SetChatEnabledRequest(false));
        Assert.False((await off.Content.ReadFromJsonAsync<ChatSummaryDto>())!.Enabled);

        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        var refused = await patient.PostAsJsonAsync($"/api/patient/chats/{open.Id}/messages", new SendTextRequest("hi"));
        Assert.Contains("CHAT_UNAVAILABLE", await refused.Content.ReadAsStringAsync());

        await doctorB.PatchAsJsonAsync($"/api/staff/chats/{open.Id}", new SetChatEnabledRequest(true));
    }
}

/// <summary>Notification centre, devices and push delivery (spec 9.2, 10).</summary>
public sealed class NotificationTests(FeaturesApiFactory api) : IClassFixture<FeaturesApiFactory>
{
    [Fact]
    public async Task Chat_push_arrives_in_the_recipients_language_without_text_unless_previews_are_on()
    {
        var doctor = await api.ClientForAsync(api.Demo.DoctorAUserId);
        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        (await doctor.PutAsJsonAsync("/api/me/devices", new RegisterDeviceRequest("doc-phone", "android", "token-doc", "1.0.0"))).EnsureSuccessStatusCode();
        (await doctor.PutAsJsonAsync("/api/me/devices", new RegisterDeviceRequest("doc-pc", "windows", "token-windows", "1.0.0"))).EnsureSuccessStatusCode();

        var chats = await patient.GetFromJsonAsync<List<ChatSummaryDto>>("/api/patient/chats");
        var chatId = chats!.Single(c => c.DoctorId == api.Demo.DoctorAUserId).Id;

        api.Push.Sent.Clear();
        (await patient.PostAsJsonAsync($"/api/patient/chats/{chatId}/messages", new SendTextRequest("سر طبي خاص"))).EnsureSuccessStatusCode();
        var push = await FeaturesApiFactory.EventuallyAsync(() => api.Push.Sent.FirstOrDefault(p => p.Tokens.Contains("token-doc")) is { Message: not null } p ? p.Message : null);

        Assert.StartsWith("رسالة جديدة من", push.Title);          // the doctor's language is Arabic
        Assert.DoesNotContain("سر طبي", push.Body);                // previews are off by default (spec 10.1)
        Assert.Equal("chatMessage", push.Data["type"]);
        Assert.DoesNotContain(api.Push.Sent, p => p.Tokens.Contains("token-windows"));   // no FCM on Windows (10.2)

        // Previews on: the text is shown.
        (await doctor.PatchAsJsonAsync("/api/me/preferences", new { notifyShowPreview = true })).EnsureSuccessStatusCode();
        api.Push.Sent.Clear();
        (await patient.PostAsJsonAsync($"/api/patient/chats/{chatId}/messages", new SendTextRequest("نص ظاهر"))).EnsureSuccessStatusCode();
        var withPreview = await FeaturesApiFactory.EventuallyAsync(() => api.Push.Sent.FirstOrDefault().Message);
        Assert.Equal("نص ظاهر", withPreview.Body);

        // Chat notifications off: nothing is pushed.
        (await doctor.PatchAsJsonAsync("/api/me/preferences", new { notifyChat = false, notifyShowPreview = false })).EnsureSuccessStatusCode();
        api.Push.Sent.Clear();
        (await patient.PostAsJsonAsync($"/api/patient/chats/{chatId}/messages", new SendTextRequest("again"))).EnsureSuccessStatusCode();
        await Task.Delay(500);
        Assert.Empty(api.Push.Sent);
        (await doctor.PatchAsJsonAsync("/api/me/preferences", new { notifyChat = true })).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Invalid_tokens_are_removed_and_tokens_move_between_accounts()
    {
        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        var doctorB = await api.ClientForAsync(api.Demo.DoctorBUserId);

        // The same phone signs in as another account: the token follows the new account only.
        (await doctorB.PutAsJsonAsync("/api/me/devices", new RegisterDeviceRequest("shared", "android", "token-shared", "1.0.0"))).EnsureSuccessStatusCode();
        (await patient.PutAsJsonAsync("/api/me/devices", new RegisterDeviceRequest("shared", "android", "token-shared", "1.0.0"))).EnsureSuccessStatusCode();
        var owners = await api.WithDbAsync(db => db.UserDevices.Where(d => d.FcmToken == "token-shared").Select(d => d.UserId).ToListAsync());
        Assert.Equal([api.Demo.PatientUserId], owners);

        // FCM says the token is dead: it is cleared.
        api.Push.Invalid.Add("token-shared");
        var chats = await patient.GetFromJsonAsync<List<ChatSummaryDto>>("/api/patient/chats");
        var chatB = chats!.Single(c => c.DoctorId == api.Demo.DoctorBUserId).Id;
        (await doctorB.PostAsJsonAsync($"/api/staff/chats/{chatB}/messages", new SendTextRequest("hello"))).EnsureSuccessStatusCode();
        await FeaturesApiFactory.EventuallyAsync(() => api.WithDbAsync(db => db.UserDevices.AnyAsync(d => d.DeviceId == "shared" && d.UserId == api.Demo.PatientUserId && d.FcmToken == null)).Result ? "ok" : null);

        // Logout removes the device.
        Assert.Equal(HttpStatusCode.NoContent, (await patient.DeleteAsync("/api/me/devices/shared")).StatusCode);
        Assert.False(await api.WithDbAsync(db => db.UserDevices.AnyAsync(d => d.DeviceId == "shared" && d.UserId == api.Demo.PatientUserId)));
    }

    [Fact]
    public async Task Notification_centre_lists_and_marks_read()
    {
        var admin = await api.ClientForAsync(api.Demo.AdminUserId);
        // An AD17 notice, as a doctor's account deletion writes it (Integration/AccountDeletionTests sends the real one).
        await api.WithDbAsync(async db =>
        {
            db.Notifications.Add(new El3yada.Data.Entities.Notification
            {
                Id = Guid.NewGuid(), RecipientUserId = api.Demo.AdminUserId, Type = "deletionRequest",
                TitleAr = "طبيب طلب حذف حسابه", TitleEn = "A doctor asked to delete their account", BodyAr = "د. تجربة", BodyEn = "Dr Test",
                Route = "/admin/account-deletions", CreatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync();
            return 0;
        });

        var page = await admin.GetFromJsonAsync<NotificationPage>("/api/me/notifications");
        var item = Assert.Single(page!.Page.Items, n => n.Type == "deletionRequest");
        Assert.True(page.UnreadCount >= 1);
        Assert.Equal("/admin/account-deletions", item.Route);

        (await admin.PostAsync($"/api/me/notifications/{item.Id}/read", null)).EnsureSuccessStatusCode();
        (await admin.PostAsync("/api/me/notifications/read-all", null)).EnsureSuccessStatusCode();
        var count = await admin.GetFromJsonAsync<Dictionary<string, int>>("/api/me/notifications/unread-count");
        Assert.Equal(0, count!["count"]);

        // Nobody reads someone else's notifications: marking another user's id does nothing.
        var doctor = await api.ClientForAsync(api.Demo.DoctorAUserId);
        Assert.Equal(HttpStatusCode.NoContent, (await doctor.PostAsync($"/api/me/notifications/{item.Id}/read", null)).StatusCode);
    }

    [Fact]
    public async Task Realtime_token_reports_disabled_without_firebase()
    {
        var doctor = await api.ClientForAsync(api.Demo.DoctorAUserId);
        var token = await (await doctor.PostAsync("/api/me/realtime-token", null)).Content.ReadFromJsonAsync<RealtimeTokenDto>();
        Assert.False(token!.Enabled);
    }
}
