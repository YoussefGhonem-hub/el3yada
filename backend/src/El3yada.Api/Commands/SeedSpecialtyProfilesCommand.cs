using System.Text;
using El3yada.Api.Catalogs;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Commands;

/// <summary>
/// <c>dotnet run --project src/El3yada.Api -- seed-specialty-profiles &lt;csv&gt;</c>
/// <para>
/// Loads the default specialty profiles (spec 6.9 table, AD19) from the catalog builder's
/// <c>tools/catalog-builder/mappings/specialty-profiles.csv</c>: a header <c>specialty_name_en,item_type,value</c>,
/// then one row per item. <c>General</c> is the General profile (BR-CAT3). Every specialty named in the file gets
/// exactly the file's items; specialties not in the file are left alone, so running it twice changes nothing.
/// Nothing is saved when a name or an item type is unknown.
/// </para>
/// </summary>
public static class SeedSpecialtyProfilesCommand
{
    public const string Name = "seed-specialty-profiles";

    public static bool IsInvocation(string[] args) => args.Length > 0 && args[0] == Name;

    public static async Task<int> RunAsync(IServiceProvider services, string[] args, TextWriter output)
    {
        await using var scope = services.CreateAsyncScope();
        return await ExecuteAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), args, output);
    }

    /// <summary>The command itself, called directly by tests. <paramref name="args"/> starts with "seed-specialty-profiles".</summary>
    public static async Task<int> ExecuteAsync(AppDbContext db, string[] args, TextWriter output, CancellationToken cancellationToken = default)
    {
        if (args.Length != 2 || !File.Exists(args[1]))
        {
            await output.WriteLineAsync($"Usage: dotnet run --project src/El3yada.Api -- {Name} <path to specialty-profiles.csv>");
            return 2;
        }

        var lines = await File.ReadAllLinesAsync(args[1], Encoding.UTF8, cancellationToken);
        var rows = new List<(string Specialty, string Type, string Value, int Line)>();
        var errors = new List<string>();
        for (var i = 0; i < lines.Length; i++)
        {
            var line = lines[i].TrimStart('﻿');
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            var fields = ParseCsvLine(line);
            if (i == 0 || rows.Count == 0 && errors.Count == 0 && IsHeader(fields))
            {
                if (!IsHeader(fields))
                {
                    errors.Add("Line 1: the header must be specialty_name_en,item_type,value.");
                }

                continue;
            }

            if (fields.Count != 3)
            {
                errors.Add($"Line {i + 1}: expected 3 fields.");
                continue;
            }

            var (specialty, type, value) = (fields[0].Trim(), fields[1].Trim(), fields[2].Trim());
            if (!SpecialtyProfiles.ItemTypes.Contains(type))
            {
                errors.Add($"Line {i + 1}: unknown item type '{type}'.");
            }
            else if (value.Length == 0 || value.Length > SpecialtyProfiles.ValueMax || !SpecialtyProfiles.ValuePattern().IsMatch(value))
            {
                errors.Add($"Line {i + 1}: the value must be printable ASCII, 1–{SpecialtyProfiles.ValueMax} characters.");
            }
            else
            {
                rows.Add((specialty, type, value, i + 1));
            }
        }

        var names = rows.Select(r => r.Specialty).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        var specialties = await db.Specialties.Where(s => names.Contains(s.NameEn)).ToListAsync(cancellationToken);
        foreach (var unknown in names.Where(n => !specialties.Any(s => string.Equals(s.NameEn, n, StringComparison.OrdinalIgnoreCase))))
        {
            errors.Add($"Unknown specialty '{unknown}' (use the English names in the Specialties table, or General).");
        }

        if (errors.Count > 0)
        {
            foreach (var error in errors)
            {
                await output.WriteLineAsync(error);
            }

            await output.WriteLineAsync("Nothing was changed.");
            return 1;
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        foreach (var specialty in specialties.OrderBy(s => s.SortOrder))
        {
            var items = rows.Where(r => string.Equals(r.Specialty, specialty.NameEn, StringComparison.OrdinalIgnoreCase))
                .Select(r => (r.Type, r.Value)).ToList();
            await SpecialtyProfileStore.ReplaceAsync(db, specialty.Id, items, cancellationToken);
            await output.WriteLineAsync($"{specialty.NameEn}: {items.Count} items");
        }

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        await output.WriteLineAsync($"Loaded {rows.Count} items for {specialties.Count} specialties.");
        return 0;
    }

    private static bool IsHeader(List<string> fields) =>
        fields.Count == 3 && fields[0].Trim() == "specialty_name_en" && fields[1].Trim() == "item_type" && fields[2].Trim() == "value";

    /// <summary>One CSV line: commas, and double quotes around a field that has commas ("" inside quotes is a quote).</summary>
    private static List<string> ParseCsvLine(string line)
    {
        var fields = new List<string>();
        var current = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < line.Length; i++)
        {
            var c = line[i];
            if (quoted)
            {
                if (c == '"' && i + 1 < line.Length && line[i + 1] == '"')
                {
                    current.Append('"');
                    i++;
                }
                else if (c == '"')
                {
                    quoted = false;
                }
                else
                {
                    current.Append(c);
                }
            }
            else if (c == '"')
            {
                quoted = true;
            }
            else if (c == ',')
            {
                fields.Add(current.ToString());
                current.Clear();
            }
            else
            {
                current.Append(c);
            }
        }

        fields.Add(current.ToString());
        return fields;
    }
}
