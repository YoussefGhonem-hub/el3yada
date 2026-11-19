using System.Net.Http.Headers;
using El3yada.Api.Development;
using El3yada.Api.Infrastructure.Auth;
using System.Collections.Concurrent;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests;

/// <summary>
/// Hosts the real API against a throwaway database built from the migrations and filled with
/// <see cref="DemoDataSeeder"/>. One per test class, so tests that change data don't affect others.
/// Uses SQL Server LocalDB by default; set EL3YADA_TEST_SQL to use another server (as the data tests do).
/// </summary>
public sealed class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string _connectionString;
    private readonly string _storageRoot = Path.Combine(Path.GetTempPath(), "el3yada-tests", Guid.NewGuid().ToString("N"));

    public ApiFactory()
    {
        var server = Environment.GetEnvironmentVariable("EL3YADA_TEST_SQL")
            ?? @"Server=(localdb)\MSSQLLocalDB;Trusted_Connection=True;TrustServerCertificate=True";
        _connectionString = $"{server.TrimEnd(';')};Database=el3yada_apitest_{Guid.NewGuid():N}";
    }

    public DemoData Demo { get; private set; } = null!;

    /// <summary>Captures the pushes the API sends instead of calling FCM.</summary>
    public FakePushSender Push { get; } = new();

    /// <summary>Waits for a background effect (push delivery) instead of sleeping a fixed time.</summary>
    public static async Task<T> EventuallyAsync<T>(Func<T?> probe, int timeoutMs = 5000) where T : class
    {
        var deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
        while (DateTime.UtcNow < deadline)
        {
            if (probe() is { } value) return value;
            await Task.Delay(50);
        }
        throw new TimeoutException("The expected effect didn't happen in time.");
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Default", _connectionString);
        builder.UseSetting("Jwt:SigningKey", "test-signing-key-0123456789-0123456789-abcdef");
        builder.UseSetting("FileStorage:RootPath", _storageRoot);
        builder.ConfigureServices(services =>
        {
            services.AddScoped<DemoDataSeeder>();
            services.AddSingleton<IPushSender>(Push);
        });
    }

    public async Task InitializeAsync()
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.MigrateAsync();
        Demo = await scope.ServiceProvider.GetRequiredService<DemoDataSeeder>().SeedAsync();
    }

    /// <summary>A client signed in as <paramref name="userId"/>, with a token issued the same way as login.</summary>
    public async Task<HttpClient> ClientForAsync(Guid userId)
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == userId);
        var doctorId = await db.Assistants.Where(a => a.UserId == userId).Select(a => (Guid?)a.DoctorId).FirstOrDefaultAsync();
        var (token, _) = scope.ServiceProvider.GetRequiredService<JwtTokenFactory>().CreateAccessToken(user, doctorId);

        var client = CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    public async Task<T> WithDbAsync<T>(Func<AppDbContext, Task<T>> action)
    {
        using var scope = Services.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        using (var scope = Services.CreateScope())
        {
            await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.EnsureDeletedAsync();
        }
        await DisposeAsync();
        try { Directory.Delete(_storageRoot, recursive: true); } catch (IOException) { }
    }
}

public sealed class FakePushSender : IPushSender
{
    public ConcurrentQueue<(IReadOnlyList<string> Tokens, PushMessage Message)> Sent { get; } = new();

    /// <summary>Tokens to report as invalid, as FCM would for an uninstalled app.</summary>
    public ConcurrentBag<string> Invalid { get; } = new();

    public Task<IReadOnlyList<string>> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken ct)
    {
        Sent.Enqueue((tokens, message));
        return Task.FromResult<IReadOnlyList<string>>(tokens.Where(t => Invalid.Contains(t)).ToList());
    }
}
