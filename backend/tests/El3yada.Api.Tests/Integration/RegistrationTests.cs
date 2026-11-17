using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using El3yada.Api.Auth;
using Microsoft.EntityFrameworkCore;
using SkiaSharp;

namespace El3yada.Api.Tests.Integration;

/// <summary>A4 registration, A5 verification, A6/A7, AD2/AD3 review and the license download.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class RegistrationTests(IntegrationHost host)
{
    private static readonly byte[] LicenseJpeg = TestImages.Encode(40, 30, SKEncodedImageFormat.Jpeg);

    private IntegrationFactory Factory => host.Factory;

    private static Dictionary<string, object?> Data(string email, Guid specialtyId, params Guid[] extras) => new()
    {
        ["fullName"] = "سامي  عبد الله",
        ["email"] = email,
        ["phone"] = "010 " + Random.Shared.Next(1000, 9999) + " " + Random.Shared.Next(1000, 9999),
        ["password"] = "Doctor123",
        ["locale"] = "ar",
        ["title"] = "استشاري",
        ["specialtyId"] = specialtyId,
        ["extraSpecialtyIds"] = extras,
        ["licenseNumber"] = "٤٥٦٧٨",
        ["examinationPricePiasters"] = 30000,
        ["branch"] = new Dictionary<string, object?>
        {
            ["nameAr"] = "فرع المعادي",
            ["governorate"] = "القاهرة",
            ["city"] = "المعادي",
            ["addressDetails"] = "١٢ شارع 9، الدور التالت، شقة ٥",
            ["landmark"] = "بجوار المترو",
            ["mapUrl"] = "https://maps.app.goo.gl/Maadi9",
            ["phones"] = new object[]
            {
                new { number = "02 2358 1234", label = "landline", isWhatsapp = false },
                new { number = "01012345678", label = "mobile", isWhatsapp = true },
            },
        },
        ["acceptTerms"] = true,
    };

    private static MultipartFormDataContent Form(object data, byte[]? license = null, string contentType = "application/octet-stream")
    {
        var form = new MultipartFormDataContent
        {
            { new StringContent(JsonSerializer.Serialize(data, new JsonSerializerOptions(JsonSerializerDefaults.Web)), Encoding.UTF8, "application/json"), "data" },
        };
        if (license is not null)
        {
            var file = new ByteArrayContent(license);
            file.Headers.ContentType = new MediaTypeHeaderValue(contentType);
            form.Add(file, "license", "card.jpg");
        }

        return form;
    }

    private async Task<(HttpStatusCode Status, JsonElement Body)> RegisterAsync(object data, byte[]? license = null)
    {
        using var response = await Factory.Client().PostAsync("/api/doctors/completeDoctorRegistration", Form(data, license));
        return (response.StatusCode, await Http.BodyAsync(response));
    }

    private async Task<(HttpStatusCode Status, JsonElement Body)> ResubmitAsync(HttpClient client, object data, byte[]? license = null)
    {
        using var response = await client.PostAsync("/api/doctors/resubmitDoctorRegistration", Form(data, license));
        return (response.StatusCode, await Http.BodyAsync(response));
    }

    [Fact]
    public async Task Registration_opens_the_clinic_at_once_with_a_free_trial()
    {
        var specialties = new[] { await TestData.AnySpecialtyAsync(Factory), await TestData.AnySpecialtyAsync(Factory, 1), await TestData.AnySpecialtyAsync(Factory, 2) };
        var admin = await TestData.CreateAdminAsync(Factory, Auth.AdminRoles.Admin);
        var email = TestData.Email("newdoc");

        var (status, session) = await RegisterAsync(Data(email.ToUpperInvariant(), specialties[0], specialties[1], specialties[2]), LicenseJpeg);

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal("signedIn", session.Str("result"));
        Assert.Equal("doctor", session.Str("role"));
        Assert.Equal("active", session.Str("doctorStatus"));
        var trialDays = await TestData.WithDbAsync(Factory, db => db.AppSettings.Select(s => s.TrialDays).SingleAsync());
        Assert.Equal(trialDays, session.GetProperty("trial").GetProperty("daysLeft").GetInt32());
        Assert.False(session.GetProperty("trial").GetProperty("ended").GetBoolean());
        Assert.False(session.GetProperty("emailVerified").GetBoolean());
        var doctorId = Guid.Parse(session.Str("userId"));
        using var doctor = Factory.Client(session.Str("accessToken"));

        // No approval step: the clinic works straight away.
        var (clinicStatus, clinic) = await doctor.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.OK, clinicStatus);
        Assert.Equal(0, clinic.GetProperty("fees").GetProperty("examinationFeePiasters").GetInt32());
        var (registerStatus, _) = await doctor.GetJsonAsync("/api/patients/register");
        Assert.Equal(HttpStatusCode.OK, registerStatus);

        // The doctor can still read what they sent.
        var (mineStatus, mine) = await doctor.GetJsonAsync("/api/doctors/myRegistration");
        Assert.Equal(HttpStatusCode.OK, mineStatus);
        Assert.Equal("سامي عبد الله", mine.Str("fullName"));
        Assert.Equal(email, mine.Str("email"));
        Assert.Equal("45678", mine.Str("licenseNumber"));
        Assert.Equal("image/jpeg", mine.Str("licenseContentType"));
        Assert.Equal(30000, mine.GetProperty("examinationPricePiasters").GetInt32());
        Assert.Equal(2, mine.GetProperty("extraSpecialtyIds").GetArrayLength());
        var branch = mine.GetProperty("branch");
        Assert.Equal(["+20223581234", "+201012345678"], branch.GetProperty("phones").EnumerateArray().Select(p => p.Str("number")));
        Assert.Equal("١٢ شارع 9، الدور التالت، شقة ٥", branch.Str("addressDetails"));
        Assert.Equal("https://maps.app.goo.gl/Maadi9", branch.Str("mapUrl"));
        Assert.False(mine.TryGetProperty("licenseDocPath", out _));
        using var ownLicense = await doctor.GetAsync("/api/doctors/myRegistration/license");
        Assert.Equal(HttpStatusCode.OK, ownLicense.StatusCode);
        Assert.Equal("no-store", ownLicense.Headers.CacheControl?.ToString());
        Assert.Equal(LicenseJpeg, await ownLicense.Content.ReadAsByteArrayAsync());

        // Stored data: user, doctor, default branch, license file, admin notification, audit, verification email.
        var row = await TestData.WithDbAsync(Factory, db => db.Doctors.Include(d => d.User).SingleAsync(d => d.UserId == doctorId));
        Assert.StartsWith($"doctors/{doctorId}/license/", row.LicenseDocPath);
        Assert.True(File.Exists(Path.Combine(Factory.FilesDirectory, row.LicenseDocPath)));
        Assert.NotNull(row.DefaultBranchId);
        Assert.NotNull(row.User.AcceptedTermsAt);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(n => n.RecipientUserId == admin.Id && n.Type == "doctorRegistrationReceived" && n.DataJson!.Contains(doctorId.ToString()))));
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "doctorRegistrationSubmitted" && a.DoctorId == doctorId)));
        var welcome = await TestData.WithDbAsync(Factory, db => db.Notifications.SingleAsync(n => n.RecipientUserId == doctorId && n.Type == "doctorWelcome"));
        Assert.Contains("فترة تجريبية مجانية", welcome.BodyAr);
        Assert.Equal(DoctorStatuses.Active, row.Status);
        Assert.NotNull(row.ApprovedAt);
        Assert.Null(row.ApprovedBy);
        await TestData.WaitForEmailAsync(Factory, email, "emailVerify");

        // AD2 and AD3 for the admin.
        using var adminClient = await Factory.SignedInClientAsync(admin);
        var (listStatus, list) = await adminClient.GetJsonAsync($"/api/admin/doctorRegistrations?status=all&trial=running&search={Uri.EscapeDataString(email)}");
        Assert.Equal(HttpStatusCode.OK, listStatus);
        var item = Assert.Single(list.GetProperty("items").EnumerateArray());
        Assert.Equal(doctorId.ToString(), item.Str("doctorId"));
        Assert.Equal("القاهرة", item.Str("governorate"));
        var (detailStatus, detail) = await adminClient.GetJsonAsync($"/api/admin/doctorRegistrations/{doctorId}");
        Assert.Equal(HttpStatusCode.OK, detailStatus);
        Assert.Equal("استشاري", detail.GetProperty("registration").Str("title"));

        using var license = await adminClient.GetAsync($"/api/admin/doctorRegistrations/{doctorId}/license");
        Assert.Equal(HttpStatusCode.OK, license.StatusCode);
        Assert.Equal("image/jpeg", license.Content.Headers.ContentType?.MediaType);
        Assert.Equal(LicenseJpeg, await license.Content.ReadAsByteArrayAsync());
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "doctorLicenseViewed" && a.ActorUserId == admin.Id)));

        // Nothing to review: the doctor is not waiting for anyone.
        var (approveStatus, approved) = await adminClient.PostAsync("/api/admin/reviewDoctorRegistration", new { doctorId, decision = "approve" });
        Assert.Equal(HttpStatusCode.Conflict, approveStatus);
        Assert.Equal(ErrorCodes.RegistrationNotPending, approved.Code());

        var (meStatus, me) = await doctor.GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.OK, meStatus);
        Assert.Equal("active", me.Str("doctorStatus"));
        var login = await Factory.LoginAsync(email, "Doctor123");
        Assert.Equal("active", login.Str("doctorStatus"));
    }

    [Fact]
    public async Task A_rejected_doctor_sees_the_reason_and_resubmits()
    {
        var specialty = await TestData.AnySpecialtyAsync(Factory);
        var admin = await TestData.CreateAdminAsync(Factory);
        var email = TestData.Email("rejected");
        var (_, session) = await RegisterAsync(Data(email, specialty), LicenseJpeg);
        var doctorId = Guid.Parse(session.Str("userId"));
        // A doctor who signed up before the free trial replaced approval (spec 6.16) is still waiting for review.
        await TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctorId).ExecuteUpdateAsync(set => set
            .SetProperty(d => d.Status, DoctorStatuses.PendingApproval)
            .SetProperty(d => d.ApprovedAt, (DateTime?)null)
            .SetProperty(d => d.TrialEndsAt, (DateTime?)null)));
        using var doctor = Factory.Client(session.Str("accessToken"));
        using var adminClient = await Factory.SignedInClientAsync(admin);
        var oldPath = await TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctorId).Select(d => d.LicenseDocPath).SingleAsync());

        var (pendingStatus, pending) = await ResubmitAsync(doctor, Data(email, specialty));
        Assert.Equal(HttpStatusCode.Conflict, pendingStatus);
        Assert.Equal(ErrorCodes.RegistrationNotEditable, pending.Code());

        var (noReasonStatus, noReason) = await adminClient.PostAsync("/api/admin/reviewDoctorRegistration", new { doctorId, decision = "reject" });
        Assert.Equal(HttpStatusCode.BadRequest, noReasonStatus);
        Assert.Equal(ErrorCodes.ReasonRequired, noReason.FieldCode("reason"));
        var (rejectStatus, _) = await adminClient.PostAsync("/api/admin/reviewDoctorRegistration",
            new { doctorId, decision = "reject", reason = "صورة الكارنيه غير واضحة" });
        Assert.Equal(HttpStatusCode.OK, rejectStatus);

        // A7: the reason reaches the doctor.
        var (_, me) = await doctor.GetJsonAsync("/api/auth/me");
        Assert.Equal("rejected", me.Str("doctorStatus"));
        Assert.Equal("صورة الكارنيه غير واضحة", me.Str("doctorStatusReason"));
        var notification = await TestData.WithDbAsync(Factory, db => db.Notifications.SingleAsync(n => n.RecipientUserId == doctorId && n.Type == "doctorRegistrationRejected"));
        Assert.Contains("صورة الكارنيه غير واضحة", notification.BodyAr);

        // Edit and resubmit, with a clearer license.
        var changed = Data(email, specialty);
        changed["fullName"] = "سامي عبد الله حسن";
        changed["password"] = null;
        changed["acceptTerms"] = null;
        var png = TestImages.Encode(30, 30, SKEncodedImageFormat.Png);
        var (resubmitStatus, resubmitted) = await ResubmitAsync(doctor, changed, png);

        Assert.Equal(HttpStatusCode.OK, resubmitStatus);
        Assert.Equal("pendingApproval", resubmitted.Str("status"));
        Assert.Equal(JsonValueKind.Null, resubmitted.GetProperty("statusReason").ValueKind);
        Assert.Equal("سامي عبد الله حسن", resubmitted.Str("fullName"));
        Assert.Equal("image/png", resubmitted.Str("licenseContentType"));
        Assert.False(File.Exists(Path.Combine(Factory.FilesDirectory, oldPath)));
        Assert.Equal(2, resubmitted.GetProperty("branch").GetProperty("phones").GetArrayLength());
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(n => n.RecipientUserId == admin.Id && n.Type == "doctorRegistrationResubmitted")));

        var (_, detail) = await adminClient.GetJsonAsync($"/api/admin/doctorRegistrations/{doctorId}");
        var review = Assert.Single(detail.GetProperty("reviews").EnumerateArray());
        Assert.Equal("reject", review.Str("decision"));
        Assert.Equal("صورة الكارنيه غير واضحة", review.Str("reason"));

        // The default branch was updated, not duplicated.
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Branches.CountAsync(b => b.DoctorId == doctorId)));
    }

    [Fact]
    public async Task Every_field_is_checked_with_its_code()
    {
        var specialty = await TestData.AnySpecialtyAsync(Factory);
        var data = Data(TestData.Email(), specialty);
        data["fullName"] = "Sami";
        data["email"] = "not-an-email";
        data["phone"] = "0123";
        data["password"] = "abcdefgh";
        data["licenseNumber"] = "1";
        data["acceptTerms"] = false;
        data["extraSpecialtyIds"] = new[] { specialty };
        data["examinationPricePiasters"] = 10_000_001;
        data["branch"] = new { nameAr = "ف", governorate = "", city = "المعادي", mapUrl = "https://example.com/maps/x", phones = Array.Empty<object>() };

        var (status, body) = await RegisterAsync(data, LicenseJpeg);

        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.ValidationFailed, body.Code());
        Assert.Equal(ErrorCodes.InvalidName, body.FieldCode("fullName"));
        Assert.Equal(ErrorCodes.InvalidEmail, body.FieldCode("email"));
        Assert.Equal(ErrorCodes.InvalidMobile, body.FieldCode("phone"));
        Assert.Equal(ErrorCodes.WeakPassword, body.FieldCode("password"));
        Assert.Equal(ErrorCodes.InvalidLicenseNumber, body.FieldCode("licenseNumber"));
        Assert.Equal(ErrorCodes.TermsNotAccepted, body.FieldCode("acceptTerms"));
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("extraSpecialtyIds"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("examinationPricePiasters"));
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("branch.nameAr"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("branch.governorate"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("branch.addressDetails"));
        Assert.Equal(ErrorCodes.InvalidMapLink, body.FieldCode("branch.mapUrl"));
        Assert.Equal(ErrorCodes.PhoneRequired, body.FieldCode("branch.phones"));
    }

    [Fact]
    public async Task The_license_specialty_and_email_are_checked()
    {
        var specialty = await TestData.AnySpecialtyAsync(Factory);
        var existing = await TestData.CreateDoctorAsync(Factory);

        var (noFileStatus, noFile) = await RegisterAsync(Data(TestData.Email(), specialty));
        var (textStatus, text) = await RegisterAsync(Data(TestData.Email(), specialty), Encoding.UTF8.GetBytes("this is not an image at all"));
        var (specialtyStatus, badSpecialty) = await RegisterAsync(Data(TestData.Email(), Guid.NewGuid()), LicenseJpeg);
        var (takenStatus, taken) = await RegisterAsync(Data(existing.Identifier, specialty), LicenseJpeg);
        var bad = Data(TestData.Email(), specialty);
        bad["branch"] = new { nameAr = "فرع", governorate = "الجيزة", city = "الدقي", addressDetails = "التحرير", phones = new[] { new { number = "999" } } };
        var (phoneStatus, phone) = await RegisterAsync(bad, LicenseJpeg);
        using var json = await Factory.Client().PostAsJsonAsyncRaw("/api/doctors/completeDoctorRegistration", Data(TestData.Email(), specialty));

        Assert.Equal(HttpStatusCode.BadRequest, noFileStatus);
        Assert.Equal(ErrorCodes.Required, noFile.FieldCode("license"));
        Assert.Equal(HttpStatusCode.BadRequest, textStatus);
        Assert.Equal(ErrorCodes.FileTypeNotAllowed, text.FieldCode("license"));
        Assert.Equal(HttpStatusCode.BadRequest, specialtyStatus);
        Assert.Equal(ErrorCodes.InvalidSpecialty, badSpecialty.FieldCode("specialtyId"));
        Assert.Equal(HttpStatusCode.Conflict, takenStatus);
        Assert.Equal(ErrorCodes.EmailAlreadyRegistered, taken.Code());
        Assert.Equal(HttpStatusCode.BadRequest, phoneStatus);
        Assert.Equal(ErrorCodes.InvalidPhone, phone.FieldCode("branch.phones[0].number"));
        Assert.Equal(HttpStatusCode.UnsupportedMediaType, json.StatusCode);
        Assert.Equal(ErrorCodes.UnsupportedMediaType, (await Http.BodyAsync(json)).Code());
    }

    [Fact]
    public async Task The_verification_link_verifies_the_email_and_resend_has_a_cooldown()
    {
        var email = TestData.Email("verify");
        var (_, session) = await RegisterAsync(Data(email, await TestData.AnySpecialtyAsync(Factory)), LicenseJpeg);
        using var doctor = Factory.Client(session.Str("accessToken"));

        var (cooldownStatus, cooldown) = await doctor.PostAsync("/api/auth/resendVerificationEmail");
        var token = TestData.TokenFrom(await TestData.WaitForEmailAsync(Factory, email, "emailVerify"));
        var (verifyStatus, _) = await Factory.Client().PostAsync("/api/auth/verifyEmail", new { token });
        var (_, me) = await doctor.GetJsonAsync("/api/auth/me");
        var (alreadyStatus, already) = await doctor.PostAsync("/api/auth/resendVerificationEmail");

        Assert.Equal(HttpStatusCode.TooManyRequests, cooldownStatus);
        Assert.Equal(ErrorCodes.VerificationEmailCooldown, cooldown.Code());
        Assert.Equal(HttpStatusCode.OK, verifyStatus);
        Assert.True(me.GetProperty("emailVerified").GetBoolean());
        Assert.Equal(HttpStatusCode.Conflict, alreadyStatus);
        Assert.Equal(ErrorCodes.EmailAlreadyVerified, already.Code());
    }

    [Fact]
    public async Task Only_doctors_reach_their_registration()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var client = await Factory.SignedInClientAsync(admin);

        var (status, body) = await client.GetJsonAsync("/api/doctors/myRegistration");

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(ErrorCodes.Forbidden, body.Code());
    }
}
