using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace El3yada.Api.Infrastructure.Auth;

public static class AuthSetup
{
    /// <summary>JWT bearer validation, the policies in <see cref="Policies"/>, and <see cref="ICurrentUser"/>.</summary>
    public static IServiceCollection AddEl3yadaAuth(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<JwtOptions>()
            .Bind(configuration.GetSection(JwtOptions.Section))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<JwtOptions>>((bearer, jwt) =>
            {
                // Keep claim names as issued ("sub", "role") instead of the long WS-* URIs.
                bearer.MapInboundClaims = false;
                bearer.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidIssuer = jwt.Value.Issuer,
                    ValidAudience = jwt.Value.Audience,
                    IssuerSigningKey = JwtTokenFactory.CreateKey(jwt.Value.SigningKey),
                    ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
                    NameClaimType = AuthClaims.UserId,
                    RoleClaimType = AuthClaims.Role,
                    ClockSkew = TimeSpan.FromSeconds(30),
                };
            });

        services.AddAuthorization(Policies.Configure);
        services.AddScoped<IAuthorizationHandler, ActiveAccountHandler>();
        services.AddHttpContextAccessor();
        services.AddScoped<ICurrentUser, HttpCurrentUser>();
        services.AddSingleton<JwtTokenFactory>();
        return services;
    }
}
