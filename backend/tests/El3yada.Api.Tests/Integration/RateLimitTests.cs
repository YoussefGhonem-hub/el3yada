using System.Net;

namespace El3yada.Api.Tests.Integration;

/// <summary>The built-in rate limiter on the public endpoints (spec section 12), with low limits on its own API instance.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class RateLimitTests(IntegrationHost host)
{
    [Fact]
    public async Task Login_over_the_limit_gets_429_with_the_code_and_Retry_After()
    {
        await using var factory = new IntegrationFactory(host.Database.ConnectionString, new Dictionary<string, string?>
        {
            ["RateLimits:LoginPerMinute"] = "3",
        });
        using var client = factory.Client();
        var body = new { identifier = TestData.Email(), password = "Wrong1234" };

        for (var i = 0; i < 3; i++)
        {
            var (status, _) = await client.PostAsync("/api/auth/login", body);
            Assert.Equal(HttpStatusCode.Unauthorized, status);
        }

        using var limited = await client.PostAsJsonAsyncRaw("/api/auth/login", body);
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.Equal("application/problem+json", limited.Content.Headers.ContentType?.MediaType);
        Assert.Equal(ErrorCodes.TooManyAttempts, (await Http.BodyAsync(limited)).Code());
        Assert.NotNull(limited.Headers.RetryAfter);

        // Other endpoints have their own limits.
        var (settingsStatus, _) = await client.GetJsonAsync("/api/settings/public");
        Assert.Equal(HttpStatusCode.OK, settingsStatus);
    }

    [Fact]
    public async Task Forgot_password_is_limited_per_IP_and_per_number()
    {
        await using var factory = new IntegrationFactory(host.Database.ConnectionString, new Dictionary<string, string?>
        {
            ["RateLimits:PasswordResetPer15Minutes"] = "5",
            ["RateLimits:PasswordResetPerIdentifierPerHour"] = "2",
        });
        using var client = factory.Client();
        var phone = TestData.Mobile();

        var first = await client.PostAsync("/api/auth/requestPatientPasswordReset", new { phone });
        var second = await client.PostAsync("/api/auth/requestPatientPasswordReset", new { phone });
        var perNumber = await client.PostAsync("/api/auth/requestPatientPasswordReset", new { phone });
        var otherNumber = await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = TestData.Email() });
        var fifth = await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = TestData.Email() });
        var perIp = await client.PostAsync("/api/auth/requestPasswordResetEmail", new { email = TestData.Email() });

        Assert.Equal(HttpStatusCode.Accepted, first.Status);
        Assert.Equal(HttpStatusCode.Accepted, second.Status);
        Assert.Equal(HttpStatusCode.TooManyRequests, perNumber.Status);
        Assert.Equal(ErrorCodes.TooManyAttempts, perNumber.Body.Code());
        Assert.Equal(HttpStatusCode.Accepted, otherNumber.Status);
        Assert.Equal(HttpStatusCode.Accepted, fifth.Status);
        Assert.Equal(HttpStatusCode.TooManyRequests, perIp.Status);
        Assert.Equal(ErrorCodes.TooManyAttempts, perIp.Body.Code());
    }
}
