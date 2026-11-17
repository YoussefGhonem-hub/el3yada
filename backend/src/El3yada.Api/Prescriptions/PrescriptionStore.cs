using System.Security.Cryptography;
using System.Text.Json;
using El3yada.Api.Clinic;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Prescriptions;

/// <summary>Reading and writing prescriptions and their items, shared by the endpoints.</summary>
public static class PrescriptionStore
{
    private const string ShortCodeAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    /// <summary>Spec 6.4.1: random, at least 10 characters, reveals nothing. 12 base62 characters ≈ 71 bits.</summary>
    public const int ShortCodeLength = 12;

    private static readonly JsonSerializerOptions TemplateJson = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull,
    };

    /// <summary>A QR short code not used by any prescription yet.</summary>
    public static async Task<string> NewShortCodeAsync(AppDbContext db, CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 5; attempt++)
        {
            var code = RandomNumberGenerator.GetString(ShortCodeAlphabet, ShortCodeLength);
            if (!await db.Prescriptions.AnyAsync(p => p.QrShortCode == code, cancellationToken))
            {
                return code;
            }
        }

        throw new InvalidOperationException("Could not find a free QR short code.");
    }

    /// <summary>Replaces the items of a draft with <paramref name="items"/>, in that order.</summary>
    public static async Task ReplaceItemsAsync(
        AppDbContext db, Prescription prescription, IReadOnlyList<PrescriptionItemInput> items, CancellationToken cancellationToken)
    {
        await db.PrescriptionMedicationItems.Where(i => i.PrescriptionId == prescription.Id).ExecuteDeleteAsync(cancellationToken);
        await db.PrescriptionInvestigationItems.Where(i => i.PrescriptionId == prescription.Id).ExecuteDeleteAsync(cancellationToken);
        var order = 0;
        foreach (var item in items)
        {
            if (prescription.Kind == PrescriptionKinds.Medication)
            {
                db.PrescriptionMedicationItems.Add(new PrescriptionMedicationItem
                {
                    Id = Guid.NewGuid(),
                    PrescriptionId = prescription.Id,
                    SortOrder = order++,
                    DrugName = Text.CollapseSpaces(item.DrugName!),
                    ActiveIngredient = Clean(item.ActiveIngredient),
                    CatalogId = Text.TrimToNull(item.CatalogId),
                    Form = Clean(item.Form),
                    Strength = Clean(item.Strength),
                    Dose = Clean(item.Dose),
                    Frequency = Clean(item.Frequency),
                    Timing = Text.TrimToNull(item.Timing),
                    Duration = Clean(item.Duration),
                    Instructions = Text.TrimToNull(item.Instructions),
                });
            }
            else
            {
                db.PrescriptionInvestigationItems.Add(new PrescriptionInvestigationItem
                {
                    Id = Guid.NewGuid(),
                    PrescriptionId = prescription.Id,
                    SortOrder = order++,
                    Category = item.Category!,
                    Name = Text.CollapseSpaces(item.Name!),
                    LoincCode = Text.TrimToNull(item.LoincCode),
                    Notes = Text.TrimToNull(item.Notes),
                });
            }
        }
    }

    /// <summary>The items of a prescription as inputs (to copy into a new draft or a template).</summary>
    public static async Task<List<PrescriptionItemInput>> ItemInputsAsync(AppDbContext db, Prescription prescription, CancellationToken cancellationToken) =>
        prescription.Kind == PrescriptionKinds.Medication
            ? await db.PrescriptionMedicationItems.AsNoTracking()
                .Where(i => i.PrescriptionId == prescription.Id).OrderBy(i => i.SortOrder)
                .Select(i => new PrescriptionItemInput(
                    i.DrugName, i.ActiveIngredient, i.CatalogId, i.Form, i.Strength, i.Dose, i.Frequency, i.Timing, i.Duration,
                    i.Instructions, null, null, null, null))
                .ToListAsync(cancellationToken)
            : await db.PrescriptionInvestigationItems.AsNoTracking()
                .Where(i => i.PrescriptionId == prescription.Id).OrderBy(i => i.SortOrder)
                .Select(i => new PrescriptionItemInput(
                    null, null, null, null, null, null, null, null, null, null, i.Category, i.Name, i.LoincCode, i.Notes))
                .ToListAsync(cancellationToken);

    public static string TemplateItemsJson(string kind, IReadOnlyList<PrescriptionItemInput> items) =>
        JsonSerializer.Serialize(items.Select(item => (object)(kind == PrescriptionKinds.Medication
            ? new MedicationItemView(
                Text.CollapseSpaces(item.DrugName!), Clean(item.ActiveIngredient), Text.TrimToNull(item.CatalogId), Clean(item.Form),
                Clean(item.Strength), Clean(item.Dose), Clean(item.Frequency), Text.TrimToNull(item.Timing), Clean(item.Duration),
                Text.TrimToNull(item.Instructions))
            : new InvestigationItemView(item.Category!, Text.CollapseSpaces(item.Name!), Text.TrimToNull(item.LoincCode), Text.TrimToNull(item.Notes)))), TemplateJson);

    public static IReadOnlyList<object> TemplateItems(string kind, string json) =>
        kind == PrescriptionKinds.Medication
            ? (JsonSerializer.Deserialize<List<MedicationItemView>>(json, TemplateJson) ?? []).Cast<object>().ToList()
            : (JsonSerializer.Deserialize<List<InvestigationItemView>>(json, TemplateJson) ?? []).Cast<object>().ToList();

    /// <summary>
    /// The prescriptions the caller may see (6.10): the doctor and assistants with <c>clinicalView</c> see every
    /// status; an assistant with only <c>prescriptionsPrint</c> sees sent ones (AS8). Never another doctor's.
    /// </summary>
    public static IQueryable<Prescription> Visible(AppDbContext db, ClinicCaller caller)
    {
        var query = db.Prescriptions.AsNoTracking().Where(p => p.DoctorId == caller.DoctorId);
        return caller.Has(ClinicPermissions.ClinicalView) ? query : query.Where(p => p.Status == PrescriptionStatuses.Sent);
    }

    /// <summary>Views of <paramref name="ids"/>, in that order.</summary>
    public static async Task<List<PrescriptionView>> ViewsAsync(
        AppDbContext db, IReadOnlyList<Guid> ids, Func<string, string> qrUrl, CancellationToken cancellationToken)
    {
        if (ids.Count == 0)
        {
            return [];
        }

        var rows = await db.Prescriptions.AsNoTracking()
            .Where(p => ids.Contains(p.Id))
            .Select(p => new
            {
                Rx = p,
                PreparedByName = p.PreparedByNavigation != null ? p.PreparedByNavigation.DisplayName : null,
                ReplacedById = p.InverseReplacesRx.OrderByDescending(r => r.CreatedAt).Select(r => (Guid?)r.Id).FirstOrDefault(),
            })
            .ToListAsync(cancellationToken);
        var medications = (await db.PrescriptionMedicationItems.AsNoTracking()
                .Where(i => ids.Contains(i.PrescriptionId)).OrderBy(i => i.SortOrder).ToListAsync(cancellationToken))
            .ToLookup(i => i.PrescriptionId);
        var investigations = (await db.PrescriptionInvestigationItems.AsNoTracking()
                .Where(i => ids.Contains(i.PrescriptionId)).OrderBy(i => i.SortOrder).ToListAsync(cancellationToken))
            .ToLookup(i => i.PrescriptionId);

        var views = rows.ToDictionary(row => row.Rx.Id, row =>
        {
            var p = row.Rx;
            IReadOnlyList<object> items = p.Kind == PrescriptionKinds.Medication
                ? medications[p.Id].Select(i => (object)new MedicationItemView(
                    i.DrugName, i.ActiveIngredient, i.CatalogId, i.Form, i.Strength, i.Dose, i.Frequency, i.Timing, i.Duration, i.Instructions)).ToList()
                : investigations[p.Id].Select(i => (object)new InvestigationItemView(i.Category, i.Name, i.LoincCode, i.Notes)).ToList();
            return new PrescriptionView(
                p.Id, p.PatientId, p.SessionId, p.Kind, p.Status, p.Diagnosis, p.Advice, p.FollowUpDate, items,
                p.PreparedBy is { } by ? new PreparedByView(by, p.PreparedByRole ?? "doctor", row.PreparedByName ?? "") : null,
                p.SentAt, p.CancelledAt, p.CancelReason, p.ReplacesRxId, row.ReplacedById, p.QrShortCode, qrUrl(p.QrShortCode),
                p.PdfPath is not null, p.CreatedAt, p.UpdatedAt);
        });
        return ids.Where(views.ContainsKey).Select(id => views[id]).ToList();
    }

    /// <summary>
    /// "Used before" (BR-CAT4): one row per doctor, kind, name, form and strength, counted on every send. A drug's
    /// key includes the form and strength; a test's is its name. Each key counts once per prescription.
    /// </summary>
    public static async Task CountUseAsync(AppDbContext db, Prescription prescription, DateTime now, CancellationToken cancellationToken)
    {
        var keys = prescription.Kind == PrescriptionKinds.Medication
            ? (await db.PrescriptionMedicationItems.AsNoTracking().Where(i => i.PrescriptionId == prescription.Id)
                .Select(i => new { Kind = "drug", Name = i.DrugName, Form = i.Form ?? "", Strength = i.Strength ?? "", i.CatalogId })
                .ToListAsync(cancellationToken))
            : (await db.PrescriptionInvestigationItems.AsNoTracking().Where(i => i.PrescriptionId == prescription.Id)
                .Select(i => new { Kind = i.Category, i.Name, Form = "", Strength = "", CatalogId = i.LoincCode })
                .ToListAsync(cancellationToken));
        foreach (var key in keys.DistinctBy(k => (k.Kind, k.Name.ToUpperInvariant(), k.Form.ToUpperInvariant(), k.Strength.ToUpperInvariant())))
        {
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                MERGE [DoctorItemHistory] WITH (HOLDLOCK) AS t
                USING (SELECT {prescription.DoctorId} AS DoctorId, {key.Kind} AS Kind, {key.Name} AS Name, {key.Form} AS Form, {key.Strength} AS Strength) AS s
                ON t.DoctorId = s.DoctorId AND t.Kind = s.Kind AND t.Name = s.Name AND t.Form = s.Form AND t.Strength = s.Strength
                WHEN MATCHED THEN UPDATE SET UseCount = t.UseCount + 1, LastUsedAt = {now}, CatalogId = COALESCE({key.CatalogId}, t.CatalogId)
                WHEN NOT MATCHED THEN INSERT (Id, DoctorId, Kind, Name, Form, Strength, CatalogId, UseCount, LastUsedAt)
                    VALUES (NEWID(), s.DoctorId, s.Kind, s.Name, s.Form, s.Strength, {key.CatalogId}, 1, {now});
                """, cancellationToken);
        }
    }

    private static string? Clean(string? value) => Text.TrimToNull(value) is { } text ? Text.CollapseSpaces(text) : null;
}
