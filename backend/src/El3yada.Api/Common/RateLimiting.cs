using System.Globalization;
using System.Threading.RateLimiting;
using El3yada.Api.Configuration;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Common;

/// <summary>Rate-limit policy names for <c>[EnableRateLimiting(...)]</c>. Limits are in <see cref="RateLimitOptions"/>.</summary>
public static class RateLimitPolicies
{
    public const string Login = "login";
    public const string PasswordReset = "passwordReset";
    public const string Registration = "registration";
    public const string Refresh = "refresh";
    public const string EmailToken = "emailToken";
}

public static class RateLimitingSetup
{
    /// <summary>
    /// The built-in ASP.NET Core rate limiter, per client IP and policy, fixed windows, no queue.
    /// A rejected request gets 429 problem+json with code TOO_MANY_ATTEMPTS and Retry-After.
    /// </summary>
    public static IServiceCollection AddAppRateLimiting(this IServiceCollection services)
    {
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.OnRejected = async (context, _) =>
            {
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                {
                    context.HttpContext.Response.Headers.RetryAfter =
                        ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString(CultureInfo.InvariantCulture);
                }

                await ApiProblems.WriteAsync(
                    context.HttpContext, StatusCodes.Status429TooManyRequests, ErrorCodes.TooManyAttempts,
                    "Too many attempts. Try again later.");
            };

            AddPerIp(options, RateLimitPolicies.Login, limits => (limits.LoginPerMinute, TimeSpan.FromMinutes(1)));
            AddPerIp(options, RateLimitPolicies.PasswordReset, limits => (limits.PasswordResetPer15Minutes, TimeSpan.FromMinutes(15)));
            AddPerIp(options, RateLimitPolicies.Registration, limits => (limits.RegistrationPerHour, TimeSpan.FromHours(1)));
            AddPerIp(options, RateLimitPolicies.Refresh, limits => (limits.RefreshPerMinute, TimeSpan.FromMinutes(1)));
            AddPerIp(options, RateLimitPolicies.EmailToken, limits => (limits.EmailTokenPer15Minutes, TimeSpan.FromMinutes(15)));
        });
        return services;
    }

    private static void AddPerIp(
        RateLimiterOptions options, string policy, Func<RateLimitOptions, (int Permits, TimeSpan Window)> limit) =>
        options.AddPolicy(policy, httpContext =>
        {
            var (permits, window) = limit(httpContext.RequestServices.GetRequiredService<IOptions<RateLimitOptions>>().Value);
            var ip = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
            return RateLimitPartition.GetFixedWindowLimiter(ip, _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = permits,
                Window = window,
                QueueLimit = 0,
                AutoReplenishment = true,
            });
        });
}
