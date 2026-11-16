using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Data.Tests;

/// <summary>
/// A throwaway database built by running every migration, dropped after the tests.
/// Uses SQL Server LocalDB by default. Set EL3YADA_TEST_SQL to a connection string
/// without a database name (for example a SQL Server container in CI) to use another server.
/// </summary>
public sealed class MigratedDatabase : IAsyncLifetime
{
    private readonly string _connectionString = NewConnectionString();

    /// <summary>A connection string for a new database with a unique name on the test server.</summary>
    public static string NewConnectionString()
    {
        var server = Environment.GetEnvironmentVariable("EL3YADA_TEST_SQL")
            ?? @"Server=(localdb)\MSSQLLocalDB;Trusted_Connection=True;TrustServerCertificate=True";
        return $"{server.TrimEnd(';')};Database=el3yada_test_{Guid.NewGuid():N}";
    }

    public static AppDbContext CreateContext(string connectionString) =>
        new(new DbContextOptionsBuilder<AppDbContext>().UseSqlServer(connectionString).Options);

    public AppDbContext CreateContext() => CreateContext(_connectionString);

    public async Task InitializeAsync()
    {
        await using var db = CreateContext();
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync()
    {
        await using var db = CreateContext();
        await db.Database.EnsureDeletedAsync();
    }
}
