namespace El3yada.Api.Configuration;

public static class OptionsSetup
{
    /// <summary>
    /// Binds the Jwt, Auth, Email, RateLimits, Storage and ConnectionStrings sections and checks them when
    /// the app starts, so a missing secret or a bad value stops the API at once with a clear message.
    /// </summary>
    public static IServiceCollection AddAppOptions(
        this IServiceCollection services, IConfiguration configuration, IHostEnvironment environment)
    {
        services.AddOptions<DatabaseOptions>()
            .Bind(configuration.GetSection(DatabaseOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddOptions<JwtOptions>()
            .Bind(configuration.GetSection(JwtOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddOptions<AuthOptions>()
            .Bind(configuration.GetSection(AuthOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddOptions<RateLimitOptions>()
            .Bind(configuration.GetSection(RateLimitOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddOptions<EmailOptions>()
            .Bind(configuration.GetSection(EmailOptions.SectionName))
            .ValidateDataAnnotations()
            .Validate(
                options => !environment.IsProduction() || options.Delivery == EmailDelivery.Smtp,
                "Email:Delivery must be Smtp in production (Email__Delivery=Smtp, plus Email__Smtp__Host and the other SMTP settings).")
            .Validate(
                options => !environment.IsProduction()
                    || (!IsLocal(options.ResetPasswordUrl) && !IsLocal(options.VerifyEmailUrl)
                        && !options.FromAddress.EndsWith(".local", StringComparison.OrdinalIgnoreCase)),
                "Production needs real email links and sender: set Email__ResetPasswordUrl, Email__VerifyEmailUrl and Email__FromAddress.")
            .ValidateOnStart();

        services.AddOptions<StorageOptions>()
            .Bind(configuration.GetSection(StorageOptions.SectionName))
            .ValidateDataAnnotations()
            .Validate(
                options => !environment.IsProduction() || Path.IsPathFullyQualified(options.RootPath),
                "Storage:RootPath must be an absolute path in production (Storage__RootPath), outside the deploy folder.")
            .ValidateOnStart();

        return services;
    }

    private static bool IsLocal(string url) =>
        Uri.TryCreate(url, UriKind.Absolute, out var uri) && (uri.IsLoopback || uri.Host.EndsWith(".local", StringComparison.OrdinalIgnoreCase));
}
