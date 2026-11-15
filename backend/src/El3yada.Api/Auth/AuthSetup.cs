using System.Security.Claims;
using El3yada.Api.Common;
using El3yada.Api.Configuration;
using El3yada.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace El3yada.Api.Auth;

/// <summary>
/// JWT bearer authentication with a database check on every request, and the authorization policies.
/// <para>
/// <b>Per-request check</b> (spec 9.4: status is read from the database, not the token): after the signature
/// and lifetime are checked, the account is read through <see cref="AccountStateCache"/> and the token is
/// refused when
/// </para>
/// <list type="bullet">
/// <item>its <c>sst</c> claim is not the hash of the current Users.SecurityStamp (password changed, signed out
/// everywhere): 401 SESSION_REVOKED;</item>
/// <item>its role or admin role is not the current one: 401 TOKEN_OUTDATED (refresh to get the new role);</item>
/// <item>the account is disabled: 403 ACCOUNT_DISABLED; an assistant's clinic is not active: 403 CLINIC_NOT_ACTIVE.</item>
/// </list>
/// Everything is denied by default: endpoints without <c>[AllowAnonymous]</c> need a valid token.
/// </summary>
public static class AuthSetup
{
    private const string FailureCodeKey = "el3yada.auth.failureCode";
    public const string AccountStateKey = "el3yada.auth.accountState";

    public static IServiceCollection AddAppAuth(this IServiceCollection services)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddMemoryCache();
        services.AddHttpContextAccessor();
        services.AddSingleton<IPasswordHasher<Data.Entities.User>, PasswordHasher<Data.Entities.User>>();
        services.AddSingleton<AccountStateCache>();
        services.AddSingleton<IdentifierThrottle>();
        services.AddSingleton<TokenService>();
        services.AddScoped<Passwords>();
        services.AddScoped<SessionService>();
        services.AddScoped<LoginService>();
        services.AddScoped<EmailTokens>();

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<JwtOptions>>((options, jwt) =>
            {
                options.MapInboundClaims = false;
                options.TokenValidationParameters = TokenService.AccessTokenParameters(jwt.Value);
                options.Events = new JwtBearerEvents
                {
                    OnTokenValidated = CheckAccountAsync,
                    OnAuthenticationFailed = context =>
                    {
                        context.HttpContext.Items[FailureCodeKey] = context.Exception is SecurityTokenExpiredException
                            ? ErrorCodes.TokenExpired
                            : ErrorCodes.Unauthenticated;
                        return Task.CompletedTask;
                    },
                    OnChallenge = WriteChallengeAsync,
                    OnForbidden = context => ApiProblems.WriteAsync(
                        context.HttpContext, StatusCodes.Status403Forbidden, ErrorCodes.Forbidden,
                        "You don't have access to this."),
                };
            });

        services.AddAuthorizationBuilder()
            .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build())
            .AddPolicy(Policies.Admin, policy => policy.RequireClaim(ClaimNames.Role, Roles.Admin))
            .AddPolicy(Policies.SuperAdmin, policy => policy
                .RequireClaim(ClaimNames.Role, Roles.Admin)
                .RequireClaim(ClaimNames.AdminRole, AdminRoles.SuperAdmin))
            .AddPolicy(Policies.Doctor, policy => policy.RequireClaim(ClaimNames.Role, Roles.Doctor));

        return services;
    }

    private static async Task CheckAccountAsync(TokenValidatedContext context)
    {
        var principal = context.Principal!;
        if (!Guid.TryParse(principal.FindFirstValue(ClaimNames.Subject), out var userId))
        {
            Fail(context, ErrorCodes.Unauthenticated);
            return;
        }

        var services = context.HttpContext.RequestServices;
        var state = await services.GetRequiredService<AccountStateCache>()
            .GetAsync(services.GetRequiredService<AppDbContext>(), userId, context.HttpContext.RequestAborted);
        if (state is null)
        {
            Fail(context, ErrorCodes.Unauthenticated);
        }
        else if (principal.FindFirstValue(ClaimNames.SecurityStamp) != state.StampHash)
        {
            Fail(context, ErrorCodes.SessionRevoked);
        }
        else if (principal.FindFirstValue(ClaimNames.Role) != state.Role
            || principal.FindFirstValue(ClaimNames.AdminRole) != state.AdminRole)
        {
            Fail(context, ErrorCodes.TokenOutdated);
        }
        else if (state.BlockCode is { } blockCode)
        {
            Fail(context, blockCode);
        }
        else
        {
            context.HttpContext.Items[AccountStateKey] = state;
        }
    }

    private static void Fail(TokenValidatedContext context, string code)
    {
        context.HttpContext.Items[FailureCodeKey] = code;
        context.Fail(code);
    }

    private static async Task WriteChallengeAsync(JwtBearerChallengeContext context)
    {
        context.HandleResponse();
        var code = context.HttpContext.Items[FailureCodeKey] as string ?? ErrorCodes.Unauthenticated;
        var (status, title) = code switch
        {
            ErrorCodes.AccountDisabled => (StatusCodes.Status403Forbidden, "This account is disabled."),
            ErrorCodes.ClinicNotActive => (StatusCodes.Status403Forbidden, "The clinic account is not active."),
            ErrorCodes.TokenExpired => (StatusCodes.Status401Unauthorized, "The access token has expired."),
            ErrorCodes.SessionRevoked => (StatusCodes.Status401Unauthorized, "This session was signed out."),
            ErrorCodes.TokenOutdated => (StatusCodes.Status401Unauthorized, "The account changed; refresh the session."),
            _ => (StatusCodes.Status401Unauthorized, "Sign in to continue."),
        };
        await ApiProblems.WriteAsync(context.HttpContext, status, code, title);
    }
}

/// <summary>Reading the signed-in user in a controller.</summary>
public static class CurrentUser
{
    public static Guid UserId(this ClaimsPrincipal user) =>
        Guid.Parse(user.FindFirstValue(ClaimNames.Subject) ?? throw new InvalidOperationException("Not signed in."));

    /// <summary>The account as checked for this request (set by the per-request check).</summary>
    public static AccountState Account(this HttpContext httpContext) =>
        httpContext.Items[AuthSetup.AccountStateKey] as AccountState
        ?? throw new InvalidOperationException("No signed-in account on this request.");

    /// <summary>The client's IP address, for RefreshTokens.CreatedByIp.</summary>
    public static string? ClientIp(this HttpContext httpContext) => httpContext.Connection.RemoteIpAddress?.ToString();
}
