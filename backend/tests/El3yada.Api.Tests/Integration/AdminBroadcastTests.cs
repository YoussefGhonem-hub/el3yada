using System.Net;
using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary>AD16 broadcast: <c>POST /api/admin/sendBroadcast</c> and <c>GET /api/admin/broadcasts</c>.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class AdminBroadcastTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static object Message(string audience = "all", IEnumerable<Guid>? doctorIds = null) => new
    {
        audience,
        doctorIds,
        titleAr = "تحديث جديد",
        bodyAr = "أضفنا الحجز من التطبيق.",
        titleEn = "New update",
        bodyEn = "Booking from the app is here.",
    };

    private static Task<List<Notification>> BroadcastsOfAsync(IntegrationFactory factory, Guid userId) =>
        TestData.WithDbAsync(factory, db => db.Notifications.Where(n => n.RecipientUserId == userId && n.Type == "broadcast").ToListAsync());

    [Fact]
    public async Task To_all_reaches_every_doctor_who_can_use_the_app_in_both_languages()
    {
        var active = await TestData.CreateDoctorAsync(Factory);
        var suspended = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.Suspended);
        var pending = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.PendingApproval);
        var disabledDoctor = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.Disabled);
        var disabledUser = await TestData.CreateDoctorAsync(Factory, userStatus: AccountStatuses.Disabled);
        var assistant = await TestData.CreateAssistantAsync(Factory, active.Id);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var eligible = await TestData.WithDbAsync(Factory, db => db.Doctors.CountAsync(d =>
            (d.Status == DoctorStatuses.Active || d.Status == DoctorStatuses.Suspended) && d.User.Status == AccountStatuses.Active));

        var (status, body) = await asAdmin.PostAsync("/api/admin/sendBroadcast", Message());

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal(eligible, body.GetProperty("recipients").GetInt32());
        Assert.Equal("all", body.Str("audience"));
        Assert.Equal("Test Admin", body.GetProperty("sentBy").Str("displayName"));
        var broadcastId = body.Str("broadcastId");

        foreach (var doctor in new[] { active, suspended })
        {
            var row = Assert.Single(await BroadcastsOfAsync(Factory, doctor.Id));
            Assert.Equal("تحديث جديد", row.TitleAr);
            Assert.Equal("أضفنا الحجز من التطبيق.", row.BodyAr);
            Assert.Equal("New update", row.TitleEn);
            Assert.Equal("Booking from the app is here.", row.BodyEn);
            Assert.Contains(broadcastId, row.DataJson);
        }

        foreach (var user in new[] { pending.Id, disabledDoctor.Id, disabledUser.Id, assistant.Id, patient.Id, admin.Id })
        {
            Assert.Empty(await BroadcastsOfAsync(Factory, user));
        }

        // One audit row, by the admin, with what was sent.
        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == AuditActions.BroadcastSent && a.TargetId == broadcastId));
        Assert.Equal(admin.Id, audit.ActorUserId);
        Assert.Equal("broadcast", audit.TargetType);
        using var details = JsonDocument.Parse(audit.DetailsJson!);
        Assert.Equal(eligible, details.RootElement.GetProperty("recipients").GetInt32());
        Assert.Equal("New update", details.RootElement.Str("titleEn"));
    }

    [Fact]
    public async Task To_chosen_doctors_reaches_only_them_and_skips_those_who_cant_use_the_app()
    {
        var first = await TestData.CreateDoctorAsync(Factory);
        var second = await TestData.CreateDoctorAsync(Factory);
        var other = await TestData.CreateDoctorAsync(Factory);
        var rejected = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.Rejected, reason: "صورة غير واضحة");
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.SuperAdmin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var (status, body) = await asAdmin.PostAsync("/api/admin/sendBroadcast", Message("selected", [first.Id, second.Id, rejected.Id]));

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal(2, body.GetProperty("recipients").GetInt32());
        Assert.Equal("selected", body.Str("audience"));
        Assert.Single(await BroadcastsOfAsync(Factory, first.Id));
        Assert.Single(await BroadcastsOfAsync(Factory, second.Id));
        Assert.Empty(await BroadcastsOfAsync(Factory, other.Id));
        Assert.Empty(await BroadcastsOfAsync(Factory, rejected.Id));

        // Someone who isn't a doctor, or nobody left to send to.
        var (unknownStatus, unknown) = await asAdmin.PostAsync("/api/admin/sendBroadcast", Message("selected", [first.Id, admin.Id]));
        Assert.Equal(HttpStatusCode.BadRequest, unknownStatus);
        Assert.Equal(ErrorCodes.InvalidValue, unknown.FieldCode("doctorIds"));
        var (nobodyStatus, nobody) = await asAdmin.PostAsync("/api/admin/sendBroadcast", Message("selected", [rejected.Id]));
        Assert.Equal(HttpStatusCode.Conflict, nobodyStatus);
        Assert.Equal(ErrorCodes.BroadcastNoRecipients, nobody.Code());
        Assert.Single(await BroadcastsOfAsync(Factory, first.Id));
    }

    [Fact]
    public async Task One_language_is_enough_and_fills_the_other_and_half_a_language_is_refused()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var (arabicOnly, _) = await asAdmin.PostAsync("/api/admin/sendBroadcast",
            new { audience = "selected", doctorIds = new[] { doctor.Id }, titleAr = " صيانة الليلة ", bodyAr = "من 2 إلى 3 صباحاً." });
        Assert.Equal(HttpStatusCode.Created, arabicOnly);
        var row = Assert.Single(await BroadcastsOfAsync(Factory, doctor.Id));
        Assert.Equal("صيانة الليلة", row.TitleAr);
        Assert.Equal("صيانة الليلة", row.TitleEn);
        Assert.Equal("من 2 إلى 3 صباحاً.", row.BodyEn);

        var (emptyStatus, empty) = await asAdmin.PostAsync("/api/admin/sendBroadcast", new { audience = "all" });
        Assert.Equal(HttpStatusCode.BadRequest, emptyStatus);
        Assert.Equal(ErrorCodes.Required, empty.FieldCode("titleAr"));

        var (halfStatus, half) = await asAdmin.PostAsync("/api/admin/sendBroadcast", new { audience = "all", titleAr = "عنوان", titleEn = "Title", bodyEn = "Text" });
        Assert.Equal(HttpStatusCode.BadRequest, halfStatus);
        Assert.Equal(ErrorCodes.Required, half.FieldCode("bodyAr"));

        var (longStatus, tooLong) = await asAdmin.PostAsync("/api/admin/sendBroadcast", new { audience = "all", titleEn = new string('x', 101), bodyEn = "Text" });
        Assert.Equal(HttpStatusCode.BadRequest, longStatus);
        Assert.Equal(ErrorCodes.TooLong, tooLong.FieldCode("titleEn"));

        var (noDoctors, noDoctorsBody) = await asAdmin.PostAsync("/api/admin/sendBroadcast", new { audience = "selected", titleEn = "Title", bodyEn = "Text" });
        Assert.Equal(HttpStatusCode.BadRequest, noDoctors);
        Assert.Equal(ErrorCodes.Required, noDoctorsBody.FieldCode("doctorIds"));
        Assert.Single(await BroadcastsOfAsync(Factory, doctor.Id));
    }

    [Fact]
    public async Task Only_admins_send_and_read_the_history()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        foreach (var user in new[] { doctor, assistant, patient })
        {
            using var client = await Factory.SignedInClientAsync(user);
            var (sendStatus, _) = await client.PostAsync("/api/admin/sendBroadcast", Message());
            var (historyStatus, _) = await client.GetJsonAsync("/api/admin/broadcasts");
            Assert.Equal(HttpStatusCode.Forbidden, sendStatus);
            Assert.Equal(HttpStatusCode.Forbidden, historyStatus);
        }

        var (anonymous, _) = await Factory.Client().PostAsync("/api/admin/sendBroadcast", Message());
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous);
        Assert.Empty(await BroadcastsOfAsync(Factory, doctor.Id));
    }

    [Fact]
    public async Task The_history_lists_what_was_sent_newest_first()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        await asAdmin.PostAsync("/api/admin/sendBroadcast", new { audience = "selected", doctorIds = new[] { doctor.Id }, titleEn = "Older", bodyEn = "First" });
        var (_, latest) = await asAdmin.PostAsync("/api/admin/sendBroadcast", new { audience = "selected", doctorIds = new[] { doctor.Id }, titleEn = "Newer", bodyEn = "Second" });

        var (status, page) = await asAdmin.GetJsonAsync("/api/admin/broadcasts?pageSize=2");

        Assert.Equal(HttpStatusCode.OK, status);
        var items = page.GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(2, items.Count);
        Assert.Equal(latest.Str("broadcastId"), items[0].Str("broadcastId"));
        Assert.Equal("Newer", items[0].Str("titleEn"));
        Assert.Equal("Newer", items[0].Str("titleAr"));
        Assert.Equal("selected", items[0].Str("audience"));
        Assert.Equal(1, items[0].GetProperty("recipients").GetInt32());
        Assert.Equal("Test Admin", items[0].GetProperty("sentBy").Str("displayName"));
        Assert.Equal("Older", items[1].Str("titleEn"));
        Assert.True(page.GetProperty("totalCount").GetInt32() >= 2);
    }

    [Fact]
    public async Task The_push_goes_out_in_each_doctors_language()
    {
        // The same API and database, with pushes captured instead of sent.
        var push = new FakePushSender();
        await using var factory = Factory.WithWebHostBuilder(builder =>
            builder.ConfigureServices(services => services.AddSingleton<IPushSender>(push)));
        var arabic = await TestData.CreateDoctorAsync(Factory);
        var english = await TestData.CreateDoctorAsync(Factory);
        await TestData.WithDbAsync(Factory, async db =>
        {
            await db.Users.Where(u => u.Id == english.Id).ExecuteUpdateAsync(set => set.SetProperty(u => u.Locale, "en"));
            db.UserDevices.AddRange(
                new UserDevice { Id = Guid.NewGuid(), UserId = arabic.Id, DeviceId = "ar-phone", Platform = "android", FcmToken = "token-ar", AppVersion = "1.0.0", UpdatedAt = DateTime.UtcNow },
                new UserDevice { Id = Guid.NewGuid(), UserId = english.Id, DeviceId = "en-phone", Platform = "ios", FcmToken = "token-en", AppVersion = "1.0.0", UpdatedAt = DateTime.UtcNow });
            await db.SaveChangesAsync();
        });
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        var (_, session) = await factory.CreateClient().PostAsync("/api/auth/login", new { identifier = admin.Identifier, password = admin.Password });
        using var asAdmin = factory.CreateClient();
        asAdmin.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", session.Str("accessToken"));

        var (status, _) = await asAdmin.PostAsync("/api/admin/sendBroadcast", Message("selected", [arabic.Id, english.Id]));

        Assert.Equal(HttpStatusCode.Created, status);
        var toArabic = await FeaturesApiFactory.EventuallyAsync(() => push.Sent.FirstOrDefault(p => p.Tokens.Contains("token-ar")) is { Message: not null } p ? p.Message : null);
        var toEnglish = await FeaturesApiFactory.EventuallyAsync(() => push.Sent.FirstOrDefault(p => p.Tokens.Contains("token-en")) is { Message: not null } p ? p.Message : null);
        Assert.Equal("تحديث جديد", toArabic.Title);
        Assert.Equal("أضفنا الحجز من التطبيق.", toArabic.Body);
        Assert.Equal("New update", toEnglish.Title);
        Assert.Equal("Booking from the app is here.", toEnglish.Body);
        Assert.Equal("broadcast", toEnglish.Data["type"]);
    }
}
