using System.Net;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary><c>POST /api/admin/setDoctorStatus</c>: suspend and reactivate by hand (BR-G4), and what it does to the clinic (BR-G5, BR-G8).</summary>
[Collection(IntegrationCollection.Name)]
public sealed class DoctorStatusTests(IntegrationHost host)
{
    private const string Url = "/api/admin/setDoctorStatus";

    private IntegrationFactory Factory => host.Factory;

    private static object NewPatientBody() =>
        new { fullName = "منى حسن", phone = TestData.Local(TestData.Mobile()), gender = "female", ageYears = 30 };

    [Fact]
    public async Task A_suspension_blocks_new_patients_at_once_for_the_doctor_and_the_assistants_and_reads_still_work()
    {
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        var disabled = await TestData.CreateAssistantAsync(Factory, doctor.Id, status: AssistantStatuses.Disabled);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        // Signed in before the suspension: the tokens they hold see it on their next request.
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);

        var (status, body) = await asAdmin.PostAsync(Url, new { doctorId = doctor.Id, status = "suspended", reason = "  فاتورة   أكتوبر غير مدفوعة " });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(doctor.Id, body.GetProperty("doctorId").GetGuid());
        Assert.Equal("أحمد علي", body.Str("fullName"));
        Assert.Equal(DoctorStatuses.Suspended, body.Str("status"));
        Assert.Equal("فاتورة أكتوبر غير مدفوعة", body.Str("statusReason"));
        Assert.NotEqual(JsonValueKind.Null, body.GetProperty("statusChangedAt").ValueKind);
        foreach (var client in new[] { asDoctor, asAssistant })
        {
            var (meStatus, me) = await client.GetJsonAsync("/api/clinic/me");
            var (createStatus, create) = await client.PostAsync("/api/patients/createPatient", NewPatientBody());
            var (registerStatus, _) = await client.GetJsonAsync("/api/patients/register");

            Assert.Equal(HttpStatusCode.OK, meStatus);
            Assert.Equal(DoctorStatuses.Suspended, me.GetProperty("doctor").Str("status"));
            Assert.Equal(HttpStatusCode.Forbidden, createStatus);
            Assert.Equal(ErrorCodes.DoctorSuspended, create.Code());
            Assert.Equal(HttpStatusCode.OK, registerStatus);
        }

        // The session shows it too (the account state cache was cleared); the reason is for the doctor only.
        var (_, doctorSession) = await asDoctor.GetJsonAsync("/api/auth/me");
        var (_, assistantSession) = await asAssistant.GetJsonAsync("/api/auth/me");
        Assert.Equal(DoctorStatuses.Suspended, doctorSession.Str("doctorStatus"));
        Assert.Equal("فاتورة أكتوبر غير مدفوعة", doctorSession.Str("doctorStatusReason"));
        Assert.Equal(DoctorStatuses.Suspended, assistantSession.Str("doctorStatus"));
        Assert.Equal(JsonValueKind.Null, assistantSession.GetProperty("doctorStatusReason").ValueKind);

        var notified = await TestData.WithDbAsync(Factory, db => db.Notifications
            .Where(n => n.Type == "doctorSuspended" && (n.RecipientUserId == doctor.Id || n.RecipientUserId == assistant.Id || n.RecipientUserId == disabled.Id))
            .ToListAsync());
        Assert.Equal(2, notified.Count);
        Assert.Contains("فاتورة أكتوبر غير مدفوعة", notified.Single(n => n.RecipientUserId == doctor.Id).BodyAr);
        Assert.DoesNotContain("فاتورة", notified.Single(n => n.RecipientUserId == assistant.Id).BodyAr);
        Assert.All(notified, n => Assert.Equal("/home", n.Route));

        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == "doctorSuspended" && a.TargetId == doctor.Id.ToString()));
        Assert.Equal(admin.Id, audit.ActorUserId);
        Assert.Equal(Roles.Admin, audit.ActorRole);
        Assert.Equal("doctor", audit.TargetType);
        Assert.Equal(doctor.Id, audit.DoctorId);
        var details = JsonDocument.Parse(audit.DetailsJson!).RootElement;
        Assert.Equal(DoctorStatuses.Active, details.Str("before"));
        Assert.Equal(DoctorStatuses.Suspended, details.Str("after"));
        Assert.Equal("فاتورة أكتوبر غير مدفوعة", details.Str("reason"));
    }

    [Fact]
    public async Task Reactivating_opens_the_clinic_again_and_clears_the_reason()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var doctor = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.Suspended, reason: "فاتورة غير مدفوعة");
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);
        var (blocked, _) = await asAssistant.PostAsync("/api/patients/createPatient", NewPatientBody());

        var (status, body) = await asAdmin.PostAsync(Url, new { doctorId = doctor.Id, status = "active", reason = "تم السداد" });

        Assert.Equal(HttpStatusCode.Forbidden, blocked);
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(DoctorStatuses.Active, body.Str("status"));
        Assert.Equal(JsonValueKind.Null, body.GetProperty("statusReason").ValueKind);
        var (doctorCreate, _) = await asDoctor.PostAsync("/api/patients/createPatient", NewPatientBody());
        var (assistantCreate, _) = await asAssistant.PostAsync("/api/patients/createPatient", NewPatientBody());
        Assert.Equal(HttpStatusCode.Created, doctorCreate);
        Assert.Equal(HttpStatusCode.Created, assistantCreate);
        var (_, session) = await asDoctor.GetJsonAsync("/api/auth/me");
        Assert.Equal(DoctorStatuses.Active, session.Str("doctorStatus"));

        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.SingleAsync(a => a.Action == "doctorReactivated" && a.TargetId == doctor.Id.ToString()));
        Assert.Equal("تم السداد", JsonDocument.Parse(audit.DetailsJson!).RootElement.Str("reason"));
        var notified = await TestData.WithDbAsync(Factory, db => db.Notifications
            .Where(n => n.Type == "doctorReactivated" && (n.RecipientUserId == doctor.Id || n.RecipientUserId == assistant.Id))
            .CountAsync());
        Assert.Equal(2, notified);

        // The admin's rows belong to AD15, not the clinic's activity log (D27).
        var (_, activity) = await asDoctor.GetJsonAsync("/api/clinic/activity?pageSize=100");
        Assert.DoesNotContain(activity.GetProperty("items").EnumerateArray(), row => row.Str("action") == "doctorReactivated");
        var (_, adminAudit) = await asAdmin.GetJsonAsync($"/api/admin/auditLogs?doctorId={doctor.Id}&action=doctorReactivated");
        Assert.Equal(1, adminAudit.GetProperty("totalCount").GetInt32());
    }

    [Theory]
    [InlineData(DoctorStatuses.PendingApproval, "suspended")]
    [InlineData(DoctorStatuses.PendingApproval, "active")]
    [InlineData(DoctorStatuses.Rejected, "suspended")]
    [InlineData(DoctorStatuses.Disabled, "suspended")]
    [InlineData(DoctorStatuses.Disabled, "active")]
    public async Task Only_an_active_doctor_is_suspended_and_only_a_suspended_one_reactivated(string current, string target)
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var doctor = await TestData.CreateDoctorAsync(Factory, current);
        using var client = await Factory.SignedInClientAsync(admin);

        var (status, body) = await client.PostAsync(Url, new { doctorId = doctor.Id, status = target, reason = "سبب الاختبار" });

        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.DoctorStatusNotChangeable, body.Code());
        Assert.Equal(current, body.Str("status"));
        Assert.Equal(current, await TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctor.Id).Select(d => d.Status).SingleAsync()));
    }

    [Fact]
    public async Task Asking_for_the_status_the_doctor_has_changes_nothing()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(admin);

        var (status, body) = await client.PostAsync(Url, new { doctorId = doctor.Id, status = "active", reason = "لا شيء" });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(DoctorStatuses.Active, body.Str("status"));
        Assert.False(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.TargetId == doctor.Id.ToString() && a.Action == "doctorReactivated")));
        Assert.False(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(n => n.RecipientUserId == doctor.Id)));
    }

    [Fact]
    public async Task A_reason_is_required_both_ways_and_only_suspended_or_active_is_accepted()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(admin);

        var (noReason, noReasonBody) = await client.PostAsync(Url, new { doctorId = doctor.Id, status = "suspended" });
        var (shortReason, shortReasonBody) = await client.PostAsync(Url, new { doctorId = doctor.Id, status = "active", reason = " ab " });
        var (longReason, longReasonBody) = await client.PostAsync(Url, new { doctorId = doctor.Id, status = "suspended", reason = new string('س', 501) });
        var (disable, disableBody) = await client.PostAsync(Url, new { doctorId = doctor.Id, status = "disabled", reason = "حساب مكرر" });
        var (noDoctor, noDoctorBody) = await client.PostAsync(Url, new { status = "suspended", reason = "حساب مكرر" });

        Assert.All(new[] { noReason, shortReason, longReason, disable, noDoctor }, s => Assert.Equal(HttpStatusCode.BadRequest, s));
        Assert.Equal(ErrorCodes.ReasonRequired, noReasonBody.FieldCode("reason"));
        Assert.Equal(ErrorCodes.ReasonRequired, shortReasonBody.FieldCode("reason"));
        Assert.Equal(ErrorCodes.TooLong, longReasonBody.FieldCode("reason"));
        Assert.Equal(ErrorCodes.InvalidValue, disableBody.FieldCode("status"));
        Assert.Equal(ErrorCodes.Required, noDoctorBody.FieldCode("doctorId"));
        Assert.Equal(DoctorStatuses.Active, await TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctor.Id).Select(d => d.Status).SingleAsync()));
    }

    [Fact]
    public async Task An_unknown_doctor_or_another_account_is_not_found()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(admin);

        foreach (var id in new[] { Guid.NewGuid(), assistant.Id, admin.Id })
        {
            var (status, body) = await client.PostAsync(Url, new { doctorId = id, status = "suspended", reason = "سبب الاختبار" });
            Assert.Equal(HttpStatusCode.NotFound, status);
            Assert.Equal(ErrorCodes.NotFound, body.Code());
        }
    }
}
