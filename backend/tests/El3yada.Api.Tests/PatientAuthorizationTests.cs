using System.Net;
using System.Net.Http.Headers;

namespace El3yada.Api.Tests;

/// <summary>Only the patient role reaches /api/patient, and only admins reach /api/admin (spec 9.4, AC-11, AC-12).</summary>
public sealed class PatientAuthorizationTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    public static TheoryData<string> PatientRoutes => new()
    {
        "/api/patient/home",
        "/api/patient/doctors",
        "/api/patient/visits",
        "/api/patient/prescriptions",
        "/api/patient/records",
        "/api/patient/medical-profile",
        "/api/patient/account",
    };

    [Theory]
    [MemberData(nameof(PatientRoutes))]
    public async Task Anonymous_callers_get_401(string route)
    {
        var response = await api.CreateClient().GetAsync(route);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [MemberData(nameof(PatientRoutes))]
    public async Task Other_roles_get_403(string route)
    {
        foreach (var userId in new[] { api.Demo.AdminUserId, api.Demo.DoctorAUserId, api.Demo.AssistantUserId })
        {
            var client = await api.ClientForAsync(userId);
            var response = await client.GetAsync(route);
            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        }
    }

    [Fact]
    public async Task Admin_cannot_read_patient_medical_content()
    {
        // AC-12: an admin JWT on sessions, records or prescriptions is denied.
        var admin = await api.ClientForAsync(api.Demo.AdminUserId);
        foreach (var route in new[]
        {
            $"/api/patient/visits/{api.Demo.VisibleSessionId}",
            $"/api/patient/records/{api.Demo.VisibleRecordId}",
            $"/api/patient/prescriptions/{api.Demo.SentRxId}",
            $"/api/patient/prescriptions/{api.Demo.SentRxId}/pdf",
        })
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await admin.GetAsync(route)).StatusCode);
        }
    }

    [Theory]
    [InlineData("/api/admin/deletion-requests")]
    [InlineData("/api/admin/accounts?phone=01000000002")]
    public async Task Admin_routes_refuse_other_roles(string route)
    {
        foreach (var userId in new[] { api.Demo.PatientUserId, api.Demo.DoctorAUserId, api.Demo.AssistantUserId })
        {
            var client = await api.ClientForAsync(userId);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(route)).StatusCode);
        }
    }

    [Fact]
    public async Task Tampered_token_is_rejected()
    {
        var client = await api.ClientForAsync(api.Demo.PatientUserId);
        var token = client.DefaultRequestHeaders.Authorization!.Parameter!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token[..^4] + "AAAA");

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/patient/home")).StatusCode);
    }

    [Fact]
    public async Task Health_stays_public()
    {
        var response = await api.CreateClient().GetAsync("/api/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
