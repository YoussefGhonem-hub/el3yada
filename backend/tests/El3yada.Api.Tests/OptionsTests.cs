using El3yada.Api.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Tests;

/// <summary>The checks <c>AddAppOptions</c> runs when the API starts (ValidateOnStart).</summary>
public class OptionsTests
{
    private const string GoodKey = "0123456789abcdef0123456789abcdef"; // exactly 32 bytes

    private static Dictionary<string, string?> ValidSettings() => new()
    {
        ["ConnectionStrings:Default"] = @"Server=(localdb)\MSSQLLocalDB;Database=el3yada_dev;Trusted_Connection=True",
        ["Jwt:Issuer"] = "el3yada-api",
        ["Jwt:Audience"] = "el3yada-app",
        ["Jwt:SigningKey"] = GoodKey,
        ["Storage:RootPath"] = "App_Data/files",
    };

    private static ServiceProvider ValidateOnStart(Dictionary<string, string?> settings, string environment = "Development")
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(settings).Build();
        var hostEnvironment = new HostingEnvironment { EnvironmentName = environment, ContentRootPath = Path.GetTempPath() };
        var services = new ServiceCollection()
            .AddAppOptions(configuration, hostEnvironment)
            .BuildServiceProvider();
        try
        {
            services.GetRequiredService<IStartupValidator>().Validate();
            return services;
        }
        catch
        {
            services.Dispose();
            throw;
        }
    }

    private static OptionsValidationException Fails(Dictionary<string, string?> settings, string environment = "Development") =>
        Assert.Throws<OptionsValidationException>(() => ValidateOnStart(settings, environment).Dispose());

    [Fact]
    public void Valid_settings_pass_and_unset_values_use_the_defaults()
    {
        using var services = ValidateOnStart(ValidSettings());

        var jwt = services.GetRequiredService<IOptions<JwtOptions>>().Value;
        Assert.Equal(15, jwt.AccessTokenMinutes);
        Assert.Equal(30, jwt.RefreshTokenDays);
        var storage = services.GetRequiredService<IOptions<StorageOptions>>().Value;
        Assert.Equal(200, storage.MaxUploadMb);
        Assert.Equal(320, storage.ThumbnailMaxPx);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("0123456789abcdef0123456789abcde")] // 31 bytes
    public void A_missing_or_short_signing_key_stops_the_start(string? key)
    {
        var settings = ValidSettings();
        settings["Jwt:SigningKey"] = key;

        var error = Fails(settings);

        Assert.Contains("Jwt:SigningKey", error.Message);
        if (!string.IsNullOrEmpty(key))
        {
            Assert.DoesNotContain(key, error.Message);
        }
    }

    [Theory]
    [InlineData("Jwt:AccessTokenMinutes", "0")]
    [InlineData("Jwt:RefreshTokenDays", "366")]
    [InlineData("Jwt:Issuer", "")]
    [InlineData("Storage:MaxUploadMb", "0")]
    [InlineData("Storage:MaxUploadMb", "201")]
    [InlineData("Storage:RootPath", "")]
    [InlineData("ConnectionStrings:Default", "")]
    [InlineData("ConnectionStrings:Default", "not a connection string")]
    public void Out_of_range_or_missing_values_stop_the_start(string key, string value)
    {
        var settings = ValidSettings();
        settings[key] = value;

        Fails(settings);
    }

    [Fact]
    public void Production_needs_an_absolute_storage_path()
    {
        var settings = ValidSettings();

        Assert.Contains("Storage:RootPath", Fails(settings, Environments.Production).Message);

        settings["Storage:RootPath"] = Path.Combine(Path.GetTempPath(), "el3yada-files");
        ValidateOnStart(settings, Environments.Production).Dispose();
    }
}
