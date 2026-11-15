using System.Net;
using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Notifications;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>D22 profile and D24 / AS12 notification preferences.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class DoctorProfileTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static object Profile(Guid specialtyId, IEnumerable<Guid>? extras = null, string fullName = "أحمد علي") => new
    {
        fullName, fullNameEn = "Ahmed Ali", title = "استشاري", titleEn = "Consultant", degreesAr = "دكتوراه الباطنة", degreesEn = (string?)null,
        specialtyId, extraSpecialtyIds = extras ?? [],
    };

    [Fact]
    public async Task The_doctor_reads_their_profile_with_the_read_only_fields()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.GetJsonAsync("/api/doctor/profile");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("أحمد علي", body.Str("fullName"));
        Assert.Equal(doctor.Identifier, body.Str("email"));
        Assert.Equal(doctor.Phone, body.Str("phone"));
        Assert.Equal("12345", body.Str("licenseNumber"));
        Assert.Equal("active", body.Str("status"));
        Assert.Equal(await TestData.AnySpecialtyAsync(Factory), body.GetProperty("specialty").GetProperty("id").GetGuid());
        Assert.Equal(body.GetProperty("specialty").Str("id"), body.Str("specialtyId"));
        Assert.Empty(body.GetProperty("extraSpecialtyIds").EnumerateArray());
    }

    [Fact]
    public async Task Updating_the_name_keeps_the_display_name_in_sync_without_notifying_admins()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var specialty = await TestData.AnySpecialtyAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/doctor/updateProfile", Profile(specialty, fullName: "  أحمد   علي حسن "));

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("أحمد علي حسن", body.Str("fullName"));
        Assert.Equal("Consultant", body.Str("titleEn"));
        Assert.Equal(JsonValueKind.Null, body.GetProperty("degreesEn").ValueKind);
        var (_, me) = await client.GetJsonAsync("/api/auth/me");
        Assert.Equal("أحمد علي حسن", me.Str("displayName"));
        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.DoctorProfileUpdated));
        Assert.Contains("fullName", audit.DetailsJson);
        Assert.Empty(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.DoctorSpecialtyChanged));
    }

    [Fact]
    public async Task A_specialty_change_applies_at_once_is_audited_and_notifies_every_active_admin()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var disabledAdmin = await TestData.CreateAdminAsync(Factory, status: "disabled");
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var newSpecialty = await TestData.AnySpecialtyAsync(Factory, skip: 1);
        var extra = await TestData.AnySpecialtyAsync(Factory, skip: 2);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/doctor/updateProfile", Profile(newSpecialty, [extra]));

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(newSpecialty.ToString(), body.Str("specialtyId"));
        Assert.Equal([extra.ToString()], body.GetProperty("extraSpecialtyIds").EnumerateArray().Select(e => e.GetString()));
        var (_, clinic) = await client.GetJsonAsync("/api/clinic/me");
        Assert.Equal(newSpecialty.ToString(), clinic.GetProperty("doctor").Str("specialtyId"));
        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.DoctorSpecialtyChanged));
        Assert.Contains(newSpecialty.ToString(), audit.DetailsJson);
        var notified = await TestData.WithDbAsync(Factory, db => db.Notifications
            .Where(n => n.Type == NotificationTexts.DoctorSpecialtyChanged && n.DataJson!.Contains(doctor.Id.ToString()))
            .Select(n => n.RecipientUserId).ToListAsync());
        Assert.Contains(admin.Id, notified);
        Assert.DoesNotContain(disabledAdmin.Id, notified);
    }

    [Fact]
    public async Task The_profile_is_checked()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var specialty = await TestData.AnySpecialtyAsync(Factory);
        var others = new[] { await TestData.AnySpecialtyAsync(Factory, 1), await TestData.AnySpecialtyAsync(Factory, 2), await TestData.AnySpecialtyAsync(Factory, 3) };
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/doctor/updateProfile", new { fullName = "أحمد", title = "", specialtyId = specialty, extraSpecialtyIds = others });
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidName, body.FieldCode("fullName"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("title"));
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("extraSpecialtyIds"));

        (status, body) = await client.PostAsync("/api/doctor/updateProfile", Profile(Guid.NewGuid()));
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidSpecialty, body.FieldCode("specialtyId"));

        (status, body) = await client.PostAsync("/api/doctor/updateProfile", Profile(specialty, [specialty]));
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("extraSpecialtyIds"));
    }

    [Fact]
    public async Task A_suspended_doctor_can_still_edit_the_profile()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory, "suspended");
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, _) = await client.PostAsync("/api/doctor/updateProfile", Profile(await TestData.AnySpecialtyAsync(Factory)));

        Assert.Equal(HttpStatusCode.OK, status);
    }

    [Fact]
    public async Task Notification_preferences_are_personal_and_change_only_what_is_sent()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        using var doctorClient = await Factory.SignedInClientAsync(doctor);
        using var assistantClient = await Factory.SignedInClientAsync(assistant);

        var (status, defaults) = await assistantClient.GetJsonAsync("/api/me/notificationPrefs");
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.True(defaults.GetProperty("chat").GetBoolean());
        Assert.True(defaults.GetProperty("reminders").GetBoolean());
        Assert.False(defaults.GetProperty("showPreview").GetBoolean());
        Assert.False(defaults.GetProperty("bookings").GetBoolean());

        var (_, changed) = await assistantClient.PostAsync("/api/me/updateNotificationPrefs", new { chat = false, showPreview = true });
        Assert.False(changed.GetProperty("chat").GetBoolean());
        Assert.True(changed.GetProperty("showPreview").GetBoolean());
        Assert.True(changed.GetProperty("reminders").GetBoolean());

        var (_, doctorPrefs) = await doctorClient.GetJsonAsync("/api/me/notificationPrefs");
        Assert.True(doctorPrefs.GetProperty("chat").GetBoolean());
        (_, doctorPrefs) = await doctorClient.PostAsync("/api/me/updateNotificationPrefs", new { bookings = true });
        Assert.True(doctorPrefs.GetProperty("bookings").GetBoolean());
        var (_, reread) = await assistantClient.GetJsonAsync("/api/me/notificationPrefs");
        Assert.False(reread.GetProperty("chat").GetBoolean());
    }

    [Fact]
    public async Task Notification_preferences_need_a_signed_in_user()
    {
        var (status, body) = await Factory.Client().GetJsonAsync("/api/me/notificationPrefs");
        Assert.Equal(HttpStatusCode.Unauthorized, status);
        Assert.Equal(ErrorCodes.Unauthenticated, body.Code());

        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        using var client = await Factory.SignedInClientAsync(patient);
        (status, _) = await client.PostAsync("/api/me/updateNotificationPrefs", new { reminders = false });
        Assert.Equal(HttpStatusCode.OK, status);
    }
}
