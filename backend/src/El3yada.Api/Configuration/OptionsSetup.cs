namespace El3yada.Api.Configuration;

public static class OptionsSetup
{
    /// <summary>
    /// Binds the Jwt, Storage and ConnectionStrings sections and checks them when the app starts,
    /// so a missing secret or a bad value stops the API at once with a clear message.
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

        services.AddOptions<StorageOptions>()
            .Bind(configuration.GetSection(StorageOptions.SectionName))
            .ValidateDataAnnotations()
            .Validate(
                options => !environment.IsProduction() || Path.IsPathFullyQualified(options.RootPath),
                "Storage:RootPath must be an absolute path in production (Storage__RootPath), outside the deploy folder.")
            .ValidateOnStart();

        return services;
    }
}
