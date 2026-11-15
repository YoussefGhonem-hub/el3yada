using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>AD13 updateSettings, SettingsHistory, the public settings endpoint (A1, A11–A13) and specialties (A4).</summary>
[Collection(IntegrationCollection.Name)]
public sealed class SettingsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task Out_of_range_values_are_refused_per_field_and_nothing_changes()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var client = await Factory.SignedInClientAsync(admin);
        var before = await TestData.WithDbAsync(Factory, db => db.AppSettings.AsNoTracking().SingleAsync());

        var (status, body) = await client.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?>
        {
            ["examFeePiasters"] = 1_000_001,
            ["consultationFeePiasters"] = -1,
            ["gracePeriodDays"] = 32,
            ["maxConsecutiveConsultations"] = 0,
            ["maxUploadMb"] = 201,
            ["maxBranchesPerDoctor"] = 0,
            ["minVersionAndroid"] = "1.2",
            ["supportEmail"] = "nope",
            ["supportPhone"] = "123",
            ["maintenanceEnabled"] = "yes",
            ["maintenanceMessageAr"] = new string('x', 501),
            ["colour"] = "red",
        });

        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("examFeePiasters"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("consultationFeePiasters"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("gracePeriodDays"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("maxConsecutiveConsultations"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("maxUploadMb"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("maxBranchesPerDoctor"));
        Assert.Equal(ErrorCodes.InvalidVersion, body.FieldCode("minVersionAndroid"));
        Assert.Equal(ErrorCodes.InvalidEmail, body.FieldCode("supportEmail"));
        Assert.Equal(ErrorCodes.InvalidPhone, body.FieldCode("supportPhone"));
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("maintenanceEnabled"));
        Assert.Equal(ErrorCodes.TooLong, body.FieldCode("maintenanceMessageAr"));
        Assert.Equal(ErrorCodes.UnknownSetting, body.FieldCode("colour"));
        var after = await TestData.WithDbAsync(Factory, db => db.AppSettings.AsNoTracking().SingleAsync());
        Assert.Equal(before.ExamFeePiasters, after.ExamFeePiasters);

        var (emptyStatus, empty) = await client.PostAsync("/api/admin/updateSettings", new { });
        Assert.Equal(HttpStatusCode.BadRequest, emptyStatus);
        Assert.Equal(ErrorCodes.Required, empty.FieldCode("body"));
    }

    [Fact]
    public async Task Each_changed_field_gets_a_history_row_and_one_audit_row()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var client = await Factory.SignedInClientAsync(admin);
        var start = await TestData.WithDbAsync(Factory, db => db.AppSettings.AsNoTracking().SingleAsync());
        var fee = start.ExamFeePiasters == 4000 ? 4500 : 4000;

        var (status, settings) = await client.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?>
        {
            ["examFeePiasters"] = fee,
            ["gracePeriodDays"] = start.GracePeriodDays, // unchanged: no history row
            ["supportWhatsapp"] = "010 1111 2222",
            ["instapayAccountName"] = "  El3yada Clinic  ",
        });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(fee, settings.GetProperty("examFeePiasters").GetInt32());
        Assert.Equal("+201011112222", settings.Str("supportWhatsapp"));
        Assert.Equal("El3yada Clinic", settings.Str("instapayAccountName"));
        Assert.Equal(admin.Id.ToString(), settings.GetProperty("updatedBy").Str("id"));

        var history = await TestData.WithDbAsync(Factory, db => db.SettingsHistories.Where(h => h.ChangedBy == admin.Id).ToListAsync());
        Assert.Equal(["examFeePiasters", "instapayAccountName", "supportWhatsapp"], history.Select(h => h.Field).Order());
        var feeRow = history.Single(h => h.Field == "examFeePiasters");
        Assert.Equal(start.ExamFeePiasters.ToString(), feeRow.BeforeValue);
        Assert.Equal(fee.ToString(), feeRow.AfterValue);
        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == "settingsUpdated" && a.ActorUserId == admin.Id));
        Assert.Contains("examFeePiasters", audit.DetailsJson);

        var (historyStatus, page) = await client.GetJsonAsync("/api/admin/settingsHistory?field=examFeePiasters&pageSize=5");
        Assert.Equal(HttpStatusCode.OK, historyStatus);
        var first = page.GetProperty("items")[0];
        Assert.Equal(fee.ToString(), first.Str("after"));
        Assert.Equal("Test Admin", first.Str("changedByName"));
        var (itemStatus, item) = await client.GetJsonAsync($"/api/admin/settingsHistory/{first.Str("id")}");
        Assert.Equal(HttpStatusCode.OK, itemStatus);
        Assert.Equal(start.ExamFeePiasters.ToString(), item.Str("before"));

        // Clearing an optional text with null.
        var (clearStatus, cleared) = await client.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?> { ["supportWhatsapp"] = null });
        Assert.Equal(HttpStatusCode.OK, clearStatus);
        Assert.Equal(JsonValueKind.Null, cleared.GetProperty("supportWhatsapp").ValueKind);
    }

    [Fact]
    public async Task The_public_settings_need_no_sign_in_and_follow_AD13()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var adminClient = await Factory.SignedInClientAsync(admin);
        using var anonymous = Factory.Client();
        var (_, before) = await anonymous.GetJsonAsync("/api/settings/public");
        var terms = "شروط الاستخدام " + Guid.NewGuid();

        var (updateStatus, _) = await adminClient.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?>
        {
            ["minVersionAndroid"] = "1.4.2",
            ["minVersionWindows"] = "1.0.10",
            ["maintenanceEnabled"] = true,
            ["maintenanceMessageAr"] = "صيانة حتى الساعة 3",
            ["supportPhone"] = "0223581234",
            ["supportEmail"] = "Help@El3yada.App",
            ["termsAr"] = terms,
        });
        var (status, body) = await anonymous.GetJsonAsync("/api/settings/public");
        await adminClient.PostAsync("/api/admin/updateSettings", new Dictionary<string, object?> { ["maintenanceEnabled"] = false });

        Assert.Equal(HttpStatusCode.OK, updateStatus);
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("1.4.2", body.GetProperty("minAppVersion").Str("android"));
        Assert.Equal("1.0.10", body.GetProperty("minAppVersion").Str("windows"));
        Assert.True(body.GetProperty("maintenance").GetProperty("enabled").GetBoolean());
        Assert.Equal("صيانة حتى الساعة 3", body.GetProperty("maintenance").Str("messageAr"));
        Assert.Equal("+20223581234", body.GetProperty("support").Str("phone"));
        Assert.Equal("help@el3yada.app", body.GetProperty("support").Str("email"));
        Assert.Equal(terms, body.GetProperty("terms").Str("ar"));
        Assert.NotEqual(before.GetProperty("terms").Str("version"), body.GetProperty("terms").Str("version"));
        Assert.Equal(12, body.GetProperty("terms").Str("version").Length);
        Assert.Equal(JsonValueKind.String, body.GetProperty("terms").GetProperty("updatedAt").ValueKind);
        Assert.False(body.TryGetProperty("examFeePiasters", out _)); // billing settings are not public
    }

    [Fact]
    public async Task Specialties_are_public_for_the_registration_form()
    {
        var (status, body) = await Factory.Client().GetJsonAsync("/api/specialties");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(19, body.GetArrayLength());
        Assert.Equal("باطنة", body[0].Str("nameAr"));
        Assert.Equal("Internal Medicine", body[0].Str("nameEn"));
    }

    [Fact]
    public async Task Unknown_routes_and_the_health_check_answer_without_sign_in()
    {
        using var client = Factory.Client();

        var (missingStatus, missing) = await client.GetJsonAsync("/api/does-not-exist");
        var (healthStatus, health) = await client.GetJsonAsync("/api/health");

        Assert.Equal(HttpStatusCode.Unauthorized, missingStatus); // denied by default, even before routing reveals anything
        Assert.Equal(ErrorCodes.Unauthenticated, missing.Code());
        Assert.Equal(HttpStatusCode.OK, healthStatus);
        Assert.Equal("ok", health.Str("status"));
    }
}
