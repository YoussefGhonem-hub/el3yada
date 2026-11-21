using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using Microsoft.EntityFrameworkCore;
using SkiaSharp;

namespace El3yada.Api.Tests.Integration;

/// <summary>AD6 "Add doctor": <c>POST /api/admin/createDoctor</c>.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class AdminCreateDoctorTests(IntegrationHost host)
{
    private static readonly byte[] LicenseJpeg = TestImages.Encode(40, 30, SKEncodedImageFormat.Jpeg);

    private IntegrationFactory Factory => host.Factory;

    private static Dictionary<string, object?> Data(string email, Guid specialtyId) => new()
    {
        ["fullName"] = "هالة  محمود",
        ["email"] = email,
        ["phone"] = "010 " + Random.Shared.Next(1000, 9999) + " " + Random.Shared.Next(1000, 9999),
        ["locale"] = "en",
        ["title"] = "أخصائي",
        ["specialtyId"] = specialtyId,
        ["licenseNumber"] = "٧٧٨٨٩",
        ["branch"] = new Dictionary<string, object?>
        {
            ["nameAr"] = "فرع الدقي",
            ["governorate"] = "الجيزة",
            ["city"] = "الدقي",
            ["addressDetails"] = "٥ شارع التحرير",
            ["phones"] = new object[] { new { number = "01012345678", label = "mobile", isWhatsapp = true } },
        },
    };

    private static MultipartFormDataContent Form(object data, byte[]? license = null)
    {
        var form = new MultipartFormDataContent
        {
            { new StringContent(JsonSerializer.Serialize(data, new JsonSerializerOptions(JsonSerializerDefaults.Web)), Encoding.UTF8, "application/json"), "data" },
        };
        if (license is not null)
        {
            var file = new ByteArrayContent(license);
            file.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
            form.Add(file, "license", "card.jpg");
        }

        return form;
    }

    private static async Task<(HttpStatusCode Status, JsonElement Body)> CreateAsync(HttpClient client, object data, byte[]? license = null)
    {
        using var response = await client.PostAsync("/api/admin/createDoctor", Form(data, license));
        return (response.StatusCode, await Http.BodyAsync(response));
    }

    [Fact]
    public async Task An_admin_adds_an_active_doctor_without_a_trial_who_sets_a_password_from_the_email()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var specialtyId = await TestData.AnySpecialtyAsync(Factory);
        var email = TestData.Email("added");

        var (status, body) = await CreateAsync(asAdmin, Data(email.ToUpperInvariant(), specialtyId), LicenseJpeg);

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal("active", body.Str("status"));
        Assert.Equal(JsonValueKind.Null, body.GetProperty("trial").ValueKind);
        Assert.Equal("هالة محمود", body.Str("fullName"));
        Assert.Equal(email, body.Str("email"));
        Assert.Equal("77889", body.Str("licenseNumber"));
        Assert.Equal("en", body.Str("locale"));
        Assert.Equal("فرع الدقي", body.GetProperty("branch").Str("nameAr"));
        Assert.False(body.GetProperty("emailVerified").GetBoolean());
        var doctorId = Guid.Parse(body.Str("doctorId"));

        var row = await TestData.WithDbAsync(Factory, db => db.Doctors.Include(d => d.User).SingleAsync(d => d.UserId == doctorId));
        Assert.Null(row.User.PasswordHash);
        Assert.Null(row.TrialEndsAt);
        Assert.Equal(admin.Id, row.ApprovedBy);
        Assert.NotNull(row.DefaultBranchId);
        Assert.Equal("doctor", row.User.Role);

        // The audit row names the admin.
        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == AuditActions.DoctorCreated && a.TargetId == doctorId.ToString()));
        Assert.Equal(admin.Id, audit.ActorUserId);
        Assert.Equal("admin", audit.ActorRole);
        Assert.Equal(doctorId, audit.DoctorId);
        Assert.Contains("\"serviceActive\":true", audit.DetailsJson);

        // A welcome waits in the notification centre.
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Notifications.CountAsync(n => n.RecipientUserId == doctorId && n.Type == "doctorWelcome")));

        // No password yet: nobody can sign in.
        var (loginStatus, login) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = email, password = "Anything123" });
        Assert.Equal(HttpStatusCode.Unauthorized, loginStatus);
        Assert.Equal(ErrorCodes.InvalidCredentials, login.Code());

        // The email, in the doctor's language first, carries a password-reset link.
        var message = await TestData.WaitForEmailAsync(Factory, email, "doctorInvite");
        Assert.Contains("https://el3yada.test/reset-password?token=", message.TextBody);
        Assert.StartsWith("Hello Dr", message.TextBody);
        var token = TestData.TokenFrom(message);
        var tokenRow = await TestData.WithDbAsync(Factory, db => db.UserTokens.SingleAsync(t => t.UserId == doctorId));
        Assert.Equal(UserTokenPurposes.PasswordReset, tokenRow.Purpose);
        Assert.InRange(tokenRow.ExpiresAt - tokenRow.CreatedAt, TimeSpan.FromHours(71), TimeSpan.FromHours(73));

        var (resetStatus, _) = await Factory.Client().PostAsync("/api/auth/resetPassword", new { token, newPassword = "Chosen123" });
        Assert.Equal(HttpStatusCode.OK, resetStatus);

        var session = await Factory.LoginAsync(email, "Chosen123");
        Assert.Equal("active", session.Str("doctorStatus"));
        Assert.True(session.GetProperty("emailVerified").GetBoolean());
        using var asDoctor = Factory.Client(session.Str("accessToken"));
        var (meStatus, me) = await asDoctor.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.OK, meStatus);
        // The service is on: sessions carry the platform fee, unlike a trial (0).
        Assert.True(me.GetProperty("fees").GetProperty("examinationFeePiasters").GetInt32() > 0);
    }

    [Fact]
    public async Task A_super_admin_may_too_and_others_may_not()
    {
        var specialtyId = await TestData.AnySpecialtyAsync(Factory);
        var superAdmin = await TestData.CreateAdminAsync(Factory, AdminRoles.SuperAdmin);
        using var asSuperAdmin = await Factory.SignedInClientAsync(superAdmin);
        var (created, _) = await CreateAsync(asSuperAdmin, Data(TestData.Email("bysuper"), specialtyId), LicenseJpeg);
        Assert.Equal(HttpStatusCode.Created, created);

        var doctor = await TestData.CreateDoctorAsync(Factory);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        var refusedEmail = TestData.Email("refused");
        foreach (var user in new[] { doctor, patient, assistant })
        {
            using var client = await Factory.SignedInClientAsync(user);
            var (status, _) = await CreateAsync(client, Data(refusedEmail, specialtyId), LicenseJpeg);
            Assert.Equal(HttpStatusCode.Forbidden, status);
        }

        var (anonymous, _) = await CreateAsync(Factory.Client(), Data(refusedEmail, specialtyId), LicenseJpeg);
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous);
        Assert.False(await TestData.WithDbAsync(Factory, db => db.Users.AnyAsync(u => u.Email == refusedEmail)));
    }

    [Fact]
    public async Task An_email_in_use_is_refused_and_nothing_is_sent()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var existing = await TestData.CreateDoctorAsync(Factory);
        var specialtyId = await TestData.AnySpecialtyAsync(Factory);
        var auditsBefore = await TestData.WithDbAsync(Factory, db => db.AuditLogs.CountAsync(a => a.Action == AuditActions.DoctorCreated));

        var (status, body) = await CreateAsync(asAdmin, Data(existing.Identifier, specialtyId), LicenseJpeg);

        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.EmailAlreadyRegistered, body.Code());
        Assert.Equal(auditsBefore, await TestData.WithDbAsync(Factory, db => db.AuditLogs.CountAsync(a => a.Action == AuditActions.DoctorCreated)));
        await Task.Delay(300);
        Assert.False(Directory.Exists(Factory.MailDirectory)
            && Directory.GetFiles(Factory.MailDirectory, "*-doctorInvite-*.eml").Any(file => MimeKit.MimeMessage.Load(file).To.Mailboxes.Any(m => m.Address == existing.Identifier)));
    }

    [Fact]
    public async Task The_sign_up_field_rules_apply_and_the_license_is_required()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var specialtyId = await TestData.AnySpecialtyAsync(Factory);

        var (noLicense, noLicenseBody) = await CreateAsync(asAdmin, Data(TestData.Email("nolicense"), specialtyId));
        Assert.Equal(HttpStatusCode.BadRequest, noLicense);
        Assert.Equal(ErrorCodes.Required, noLicenseBody.FieldCode("license"));

        var bad = Data(TestData.Email("bad"), specialtyId);
        bad["licenseNumber"] = "x";
        bad["branch"] = new Dictionary<string, object?> { ["nameAr"] = "فرع", ["phones"] = Array.Empty<object>() };
        var (badStatus, badBody) = await CreateAsync(asAdmin, bad, LicenseJpeg);
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidLicenseNumber, badBody.FieldCode("licenseNumber"));
        Assert.Equal(ErrorCodes.Required, badBody.FieldCode("branch.governorate"));
        Assert.Equal(ErrorCodes.PhoneRequired, badBody.FieldCode("branch.phones"));

        var (unknownSpecialty, unknownBody) = await CreateAsync(asAdmin, Data(TestData.Email("nospec"), Guid.NewGuid()), LicenseJpeg);
        Assert.Equal(HttpStatusCode.BadRequest, unknownSpecialty);
        Assert.Equal(ErrorCodes.InvalidSpecialty, unknownBody.FieldCode("specialtyId"));

        // No password or Terms in this form: a password sent anyway is ignored.
        var withPassword = Data(TestData.Email("withpw"), specialtyId);
        withPassword["password"] = "Ignored123";
        var (pwStatus, pwBody) = await CreateAsync(asAdmin, withPassword, LicenseJpeg);
        Assert.Equal(HttpStatusCode.Created, pwStatus);
        var id = Guid.Parse(pwBody.Str("doctorId"));
        Assert.Null(await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == id).Select(u => u.PasswordHash).SingleAsync()));
    }
}
