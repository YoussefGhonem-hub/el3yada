using FluentValidation;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests;

/// <summary>
/// The real API (Program.cs) in memory, with test settings: a test signing key, a temp storage folder,
/// and the sample controller and validator from this assembly. It never opens the database.
/// </summary>
public sealed class ApiFactory : WebApplicationFactory<Program>
{
    public string TempRoot { get; } = Path.Combine(Path.GetTempPath(), "el3yada-api-tests", Guid.NewGuid().ToString("N"));

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = "test-only-signing-key-0123456789abcdef",
            ["Storage:RootPath"] = Path.Combine(TempRoot, "files"),
            ["Serilog:MinimumLevel:Default"] = "Warning",
            ["Serilog:WriteTo:File:Args:path"] = Path.Combine(TempRoot, "logs", "api-.log"),
        }));
        builder.ConfigureServices(services =>
        {
            services.AddControllers().AddApplicationPart(typeof(ApiFactory).Assembly);
            services.AddValidatorsFromAssemblyContaining<ApiFactory>();
        });
    }

    public override async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();
        // Best effort: on Windows the Serilog file sink can still hold the log file for a moment
        // after the host stops, and a failed cleanup must not fail the test run. It's the temp folder.
        try
        {
            if (Directory.Exists(TempRoot))
            {
                Directory.Delete(TempRoot, recursive: true);
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
