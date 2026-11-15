using System.Net;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// Spec 9.4 authorization for every branches, prices, profile, assistants and activity endpoint: each role, each
/// assistant permission, the assistant's branches (BR-AS13), another doctor's records, and suspension (BR-G5).
/// Phase 2 does not close without these. The bodies are valid, so every refusal comes from the access checks.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class ClinicAdminAuthorizationTests(IntegrationHost host)
{
    private static Task<World>? _world;

    private IntegrationFactory Factory => host.Factory;

    /// <summary>Who may call: any doctor or assistant, the doctor only, or the doctor and assistants with the permission.</summary>
    public enum Access
    {
        AnyClinic,
        DoctorOnly,
        Permission,
    }

    /// <summary>The records a call points at: a branch and an assistant.</summary>
    public sealed record Target(Guid BranchId, Guid AssistantId);

    public sealed record Call(HttpMethod Method, string Url, object? Body = null);

    /// <summary>
    /// <paramref name="Records"/>: the call points at a branch or an assistant, so another doctor's is 404.
    /// <paramref name="BranchScoped"/>: an assistant may use it only in their branches.
    /// </summary>
    public sealed record Endpoint(
        string Name, Access Access, string? Permission, bool Records, bool BranchScoped, Func<Clinic, Target, Call> Build);

    private static readonly Endpoint[] Endpoints =
    [
        new("listBranches", Access.AnyClinic, null, false, false, (_, _) => Get("/api/branches")),
        new("getBranch", Access.AnyClinic, null, true, false, (_, t) => Get($"/api/branches/{t.BranchId}")),
        new("createBranch", Access.DoctorOnly, null, false, false, (_, _) => Post("/api/branches/createBranch", TestData.NewBranchBody())),
        new("updateBranch", Access.DoctorOnly, null, true, false,
            (_, t) => Post("/api/branches/updateBranch", new { branchId = t.BranchId, info = new { nameAr = "فرع المعادي" } })),
        new("updateBranchHours", Access.Permission, ClinicPermissions.ScheduleManage, true, true,
            (_, t) => Post("/api/branches/updateBranchHours", new
            {
                branchId = t.BranchId, periods = new[] { new { weekday = 6, startLocal = "10:00", endLocal = "14:00" } },
            })),
        new("setBranchStatus", Access.DoctorOnly, null, true, false,
            (_, t) => Post("/api/branches/setBranchStatus", new { branchId = t.BranchId, status = "active" })),
        new("setDefaultBranch", Access.DoctorOnly, null, true, false,
            (c, t) => Post("/api/branches/setDefaultBranch", new { branchId = t.BranchId })),
        new("getPrices", Access.Permission, ClinicPermissions.PricesManage, false, false, (_, _) => Get("/api/prices")),
        new("updateDoctorPrices", Access.Permission, ClinicPermissions.PricesManage, false, false,
            (_, _) => Post("/api/prices/updatePrices", new { examinationPricePiasters = 30000, consultationPricePiasters = 15000 })),
        new("updateBranchPrices", Access.Permission, ClinicPermissions.PricesManage, true, true,
            (_, t) => Post("/api/prices/updatePrices", new { branchId = t.BranchId, examinationPricePiasters = 35000 })),
        new("getProfile", Access.DoctorOnly, null, false, false, (_, _) => Get("/api/doctor/profile")),
        new("updateProfile", Access.DoctorOnly, null, false, false,
            (c, _) => Post("/api/doctor/updateProfile", new { fullName = "أحمد علي", title = "أخصائي", specialtyId = c.SpecialtyId })),
        new("listAssistants", Access.DoctorOnly, null, false, false, (_, _) => Get("/api/assistants")),
        new("getAssistant", Access.DoctorOnly, null, true, false, (_, t) => Get($"/api/assistants/{t.AssistantId}")),
        new("createAssistant", Access.DoctorOnly, null, false, false,
            (_, _) => Post("/api/assistants/createAssistant", new
            {
                fullName = "سارة محمود", phone = TestData.Mobile(), allBranches = true,
                permissions = new Dictionary<string, bool> { [ClinicPermissions.Chat] = true },
            })),
        new("updateAssistant", Access.DoctorOnly, null, true, false,
            (_, t) => Post("/api/assistants/updateAssistant", new { assistantId = t.AssistantId, fullName = "هدى كمال" })),
        new("resetAssistantPassword", Access.DoctorOnly, null, true, false,
            (_, t) => Post("/api/assistants/resetAssistantPassword", new { assistantId = t.AssistantId })),
        new("setAssistantStatus", Access.DoctorOnly, null, true, false,
            (_, t) => Post("/api/assistants/setAssistantStatus", new { assistantId = t.AssistantId, status = "active" })),
        new("getClinicActivity", Access.DoctorOnly, null, false, false, (_, _) => Get("/api/clinic/activity")),
    ];

    public static TheoryData<string> All => new(Endpoints.Select(e => e.Name));

    public static TheoryData<string> WithRecords => new(Endpoints.Where(e => e.Records).Select(e => e.Name));

    public static TheoryData<string> BranchScoped => new(Endpoints.Where(e => e.BranchScoped).Select(e => e.Name));

    [Theory]
    [MemberData(nameof(All))]
    public async Task No_token_is_401(string name)
    {
        var world = await WorldAsync();
        var (status, body) = await SendAsync(Factory.Client(), Build(name, world.Active));

        Assert.Equal(HttpStatusCode.Unauthorized, status);
        Assert.Equal(ErrorCodes.Unauthenticated, body.Code());
    }

    [Theory]
    [MemberData(nameof(All))]
    public async Task Patients_and_admins_get_FORBIDDEN(string name)
    {
        var world = await WorldAsync();
        foreach (var client in new[] { world.Patient, world.Admin })
        {
            var (status, body) = await SendAsync(client, Build(name, world.Active));

            Assert.Equal(HttpStatusCode.Forbidden, status);
            Assert.Equal(ErrorCodes.Forbidden, body.Code());
        }
    }

    [Theory]
    [MemberData(nameof(All))]
    public async Task The_doctor_is_allowed(string name)
    {
        var world = await WorldAsync();
        var (status, body) = await SendAsync(world.Active.Doctor, Build(name, world.Active));

        AssertSuccess(status, body);
    }

    [Theory]
    [MemberData(nameof(All))]
    public async Task A_suspended_doctor_is_still_allowed(string name)
    {
        var world = await WorldAsync();
        var (status, body) = await SendAsync(world.Suspended.Doctor, Build(name, world.Suspended));

        AssertSuccess(status, body);
    }

    [Theory]
    [MemberData(nameof(All))]
    public async Task An_assistant_without_permissions_gets_PERMISSION_DENIED_with_the_key(string name)
    {
        var world = await WorldAsync();
        var endpoint = Endpoints.Single(e => e.Name == name);
        var (status, body) = await SendAsync(world.Active.NoPermissions, Build(name, world.Active));

        if (endpoint.Access == Access.AnyClinic)
        {
            AssertSuccess(status, body);
            return;
        }

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(ErrorCodes.PermissionDenied, body.Code());
        Assert.Equal(endpoint.Access == Access.DoctorOnly ? "doctorOnly" : endpoint.Permission, body.Str("permission"));
    }

    [Theory]
    [MemberData(nameof(All))]
    public async Task An_assistant_with_every_permission_still_cannot_use_doctor_only_endpoints(string name)
    {
        var world = await WorldAsync();
        var endpoint = Endpoints.Single(e => e.Name == name);
        foreach (var clinic in new[] { world.Active, world.Suspended })
        {
            var (status, body) = await SendAsync(clinic.EveryPermission, Build(name, clinic));

            if (endpoint.Access == Access.DoctorOnly)
            {
                Assert.Equal(HttpStatusCode.Forbidden, status);
                Assert.Equal(ErrorCodes.PermissionDenied, body.Code());
                Assert.Equal("doctorOnly", body.Str("permission"));
            }
            else
            {
                // BR-G5 doesn't block schedules or prices, so a suspended clinic's assistant passes too.
                AssertSuccess(status, body);
            }
        }
    }

    [Theory]
    [MemberData(nameof(BranchScoped))]
    public async Task An_assistant_works_only_in_their_branches(string name)
    {
        var world = await WorldAsync();
        var clinic = world.Active;

        var (own, ownBody) = await SendAsync(clinic.BranchA, Build(name, clinic, clinic.Default with { BranchId = clinic.BranchAId }));
        var (other, otherBody) = await SendAsync(clinic.BranchA, Build(name, clinic, clinic.Default with { BranchId = clinic.BranchBId }));

        AssertSuccess(own, ownBody);
        Assert.Equal(HttpStatusCode.Forbidden, other);
        Assert.Equal(ErrorCodes.BranchNotAllowed, otherBody.Code());
    }

    [Theory]
    [MemberData(nameof(WithRecords))]
    public async Task Another_doctors_branch_or_assistant_is_not_found(string name)
    {
        var world = await WorldAsync();
        var foreign = new Target(world.Suspended.BranchAId, world.Suspended.TargetAssistantId);

        var (status, body) = await SendAsync(world.Active.Doctor, Build(name, world.Active, foreign));

        Assert.Equal(HttpStatusCode.NotFound, status);
        Assert.Equal(ErrorCodes.NotFound, body.Code());

        // An assistant who works in every branch gets the same answer.
        var endpoint = Endpoints.Single(e => e.Name == name);
        if (endpoint.Access != Access.DoctorOnly)
        {
            (status, body) = await SendAsync(world.Active.EveryPermission, Build(name, world.Active, foreign));
            Assert.Equal(HttpStatusCode.NotFound, status);
            Assert.Equal(ErrorCodes.NotFound, body.Code());
        }
    }

    private static Call Build(string name, Clinic clinic, Target? target = null) =>
        Endpoints.Single(e => e.Name == name).Build(clinic, target ?? clinic.Default);

    private static Call Get(string url) => new(HttpMethod.Get, url);

    private static Call Post(string url, object body) => new(HttpMethod.Post, url, body);

    private static Task<(HttpStatusCode Status, JsonElement Body)> SendAsync(HttpClient client, Call call) =>
        call.Method == HttpMethod.Get ? client.GetJsonAsync(call.Url) : client.PostAsync(call.Url, call.Body);

    private static void AssertSuccess(HttpStatusCode status, JsonElement body) =>
        Assert.True(status is HttpStatusCode.OK or HttpStatusCode.Created, $"{(int)status} {body}");

    private Task<World> WorldAsync() => _world ??= World.CreateAsync(Factory);

    /// <summary>One clinic and the people who call into it.</summary>
    public sealed record Clinic(
        HttpClient Doctor, HttpClient NoPermissions, HttpClient EveryPermission, HttpClient BranchA,
        Guid BranchAId, Guid BranchBId, Guid TargetAssistantId, Guid SpecialtyId)
    {
        /// <summary>The default branch, and an assistant no test signs in as (resetAssistantPassword signs them out).</summary>
        public Target Default => new(BranchAId, TargetAssistantId);

        public static async Task<Clinic> CreateAsync(IntegrationFactory factory, string status)
        {
            var doctor = await TestData.CreateDoctorAsync(factory);
            var branchA = await TestData.DefaultBranchAsync(factory, doctor.Id);
            var branchB = await TestData.AddBranchAsync(factory, doctor.Id);
            var none = await TestData.CreateAssistantAsync(factory, doctor.Id, permissions: []);
            var every = await TestData.CreateAssistantAsync(factory, doctor.Id, permissions: ClinicPermissions.All);
            var scoped = await TestData.CreateAssistantAsync(
                factory, doctor.Id, branchIds: [branchA],
                permissions: ClinicPermissions.WithDependencies([ClinicPermissions.ScheduleManage, ClinicPermissions.PricesManage]));
            var target = await TestData.CreateAssistantAsync(factory, doctor.Id);
            var clinic = new Clinic(
                await factory.SignedInClientAsync(doctor), await factory.SignedInClientAsync(none),
                await factory.SignedInClientAsync(every), await factory.SignedInClientAsync(scoped),
                branchA, branchB, target.Id, await TestData.AnySpecialtyAsync(factory));
            if (status != DoctorStatuses.Active)
            {
                // Suspension (Phase 7) is read from the database on each request, so it applies to these sessions.
                await TestData.SetDoctorStatusAsync(factory, doctor.Id, status);
            }

            return clinic;
        }
    }

    /// <summary>An active clinic, a suspended clinic, a patient and an admin.</summary>
    public sealed record World(Clinic Active, Clinic Suspended, HttpClient Patient, HttpClient Admin)
    {
        public static async Task<World> CreateAsync(IntegrationFactory factory)
        {
            var (patient, _) = await TestData.CreatePatientAsync(factory);
            var admin = await TestData.CreateAdminAsync(factory);
            return new World(
                await Clinic.CreateAsync(factory, DoctorStatuses.Active),
                await Clinic.CreateAsync(factory, DoctorStatuses.Suspended),
                await factory.SignedInClientAsync(patient),
                await factory.SignedInClientAsync(admin));
        }
    }
}
