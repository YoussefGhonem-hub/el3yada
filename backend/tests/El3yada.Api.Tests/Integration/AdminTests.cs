using System.Net;
using El3yada.Api.Auth;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>Admin roles (spec section 5), AD14 admin users, AD18 profile, AD15 audit log.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class AdminTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Theory]
    [InlineData("GET", "/api/admin/settings")]
    [InlineData("GET", "/api/admin/doctorRegistrations")]
    [InlineData("GET", "/api/admin/auditLogs")]
    [InlineData("GET", "/api/admin/admins")]
    [InlineData("POST", "/api/admin/createAdmin")]
    [InlineData("POST", "/api/admin/updateSettings")]
    [InlineData("POST", "/api/admin/reviewDoctorRegistration")]
    public async Task Admin_endpoints_need_a_token_and_an_admin(string method, string url)
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var anonymous = Factory.Client();
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        using var noToken = await anonymous.SendAsync(new HttpRequestMessage(new HttpMethod(method), url));
        using var wrongRole = await asDoctor.SendAsync(new HttpRequestMessage(new HttpMethod(method), url));

        Assert.Equal(HttpStatusCode.Unauthorized, noToken.StatusCode);
        Assert.Equal(ErrorCodes.Unauthenticated, (await Http.BodyAsync(noToken)).Code());
        Assert.Equal(HttpStatusCode.Forbidden, wrongRole.StatusCode);
        Assert.Equal(ErrorCodes.Forbidden, (await Http.BodyAsync(wrongRole)).Code());
    }

    [Fact]
    public async Task Only_super_admins_manage_admins()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var client = await Factory.SignedInClientAsync(admin);

        var (listStatus, _) = await client.GetJsonAsync("/api/admin/admins");
        var (createStatus, create) = await client.PostAsync("/api/admin/createAdmin", new { email = TestData.Email(), displayName = "New Admin", adminRole = "admin" });
        var (settingsStatus, _) = await client.GetJsonAsync("/api/admin/settings");

        Assert.Equal(HttpStatusCode.Forbidden, listStatus);
        Assert.Equal(HttpStatusCode.Forbidden, createStatus);
        Assert.Equal(ErrorCodes.Forbidden, create.Code());
        Assert.Equal(HttpStatusCode.OK, settingsStatus); // everything else is open to any admin
    }

    [Fact]
    public async Task CreateAdmin_shows_the_temporary_password_once_and_forces_a_change()
    {
        var super = await TestData.CreateAdminAsync(Factory);
        using var client = await Factory.SignedInClientAsync(super);
        var email = TestData.Email("created");

        var (status, created) = await client.PostAsync("/api/admin/createAdmin", new { email = email.ToUpperInvariant(), displayName = "Nour Adel", adminRole = "admin" });
        var (dupStatus, dup) = await client.PostAsync("/api/admin/createAdmin", new { email, displayName = "Nour Adel", adminRole = "admin" });
        var (badStatus, bad) = await client.PostAsync("/api/admin/createAdmin", new { email = "x", displayName = "N", adminRole = "owner" });

        Assert.Equal(HttpStatusCode.Created, status);
        var password = created.Str("temporaryPassword");
        Assert.Equal(Passwords.AdminTemporaryLength, password.Length);
        Assert.Equal(email, created.GetProperty("admin").Str("email"));
        Assert.True(created.GetProperty("admin").GetProperty("mustChangePassword").GetBoolean());
        Assert.Equal(HttpStatusCode.Conflict, dupStatus);
        Assert.Equal(ErrorCodes.EmailAlreadyRegistered, dup.Code());
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidEmail, bad.FieldCode("email"));
        Assert.Equal(ErrorCodes.InvalidName, bad.FieldCode("displayName"));
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("adminRole"));

        var login = await Factory.LoginAsync(email, password);
        Assert.True(login.GetProperty("mustChangePassword").GetBoolean());
        Assert.Equal("admin", login.Str("adminRole"));
        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == "adminCreated" && a.ActorUserId == super.Id));
        Assert.DoesNotContain(password, audit.DetailsJson ?? "");
        var hash = await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Email == email).Select(u => u.PasswordHash).SingleAsync());
        Assert.DoesNotContain(password, hash);
    }

    [Fact]
    public async Task A_role_change_applies_at_the_next_request_and_a_refresh_brings_the_new_role()
    {
        var super = await TestData.CreateAdminAsync(Factory);
        var other = await TestData.CreateAdminAsync(Factory);
        using var client = await Factory.SignedInClientAsync(super);
        var otherSession = await Factory.LoginAsync(other.Identifier, other.Password);

        var (status, changed) = await client.PostAsync("/api/admin/setAdminRole", new { userId = other.Id, adminRole = "admin" });
        var (oldStatus, old) = await Factory.Client(otherSession.Str("accessToken")).GetJsonAsync("/api/admin/admins");
        var (_, refreshed) = await Factory.Client().PostAsync("/api/auth/refresh", new { refreshToken = otherSession.Str("refreshToken") });
        var (newStatus, _) = await Factory.Client(refreshed.Str("accessToken")).GetJsonAsync("/api/admin/admins");
        var (selfStatus, self) = await client.PostAsync("/api/admin/setAdminRole", new { userId = super.Id, adminRole = "admin" });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("admin", changed.Str("adminRole"));
        Assert.Equal(HttpStatusCode.Unauthorized, oldStatus);
        Assert.Equal(ErrorCodes.TokenOutdated, old.Code());
        Assert.Equal("admin", refreshed.Str("adminRole"));
        Assert.Equal(HttpStatusCode.Forbidden, newStatus);
        Assert.Equal(HttpStatusCode.Conflict, selfStatus);
        Assert.Equal(ErrorCodes.CannotChangeOwnRole, self.Code());
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "adminRoleChanged" && a.TargetId == other.Id.ToString())));
    }

    [Fact]
    public async Task Disabling_an_admin_signs_them_out_and_enabling_lets_them_back()
    {
        var super = await TestData.CreateAdminAsync(Factory);
        var other = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var client = await Factory.SignedInClientAsync(super);
        var otherSession = await Factory.LoginAsync(other.Identifier, other.Password);

        var (disableStatus, disabled) = await client.PostAsync("/api/admin/setAdminStatus", new { userId = other.Id, status = "disabled" });
        var (meStatus, _) = await Factory.Client(otherSession.Str("accessToken")).GetJsonAsync("/api/auth/me");
        var (loginStatus, login) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = other.Identifier, password = other.Password });
        var (selfStatus, self) = await client.PostAsync("/api/admin/setAdminStatus", new { userId = super.Id, status = "disabled" });
        var (enableStatus, _) = await client.PostAsync("/api/admin/setAdminStatus", new { userId = other.Id, status = "active" });

        Assert.Equal(HttpStatusCode.OK, disableStatus);
        Assert.Equal("disabled", disabled.Str("status"));
        Assert.Equal(HttpStatusCode.Unauthorized, meStatus); // new security stamp
        Assert.Equal(HttpStatusCode.Forbidden, loginStatus);
        Assert.Equal(ErrorCodes.AccountDisabled, login.Code());
        Assert.Equal(HttpStatusCode.Conflict, selfStatus);
        Assert.Equal(ErrorCodes.CannotDisableSelf, self.Code());
        Assert.Equal(HttpStatusCode.OK, enableStatus);
        await Factory.LoginAsync(other.Identifier, other.Password);
    }

    [Fact]
    public async Task The_last_active_super_admin_is_always_kept()
    {
        var a = await TestData.CreateAdminAsync(Factory);
        var b = await TestData.CreateAdminAsync(Factory);
        await DisableOtherSuperAdminsAsync(a.Id, b.Id);
        using var asA = await Factory.SignedInClientAsync(a);

        // Nobody changes their own role or disables themselves, so the caller always remains a super admin.
        var (selfRole, selfRoleBody) = await asA.PostAsync("/api/admin/setAdminRole", new { userId = a.Id, adminRole = "admin" });
        var (selfDisable, selfDisableBody) = await asA.PostAsync("/api/admin/setAdminStatus", new { userId = a.Id, status = "disabled" });
        var (demoteB, _) = await asA.PostAsync("/api/admin/setAdminRole", new { userId = b.Id, adminRole = "admin" });

        Assert.Equal(HttpStatusCode.Conflict, selfRole);
        Assert.Equal(ErrorCodes.CannotChangeOwnRole, selfRoleBody.Code());
        Assert.Equal(HttpStatusCode.Conflict, selfDisable);
        Assert.Equal(ErrorCodes.CannotDisableSelf, selfDisableBody.Code());
        Assert.Equal(HttpStatusCode.OK, demoteB); // a is still a super admin
        Assert.Equal(1, await ActiveSuperAdminsAsync());

        // The count itself is checked in the database, under a lock. It matters when the caller's own change
        // isn't visible yet: another API instance (or another request at the same moment) disabled super admin
        // c, but c's account check is still cached here (Auth:UserStateCacheSeconds).
        var c = await TestData.CreateAdminAsync(Factory);
        using var asC = await Factory.SignedInClientAsync(c);
        var (warm, _) = await asC.GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.OK, warm);
        await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == c.Id)
            .ExecuteUpdateAsync(set => set.SetProperty(u => u.Status, AccountStatuses.Disabled)));

        var (demoteA, demoteABody) = await asC.PostAsync("/api/admin/setAdminRole", new { userId = a.Id, adminRole = "admin" });
        var (disableA, disableABody) = await asC.PostAsync("/api/admin/setAdminStatus", new { userId = a.Id, status = "disabled" });

        Assert.Equal(HttpStatusCode.Conflict, demoteA);
        Assert.Equal(ErrorCodes.LastSuperAdmin, demoteABody.Code());
        Assert.Equal(HttpStatusCode.Conflict, disableA);
        Assert.Equal(ErrorCodes.LastSuperAdmin, disableABody.Code());
        var stillSuper = await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == a.Id).Select(u => new { u.AdminRole, u.Status }).SingleAsync());
        Assert.Equal(AdminRoles.SuperAdmin, stillSuper.AdminRole);
        Assert.Equal(AccountStatuses.Active, stillSuper.Status);
    }

    [Fact]
    public async Task Two_super_admins_demoting_each_other_at_once_leave_one()
    {
        var a = await TestData.CreateAdminAsync(Factory);
        var b = await TestData.CreateAdminAsync(Factory);
        await DisableOtherSuperAdminsAsync(a.Id, b.Id);
        using var asA = await Factory.SignedInClientAsync(a);
        using var asB = await Factory.SignedInClientAsync(b);
        await asA.GetJsonAsync("/api/auth/me");
        await asB.GetJsonAsync("/api/auth/me");

        var results = await Task.WhenAll(
            asA.PostAsync("/api/admin/setAdminRole", new { userId = b.Id, adminRole = "admin" }),
            asB.PostAsync("/api/admin/setAdminRole", new { userId = a.Id, adminRole = "admin" }));

        Assert.Equal(1, await ActiveSuperAdminsAsync());
        Assert.Contains(results, r => r.Status == HttpStatusCode.OK);
        Assert.All(results, r => Assert.True(
            r.Status == HttpStatusCode.OK || r.Body.Code() is ErrorCodes.LastSuperAdmin or ErrorCodes.TokenOutdated,
            $"{r.Status} {r.Body}"));
    }

    private Task DisableOtherSuperAdminsAsync(params Guid[] keep) =>
        TestData.WithDbAsync(Factory, db => db.Users
            .Where(u => u.Role == Roles.Admin && u.AdminRole == AdminRoles.SuperAdmin && !keep.Contains(u.Id))
            .ExecuteUpdateAsync(set => set.SetProperty(u => u.Status, AccountStatuses.Disabled)));

    private Task<int> ActiveSuperAdminsAsync() =>
        TestData.WithDbAsync(Factory, db => db.Users.CountAsync(u =>
            u.Role == Roles.Admin && u.AdminRole == AdminRoles.SuperAdmin && u.Status == AccountStatuses.Active));

    [Fact]
    public async Task An_admin_updates_their_own_profile()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var client = await Factory.SignedInClientAsync(admin);

        var (status, body) = await client.PostAsync("/api/admin/updateAdminProfile", new { displayName = "Hoda  Kamal" });
        var (getStatus, profile) = await client.GetJsonAsync("/api/admin/profile");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("Hoda Kamal", body.GetProperty("admin").Str("displayName"));
        Assert.Equal(HttpStatusCode.OK, getStatus);
        Assert.Equal("Hoda Kamal", profile.GetProperty("admin").Str("displayName"));
        Assert.Equal("ar", profile.Str("locale"));
    }

    [Fact]
    public async Task The_audit_log_lists_admin_actions_newest_first_with_filters()
    {
        var super = await TestData.CreateAdminAsync(Factory);
        using var client = await Factory.SignedInClientAsync(super);
        await client.PostAsync("/api/admin/createAdmin", new { email = TestData.Email(), displayName = "First Admin", adminRole = "admin" });
        await client.PostAsync("/api/admin/createAdmin", new { email = TestData.Email(), displayName = "Second Admin", adminRole = "admin" });

        var (status, page) = await client.GetJsonAsync($"/api/admin/auditLogs?actorUserId={super.Id}&action=adminCreated&pageSize=1");
        var (badStatus, bad) = await client.GetJsonAsync("/api/admin/auditLogs?pageSize=1000");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(2, page.GetProperty("totalCount").GetInt32());
        Assert.Equal(2, page.GetProperty("totalPages").GetInt32());
        var item = Assert.Single(page.GetProperty("items").EnumerateArray());
        Assert.Equal("adminCreated", item.Str("action"));
        Assert.Equal("Test Admin", item.Str("actorName"));
        Assert.Equal("admin", item.Str("actorRole"));
        Assert.Equal("admin", item.GetProperty("details").Str("adminRole"));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.OutOfRange, bad.FieldCode("pageSize"));
    }

}
