using System.Linq.Expressions;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Patients;

/// <summary>
/// D4 / AS2 (<c>getPatientsRegister</c>). Every filter is optional.
/// </summary>
public sealed class PatientsRegisterQuery : IPagedQuery
{
    /// <summary>Name (normalized, each word contained), phone digits (partial) or file number.</summary>
    public string? Search { get; init; }

    /// <summary><see cref="RegisterLastVisit"/> values.</summary>
    public string? LastVisit { get; init; }

    /// <summary>Patients with at least one visit in this branch.</summary>
    public Guid? BranchId { get; init; }

    public int? MinVisits { get; init; }

    public int? MaxVisits { get; init; }

    /// <summary>Linked to the doctor in the current Cairo month.</summary>
    public bool? NewThisMonth { get; init; }

    /// <summary>Patients with a pending or confirmed booking from today on.</summary>
    public bool? HasUpcomingBooking { get; init; }

    /// <summary>Patients with at least one no-show.</summary>
    public bool? HasNoShows { get; init; }

    /// <summary>false or absent: active patients only (BR-P7). true: archived patients only.</summary>
    public bool? Archived { get; init; }

    /// <summary>clinicalView only: patients with any chronic disease in their profile.</summary>
    public bool? HasChronicDisease { get; init; }

    /// <summary>clinicalView only: patients with a chronic disease containing this text.</summary>
    public string? ChronicDisease { get; init; }

    /// <summary><see cref="RegisterSort"/> values; default <c>lastVisit</c>.</summary>
    public string? Sort { get; init; }

    /// <summary><c>asc</c> or <c>desc</c>. Default: <c>desc</c> for lastVisit, firstVisit, linkedAt, visits and totals; <c>asc</c> otherwise.</summary>
    public string? Direction { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public static class RegisterLastVisit
{
    public const string ThisWeek = "thisWeek";
    public const string ThisMonth = "thisMonth";
    public const string NotSeen3Months = "notSeen3m";
    public const string NotSeen6Months = "notSeen6m";
    public const string NotSeen12Months = "notSeen12m";
    public const string Never = "never";

    public static readonly string[] All = [ThisWeek, ThisMonth, NotSeen3Months, NotSeen6Months, NotSeen12Months, Never];
}

public static class RegisterSort
{
    public const string FileNumber = "fileNumber";
    public const string Name = "name";
    public const string Phone = "phone";
    public const string Age = "age";
    public const string Gender = "gender";
    public const string FirstVisit = "firstVisit";
    public const string LastVisit = "lastVisit";
    public const string Visits = "visits";
    public const string Examinations = "examinations";
    public const string Consultations = "consultations";
    public const string Files = "files";
    public const string LinkedAt = "linkedAt";

    /// <summary>revenueView only.</summary>
    public const string TotalPaid = "totalPaid";

    /// <summary>clinicalView only.</summary>
    public const string Allergies = "allergies";

    public static readonly string[] All =
    [
        FileNumber, Name, Phone, Age, Gender, FirstVisit, LastVisit, Visits, Examinations, Consultations, Files,
        LinkedAt, TotalPaid, Allergies,
    ];

    /// <summary>Sorts that list the largest or newest first unless <c>direction</c> says otherwise.</summary>
    public static readonly string[] DescendingByDefault =
        [FirstVisit, LastVisit, Visits, Examinations, Consultations, Files, LinkedAt, TotalPaid, Allergies];
}

public sealed class PatientsRegisterQueryValidator : AbstractValidator<PatientsRegisterQuery>
{
    public PatientsRegisterQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Search).MaxChars(60);
        RuleFor(x => x.LastVisit).OneOf(RegisterLastVisit.All);
        RuleFor(x => x.MinVisits).GreaterThanOrEqualTo(0).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.MaxVisits).GreaterThanOrEqualTo(0).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.ChronicDisease).MaxChars(200);
        RuleFor(x => x.Sort).OneOf(RegisterSort.All);
        RuleFor(x => x.Direction).OneOf("asc", "desc");
    }
}

/// <summary>
/// The register query. The filters and sorts run in SQL on DoctorPatients (IX_DoctorPatients_Doctor_LastSession,
/// _SearchName and _Phone all start with DoctorId); the money and clinical columns are read afterwards for the
/// page's rows only, and only when the caller may see them.
/// </summary>
public static class PatientsRegister
{
    public static async Task<PagedResult<PatientRegisterRow>> PageAsync(
        AppDbContext db, ClinicCaller caller, PatientsRegisterQuery query, DateOnly today, CancellationToken cancellationToken)
    {
        var doctorId = caller.DoctorId;
        var links = db.DoctorPatients.AsNoTracking().Where(l => l.DoctorId == doctorId);
        links = query.Archived == true ? links.Where(l => l.Archived) : links.Where(l => !l.Archived);
        links = Search(links, query.Search);
        links = LastVisit(links, query.LastVisit, today);

        if (query.BranchId is { } branchId)
        {
            links = links.Where(l => db.Sessions.Any(s =>
                s.DoctorId == doctorId && s.PatientId == l.PatientId && !s.Deleted && s.BranchId == branchId));
        }

        if (query.MinVisits is { } min)
        {
            links = links.Where(l => l.SessionCount >= min);
        }

        if (query.MaxVisits is { } max)
        {
            links = links.Where(l => l.SessionCount <= max);
        }

        if (query.NewThisMonth == true)
        {
            var monthStart = CairoTime.StartUtc(new DateOnly(today.Year, today.Month, 1));
            links = links.Where(l => l.LinkedAt >= monthStart);
        }

        if (query.HasUpcomingBooking == true)
        {
            links = links.Where(l => db.Appointments.Any(a => a.DoctorId == doctorId && a.PatientId == l.PatientId && a.LocalDate >= today
                && (a.Status == "pending" || a.Status == "confirmed")));
        }

        if (query.HasNoShows == true)
        {
            links = links.Where(l => db.Appointments.Any(a => a.DoctorId == doctorId && a.PatientId == l.PatientId && a.Status == "noShow"));
        }

        if (query.HasChronicDisease == true)
        {
            links = links.Where(l => l.PatientMedicalProfileItems.Any(i => i.Kind == ProfileKinds.ChronicDisease));
        }

        if (Text.TrimToNull(query.ChronicDisease) is { } disease)
        {
            links = links.Where(l => l.PatientMedicalProfileItems.Any(i => i.Kind == ProfileKinds.ChronicDisease && i.Text.Contains(disease)));
        }

        var page = await Sort(db, links, doctorId, query)
            .Select(l => new
            {
                LinkId = l.Id,
                l.PatientId,
                l.FileNumber,
                l.PatientName,
                l.PatientPhone,
                l.Patient.Gender,
                l.Patient.DateOfBirth,
                l.Patient.DateOfBirthEstimated,
                Visits = new VisitCounters(
                    l.FirstSessionAt, l.LastSessionId, l.LastSessionAt, l.LastSessionType, l.LastSessionBranchId,
                    l.LastSessionBranch != null ? l.LastSessionBranch.NameAr : null,
                    l.LastSessionBranch != null ? l.LastSessionBranch.NameEn : null,
                    l.SessionCount, l.ExamCount, l.ConsultationCount, l.ConsultationsSinceExam),
                FilesCount = db.MedicalRecords.Count(r => r.DoctorId == doctorId && r.PatientId == l.PatientId && !r.Deleted),
                l.Archived,
                l.LinkedAt,
            })
            .ToPageAsync(query, cancellationToken);

        var patientIds = page.Items.Select(r => r.PatientId).ToList();
        var linkIds = page.Items.Select(r => r.LinkId).ToList();
        Dictionary<Guid, int>? paid = null;
        if (caller.Has(ClinicPermissions.RevenueView))
        {
            paid = await db.Sessions.AsNoTracking()
                .Where(s => s.DoctorId == doctorId && patientIds.Contains(s.PatientId) && !s.Deleted)
                .GroupBy(s => s.PatientId)
                .Select(g => new { PatientId = g.Key, Total = g.Sum(s => s.PatientFeePiasters) })
                .ToDictionaryAsync(g => g.PatientId, g => g.Total, cancellationToken);
        }

        var nextBookings = await PatientBookings.NextAsync(db, doctorId, patientIds, today, cancellationToken);
        var noShows = await PatientBookings.NoShowsAsync(db, doctorId, patientIds, cancellationToken);
        ILookup<Guid, (string Kind, string Text)>? profile = null;
        if (caller.Has(ClinicPermissions.ClinicalView))
        {
            profile = (await db.PatientMedicalProfileItems.AsNoTracking()
                    .Where(i => linkIds.Contains(i.LinkId) && (i.Kind == ProfileKinds.Allergy || i.Kind == ProfileKinds.ChronicDisease))
                    .OrderBy(i => i.SortOrder)
                    .Select(i => new { i.LinkId, i.Kind, i.Text })
                    .ToListAsync(cancellationToken))
                .ToLookup(i => i.LinkId, i => (i.Kind, i.Text));
        }

        var rows = page.Items.Select(r => new PatientRegisterRow(
            r.PatientId,
            r.FileNumber,
            r.PatientName,
            r.PatientPhone,
            r.Gender,
            r.DateOfBirth,
            r.DateOfBirthEstimated,
            PatientAge.Years(r.DateOfBirth, today),
            r.Visits.View(today),
            paid is null ? null : paid.GetValueOrDefault(r.PatientId),
            nextBookings.GetValueOrDefault(r.PatientId),
            noShows.GetValueOrDefault(r.PatientId),
            r.FilesCount,
            profile is null ? null : profile[r.LinkId].Any(i => i.Kind == ProfileKinds.Allergy),
            profile?[r.LinkId].Where(i => i.Kind == ProfileKinds.ChronicDisease).Select(i => i.Text).ToList(),
            r.Archived,
            r.LinkedAt)).ToList();
        return new PagedResult<PatientRegisterRow>(rows, page.Page, page.PageSize, page.TotalCount);
    }

    /// <summary>
    /// The search box. Text is normalized like SearchName (spec A.6) and every word must appear in the name.
    /// Digits (Arabic-Indic too, spaces ignored) match part of the phone or the whole file number. Stored
    /// phones are +20 followed by the local number, so typing the local form (010…) matches.
    /// </summary>
    internal static IQueryable<DoctorPatient> Search(IQueryable<DoctorPatient> links, string? search)
    {
        var text = SearchText.Normalize(search);
        if (text.Length == 0)
        {
            return links;
        }

        var compact = text.Replace(" ", "", StringComparison.Ordinal);
        if (compact.All(char.IsAsciiDigit))
        {
            var digits = compact.StartsWith("0020", StringComparison.Ordinal) ? compact[2..] : compact;
            int? fileNumber = compact.Length <= 9 ? int.Parse(compact, System.Globalization.CultureInfo.InvariantCulture) : null;
            return links.Where(l => l.PatientPhone.Contains(digits) || l.FileNumber == fileNumber);
        }

        foreach (var word in text.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            links = word.All(char.IsAsciiDigit)
                ? links.Where(l => l.PatientPhone.Contains(word))
                : links.Where(l => l.SearchName.Contains(word));
        }

        return links;
    }

    private static IQueryable<DoctorPatient> LastVisit(IQueryable<DoctorPatient> links, string? filter, DateOnly today)
    {
        switch (filter)
        {
            case RegisterLastVisit.ThisWeek:
                // The Egyptian week starts on Saturday.
                var weekStart = CairoTime.StartUtc(today.AddDays(-(((int)today.DayOfWeek + 1) % 7)));
                return links.Where(l => l.LastSessionAt >= weekStart);
            case RegisterLastVisit.ThisMonth:
                var monthStart = CairoTime.StartUtc(new DateOnly(today.Year, today.Month, 1));
                return links.Where(l => l.LastSessionAt >= monthStart);
            case RegisterLastVisit.NotSeen3Months:
                return NotSeenSince(links, today.AddMonths(-3));
            case RegisterLastVisit.NotSeen6Months:
                return NotSeenSince(links, today.AddMonths(-6));
            case RegisterLastVisit.NotSeen12Months:
                return NotSeenSince(links, today.AddMonths(-12));
            case RegisterLastVisit.Never:
                return links.Where(l => l.LastSessionAt == null);
            default:
                return links;
        }
    }

    /// <summary>The last visit was before <paramref name="day"/> (more than N months ago, AC-24). Never-visited patients are not included.</summary>
    private static IQueryable<DoctorPatient> NotSeenSince(IQueryable<DoctorPatient> links, DateOnly day)
    {
        var cutoff = CairoTime.StartUtc(day);
        return links.Where(l => l.LastSessionAt != null && l.LastSessionAt < cutoff);
    }

    private static IOrderedQueryable<DoctorPatient> Sort(
        AppDbContext db, IQueryable<DoctorPatient> links, Guid doctorId, PatientsRegisterQuery query)
    {
        var sort = query.Sort ?? RegisterSort.LastVisit;
        var descending = query.Direction is null ? RegisterSort.DescendingByDefault.Contains(sort) : query.Direction == "desc";
        var ordered = sort switch
        {
            RegisterSort.FileNumber => Order(links, l => l.FileNumber, descending),
            RegisterSort.Name => Order(links, l => l.SearchName, descending),
            RegisterSort.Phone => Order(links, l => l.PatientPhone, descending),
            // Older patients have earlier dates of birth.
            RegisterSort.Age => Order(links, l => l.Patient.DateOfBirth, !descending),
            RegisterSort.Gender => Order(links, l => l.Patient.Gender, descending),
            RegisterSort.FirstVisit => Order(links, l => l.FirstSessionAt, descending),
            RegisterSort.Visits => Order(links, l => l.SessionCount, descending),
            RegisterSort.Examinations => Order(links, l => l.ExamCount, descending),
            RegisterSort.Consultations => Order(links, l => l.ConsultationCount, descending),
            RegisterSort.Files => Order(
                links, l => db.MedicalRecords.Count(r => r.DoctorId == doctorId && r.PatientId == l.PatientId && !r.Deleted), descending),
            RegisterSort.LinkedAt => Order(links, l => l.LinkedAt, descending),
            RegisterSort.TotalPaid => Order(
                links,
                l => db.Sessions.Where(s => s.DoctorId == doctorId && s.PatientId == l.PatientId && !s.Deleted).Sum(s => (int?)s.PatientFeePiasters) ?? 0,
                descending),
            RegisterSort.Allergies => Order(
                links, l => l.PatientMedicalProfileItems.Any(i => i.Kind == ProfileKinds.Allergy) ? 1 : 0, descending),
            _ => Order(links, l => l.LastSessionAt, descending),
        };
        return ordered.ThenBy(l => l.FileNumber);
    }

    private static IOrderedQueryable<DoctorPatient> Order<TKey>(
        IQueryable<DoctorPatient> links, Expression<Func<DoctorPatient, TKey>> key, bool descending) =>
        descending ? links.OrderByDescending(key) : links.OrderBy(key);
}
