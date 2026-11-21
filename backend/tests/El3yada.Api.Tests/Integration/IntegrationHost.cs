using El3yada.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// A throwaway SQL Server database built by running every migration (same approach as
/// El3yada.Data.Tests/MigratedDatabase): LocalDB by default, or the server in EL3YADA_TEST_SQL
/// (a connection string without a database name; CI sets it to a SQL Server container).
/// </summary>
public sealed class TestDatabase
{
    public TestDatabase()
    {
        var server = Environment.GetEnvironmentVariable("EL3YADA_TEST_SQL")
            ?? @"Server=(localdb)\MSSQLLocalDB;Trusted_Connection=True;TrustServerCertificate=True";
        ConnectionString = $"{server.TrimEnd(';')};Database=el3yada_apitest_{Guid.NewGuid():N};MultipleActiveResultSets=True";
    }

    public string ConnectionString { get; }

    public AppDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<AppDbContext>().UseSqlServer(ConnectionString).Options);

    public async Task CreateAsync()
    {
        await using var db = CreateContext();
        await db.Database.MigrateAsync();
    }

    public async Task DropAsync()
    {
        await using var db = CreateContext();
        await db.Database.EnsureDeletedAsync();
    }
}

/// <summary>
/// The real API (Program.cs) in memory on a <see cref="TestDatabase"/>, with a test signing key, temp folders
/// for files and emails (.eml), and rate limits high enough that tests never meet them unless
/// <paramref name="settings"/> lowers one.
/// </summary>
public sealed class IntegrationFactory(string connectionString, IDictionary<string, string?>? settings = null)
    : WebApplicationFactory<Program>
{
    public string TempRoot { get; } = Path.Combine(Path.GetTempPath(), "el3yada-api-it", Guid.NewGuid().ToString("N"));

    public string MailDirectory => Path.Combine(TempRoot, "mail");

    public string FilesDirectory => Path.Combine(TempRoot, "files");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        var config = new Dictionary<string, string?>
        {
            ["ConnectionStrings:Default"] = connectionString,
            ["Jwt:SigningKey"] = "integration-test-signing-key-0123456789abcdef",
            ["Storage:RootPath"] = FilesDirectory,
            ["Email:Delivery"] = "Pickup",
            ["Email:PickupDirectory"] = MailDirectory,
            ["Email:ResetPasswordUrl"] = "https://el3yada.test/reset-password",
            ["Email:VerifyEmailUrl"] = "https://el3yada.test/verify-email",
            ["Auth:UserStateCacheSeconds"] = "30",
            // Background jobs run only when a test calls them, at the time the test chooses.
            ["Jobs:Enabled"] = "false",
            ["RateLimits:LoginPerMinute"] = "100000",
            ["RateLimits:PasswordResetPer15Minutes"] = "100000",
            ["RateLimits:PasswordResetPerIdentifierPerHour"] = "100000",
            ["RateLimits:RegistrationPerHour"] = "100000",
            ["RateLimits:RefreshPerMinute"] = "100000",
            ["RateLimits:EmailTokenPer15Minutes"] = "100000",
            ["Serilog:MinimumLevel:Default"] = "Warning",
            ["Serilog:WriteTo:File:Args:path"] = Path.Combine(TempRoot, "logs", "api-.log"),
        };
        foreach (var (key, value) in settings ?? new Dictionary<string, string?>())
        {
            config[key] = value;
        }

        builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(config));
    }

    /// <summary>A DbContext from the app's own services (same model and connection), for arranging and checking data.</summary>
    public AsyncServiceScope CreateScope() => Services.CreateAsyncScope();

    public override async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();
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

/// <summary>One database and one API for every integration test class (they run one after another).</summary>
public sealed class IntegrationHost : IAsyncLifetime
{
    public TestDatabase Database { get; } = new();

    public IntegrationFactory Factory { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await Database.CreateAsync();
        Factory = new IntegrationFactory(Database.ConnectionString);
        _ = Factory.Server; // start the host
    }

    public async Task DisposeAsync()
    {
        await Factory.DisposeAsync();
        await Database.DropAsync();
    }
}

[CollectionDefinition(Name)]
public sealed class IntegrationCollection : ICollectionFixture<IntegrationHost>
{
    public const string Name = "integration";
}
