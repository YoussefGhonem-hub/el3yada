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
        var settings = ProductionEmail(ValidSettings());

        Assert.Contains("Storage:RootPath", Fails(settings, Environments.Production).Message);

        settings["Storage:RootPath"] = Path.Combine(Path.GetTempPath(), "el3yada-files");
        ValidateOnStart(settings, Environments.Production).Dispose();
    }

    [Fact]
    public void Production_needs_smtp_with_a_host()
    {
        var settings = ValidSettings();
        settings["Storage:RootPath"] = Path.Combine(Path.GetTempPath(), "el3yada-files");
        settings["AppLinks:PublicBaseUrl"] = "https://api.example.com";

        Assert.Contains("Email:Delivery", Fails(settings, Environments.Production).Message);

        settings["Email:Delivery"] = "Smtp";
        Assert.Contains("Email:Smtp:Host", Fails(settings, Environments.Production).Message);

        ValidateOnStart(ProductionEmail(settings), Environments.Production).Dispose();
    }

    [Theory]
    [InlineData("Email:ResetPasswordUrl", "not a link")]
    [InlineData("Email:ResetPasswordUrl", "https://el3yada.app/reset?x=1")]
    [InlineData("Email:FromAddress", "")]
    [InlineData("Auth:MaxFailedLogins", "0")]
    [InlineData("RateLimits:LoginPerMinute", "0")]
    public void Bad_auth_email_and_rate_limit_settings_stop_the_start(string key, string value)
    {
        var settings = ValidSettings();
        settings[key] = value;

        Fails(settings);
    }

    [Fact]
    public void Defaults_for_auth_and_rate_limits()
    {
        using var services = ValidateOnStart(ValidSettings());

        var auth = services.GetRequiredService<IOptions<AuthOptions>>().Value;
        Assert.Equal(5, auth.MaxFailedLogins);
        Assert.Equal(15, auth.LockoutMinutes);
        Assert.Equal(60, auth.PasswordResetTokenMinutes);
        var limits = services.GetRequiredService<IOptions<RateLimitOptions>>().Value;
        Assert.Equal(10, limits.LoginPerMinute);
        Assert.Equal(5, limits.PasswordResetPer15Minutes);
        Assert.Equal(EmailDelivery.Pickup, services.GetRequiredService<IOptions<EmailOptions>>().Value.Delivery);
    }

    [Fact]
    public void Production_needs_real_email_links_and_sender()
    {
        var settings = ProductionEmail(ValidSettings());
        settings["Storage:RootPath"] = Path.Combine(Path.GetTempPath(), "el3yada-files");
        settings["Email:ResetPasswordUrl"] = "https://localhost:7001/reset-password";

        Assert.Contains("Email__ResetPasswordUrl", Fails(settings, Environments.Production).Message);
    }

    [Fact]
    public void Production_needs_a_public_address_for_prescription_qr_codes()
    {
        var settings = ProductionEmail(ValidSettings());
        settings["Storage:RootPath"] = Path.Combine(Path.GetTempPath(), "el3yada-files");
        settings["AppLinks:PublicBaseUrl"] = "https://localhost:7001";

        Assert.Contains("AppLinks:PublicBaseUrl", Fails(settings, Environments.Production).Message);

        settings["AppLinks:PublicBaseUrl"] = "not a url";
        Assert.Contains("PublicBaseUrl", Fails(settings).Message);
    }

    private static Dictionary<string, string?> ProductionEmail(Dictionary<string, string?> settings)
    {
        settings["Email:Delivery"] = "Smtp";
        settings["Email:Smtp:Host"] = "smtp.example.com";
        settings["Email:FromAddress"] = "no-reply@example.com";
        settings["Email:ResetPasswordUrl"] = "https://app.example.com/reset-password";
        settings["Email:VerifyEmailUrl"] = "https://app.example.com/verify-email";
        // Printed in prescription QR codes (Phase 3): production needs the real public address.
        settings["AppLinks:PublicBaseUrl"] = "https://api.example.com";
        return settings;
    }
}
