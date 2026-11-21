using System.Net;
using System.Net.Http.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// Phase 8 security review, as a sweep over every route the API maps (so a new endpoint is covered the day it is
/// added): nothing is open without a sign-in unless it is marked anonymous on purpose, and an admin (BR-REV1, spec 9.4)
/// never reaches a clinical, patient or clinic-money endpoint.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed partial class SecuritySweepTests(IntegrationHost host)
{
    /// <summary>Anonymous on purpose: sign-in and sign-up, password reset, public settings, catalogs, health, dev tools.</summary>
    private static readonly string[] AnonymousPrefixes =
    [
        "/.well-known/", "/openapi/", "/api/auth/", "/api/settings", "/api/catalog", "/api/specialties", "/api/health", "/api/dev/", "/api/doctors/completeDoctorRegistration",
    ];

    /// <summary>What an admin must never open: the clinic, its patients and money, the patients' own app, chats.</summary>
    private static readonly string[] AdminForbiddenPrefixes =
    [
        "/api/patients", "/api/sessions", "/api/staff/", "/api/patient/", "/api/billing", "/api/dashboard", "/api/revenue",
        "/api/branches", "/api/prices", "/api/assistants", "/api/clinic",
    ];

    public sealed record Route(string Method, string Path);

    private IEnumerable<Route> Routes()
    {
        var endpoints = host.Factory.Services.GetRequiredService<EndpointDataSource>().Endpoints.OfType<RouteEndpoint>();
        foreach (var endpoint in endpoints)
        {
            var path = "/" + endpoint.RoutePattern.RawText!.TrimStart('/');
            if (path.StartsWith("/hubs", StringComparison.Ordinal)) continue;
            var methods = endpoint.Metadata.GetMetadata<HttpMethodMetadata>()?.HttpMethods ?? ["GET"];
            foreach (var method in methods)
            {
                yield return new Route(method, Fill(path));
            }
        }
    }

    // Route parameters ({id}, {id:guid}) become a well-formed value; the request is refused before it is read.
    private static string Fill(string path) => Param().Replace(path, m => m.Value.Contains(":guid") || m.Value.Contains("id", StringComparison.OrdinalIgnoreCase)
        ? Guid.Empty.ToString() : "1");

    [GeneratedRegex(@"\{[^}]+\}")]
    private static partial Regex Param();

    private static async Task<HttpStatusCode> SendAsync(HttpClient client, Route route)
    {
        using var request = new HttpRequestMessage(new HttpMethod(route.Method), route.Path);
        if (route.Method is "POST" or "PUT" or "PATCH") request.Content = JsonContent.Create(new { });
        using var response = await client.SendAsync(request);
        if (response.StatusCode != HttpStatusCode.UnsupportedMediaType) return response.StatusCode;

        // An upload route: ask again the way it expects (multipart), so the answer comes from the access check.
        using var upload = new HttpRequestMessage(new HttpMethod(route.Method), route.Path) { Content = new MultipartFormDataContent() };
        using var second = await client.SendAsync(upload);
        return second.StatusCode;
    }

    [Fact]
    public async Task The_sweep_sees_the_api()
    {
        Assert.True(Routes().Count() > 150);
        await Task.CompletedTask;
    }

    [Fact]
    public async Task Without_a_token_only_the_public_routes_answer()
    {
        var anonymous = host.Factory.Client();
        var open = new List<string>();
        foreach (var route in Routes())
        {
            if (AnonymousPrefixes.Any(p => route.Path.StartsWith(p, StringComparison.Ordinal))) continue;
            var status = await SendAsync(anonymous, route);
            if (status != HttpStatusCode.Unauthorized) open.Add($"{route.Method} {route.Path} -> {(int)status}");
        }

        Assert.True(open.Count == 0, "Reachable without signing in:\n" + string.Join("\n", open));
    }

    [Fact]
    public async Task An_admin_never_reaches_clinic_patient_or_money_routes()
    {
        var admin = await TestData.CreateAdminAsync(host.Factory);
        var client = await host.Factory.SignedInClientAsync(admin);
        var reached = new List<string>();
        foreach (var route in Routes())
        {
            if (!AdminForbiddenPrefixes.Any(p => route.Path.StartsWith(p, StringComparison.Ordinal))) continue;
            var status = await SendAsync(client, route);
            if (status != HttpStatusCode.Forbidden) reached.Add($"{route.Method} {route.Path} -> {(int)status}");
        }

        Assert.True(reached.Count == 0, "An admin was not refused with 403:\n" + string.Join("\n", reached));
    }

    [Fact]
    public async Task A_patient_never_reaches_clinic_admin_or_money_routes()
    {
        var (patient, _) = await TestData.CreatePatientAsync(host.Factory);
        var client = await host.Factory.SignedInClientAsync(patient);
        var reached = new List<string>();
        foreach (var route in Routes())
        {
            var isStaffArea = route.Path.StartsWith("/api/admin", StringComparison.Ordinal)
                || AdminForbiddenPrefixes.Where(p => p != "/api/patient/").Any(p => route.Path.StartsWith(p, StringComparison.Ordinal));
            if (!isStaffArea) continue;
            var status = await SendAsync(client, route);
            if (status != HttpStatusCode.Forbidden) reached.Add($"{route.Method} {route.Path} -> {(int)status}");
        }

        Assert.True(reached.Count == 0, "A patient was not refused with 403:\n" + string.Join("\n", reached));
    }
}

