using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Catalogs;

/// <summary>Reading and replacing specialty profiles (BR-CAT2, BR-CAT3), shared by AD19, myProfile and the seed command.</summary>
public static class SpecialtyProfileStore
{
    public static Task<Specialty?> GeneralAsync(AppDbContext db, CancellationToken cancellationToken) =>
        db.Specialties.SingleOrDefaultAsync(s => s.NameEn == SpecialtyProfiles.GeneralNameEn, cancellationToken);

    /// <summary>Replaces every item of one specialty, de-duplicated and trimmed.</summary>
    public static async Task ReplaceAsync(
        AppDbContext db, Guid specialtyId, IEnumerable<(string Type, string Value)> items, CancellationToken cancellationToken)
    {
        await db.SpecialtyProfileItems.Where(i => i.SpecialtyId == specialtyId).ExecuteDeleteAsync(cancellationToken);
        foreach (var (type, value) in items
            .Select(i => (i.Type, Value: i.Value.Trim()))
            .DistinctBy(i => (i.Type, i.Value.ToUpperInvariant())))
        {
            db.SpecialtyProfileItems.Add(new SpecialtyProfileItem { Id = Guid.NewGuid(), SpecialtyId = specialtyId, ItemType = type, Value = value });
        }
    }

    public static IEnumerable<(string Type, string Value)> ItemsOf(SpecialtyProfileRequest request) =>
        Pairs(SpecialtyProfiles.DrugGroup, request.DrugGroups)
            .Concat(Pairs(SpecialtyProfiles.Route, request.Routes))
            .Concat(Pairs(SpecialtyProfiles.LabCode, request.LabCodes))
            .Concat(Pairs(SpecialtyProfiles.RadiologyRegion, request.RadiologyRegions))
            .Concat(Pairs(SpecialtyProfiles.RadiologyModality, request.RadiologyModalities))
            .Concat(Pairs(SpecialtyProfiles.RadiologyCode, request.RadiologyCodes));

    public static async Task<SpecialtyProfileView?> ViewAsync(AppDbContext db, Guid specialtyId, CancellationToken cancellationToken)
    {
        var specialty = await db.Specialties.AsNoTracking().SingleOrDefaultAsync(s => s.Id == specialtyId, cancellationToken);
        if (specialty is null)
        {
            return null;
        }

        var items = await db.SpecialtyProfileItems.AsNoTracking()
            .Where(i => i.SpecialtyId == specialtyId)
            .Select(i => new { i.ItemType, i.Value })
            .ToListAsync(cancellationToken);
        List<string> Of(string type) => items.Where(i => i.ItemType == type).Select(i => i.Value).Order(StringComparer.Ordinal).ToList();
        var general = specialty.NameEn == SpecialtyProfiles.GeneralNameEn;
        return new SpecialtyProfileView(
            specialty.Id, specialty.NameAr, specialty.NameEn, general, !general && specialty.IncludeGeneral,
            Of(SpecialtyProfiles.DrugGroup), Of(SpecialtyProfiles.Route), Of(SpecialtyProfiles.LabCode),
            Of(SpecialtyProfiles.RadiologyRegion), Of(SpecialtyProfiles.RadiologyModality), Of(SpecialtyProfiles.RadiologyCode),
            specialty.UpdatedAt);
    }

    /// <summary>
    /// The doctor's primary and extra specialties merged, plus the General profile when any of them includes it
    /// (BR-CAT3, on by default).
    /// </summary>
    public static async Task<MyProfileView> ForDoctorAsync(AppDbContext db, Guid doctorId, CancellationToken cancellationToken)
    {
        var doctor = await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new
            {
                Ids = d.Specialties.Select(s => new { s.Id, s.IncludeGeneral }).ToList(),
                Primary = new { d.Specialty.Id, d.Specialty.IncludeGeneral },
            })
            .SingleAsync(cancellationToken);
        var specialties = doctor.Ids.Prepend(doctor.Primary).DistinctBy(s => s.Id).ToList();
        var ids = specialties.Select(s => s.Id).ToList();
        var includesGeneral = specialties.Any(s => s.IncludeGeneral);
        if (includesGeneral && await GeneralAsync(db, cancellationToken) is { } general)
        {
            ids.Add(general.Id);
        }

        var items = await db.SpecialtyProfileItems.AsNoTracking()
            .Where(i => ids.Contains(i.SpecialtyId))
            .Select(i => new { i.ItemType, i.Value })
            .ToListAsync(cancellationToken);
        List<string> Of(string type) => items.Where(i => i.ItemType == type).Select(i => i.Value)
            .Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.Ordinal).ToList();
        return new MyProfileView(
            specialties.Select(s => s.Id).ToList(), includesGeneral,
            Of(SpecialtyProfiles.DrugGroup), Of(SpecialtyProfiles.Route), Of(SpecialtyProfiles.LabCode),
            Of(SpecialtyProfiles.RadiologyRegion), Of(SpecialtyProfiles.RadiologyModality), Of(SpecialtyProfiles.RadiologyCode));
    }

    private static IEnumerable<(string Type, string Value)> Pairs(string type, IReadOnlyList<string>? values) =>
        (values ?? []).Where(v => !string.IsNullOrWhiteSpace(v)).Select(v => (type, v));
}
