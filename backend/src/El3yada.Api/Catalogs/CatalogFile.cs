using System.Globalization;
using System.IO.Compression;
using System.Security.Cryptography;
using Microsoft.Data.Sqlite;

namespace El3yada.Api.Catalogs;

/// <summary>What a published catalog file holds (spec 9.5 <c>meta</c> and row counts).</summary>
public sealed record CatalogFileInfo(
    int SchemaVersion, string? CatalogVersion, string? BuiltAt, DateOnly? DrugSourceDate, string? LoincRelease,
    int Drugs, int Labs, int Radiology);

/// <summary>Opens a <c>catalog-v{n}.sqlite.gz</c> from the catalog builder (tools/catalog-builder) to check it before publishing.</summary>
public static class CatalogFile
{
    public static async Task<string> Sha256Async(string path, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        return Convert.ToHexStringLower(await SHA256.HashDataAsync(stream, cancellationToken));
    }

    /// <summary>
    /// Unzips <paramref name="gzipPath"/> to a temporary file and reads <c>meta</c> and the counts of
    /// <c>drugs</c>, <c>lab_tests</c> and <c>radiology</c>. Null when it isn't a gzip-compressed SQLite database with
    /// those tables. <c>meta</c> may be one row with a column per key, or key/value rows.
    /// </summary>
    public static async Task<CatalogFileInfo?> InspectAsync(string gzipPath, CancellationToken cancellationToken)
    {
        var database = Path.Combine(Path.GetTempPath(), $"el3yada-catalog-{Guid.NewGuid():N}.sqlite");
        try
        {
            try
            {
                await using var input = File.OpenRead(gzipPath);
                await using var gzip = new GZipStream(input, CompressionMode.Decompress);
                await using var output = File.Create(database);
                await gzip.CopyToAsync(output, cancellationToken);
            }
            catch (InvalidDataException)
            {
                return null;
            }

            var connectionString = new SqliteConnectionStringBuilder
            {
                DataSource = database,
                Mode = SqliteOpenMode.ReadOnly,
                Pooling = false,
            }.ToString();
            try
            {
                await using var connection = new SqliteConnection(connectionString);
                await connection.OpenAsync(cancellationToken);
                var meta = await ReadMetaAsync(connection, cancellationToken);
                if (meta is null || !int.TryParse(meta.GetValueOrDefault("schema_version"), NumberStyles.Integer, CultureInfo.InvariantCulture, out var schema))
                {
                    return null;
                }

                DateOnly? drugDate = DateOnly.TryParse(
                    meta.GetValueOrDefault("drug_source_date")?.Split('T')[0], CultureInfo.InvariantCulture, out var date) ? date : null;
                return new CatalogFileInfo(
                    schema, meta.GetValueOrDefault("catalog_version"), meta.GetValueOrDefault("built_at"), drugDate,
                    meta.GetValueOrDefault("loinc_release"),
                    await CountAsync(connection, "drugs", cancellationToken),
                    await CountAsync(connection, "lab_tests", cancellationToken),
                    await CountAsync(connection, "radiology", cancellationToken));
            }
            catch (SqliteException)
            {
                return null;
            }
        }
        finally
        {
            try
            {
                File.Delete(database);
            }
            catch (IOException)
            {
            }
        }
    }

    private static async Task<Dictionary<string, string?>?> ReadMetaAsync(SqliteConnection connection, CancellationToken cancellationToken)
    {
        var columns = new List<string>();
        await using (var info = connection.CreateCommand())
        {
            info.CommandText = "PRAGMA table_info('meta')";
            await using var reader = await info.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                columns.Add(reader.GetString(1));
            }
        }

        if (columns.Count == 0)
        {
            return null;
        }

        var meta = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        await using var command = connection.CreateCommand();
        if (columns.Contains("key", StringComparer.OrdinalIgnoreCase) && columns.Contains("value", StringComparer.OrdinalIgnoreCase))
        {
            command.CommandText = "SELECT key, value FROM meta";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                meta[reader.GetString(0)] = reader.IsDBNull(1) ? null : Convert.ToString(reader.GetValue(1), CultureInfo.InvariantCulture);
            }
        }
        else
        {
            command.CommandText = "SELECT * FROM meta LIMIT 1";
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                return null;
            }

            for (var i = 0; i < reader.FieldCount; i++)
            {
                meta[reader.GetName(i)] = reader.IsDBNull(i) ? null : Convert.ToString(reader.GetValue(i), CultureInfo.InvariantCulture);
            }
        }

        return meta;
    }

    private static async Task<int> CountAsync(SqliteConnection connection, string table, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = $"SELECT COUNT(*) FROM \"{table}\"";
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), CultureInfo.InvariantCulture);
    }
}
