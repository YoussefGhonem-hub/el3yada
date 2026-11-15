using System.Net;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>The clinic guard (<see cref="ClinicAttribute"/>) and <c>GET /api/clinic/me</c>.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class ClinicAccessTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task Patients_and_admins_are_refused()
    {
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var admin = await TestData.CreateAdminAsync(Factory);

        foreach (var user in new[] { patient, admin })
        {
            using var client = await Factory.SignedInClientAsync(user);
            var (status, body) = await client.GetJsonAsync("/api/clinic/me");
            Assert.Equal(HttpStatusCode.Forbidden, status);
            Assert.Equal(ErrorCodes.Forbidden, body.Code());
        }
    }

    [Theory]
    [InlineData(DoctorStatuses.PendingApproval, ErrorCodes.DoctorPendingApproval)]
    [InlineData(DoctorStatuses.Rejected, ErrorCodes.DoctorRejected)]
    public async Task A_doctor_who_is_not_approved_is_refused(string doctorStatus, string code)
    {
        var doctor = await TestData.CreateDoctorAsync(Factory, doctorStatus);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.GetJsonAsync("/api/clinic/me");

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(code, body.Code());
    }

    [Fact]
    public async Task The_doctor_gets_every_permission_every_branch_and_the_fees()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var second = await TestData.AddBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.GetJsonAsync("/api/clinic/me");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("doctor", body.Str("role"));
        Assert.Equal(DoctorStatuses.Active, body.GetProperty("doctor").Str("status"));
        Assert.Equal(System.Text.Json.JsonValueKind.Null, body.GetProperty("assistant").ValueKind);
        Assert.All(ClinicPermissions.All, key => Assert.True(body.GetProperty("permissions").GetProperty(key).GetBoolean()));
        var branches = body.GetProperty("branches").EnumerateArray().ToList();
        Assert.Equal(2, branches.Count);
        Assert.True(branches[0].GetProperty("isDefault").GetBoolean());
        Assert.Contains(branches, b => b.Str("id") == second.ToString());
        Assert.All(branches, b => Assert.True(b.GetProperty("assigned").GetBoolean()));
        Assert.Equal(branches[0].Str("id"), body.Str("defaultBranchId"));
        var fees = body.GetProperty("fees");
        Assert.True(fees.GetProperty("examinationFeePiasters").GetInt32() > 0);
        Assert.True(fees.GetProperty("maxConsecutiveConsultations").GetInt32() >= 1);
    }

    [Fact]
    public async Task A_suspended_doctor_still_opens_the_clinic()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory, DoctorStatuses.Suspended);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.GetJsonAsync("/api/clinic/me");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(DoctorStatuses.Suspended, body.GetProperty("doctor").Str("status"));
    }

    [Fact]
    public async Task An_assistant_sees_their_doctor_permissions_and_branches()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branchA = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var branchB = await TestData.AddBranchAsync(Factory, doctor.Id);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception, [branchA]);
        using var client = await Factory.SignedInClientAsync(assistant);

        var (status, body) = await client.GetJsonAsync("/api/clinic/me");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("assistant", body.Str("role"));
        Assert.Equal(doctor.Id.ToString(), body.GetProperty("doctor").Str("id"));
        var me = body.GetProperty("assistant");
        Assert.Equal(AssistantPresets.Reception, me.Str("preset"));
        Assert.False(me.GetProperty("allBranches").GetBoolean());
        Assert.Equal([branchA.ToString()], me.GetProperty("branchIds").EnumerateArray().Select(b => b.GetString()!));
        foreach (var key in ClinicPermissions.All)
        {
            Assert.Equal(AssistantPresets.Permissions[AssistantPresets.Reception].Contains(key),
                body.GetProperty("permissions").GetProperty(key).GetBoolean());
        }

        var branches = body.GetProperty("branches").EnumerateArray().ToDictionary(b => b.Str("id"), b => b.GetProperty("assigned").GetBoolean());
        Assert.True(branches[branchA.ToString()]);
        Assert.False(branches[branchB.ToString()]);
    }

    [Fact]
    public async Task Permission_changes_apply_on_the_next_request_without_signing_in_again()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.SessionsCreate]);
        using var client = await Factory.SignedInClientAsync(assistant);
        var (_, before) = await client.GetJsonAsync("/api/clinic/me");
        Assert.True(before.GetProperty("permissions").GetProperty(ClinicPermissions.SessionsCreate).GetBoolean());

        await TestData.SetAssistantPermissionsAsync(Factory, assistant.Id, []);
        var (_, after) = await client.GetJsonAsync("/api/clinic/me");

        Assert.False(after.GetProperty("permissions").GetProperty(ClinicPermissions.SessionsCreate).GetBoolean());
    }

    [Fact]
    public async Task An_assistant_request_marks_them_last_active()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(assistant);

        await client.GetJsonAsync("/api/clinic/me");

        var lastActive = await TestData.WithDbAsync(Factory, db =>
            db.Assistants.Where(a => a.UserId == assistant.Id).Select(a => a.LastActiveAt).SingleAsync());
        Assert.NotNull(lastActive);
    }

    [Fact]
    public async Task An_assistant_of_a_doctor_who_is_suspended_later_still_opens_the_clinic()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(assistant);

        await TestData.SetDoctorStatusAsync(Factory, doctor.Id, DoctorStatuses.Suspended);
        var (status, body) = await client.GetJsonAsync("/api/clinic/me");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(DoctorStatuses.Suspended, body.GetProperty("doctor").Str("status"));
    }
}
