using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// The authorization matrix (spec 9.4, 6.10; Phase 2 doesn't close without it) for every patients, sessions and
/// fee endpoint: no token, patient, admin, assistant without and with the permission, another clinic's record,
/// a suspended doctor (BR-G5), and a branch the assistant isn't assigned to (BR-AS13).
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class PatientsAuthorizationTests(IntegrationHost host)
{
    private const string DoctorOnly = "doctorOnly";

    private IntegrationFactory Factory => host.Factory;

    public static TheoryData<string> Endpoints() => new(Table.Keys);

    [Theory]
    [MemberData(nameof(Endpoints))]
    public async Task Every_caller_gets_the_answer_the_rules_give(string name)
    {
        var endpoint = Table[name];
        var shared = await SharedActors.GetAsync(Factory);
        var m = await Matrix.CreateAsync(Factory, shared);

        // No token.
        var (anonymous, _) = await SendAsync(Factory.Client(), endpoint.Static(m));
        Assert.True(anonymous == HttpStatusCode.Unauthorized, $"{name}, no token: {anonymous}");

        // Patients and admins are not clinic callers (AC-11, AC-12).
        foreach (var (who, client) in new[] { ("patient", shared.Patient), ("admin", shared.Admin) })
        {
            var (status, body) = await SendAsync(client, endpoint.Static(m));
            Assert.True(status == HttpStatusCode.Forbidden && body.Code() == ErrorCodes.Forbidden, $"{name}, {who}: {status} {body}");
        }

        if (endpoint.Permission is null)
        {
            // Any clinic caller: an assistant with no permission at all.
            using var bare = await AssistantAsync(m, []);
            var (status, body) = await SendAsync(bare, endpoint.Static(m));
            Assert.True(IsSuccess(status), $"{name}, assistant with no permissions: {status} {body}");
        }
        else
        {
            // Without the permission (and without any other permission that opens the endpoint).
            var closed = new HashSet<string>([endpoint.Permission, .. endpoint.AlsoAccepted]);
            using var without = await AssistantAsync(m, AllExcept(closed));
            var (status, body) = await SendAsync(without, endpoint.Static(m));
            Assert.True(
                status == HttpStatusCode.Forbidden && body.Code() == ErrorCodes.PermissionDenied && body.Str("permission") == endpoint.Permission,
                $"{name}, assistant without {endpoint.Permission}: {status} {body}");
        }

        if (endpoint.Permission is { } permission && permission != DoctorOnly)
        {
            var assistant = await TestData.CreateAssistantAsync(Factory, m.Doctor.Id, permissions: ClinicPermissions.WithDependencies([permission]));
            using var with = await Factory.SignedInClientAsync(assistant);
            var call = endpoint.Fresh is null ? endpoint.Static(m) : await endpoint.Fresh(m, with);
            var (status, body) = await SendAsync(with, call);
            Assert.True(IsSuccess(status), $"{name}, assistant with {permission}: {status} {body}");
        }

        if (endpoint.Foreign is { } foreign)
        {
            var (status, body) = await SendAsync(m.DoctorClient, foreign(m));
            var code = name == "createSession" ? ErrorCodes.NotLinked : ErrorCodes.NotFound;
            Assert.True(status == HttpStatusCode.NotFound && body.Code() == code, $"{name}, another clinic's record: {status} {body}");
        }

        if (endpoint.OtherBranch is { } otherBranch)
        {
            var assistant = await TestData.CreateAssistantAsync(
                Factory, m.Doctor.Id, permissions: ClinicPermissions.WithDependencies([endpoint.Permission ?? ClinicPermissions.SessionsCreate]), branchIds: [m.Branch]);
            using var scoped = await Factory.SignedInClientAsync(assistant);
            var (status, body) = await SendAsync(scoped, await otherBranch(m));
            Assert.True(status == HttpStatusCode.Forbidden && body.Code() == ErrorCodes.BranchNotAllowed, $"{name}, other branch: {status} {body}");
        }

        // A suspended doctor: blocked actions refuse (BR-G5), everything else still works.
        var suspendedCall = endpoint.Fresh is null ? endpoint.Static(m) : await endpoint.Fresh(m, m.DoctorClient);
        await TestData.SetDoctorStatusAsync(Factory, m.Doctor.Id, DoctorStatuses.Suspended);
        var (suspended, suspendedBody) = await SendAsync(m.DoctorClient, suspendedCall);
        await TestData.SetDoctorStatusAsync(Factory, m.Doctor.Id, DoctorStatuses.Active);
        if (endpoint.BlockedWhileSuspended)
        {
            Assert.True(
                suspended == HttpStatusCode.Forbidden && suspendedBody.Code() == ErrorCodes.DoctorSuspended,
                $"{name}, suspended doctor: {suspended} {suspendedBody}");
            var call = endpoint.Fresh is null ? endpoint.Static(m) : await endpoint.Fresh(m, m.DoctorClient);
            var (status, body) = await SendAsync(m.DoctorClient, call);
            Assert.True(IsSuccess(status), $"{name}, doctor: {status} {body}");
        }
        else
        {
            Assert.True(IsSuccess(suspended), $"{name}, suspended doctor: {suspended} {suspendedBody}");
        }
    }

    [Fact]
    public void The_matrix_covers_every_endpoint_of_the_patients_and_sessions_controllers()
    {
        var actions = new[] { typeof(Controllers.PatientsController), typeof(Controllers.SessionsController), typeof(Controllers.SessionReportsController) }
            .SelectMany(t => t.GetMethods().Where(m => m.DeclaringType == t && m.IsPublic && m.ReturnType == typeof(Task<Microsoft.AspNetCore.Mvc.IActionResult>)))
            .Count();
        Assert.Equal(actions, Table.Count);
    }

    private static bool IsSuccess(HttpStatusCode status) => (int)status is >= 200 and < 300;

    /// <summary>
    /// Every permission except <paramref name="closed"/> and those that need one of them (CK_Assistants_Deps
    /// refuses an assistant with clinicalEditProfile but not clinicalView).
    /// </summary>
    private static HashSet<string> AllExcept(IReadOnlySet<string> closed)
    {
        var keys = ClinicPermissions.All.Where(p => !closed.Contains(p)).ToHashSet();
        while (keys.RemoveWhere(k => ClinicPermissions.Requires.TryGetValue(k, out var needed) && !keys.Contains(needed)) > 0)
        {
        }

        return keys;
    }

    private async Task<HttpClient> AssistantAsync(Matrix m, IEnumerable<string> permissions) =>
        await Factory.SignedInClientAsync(await TestData.CreateAssistantAsync(Factory, m.Doctor.Id, permissions: permissions));

    private static async Task<(HttpStatusCode Status, JsonElement Body)> SendAsync(HttpClient client, Call call)
    {
        using var request = new HttpRequestMessage(call.Method, call.Url);
        if (call.Method == HttpMethod.Post)
        {
            request.Content = JsonContent.Create(call.Body ?? new { });
        }

        using var response = await client.SendAsync(request);
        return (response.StatusCode, await Http.BodyAsync(response));
    }

    public sealed record Call(HttpMethod Method, string Url, object? Body = null);

    private static Call Get(string url) => new(HttpMethod.Get, url);

    private static Call Post(string verb, object body) => new(HttpMethod.Post, verb, body);

    /// <summary>
    /// One endpoint. <c>Static</c> is a valid request on the clinic's own records (refusals never reach the data).
    /// <c>Fresh</c> prepares new data for a write that may run only once (by the caller given). <c>Foreign</c> is
    /// the same request on another clinic's record. <c>OtherBranch</c> uses the branch the scoped assistant
    /// isn't assigned to. <c>Permission</c> null means any clinic caller.
    /// </summary>
    private sealed record Endpoint(
        string? Permission,
        bool BlockedWhileSuspended,
        Func<Matrix, Call> Static,
        Func<Matrix, Call>? Foreign = null,
        Func<Matrix, HttpClient, Task<Call>>? Fresh = null,
        Func<Matrix, Task<Call>>? OtherBranch = null,
        string[]? Also = null)
    {
        public string[] AlsoAccepted => Also ?? [];
    }

    private static readonly Dictionary<string, Endpoint> Table = new()
    {
        ["lookupPhone"] = new(ClinicPermissions.PatientsManage, false,
            _ => Get($"/api/patients/lookupPhone?phone={TestData.Local(TestData.Mobile())}")),
        ["createPatient"] = new(ClinicPermissions.PatientsManage, true,
            _ => Post("/api/patients/createPatient", TestData.PatientBody(TestData.Mobile()))),
        ["getPatient"] = new(null, false,
            m => Get($"/api/patients/{m.PatientId}"),
            m => Get($"/api/patients/{m.ForeignPatientId}")),
        ["updatePatient"] = new(ClinicPermissions.PatientsManage, false,
            m => Post("/api/patients/updatePatient", Identity(m.PatientId)),
            m => Post("/api/patients/updatePatient", Identity(m.ForeignPatientId))),
        ["updatePatientPhone"] = new(ClinicPermissions.PatientsManage, false,
            m => Post("/api/patients/updatePatientPhone", new { patientId = m.PatientId, phone = TestData.Mobile() }),
            m => Post("/api/patients/updatePatientPhone", new { patientId = m.ForeignPatientId, phone = TestData.Mobile() })),
        ["resetPatientPassword"] = new(ClinicPermissions.PatientsResetPassword, false,
            m => Post("/api/patients/resetPatientPassword", new { patientId = m.PatientId }),
            m => Post("/api/patients/resetPatientPassword", new { patientId = m.ForeignPatientId })),
        ["setArchived"] = new(ClinicPermissions.PatientsManage, false,
            m => Post("/api/patients/setArchived", new { patientId = m.PatientId, archived = false }),
            m => Post("/api/patients/setArchived", new { patientId = m.ForeignPatientId, archived = true })),
        ["getMedicalProfile"] = new(ClinicPermissions.ClinicalView, false,
            m => Get($"/api/patients/{m.PatientId}/medicalProfile"),
            m => Get($"/api/patients/{m.ForeignPatientId}/medicalProfile")),
        ["updateMedicalProfile"] = new(ClinicPermissions.ClinicalEditProfile, false,
            m => Post("/api/patients/updateMedicalProfile", new { patientId = m.PatientId, allergies = new[] { "Penicillin" } }),
            m => Post("/api/patients/updateMedicalProfile", new { patientId = m.ForeignPatientId, allergies = new[] { "Penicillin" } })),
        ["register"] = new(null, false, _ => Get("/api/patients/register")),
        // D4 [S]: the whole list with phone numbers, so the doctor only (it answers text/csv).
        ["exportRegister"] = new(DoctorOnly, false, _ => Get("/api/patients/register/export")),
        ["patientSessions"] = new(ClinicPermissions.SessionsCreate, false,
            m => Get($"/api/patients/{m.PatientId}/sessions"),
            m => Get($"/api/patients/{m.ForeignPatientId}/sessions"),
            Also: [ClinicPermissions.ClinicalView]),
        ["newSessionInfo"] = new(ClinicPermissions.SessionsCreate, false,
            m => Get($"/api/sessions/newSessionInfo?patientId={m.PatientId}&branchId={m.Branch}"),
            m => Get($"/api/sessions/newSessionInfo?patientId={m.ForeignPatientId}&branchId={m.Branch}"),
            OtherBranch: m => Task.FromResult(Get($"/api/sessions/newSessionInfo?patientId={m.PatientId}&branchId={m.OtherBranch}"))),
        ["createSession"] = new(ClinicPermissions.SessionsCreate, true,
            // An examination is always allowed, so the same request works every time.
            m => Post("/api/sessions/createSession", TestData.SessionBody(m.PatientId, m.Branch)),
            m => Post("/api/sessions/createSession", TestData.SessionBody(m.ForeignPatientId, m.Branch)),
            OtherBranch: m => Task.FromResult(Post("/api/sessions/createSession", TestData.SessionBody(m.PatientId, m.OtherBranch)))),
        ["getSession"] = new(ClinicPermissions.SessionsCreate, false,
            m => Get($"/api/sessions/{m.SessionId}"),
            m => Get($"/api/sessions/{m.ForeignSessionId}"),
            Also: [ClinicPermissions.ClinicalView, ClinicPermissions.BillingView]),
        ["getPrivateNote"] = new(DoctorOnly, false,
            m => Get($"/api/sessions/{m.SessionId}/privateNote"),
            m => Get($"/api/sessions/{m.ForeignSessionId}/privateNote")),
        ["setPrivateNote"] = new(DoctorOnly, false,
            m => Post("/api/sessions/setPrivateNote", new { sessionId = m.SessionId, text = "ملاحظة" }),
            m => Post("/api/sessions/setPrivateNote", new { sessionId = m.ForeignSessionId, text = "ملاحظة" })),
        ["updateClinical"] = new(DoctorOnly, false,
            m => Post("/api/sessions/updateClinical", new { sessionId = m.SessionId, diagnosis = "نزلة برد" }),
            m => Post("/api/sessions/updateClinical", new { sessionId = m.ForeignSessionId, diagnosis = "نزلة برد" })),
        ["updateAmountCharged"] = new(ClinicPermissions.SessionsCreate, false,
            m => Post("/api/sessions/updateAmountCharged", new { sessionId = m.SessionId, amountChargedPiasters = 1000 }),
            m => Post("/api/sessions/updateAmountCharged", new { sessionId = m.ForeignSessionId, amountChargedPiasters = 1000 }),
            // An assistant may change only the amounts they recorded (BR-S10).
            Fresh: async (m, caller) => Post("/api/sessions/updateAmountCharged", new
            {
                sessionId = await TestData.RecordSessionAsync(caller, m.PatientId, m.Branch), amountChargedPiasters = 1000,
            })),
        ["deleteSession"] = new(ClinicPermissions.SessionsDelete, false,
            m => Post("/api/sessions/deleteSession", new { sessionId = m.SessionId, reason = "خطأ" }),
            m => Post("/api/sessions/deleteSession", new { sessionId = m.ForeignSessionId, reason = "خطأ" }),
            Fresh: async (m, _) => Post("/api/sessions/deleteSession", new { sessionId = await m.NewSessionAsync(m.Branch), reason = "خطأ" }),
            OtherBranch: async m => Post("/api/sessions/deleteSession", new { sessionId = await m.NewSessionAsync(m.OtherBranch), reason = "خطأ" })),
        ["day"] = new(ClinicPermissions.SessionsCreate, false,
            _ => Get("/api/sessions/day"),
            OtherBranch: m => Task.FromResult(Get($"/api/sessions/day?branchId={m.OtherBranch}")),
            Also: [ClinicPermissions.BillingView]),
        ["feeSummary"] = new(ClinicPermissions.BillingView, false, _ => Get("/api/sessions/feeSummary")),
        ["month"] = new(ClinicPermissions.BillingView, false, _ => Get("/api/sessions/month")),
    };

    private static object Identity(Guid patientId) => new { patientId, fullName = "منى حسن", gender = "female", dateOfBirth = "1990-05-01" };

    /// <summary>One clinic for one endpoint's run: two branches, a patient with today's examination.</summary>
    private sealed class Matrix
    {
        public required TestUser Doctor { get; init; }
        public required HttpClient DoctorClient { get; init; }
        public required Guid Branch { get; init; }
        public required Guid OtherBranch { get; init; }
        public required Guid PatientId { get; init; }
        public required Guid SessionId { get; init; }
        public required Guid ForeignPatientId { get; init; }
        public required Guid ForeignSessionId { get; init; }

        /// <summary>A new patient's examination by the doctor: always the latest and from today, so deletable.</summary>
        public async Task<Guid> NewSessionAsync(Guid branchId) =>
            await TestData.RecordSessionAsync(DoctorClient, await TestData.AddPatientViaApiAsync(DoctorClient), branchId);

        public static async Task<Matrix> CreateAsync(IntegrationFactory factory, SharedActors shared)
        {
            var scene = await PatientScene.CreateAsync(factory);
            return new Matrix
            {
                Doctor = scene.Doctor,
                DoctorClient = scene.Client,
                Branch = scene.BranchId,
                OtherBranch = await TestData.AddBranchAsync(factory, scene.Doctor.Id),
                PatientId = scene.PatientId,
                SessionId = scene.SessionId,
                ForeignPatientId = shared.Foreign.PatientId,
                ForeignSessionId = shared.Foreign.SessionId,
            };
        }
    }

    /// <summary>Callers that every run shares: a patient, an admin and another clinic with a patient and a session.</summary>
    private sealed record SharedActors(HttpClient Patient, HttpClient Admin, PatientScene Foreign)
    {
        private static readonly SemaphoreSlim Gate = new(1, 1);
        private static (IntegrationFactory Factory, SharedActors Actors)? _cached;

        public static async Task<SharedActors> GetAsync(IntegrationFactory factory)
        {
            await Gate.WaitAsync();
            try
            {
                if (_cached is { } cached && ReferenceEquals(cached.Factory, factory))
                {
                    return cached.Actors;
                }

                var (patient, _) = await TestData.CreatePatientAsync(factory);
                var admin = await TestData.CreateAdminAsync(factory);
                var actors = new SharedActors(
                    await factory.SignedInClientAsync(patient), await factory.SignedInClientAsync(admin), await PatientScene.CreateAsync(factory));
                _cached = (factory, actors);
                return actors;
            }
            finally
            {
                Gate.Release();
            }
        }
    }
}
