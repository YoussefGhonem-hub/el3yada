using System.Net;
using El3yada.Api.Auth;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>A3 login, A1 routing fields, the same-number "log in as" flow and the lockout.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class LoginTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task Email_login_returns_the_session_the_app_reads()
    {
        var admin = await TestData.CreateAdminAsync(Factory);

        var body = await Factory.LoginAsync($"  {admin.Identifier.ToUpperInvariant()} ", admin.Password);

        Assert.Equal(admin.Id.ToString(), body.Str("userId"));
        Assert.Equal("Test Admin", body.Str("displayName"));
        Assert.Equal("admin", body.Str("role"));
        Assert.Equal("superAdmin", body.Str("adminRole"));
        Assert.Equal("active", body.Str("accountStatus"));
        Assert.False(body.GetProperty("mustChangePassword").GetBoolean());
        Assert.Equal(System.Text.Json.JsonValueKind.Null, body.GetProperty("doctorId").ValueKind);
        Assert.False(string.IsNullOrEmpty(body.Str("accessToken")));
        Assert.Equal(43, body.Str("refreshToken").Length);
        Assert.EndsWith("Z", body.Str("accessTokenExpiresAt"));
    }

    [Theory]
    [InlineData("local")]
    [InlineData("e164")]
    [InlineData("0020")]
    [InlineData("20")]
    [InlineData("arabicDigits")]
    [InlineData("spaces")]
    public async Task Mobile_login_accepts_every_form_of_the_number(string form)
    {
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var local = TestData.Local(patient.Phone!); // 011XXXXXXXX
        var identifier = form switch
        {
            "local" => local,
            "e164" => patient.Phone!,
            "0020" => "0020" + local[1..],
            "20" => "20" + local[1..],
            "arabicDigits" => string.Concat(local.Select(c => (char)('٠' + (c - '0')))),
            _ => $"{local[..3]} {local[3..7]} {local[7..]}",
        };

        var body = await Factory.LoginAsync(identifier, patient.Password);

        Assert.Equal(patient.Id.ToString(), body.Str("userId"));
        Assert.Equal("patient", body.Str("role"));
        Assert.Equal(patient.Phone, body.Str("phone"));
    }

    [Fact]
    public async Task Wrong_password_and_unknown_identifier_get_the_same_answer()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var client = Factory.Client();

        var (wrongStatus, wrong) = await client.PostAsync("/api/auth/login", new { identifier = admin.Identifier, password = "Wrong1234" });
        var (unknownStatus, unknown) = await client.PostAsync("/api/auth/login", new { identifier = TestData.Email(), password = "Wrong1234" });
        var (mobileStatus, mobile) = await client.PostAsync("/api/auth/login", new { identifier = TestData.Mobile(), password = "Wrong1234" });

        Assert.All([wrongStatus, unknownStatus, mobileStatus], status => Assert.Equal(HttpStatusCode.Unauthorized, status));
        Assert.All([wrong, unknown, mobile], body => Assert.Equal(ErrorCodes.InvalidCredentials, body.Code()));
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == admin.Id).Select(u => u.AccessFailedCount).SingleAsync()));
    }

    [Fact]
    public async Task Bad_input_is_a_validation_problem()
    {
        using var client = Factory.Client();

        var (status, body) = await client.PostAsync("/api/auth/login", new { identifier = "0123", password = "" });

        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.ValidationFailed, body.Code());
        Assert.Equal(ErrorCodes.InvalidIdentifier, body.FieldCode("identifier"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("password"));
    }

    [Fact]
    public async Task A_body_that_is_not_json_or_has_wrong_types_is_INVALID_REQUEST()
    {
        using var client = Factory.Client();

        using var notJson = await client.PostAsync("/api/auth/login", new StringContent("{oops", System.Text.Encoding.UTF8, "application/json"));
        using var wrongType = await client.PostAsync("/api/auth/login", new StringContent("{\"identifier\":5,\"password\":\"x\"}", System.Text.Encoding.UTF8, "application/json"));
        using var empty = await client.PostAsync("/api/auth/login", new StringContent("", System.Text.Encoding.UTF8, "application/json"));

        Assert.All([notJson, wrongType, empty], response => Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode));
        var wrongTypeBody = await Http.BodyAsync(wrongType);
        Assert.Equal(ErrorCodes.InvalidRequest, wrongTypeBody.Code());
        Assert.Equal(ErrorCodes.InvalidRequest, wrongTypeBody.FieldCode("identifier"));
        Assert.Equal(ErrorCodes.InvalidRequest, (await Http.BodyAsync(empty)).FieldCode("body"));
        Assert.Equal(ErrorCodes.InvalidRequest, (await Http.BodyAsync(notJson)).Code());
    }

    [Fact]
    public async Task A_disabled_account_is_refused_only_after_the_right_password()
    {
        var admin = await TestData.CreateAdminAsync(Factory, status: AccountStatuses.Disabled);
        using var client = Factory.Client();

        var (wrongStatus, wrong) = await client.PostAsync("/api/auth/login", new { identifier = admin.Identifier, password = "Wrong1234" });
        var (rightStatus, right) = await client.PostAsync("/api/auth/login", new { identifier = admin.Identifier, password = admin.Password });

        Assert.Equal(HttpStatusCode.Unauthorized, wrongStatus);
        Assert.Equal(ErrorCodes.InvalidCredentials, wrong.Code());
        Assert.Equal(HttpStatusCode.Forbidden, rightStatus);
        Assert.Equal(ErrorCodes.AccountDisabled, right.Code());
    }

    [Theory]
    [InlineData(DoctorStatuses.PendingApproval, null)]
    [InlineData(DoctorStatuses.Rejected, "صورة الكارنيه غير واضحة")]
    [InlineData(DoctorStatuses.Active, null)]
    [InlineData(DoctorStatuses.Suspended, "فاتورة أكتوبر")]
    public async Task Doctors_sign_in_with_their_status_for_splash_routing(string status, string? reason)
    {
        var doctor = await TestData.CreateDoctorAsync(Factory, status, reason);

        var body = await Factory.LoginAsync(doctor.Identifier, doctor.Password);

        Assert.Equal("doctor", body.Str("role"));
        Assert.Equal(doctor.Id.ToString(), body.Str("doctorId"));
        Assert.Equal(status, body.Str("doctorStatus"));
        Assert.Equal(reason, body.GetProperty("doctorStatusReason").GetString());

        using var me = Factory.Client(body.Str("accessToken"));
        var (meStatus, meBody) = await me.GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.OK, meStatus);
        Assert.Equal(status, meBody.Str("doctorStatus"));
    }

    [Fact]
    public async Task A_doctor_disabled_by_the_admin_cannot_sign_in()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.Disabled);

        var (status, body) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = doctor.Identifier, password = doctor.Password });

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(ErrorCodes.AccountDisabled, body.Code());
    }

    [Theory]
    [InlineData(DoctorStatuses.PendingApproval, ErrorCodes.ClinicNotActive)]
    [InlineData(DoctorStatuses.Rejected, ErrorCodes.ClinicNotActive)]
    [InlineData(DoctorStatuses.Disabled, ErrorCodes.ClinicNotActive)]
    public async Task An_assistant_of_a_clinic_that_is_not_active_is_refused(string doctorStatus, string code)
    {
        var doctor = await TestData.CreateDoctorAsync(Factory, doctorStatus);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);

        var (status, body) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = assistant.Identifier, password = assistant.Password });

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(code, body.Code());
    }

    [Fact]
    public async Task An_assistant_signs_in_with_their_doctor()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.Suspended);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);

        var body = await Factory.LoginAsync(TestData.Local(assistant.Phone!), assistant.Password);

        Assert.Equal("assistant", body.Str("role"));
        Assert.Equal(doctor.Id.ToString(), body.Str("doctorId"));
        Assert.Equal(DoctorStatuses.Suspended, body.Str("doctorStatus"));
        Assert.Equal(System.Text.Json.JsonValueKind.Null, body.GetProperty("doctorStatusReason").ValueKind);
    }

    [Fact]
    public async Task A_removed_assistant_cannot_sign_in()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, status: "removed");

        var (status, body) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = assistant.Identifier, password = assistant.Password });

        Assert.Equal(HttpStatusCode.Unauthorized, status);
        Assert.Equal(ErrorCodes.InvalidCredentials, body.Code());
    }

    [Fact]
    public async Task A_patient_on_desktop_is_refused_with_A14()
    {
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var device = new { deviceId = "pc-1", platform = "windows", appVersion = "1.0.0" };

        var (status, body) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = patient.Identifier, password = patient.Password, device });

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(ErrorCodes.PatientDesktopNotSupported, body.Code());
        Assert.False(await TestData.WithDbAsync(Factory, db => db.RefreshTokens.AnyAsync(t => t.UserId == patient.Id)));
    }

    [Fact]
    public async Task Same_number_and_password_asks_which_account_then_signs_in_the_chosen_one()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, patient.Phone);
        using var client = Factory.Client();

        var (status, choice) = await client.PostAsync("/api/auth/login", new { identifier = TestData.Local(patient.Phone!), password = TestData.Password });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("chooseAccount", choice.Str("result"));
        Assert.False(choice.TryGetProperty("accessToken", out _));
        var accounts = choice.GetProperty("accounts").EnumerateArray().ToList();
        Assert.Equal(["patient", "assistant"], accounts.Select(a => a.Str("role")));
        Assert.Equal("أحمد علي", accounts[1].Str("doctorName"));

        var device = new { deviceId = "phone-1", platform = "android", appVersion = "1.0.0", pushToken = "fcm-" + Guid.NewGuid() };
        var (selectedStatus, selected) = await client.PostAsync("/api/auth/selectAccount",
            new { selectionToken = choice.Str("selectionToken"), role = "assistant", device });
        Assert.Equal(HttpStatusCode.OK, selectedStatus);
        Assert.Equal("signedIn", selected.Str("result"));
        Assert.Equal(assistant.Id.ToString(), selected.Str("userId"));
        Assert.Equal(doctor.Id.ToString(), selected.Str("doctorId"));
        Assert.True(await TestData.WithDbAsync(Factory, db => db.UserDevices.AnyAsync(d => d.UserId == assistant.Id && d.DeviceId == "phone-1")));

        // A selection token works once.
        var (againStatus, again) = await client.PostAsync("/api/auth/selectAccount",
            new { selectionToken = choice.Str("selectionToken"), role = "patient" });
        Assert.Equal(HttpStatusCode.Unauthorized, againStatus);
        Assert.Equal(ErrorCodes.SelectionTokenInvalid, again.Code());
    }

    [Fact]
    public async Task Same_number_with_different_passwords_signs_in_whichever_matches()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var (patient, _) = await TestData.CreatePatientAsync(Factory, password: "Patient123");
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, patient.Phone, password: "Assistant123");

        var asPatient = await Factory.LoginAsync(patient.Phone!, "Patient123");
        var asAssistant = await Factory.LoginAsync(patient.Phone!, "Assistant123");
        var (wrongStatus, wrong) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = patient.Phone, password = "Neither123" });

        Assert.Equal(patient.Id.ToString(), asPatient.Str("userId"));
        Assert.Equal(assistant.Id.ToString(), asAssistant.Str("userId"));
        Assert.Equal(HttpStatusCode.Unauthorized, wrongStatus);
        Assert.Equal(ErrorCodes.InvalidCredentials, wrong.Code());
    }

    [Fact]
    public async Task Same_number_on_desktop_signs_in_the_assistant_directly()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, patient.Phone);

        var body = await Factory.LoginAsync(patient.Phone!, TestData.Password, new { deviceId = "pc-2", platform = "windows", appVersion = "1.0.0" });

        Assert.Equal(assistant.Id.ToString(), body.Str("userId"));
    }

    [Fact]
    public async Task Five_wrong_passwords_lock_the_account_and_unknown_identifiers_alike()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var unknown = TestData.Email("nobody");
        using var client = Factory.Client();

        for (var i = 0; i < 5; i++)
        {
            var (status, _) = await client.PostAsync("/api/auth/login", new { identifier = admin.Identifier, password = "Wrong1234" });
            Assert.Equal(HttpStatusCode.Unauthorized, status);
            await client.PostAsync("/api/auth/login", new { identifier = unknown, password = "Wrong1234" });
        }

        using var locked = await client.PostAsJsonAsyncRaw("/api/auth/login", new { identifier = admin.Identifier, password = admin.Password });
        var (unknownStatus, unknownBody) = await client.PostAsync("/api/auth/login", new { identifier = unknown, password = "Wrong1234" });

        Assert.Equal(HttpStatusCode.TooManyRequests, locked.StatusCode);
        Assert.Equal(ErrorCodes.TooManyAttempts, (await Http.BodyAsync(locked)).Code());
        Assert.NotNull(locked.Headers.RetryAfter);
        Assert.Equal(HttpStatusCode.TooManyRequests, unknownStatus);
        Assert.Equal(ErrorCodes.TooManyAttempts, unknownBody.Code());
        var lockoutEnd = await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == admin.Id).Select(u => u.LockoutEndAt).SingleAsync());
        Assert.True(lockoutEnd > DateTime.UtcNow.AddMinutes(14));
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "accountLockedOut" && a.TargetId == admin.Id.ToString())));
    }

    [Fact]
    public async Task Me_needs_a_token_and_gives_problem_json_codes()
    {
        using var anonymous = Factory.Client();
        using var garbage = Factory.Client("not-a-jwt");

        var (noTokenStatus, noToken) = await anonymous.GetJsonAsync("/api/auth/me");
        var (badTokenStatus, badToken) = await garbage.GetJsonAsync("/api/auth/me");

        Assert.Equal(HttpStatusCode.Unauthorized, noTokenStatus);
        Assert.Equal(ErrorCodes.Unauthenticated, noToken.Code());
        Assert.Equal(HttpStatusCode.Unauthorized, badTokenStatus);
        Assert.Equal(ErrorCodes.Unauthenticated, badToken.Code());
    }

    [Fact]
    public async Task Disabling_an_account_refuses_its_next_request()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        var session = await Factory.LoginAsync(admin.Identifier, admin.Password);
        await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == admin.Id)
            .ExecuteUpdateAsync(set => set.SetProperty(u => u.Status, AccountStatuses.Disabled)));
        Factory.Services.GetRequiredServiceForTest<AccountStateCache>().Invalidate(admin.Id);

        var (status, body) = await Factory.Client(session.Str("accessToken")).GetJsonAsync("/api/auth/me");
        var (refreshStatus, refresh) = await Factory.Client().PostAsync("/api/auth/refresh", new { refreshToken = session.Str("refreshToken") });

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(ErrorCodes.AccountDisabled, body.Code());
        Assert.Equal(HttpStatusCode.Forbidden, refreshStatus);
        Assert.Equal(ErrorCodes.AccountDisabled, refresh.Code());
    }
}

internal static class TestServiceExtensions
{
    public static T GetRequiredServiceForTest<T>(this IServiceProvider services)
        where T : notnull =>
        Microsoft.Extensions.DependencyInjection.ServiceProviderServiceExtensions.GetRequiredService<T>(services);

    public static Task<HttpResponseMessage> PostAsJsonAsyncRaw(this HttpClient client, string url, object body) =>
        System.Net.Http.Json.HttpClientJsonExtensions.PostAsJsonAsync(client, url, body);
}
