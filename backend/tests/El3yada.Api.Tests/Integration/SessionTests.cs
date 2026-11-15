using System.Net;
using El3yada.Api.Auth;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>Refresh rotation and reuse, logout, A9 set new password, change password.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class SessionTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task Refresh_rotates_and_only_hashes_are_stored()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var login = await Factory.LoginAsync(admin.Identifier, admin.Password);
        using var client = Factory.Client();

        var (status, refreshed) = await client.PostAsync("/api/auth/refresh", new { refreshToken = login.Str("refreshToken") });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("signedIn", refreshed.Str("result"));
        Assert.NotEqual(login.Str("refreshToken"), refreshed.Str("refreshToken"));
        Assert.NotEqual(login.Str("accessToken"), refreshed.Str("accessToken"));
        var (meStatus, _) = await Factory.Client(refreshed.Str("accessToken")).GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.OK, meStatus);

        var tokens = await TestData.WithDbAsync(Factory, db => db.RefreshTokens.Where(t => t.UserId == admin.Id).ToListAsync());
        Assert.Equal(2, tokens.Count);
        Assert.Single(tokens.Select(t => t.FamilyId).Distinct());
        var old = tokens.Single(t => t.RevokedAt is not null);
        var current = tokens.Single(t => t.RevokedAt is null);
        Assert.Equal(current.Id, old.ReplacedByTokenId);
        Assert.Equal(SecretTokens.Hash(refreshed.Str("refreshToken")), current.TokenHash);
        Assert.DoesNotContain(tokens, t => t.TokenHash.SequenceEqual(System.Text.Encoding.UTF8.GetBytes(refreshed.Str("refreshToken"))));
    }

    [Fact]
    public async Task A_rotated_token_that_comes_back_revokes_the_whole_session()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var login = await Factory.LoginAsync(admin.Identifier, admin.Password);
        var other = await Factory.LoginAsync(admin.Identifier, admin.Password); // another device, another family
        using var client = Factory.Client();
        var (_, rotated) = await client.PostAsync("/api/auth/refresh", new { refreshToken = login.Str("refreshToken") });

        var (reuseStatus, reuse) = await client.PostAsync("/api/auth/refresh", new { refreshToken = login.Str("refreshToken") });
        var (newStatus, newer) = await client.PostAsync("/api/auth/refresh", new { refreshToken = rotated.Str("refreshToken") });
        var (otherStatus, _) = await client.PostAsync("/api/auth/refresh", new { refreshToken = other.Str("refreshToken") });

        Assert.Equal(HttpStatusCode.Unauthorized, reuseStatus);
        Assert.Equal(ErrorCodes.RefreshTokenReused, reuse.Code());
        Assert.Equal(HttpStatusCode.Unauthorized, newStatus);
        Assert.Equal(ErrorCodes.RefreshTokenInvalid, newer.Code());
        Assert.Equal(HttpStatusCode.OK, otherStatus); // the other device's session is untouched
        Assert.True(await TestData.WithDbAsync(Factory, db =>
            db.AuditLogs.AnyAsync(a => a.Action == "refreshTokenReuseDetected" && a.TargetId == admin.Id.ToString())));
    }

    [Fact]
    public async Task Unknown_refresh_tokens_are_refused()
    {
        var (status, body) = await Factory.Client().PostAsync("/api/auth/refresh", new { refreshToken = "x" + Guid.NewGuid() });

        Assert.Equal(HttpStatusCode.Unauthorized, status);
        Assert.Equal(ErrorCodes.RefreshTokenInvalid, body.Code());
    }

    [Fact]
    public async Task Logout_revokes_the_session_and_removes_the_push_token()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var device = new { deviceId = "tablet-7", platform = "android", appVersion = "1.0.0", pushToken = "fcm-" + Guid.NewGuid() };
        var login = await Factory.LoginAsync(doctor.Identifier, doctor.Password, device);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.UserDevices.AnyAsync(d => d.UserId == doctor.Id && d.FcmToken == device.pushToken)));
        using var client = Factory.Client();

        using var logout = await client.PostAsJsonAsyncRaw("/api/auth/logout", new { refreshToken = login.Str("refreshToken") });
        var (refreshStatus, refresh) = await client.PostAsync("/api/auth/refresh", new { refreshToken = login.Str("refreshToken") });
        using var again = await client.PostAsJsonAsyncRaw("/api/auth/logout", new { refreshToken = login.Str("refreshToken") });

        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, refreshStatus);
        Assert.Equal(ErrorCodes.RefreshTokenInvalid, refresh.Code());
        Assert.Equal(HttpStatusCode.NoContent, again.StatusCode);
        Assert.False(await TestData.WithDbAsync(Factory, db => db.UserDevices.AnyAsync(d => d.UserId == doctor.Id)));
    }

    [Fact]
    public async Task A_push_token_moves_to_the_account_that_signs_in_last_on_the_device()
    {
        var first = await TestData.CreateDoctorAsync(Factory);
        var second = await TestData.CreateDoctorAsync(Factory);
        var device = new { deviceId = "shared-phone", platform = "android", appVersion = "1.0.0", pushToken = "fcm-" + Guid.NewGuid() };

        await Factory.LoginAsync(first.Identifier, first.Password, device);
        await Factory.LoginAsync(second.Identifier, second.Password, device);

        var owners = await TestData.WithDbAsync(Factory, db => db.UserDevices.Where(d => d.FcmToken == device.pushToken).Select(d => d.UserId).ToListAsync());
        Assert.Equal([second.Id], owners);
    }

    [Fact]
    public async Task Must_change_password_blocks_everything_but_A9_until_a_new_password_is_set()
    {
        var admin = await TestData.CreateAdminAsync(Factory, mustChangePassword: true);
        var login = await Factory.LoginAsync(admin.Identifier, admin.Password);
        Assert.True(login.GetProperty("mustChangePassword").GetBoolean());
        using var client = Factory.Client(login.Str("accessToken"));

        var (blockedStatus, blocked) = await client.GetJsonAsync("/api/admin/settings");
        var (meStatus, _) = await client.GetJsonAsync("/api/auth/me");
        var (weakStatus, weak) = await client.PostAsync("/api/auth/setNewPassword", new { newPassword = "short1" });
        var (lettersStatus, letters) = await client.PostAsync("/api/auth/setNewPassword", new { newPassword = "onlyletters" });
        var (sameStatus, same) = await client.PostAsync("/api/auth/setNewPassword", new { newPassword = admin.Password });
        var (setStatus, session) = await client.PostAsync("/api/auth/setNewPassword", new { newPassword = "NewSecret99" });

        Assert.Equal(HttpStatusCode.Forbidden, blockedStatus);
        Assert.Equal(ErrorCodes.PasswordChangeRequired, blocked.Code());
        Assert.Equal(HttpStatusCode.OK, meStatus);
        Assert.Equal(HttpStatusCode.BadRequest, weakStatus);
        Assert.Equal(ErrorCodes.WeakPassword, weak.FieldCode("newPassword"));
        Assert.Equal(ErrorCodes.WeakPassword, letters.FieldCode("newPassword"));
        Assert.Equal(HttpStatusCode.BadRequest, lettersStatus);
        Assert.Equal(HttpStatusCode.BadRequest, sameStatus);
        Assert.Equal(ErrorCodes.PasswordSameAsOld, same.FieldCode("newPassword"));
        Assert.Equal(HttpStatusCode.OK, setStatus);
        Assert.False(session.GetProperty("mustChangePassword").GetBoolean());

        // The old token is out (new security stamp); the new session works everywhere.
        var (oldStatus, old) = await client.GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, oldStatus);
        Assert.Equal(ErrorCodes.SessionRevoked, old.Code());
        var (settingsStatus, _) = await Factory.Client(session.Str("accessToken")).GetJsonAsync("/api/admin/settings");
        Assert.Equal(HttpStatusCode.OK, settingsStatus);
        await Factory.LoginAsync(admin.Identifier, "NewSecret99");

        var (againStatus, again) = await Factory.Client(session.Str("accessToken")).PostAsync("/api/auth/setNewPassword", new { newPassword = "Another99" });
        Assert.Equal(HttpStatusCode.Conflict, againStatus);
        Assert.Equal(ErrorCodes.PasswordChangeNotRequired, again.Code());
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "passwordSet" && a.TargetId == admin.Id.ToString())));
    }

    [Fact]
    public async Task A_patient_accepts_the_terms_with_the_first_password()
    {
        var (patient, _) = await TestData.CreatePatientAsync(Factory, mustChangePassword: true, acceptedTerms: false);
        var login = await Factory.LoginAsync(patient.Identifier, patient.Password);
        Assert.True(login.GetProperty("mustAcceptTerms").GetBoolean());
        using var client = Factory.Client(login.Str("accessToken"));

        var (refusedStatus, refused) = await client.PostAsync("/api/auth/setNewPassword", new { newPassword = "MyOwn1234" });
        var (status, session) = await client.PostAsync("/api/auth/setNewPassword", new { newPassword = "MyOwn1234", acceptTerms = true });

        Assert.Equal(HttpStatusCode.BadRequest, refusedStatus);
        Assert.Equal(ErrorCodes.TermsNotAccepted, refused.FieldCode("acceptTerms"));
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.False(session.GetProperty("mustAcceptTerms").GetBoolean());
        Assert.NotNull(await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == patient.Id).Select(u => u.AcceptedTermsAt).SingleAsync()));
    }

    [Fact]
    public async Task Changing_the_password_signs_out_every_other_device()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var phoneA = await Factory.LoginAsync(doctor.Identifier, doctor.Password, new { deviceId = "phone-a", platform = "ios", appVersion = "1.0.0" });
        var pcB = await Factory.LoginAsync(doctor.Identifier, doctor.Password, new { deviceId = "pc-b", platform = "windows", appVersion = "1.0.0" });
        using var a = Factory.Client(phoneA.Str("accessToken"));
        using var b = Factory.Client(pcB.Str("accessToken"));

        var (wrongStatus, wrong) = await a.PostAsync("/api/auth/changePassword", new { currentPassword = "Wrong1234", newPassword = "Changed123" });
        var (status, session) = await a.PostAsync("/api/auth/changePassword", new { currentPassword = doctor.Password, newPassword = "Changed123" });

        Assert.Equal(HttpStatusCode.BadRequest, wrongStatus);
        Assert.Equal(ErrorCodes.CurrentPasswordIncorrect, wrong.FieldCode("currentPassword"));
        Assert.Equal(HttpStatusCode.OK, status);

        var (bStatus, bBody) = await b.GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, bStatus);
        Assert.Equal(ErrorCodes.SessionRevoked, bBody.Code());
        var (bRefreshStatus, _) = await Factory.Client().PostAsync("/api/auth/refresh", new { refreshToken = pcB.Str("refreshToken") });
        Assert.Equal(HttpStatusCode.Unauthorized, bRefreshStatus);
        var (aOldStatus, _) = await a.GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, aOldStatus);

        // Device A carries on with the new session, still tied to its device.
        var (aNewStatus, _) = await Factory.Client(session.Str("accessToken")).GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.OK, aNewStatus);
        var active = await TestData.WithDbAsync(Factory, db => db.RefreshTokens.Where(t => t.UserId == doctor.Id && t.RevokedAt == null).ToListAsync());
        Assert.Equal("phone-a", Assert.Single(active).DeviceId);
        await Factory.LoginAsync(doctor.Identifier, "Changed123");
    }

    [Fact]
    public async Task Preferences_are_saved_on_the_account()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/auth/updatePreferences", new { locale = "en", themeMode = "dark" });
        var (badStatus, bad) = await client.PostAsync("/api/auth/updatePreferences", new { locale = "fr" });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("en", body.Str("locale"));
        Assert.Equal("dark", body.Str("themeMode"));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("locale"));
    }
}
