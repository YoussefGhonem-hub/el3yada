using System.Net;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>A8: the reset email for doctors and admins, and the request to the doctor for patients and assistants.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class PasswordResetTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task The_answer_is_the_same_whether_or_not_the_email_exists_and_only_real_accounts_get_mail()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var unknown = TestData.Email("ghost");
        using var client = Factory.Client();

        var (knownStatus, known) = await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = doctor.Identifier.ToUpperInvariant() });
        var (unknownStatus, unknownBody) = await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = unknown });

        Assert.Equal(HttpStatusCode.Accepted, knownStatus);
        Assert.Equal(knownStatus, unknownStatus);
        Assert.Equal(known.ToString(), unknownBody.ToString());
        var mail = await TestData.WaitForEmailAsync(Factory, doctor.Identifier, "passwordReset");
        Assert.Contains("https://el3yada.test/reset-password?token=", mail.TextBody);
        Assert.Contains("إعادة تعيين كلمة المرور", mail.Subject);
        Assert.False(TestData.HasEmail(Factory, unknown));
    }

    [Fact]
    public async Task The_emailed_token_resets_the_password_once_and_signs_out_every_device()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var session = await Factory.LoginAsync(admin.Identifier, admin.Password);
        using var client = Factory.Client();
        await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = admin.Identifier });
        var token = TestData.TokenFrom(await TestData.WaitForEmailAsync(Factory, admin.Identifier, "passwordReset"));

        var (weakStatus, weak) = await client.PostAsync("/api/auth/resetPassword", new { token, newPassword = "weak" });
        var (status, body) = await client.PostAsync("/api/auth/resetPassword", new { token, newPassword = "Reset12345" });
        var (usedStatus, used) = await client.PostAsync("/api/auth/resetPassword", new { token, newPassword = "Reset67890" });

        Assert.Equal(HttpStatusCode.BadRequest, weakStatus);
        Assert.Equal(ErrorCodes.WeakPassword, weak.FieldCode("newPassword"));
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("passwordReset", body.Str("status"));
        Assert.Equal(HttpStatusCode.BadRequest, usedStatus);
        Assert.Equal(ErrorCodes.EmailTokenUsed, used.Code());
        await Factory.LoginAsync(admin.Identifier, "Reset12345");
        var (oldStatus, _) = await Factory.Client(session.Str("accessToken")).GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, oldStatus);
        var (refreshStatus, _) = await client.PostAsync("/api/auth/refresh", new { refreshToken = session.Str("refreshToken") });
        Assert.Equal(HttpStatusCode.Unauthorized, refreshStatus);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "passwordReset" && a.TargetId == admin.Id.ToString())));
    }

    [Fact]
    public async Task Expired_and_unknown_tokens_are_refused()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = Factory.Client();
        await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = doctor.Identifier });
        var token = TestData.TokenFrom(await TestData.WaitForEmailAsync(Factory, doctor.Identifier, "passwordReset"));
        await TestData.WithDbAsync(Factory, db => db.UserTokens.Where(t => t.UserId == doctor.Id)
            .ExecuteUpdateAsync(set => set.SetProperty(t => t.ExpiresAt, DateTime.UtcNow.AddMinutes(-1))));

        var (expiredStatus, expired) = await client.PostAsync("/api/auth/resetPassword", new { token, newPassword = "Reset12345" });
        var (unknownStatus, unknown) = await client.PostAsync("/api/auth/resetPassword", new { token = "nope" + Guid.NewGuid(), newPassword = "Reset12345" });

        Assert.Equal(HttpStatusCode.BadRequest, expiredStatus);
        Assert.Equal(ErrorCodes.EmailTokenExpired, expired.Code());
        Assert.Equal(HttpStatusCode.BadRequest, unknownStatus);
        Assert.Equal(ErrorCodes.EmailTokenInvalid, unknown.Code());
        await Factory.LoginAsync(doctor.Identifier, doctor.Password); // unchanged
    }

    [Fact]
    public async Task A_new_reset_email_replaces_the_previous_link()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = Factory.Client();
        await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = doctor.Identifier });
        var first = TestData.TokenFrom(await TestData.WaitForEmailAsync(Factory, doctor.Identifier, "passwordReset"));
        await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = doctor.Identifier });

        var (status, body) = await client.PostAsync("/api/auth/resetPassword", new { token = first, newPassword = "Reset12345" });

        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.EmailTokenInvalid, body.Code());
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.UserTokens.CountAsync(t => t.UserId == doctor.Id && t.UsedAt == null)));
    }

    [Fact]
    public async Task A_patient_request_notifies_every_linked_doctor_and_their_permitted_assistants()
    {
        var doctorA = await TestData.CreateDoctorAsync(Factory);
        var doctorB = await TestData.CreateDoctorAsync(Factory);
        var allowed = await TestData.CreateAssistantAsync(Factory, doctorA.Id, patientsResetPassword: true);
        var notAllowed = await TestData.CreateAssistantAsync(Factory, doctorA.Id, patientsResetPassword: false);
        var (patient, patientId) = await TestData.CreatePatientAsync(Factory);
        await TestData.LinkAsync(Factory, doctorA.Id, patientId, "منى حسن");
        await TestData.LinkAsync(Factory, doctorB.Id, patientId, "منى حسن");

        var (status, body) = await Factory.Client().PostAsync("/api/auth/requestPatientPasswordReset", new { phone = TestData.Local(patient.Phone!) });

        Assert.Equal(HttpStatusCode.Accepted, status);
        Assert.Equal("requested", body.Str("status"));
        var recipients = await TestData.WithDbAsync(Factory, db => db.Notifications
            .Where(n => n.Type == "patientPasswordResetRequested" && n.DataJson!.Contains(patientId.ToString()))
            .Select(n => n.RecipientUserId).ToListAsync());
        Assert.Equal(new[] { doctorA.Id, doctorB.Id, allowed.Id }.Order(), recipients.Order());
        Assert.DoesNotContain(notAllowed.Id, recipients);
        var row = await TestData.WithDbAsync(Factory, db => db.Notifications.FirstAsync(n => n.RecipientUserId == doctorA.Id));
        Assert.Contains("منى حسن", row.BodyAr);
        Assert.Equal($"/patients/{patientId}", row.Route);
    }

    [Fact]
    public async Task An_assistant_request_goes_to_their_doctor_and_unknown_numbers_get_the_same_answer()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        using var client = Factory.Client();

        var (status, body) = await client.PostAsync("/api/auth/requestPatientPasswordReset", new { phone = assistant.Phone });
        var (unknownStatus, unknownBody) = await client.PostAsync("/api/auth/requestPatientPasswordReset", new { phone = TestData.Mobile() });

        Assert.Equal(HttpStatusCode.Accepted, status);
        Assert.Equal(status, unknownStatus);
        Assert.Equal(body.ToString(), unknownBody.ToString());
        var row = await TestData.WithDbAsync(Factory, db => db.Notifications.SingleAsync(n => n.RecipientUserId == doctor.Id));
        Assert.Equal("assistantPasswordResetRequested", row.Type);
        Assert.Contains("سارة محمود", row.BodyAr);
    }

    [Fact]
    public async Task Patients_and_assistants_get_no_reset_email()
    {
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var email = TestData.Email("patient");
        await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Id == patient.Id).ExecuteUpdateAsync(set => set.SetProperty(u => u.Email, email)));

        var (status, _) = await Factory.Client().PostAsync("/api/auth/requestPasswordResetEmail", new { email });

        Assert.Equal(HttpStatusCode.Accepted, status);
        Assert.Equal(0, await TestData.WithDbAsync(Factory, db => db.UserTokens.CountAsync(t => t.UserId == patient.Id)));
    }
}
