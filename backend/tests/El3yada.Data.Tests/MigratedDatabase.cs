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
    private readonly string _connectionString;

    public MigratedDatabase()
    {
        var server = Environment.GetEnvironmentVariable("EL3YADA_TEST_SQL")
            ?? @"Server=(localdb)\MSSQLLocalDB;Trusted_Connection=True;TrustServerCertificate=True";
        _connectionString = $"{server.TrimEnd(';')};Database=el3yada_test_{Guid.NewGuid():N}";
    }

    public AppDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<AppDbContext>().UseSqlServer(_connectionString).Options);

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
