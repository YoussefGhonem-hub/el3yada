using System.Net;
using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>D25 and D26 assistants (spec 6.10, BR-AS1–AS13, AC-19).</summary>
[Collection(IntegrationCollection.Name)]
public sealed class AssistantsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static object NewAssistant(string phone, IReadOnlyCollection<string>? permissions = null, Guid[]? branchIds = null, string fullName = "سارة محمود") => new
    {
        fullName,
        phone,
        allBranches = branchIds is null,
        branchIds,
        permissions = ClinicPermissions.ToMap((permissions ?? AssistantPresets.Permissions[AssistantPresets.Reception]).ToHashSet()),
    };

    [Fact]
    public async Task AC19_three_assistants_get_a_temporary_password_and_must_change_it_and_the_limit_holds()
    {
        var before = await TestData.SetAssistantLimitAsync(Factory, 5);
        try
        {
            var doctor = await TestData.CreateDoctorAsync(Factory);
            using var client = await Factory.SignedInClientAsync(doctor);

            for (var i = 0; i < 3; i++)
            {
                var phone = TestData.Mobile();
                using var response = await client.PostAsync("/api/assistants/createAssistant", JsonContent(NewAssistant(TestData.Local(phone))));
                var body = await Http.BodyAsync(response);
                Assert.Equal(HttpStatusCode.Created, response.StatusCode);
                Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
                var password = body.Str("temporaryPassword");
                Assert.Equal(8, password.Length);
                var assistant = body.GetProperty("assistant");
                Assert.Equal(phone, assistant.Str("phone"));
                Assert.Equal("reception", assistant.Str("preset"));
                Assert.True(assistant.GetProperty("mustChangePassword").GetBoolean());

                var session = await Factory.LoginAsync(phone, password);
                Assert.True(session.GetProperty("mustChangePassword").GetBoolean());
                Assert.Equal("assistant", session.Str("role"));
            }

            var (_, list) = await client.GetJsonAsync("/api/assistants");
            Assert.Equal(3, list.GetProperty("count").GetInt32());
            Assert.Equal(5, list.GetProperty("limit").GetInt32());
            Assert.True(list.GetProperty("canAdd").GetBoolean());

            for (var i = 0; i < 2; i++)
            {
                var (created, _) = await client.PostAsync("/api/assistants/createAssistant", NewAssistant(TestData.Mobile()));
                Assert.Equal(HttpStatusCode.Created, created);
            }

            var (status, refused) = await client.PostAsync("/api/assistants/createAssistant", NewAssistant(TestData.Mobile()));
            Assert.Equal(HttpStatusCode.Conflict, status);
            Assert.Equal(ErrorCodes.AssistantLimitReached, refused.Code());
            (_, list) = await client.GetJsonAsync("/api/assistants");
            Assert.False(list.GetProperty("canAdd").GetBoolean());

            // A disabled assistant still counts; a removed one doesn't.
            var first = list.GetProperty("items")[0].Str("userId");
            await client.PostAsync("/api/assistants/setAssistantStatus", new { assistantId = first, status = "disabled" });
            (status, _) = await client.PostAsync("/api/assistants/createAssistant", NewAssistant(TestData.Mobile()));
            Assert.Equal(HttpStatusCode.Conflict, status);
            await client.PostAsync("/api/assistants/setAssistantStatus", new { assistantId = first, status = "removed" });
            (status, _) = await client.PostAsync("/api/assistants/createAssistant", NewAssistant(TestData.Mobile()));
            Assert.Equal(HttpStatusCode.Created, status);
        }
        finally
        {
            await TestData.SetAssistantLimitAsync(Factory, before);
        }
    }

    [Fact]
    public async Task Create_stores_branches_permissions_with_dependencies_and_the_preset_and_audits_it()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branchA = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        await TestData.AddBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/assistants/createAssistant", new
        {
            fullName = "  منى   سمير ",
            phone = TestData.Local(TestData.Mobile()),
            allBranches = false,
            branchIds = new[] { branchA },
            permissions = new Dictionary<string, bool> { ["scheduleManage"] = true, ["billingPay"] = true, ["chat"] = false },
        });

        Assert.Equal(HttpStatusCode.Created, status);
        var assistant = body.GetProperty("assistant");
        Assert.Equal("منى سمير", assistant.Str("fullName"));
        Assert.Equal("custom", assistant.Str("preset"));
        Assert.False(assistant.GetProperty("allBranches").GetBoolean());
        Assert.Equal([branchA.ToString()], assistant.GetProperty("branchIds").EnumerateArray().Select(b => b.GetString()));
        Assert.Equal("فرع المعادي", assistant.GetProperty("branches")[0].Str("nameAr"));
        var permissions = assistant.GetProperty("permissions");
        foreach (var key in new[] { "scheduleManage", "appointmentsManage", "appointmentsView", "billingPay", "billingView" })
        {
            Assert.True(permissions.GetProperty(key).GetBoolean(), key);
        }

        Assert.False(permissions.GetProperty("chat").GetBoolean());
        Assert.Equal(ClinicPermissions.All.Count, permissions.EnumerateObject().Count());

        var id = Guid.Parse(assistant.Str("userId"));
        var user = await TestData.WithDbAsync(Factory, db => db.Users.SingleAsync(u => u.Id == id));
        Assert.Equal(Roles.Assistant, user.Role);
        Assert.Equal("منى سمير", user.DisplayName);
        Assert.True(user.MustChangePassword);
        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.AssistantCreated));
        Assert.Equal(id.ToString(), audit.TargetId);
        Assert.DoesNotContain("temporaryPassword", audit.DetailsJson!, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Create_checks_the_fields_and_the_branches()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var other = await TestData.CreateDoctorAsync(Factory);
        var otherBranch = await TestData.DefaultBranchAsync(Factory, other.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/assistants/createAssistant", new
        {
            fullName = "سارة", phone = "0123", allBranches = false, permissions = new Dictionary<string, bool> { ["fly"] = true },
        });
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidName, body.FieldCode("fullName"));
        Assert.Equal(ErrorCodes.InvalidMobile, body.FieldCode("phone"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("branchIds"));
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("permissions"));

        (status, body) = await client.PostAsync("/api/assistants/createAssistant", NewAssistant(TestData.Mobile(), branchIds: [otherBranch]));
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidBranch, body.FieldCode("branchIds"));
    }

    [Fact]
    public async Task A_number_can_be_an_assistant_of_one_doctor_only_but_may_be_a_patient()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var other = await TestData.CreateDoctorAsync(Factory);
        var taken = await TestData.CreateAssistantAsync(Factory, other.Id);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/assistants/createAssistant", NewAssistant(TestData.Local(taken.Phone!)));
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.AssistantPhoneTaken, body.Code());

        (status, body) = await client.PostAsync("/api/assistants/createAssistant", NewAssistant(patient.Phone!));
        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal(patient.Phone, body.GetProperty("assistant").Str("phone"));
    }

    [Fact]
    public async Task AC19_disabling_an_assistant_refuses_their_next_request_and_signs_them_out()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        var session = await Factory.LoginAsync(assistant.Identifier, assistant.Password);
        using var assistantClient = Factory.Client(session.Str("accessToken"));
        var (before, _) = await assistantClient.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.OK, before);
        using var doctorClient = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await doctorClient.PostAsync("/api/assistants/setAssistantStatus", new { assistantId = assistant.Id, status = "disabled" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("disabled", body.Str("status"));

        var (next, refused) = await assistantClient.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.Forbidden, next);
        Assert.Equal(ErrorCodes.AccountDisabled, refused.Code());
        var (refresh, refreshBody) = await Factory.Client().PostAsync("/api/auth/refresh", new { refreshToken = session.Str("refreshToken") });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh);
        Assert.Equal(ErrorCodes.RefreshTokenInvalid, refreshBody.Code());
        var (login, loginBody) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = assistant.Identifier, password = assistant.Password });
        Assert.Equal(HttpStatusCode.Forbidden, login);
        Assert.Equal(ErrorCodes.AccountDisabled, loginBody.Code());
        Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.AssistantDisabled));

        // Enabled again, they sign in again.
        (status, _) = await doctorClient.PostAsync("/api/assistants/setAssistantStatus", new { assistantId = assistant.Id, status = "active" });
        Assert.Equal(HttpStatusCode.OK, status);
        await Factory.LoginAsync(assistant.Identifier, assistant.Password);
    }

    [Fact]
    public async Task AC19_permission_changes_apply_on_the_next_request_without_signing_in_again()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        using var assistantClient = await Factory.SignedInClientAsync(assistant);
        using var doctorClient = await Factory.SignedInClientAsync(doctor);
        var (denied, deniedBody) = await assistantClient.GetJsonAsync("/api/prices");
        Assert.Equal(HttpStatusCode.Forbidden, denied);
        Assert.Equal("pricesManage", deniedBody.Str("permission"));

        var withPrices = AssistantPresets.Permissions[AssistantPresets.Reception].Append(ClinicPermissions.PricesManage).ToHashSet();
        var (status, body) = await doctorClient.PostAsync("/api/assistants/updateAssistant", new
        {
            assistantId = assistant.Id, permissions = ClinicPermissions.ToMap(withPrices),
        });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("custom", body.Str("preset"));
        var (allowed, _) = await assistantClient.GetJsonAsync("/api/prices");
        Assert.Equal(HttpStatusCode.OK, allowed);

        (status, body) = await doctorClient.PostAsync("/api/assistants/updateAssistant", new
        {
            assistantId = assistant.Id, permissions = ClinicPermissions.ToMap(AssistantPresets.Permissions[AssistantPresets.Reception]),
        });
        Assert.Equal("reception", body.Str("preset"));
        (denied, _) = await assistantClient.GetJsonAsync("/api/prices");
        Assert.Equal(HttpStatusCode.Forbidden, denied);

        var audit = await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.AssistantPermissionsChanged);
        Assert.Equal(2, audit.Count);
        using var details = JsonDocument.Parse(audit[1].DetailsJson!);
        Assert.Equal(["pricesManage"], details.RootElement.GetProperty("added").EnumerateArray().Select(k => k.GetString()));
        Assert.Equal("reception", details.RootElement.Str("presetBefore"));
        Assert.Equal("custom", details.RootElement.Str("presetAfter"));
    }

    [Fact]
    public async Task Update_changes_the_name_mobile_and_branches()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branchA = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var branchB = await TestData.AddBranchAsync(Factory, doctor.Id);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, branchIds: [branchA]);
        var taken = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);
        var newPhone = TestData.Mobile();

        var (status, body) = await client.PostAsync("/api/assistants/updateAssistant", new { assistantId = assistant.Id, phone = taken.Phone });
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.AssistantPhoneTaken, body.Code());

        (status, body) = await client.PostAsync("/api/assistants/updateAssistant", new
        {
            assistantId = assistant.Id, fullName = "سارة محمود علي", phone = TestData.Local(newPhone), branchIds = new[] { branchA, branchB },
        });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("سارة محمود علي", body.Str("fullName"));
        Assert.Equal(newPhone, body.Str("phone"));
        Assert.Equal(2, body.GetProperty("branchIds").GetArrayLength());

        // They sign in with the new number, and clinic/me shows the new branches.
        var session = await Factory.LoginAsync(newPhone, assistant.Password);
        Assert.Equal("سارة محمود علي", session.Str("displayName"));
        using var assistantClient = Factory.Client(session.Str("accessToken"));
        var (_, me) = await assistantClient.GetJsonAsync("/api/clinic/me");
        Assert.Equal(2, me.GetProperty("assistant").GetProperty("branchIds").GetArrayLength());

        (status, body) = await client.PostAsync("/api/assistants/updateAssistant", new { assistantId = assistant.Id, allBranches = true });
        Assert.True(body.GetProperty("allBranches").GetBoolean());
        Assert.Empty(body.GetProperty("branchIds").EnumerateArray());
        var audit = await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.AssistantUpdated);
        Assert.Equal(2, audit.Count);
        Assert.Contains("phone", audit[1].DetailsJson);
    }

    [Fact]
    public async Task Reset_password_gives_a_new_temporary_password_and_signs_out_everywhere()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        var session = await Factory.LoginAsync(assistant.Identifier, assistant.Password);
        using var assistantClient = Factory.Client(session.Str("accessToken"));
        using var doctorClient = await Factory.SignedInClientAsync(doctor);

        using var response = await doctorClient.PostAsync("/api/assistants/resetAssistantPassword", JsonContent(new { assistantId = assistant.Id }));
        var body = await Http.BodyAsync(response);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        var password = body.Str("temporaryPassword");
        Assert.True(body.GetProperty("assistant").GetProperty("mustChangePassword").GetBoolean());
        var (old, oldBody) = await assistantClient.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.Unauthorized, old);
        Assert.Equal(ErrorCodes.SessionRevoked, oldBody.Code());
        var (refresh, _) = await Factory.Client().PostAsync("/api/auth/refresh", new { refreshToken = session.Str("refreshToken") });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh);
        var (login, _) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = assistant.Identifier, password = assistant.Password });
        Assert.Equal(HttpStatusCode.Unauthorized, login);
        var fresh = await Factory.LoginAsync(assistant.Identifier, password);
        Assert.True(fresh.GetProperty("mustChangePassword").GetBoolean());
        Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.AssistantPasswordReset));
    }

    [Fact]
    public async Task Removing_is_final_keeps_the_history_and_frees_the_number()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        using var assistantClient = await Factory.SignedInClientAsync(assistant);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/assistants/setAssistantStatus", new { assistantId = assistant.Id, status = "removed" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("removed", body.Str("status"));
        Assert.NotEqual(JsonValueKind.Null, body.GetProperty("removedAt").ValueKind);

        var (next, nextBody) = await assistantClient.GetJsonAsync("/api/clinic/me");
        Assert.Equal(HttpStatusCode.Forbidden, next);
        Assert.Equal(ErrorCodes.AccountDisabled, nextBody.Code());
        var (login, _) = await Factory.Client().PostAsync("/api/auth/login", new { identifier = assistant.Identifier, password = assistant.Password });
        Assert.Equal(HttpStatusCode.Unauthorized, login);

        foreach (var request in new (string Url, object Body)[]
        {
            ("/api/assistants/setAssistantStatus", new { assistantId = assistant.Id, status = "active" }),
            ("/api/assistants/updateAssistant", new { assistantId = assistant.Id, fullName = "اسم جديد" }),
            ("/api/assistants/resetAssistantPassword", new { assistantId = assistant.Id }),
        })
        {
            var (refused, refusedBody) = await client.PostAsync(request.Url, request.Body);
            Assert.Equal(HttpStatusCode.Conflict, refused);
            Assert.Equal(ErrorCodes.AssistantRemoved, refusedBody.Code());
        }

        var (_, list) = await client.GetJsonAsync("/api/assistants");
        Assert.DoesNotContain(list.GetProperty("items").EnumerateArray(), a => a.Str("userId") == assistant.Id.ToString());
        (_, list) = await client.GetJsonAsync("/api/assistants?includeRemoved=true");
        Assert.Equal("removed", list.GetProperty("items").EnumerateArray().Single(a => a.Str("userId") == assistant.Id.ToString()).Str("status"));
        var (again, _) = await client.PostAsync("/api/assistants/createAssistant", NewAssistant(assistant.Phone!, fullName: "سارة محمود"));
        Assert.Equal(HttpStatusCode.Created, again);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Assistants.AnyAsync(a => a.UserId == assistant.Id && a.Status == "removed")));
    }

    [Fact]
    public async Task The_doctor_reads_one_assistant_and_another_doctors_assistant_is_not_found()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Clinical);
        var other = await TestData.CreateDoctorAsync(Factory);
        var foreign = await TestData.CreateAssistantAsync(Factory, other.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.GetJsonAsync($"/api/assistants/{assistant.Id}");
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("clinical", body.Str("preset"));
        Assert.True(body.GetProperty("permissions").GetProperty("clinicalView").GetBoolean());

        (status, body) = await client.GetJsonAsync($"/api/assistants/{foreign.Id}");
        Assert.Equal(HttpStatusCode.NotFound, status);
        Assert.Equal(ErrorCodes.NotFound, body.Code());
    }

    private static StringContent JsonContent(object body) =>
        new(JsonSerializer.Serialize(body, new JsonSerializerOptions(JsonSerializerDefaults.Web)), System.Text.Encoding.UTF8, "application/json");
}
