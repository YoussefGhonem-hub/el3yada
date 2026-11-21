using System.Globalization;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Sessions;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Analytics;

/// <summary>Period presets of BR-REV3. Weeks start on Saturday.</summary>
public static class PeriodPresets
{
    public const string Today = "today";
    public const string Yesterday = "yesterday";
    public const string ThisWeek = "thisWeek";
    public const string LastWeek = "lastWeek";
    public const string ThisMonth = "thisMonth";
    public const string LastMonth = "lastMonth";
    public const string Last3Months = "last3Months";
    public const string Last6Months = "last6Months";
    public const string ThisYear = "thisYear";
    public const string LastYear = "lastYear";
    public const string Custom = "custom";

    public static readonly string[] All =
        [Today, Yesterday, ThisWeek, LastWeek, ThisMonth, LastMonth, Last3Months, Last6Months, ThisYear, LastYear, Custom];

    /// <summary>The longest custom range (about two years), so a page can't ask for the whole history.</summary>
    public const int MaxCustomDays = 800;
}

/// <summary>A Cairo date range, both ends included, and the previous range of the same length (BR-REV4).</summary>
public readonly record struct Period(DateOnly From, DateOnly To)
{
    public int Days => To.DayNumber - From.DayNumber + 1;

    public Period Previous => new(From.AddDays(-Days), From.AddDays(-1));

    public bool Contains(DateOnly day) => day >= From && day <= To;

    /// <summary>Saturday of the week that holds <paramref name="day"/>.</summary>
    public static DateOnly WeekStart(DateOnly day) => day.AddDays(-(((int)day.DayOfWeek + 1) % 7));

    /// <summary>Resolves a preset against today. A custom range is returned as given (the caller validated it).</summary>
    public static Period Resolve(string preset, DateOnly today, DateOnly? from, DateOnly? to)
    {
        var weekStart = WeekStart(today);
        var monthStart = new DateOnly(today.Year, today.Month, 1);
        return preset switch
        {
            PeriodPresets.Today => new(today, today),
            PeriodPresets.Yesterday => new(today.AddDays(-1), today.AddDays(-1)),
            PeriodPresets.ThisWeek => new(weekStart, today),
            PeriodPresets.LastWeek => new(weekStart.AddDays(-7), weekStart.AddDays(-1)),
            PeriodPresets.LastMonth => new(monthStart.AddMonths(-1), monthStart.AddDays(-1)),
            PeriodPresets.Last3Months => new(today.AddMonths(-3).AddDays(1), today),
            PeriodPresets.Last6Months => new(today.AddMonths(-6).AddDays(1), today),
            PeriodPresets.ThisYear => new(new DateOnly(today.Year, 1, 1), today),
            PeriodPresets.LastYear => new(new DateOnly(today.Year - 1, 1, 1), new DateOnly(today.Year - 1, 12, 31)),
            PeriodPresets.Custom => new(from!.Value, to!.Value),
            _ => new(monthStart, today),
        };
    }

    /// <summary>The chart granularity for the range: days up to 31, weeks up to about 6 months, then months.</summary>
    public string Bucket => Days <= 31 ? "day" : Days <= 190 ? "week" : "month";

    /// <summary>The start dates of the buckets that cover the range (the first may start before <see cref="From"/>).</summary>
    public IReadOnlyList<DateOnly> BucketStarts(string bucket)
    {
        var starts = new List<DateOnly>();
        switch (bucket)
        {
            case "day":
                for (var day = From; day <= To; day = day.AddDays(1))
                {
                    starts.Add(day);
                }

                break;
            case "week":
                for (var day = WeekStart(From); day <= To; day = day.AddDays(7))
                {
                    starts.Add(day);
                }

                break;
            default:
                for (var day = new DateOnly(From.Year, From.Month, 1); day <= To; day = day.AddMonths(1))
                {
                    starts.Add(day);
                }

                break;
        }

        return starts;
    }

    /// <summary>The bucket start that holds <paramref name="day"/>.</summary>
    public static DateOnly BucketOf(DateOnly day, string bucket) => bucket switch
    {
        "day" => day,
        "week" => WeekStart(day),
        _ => new DateOnly(day.Year, day.Month, 1),
    };
}

/// <summary>The filter of every analytics page (BR-REV2): period, branch and visit type, and compare.</summary>
public sealed class AnalyticsQuery
{
    /// <summary>One of <see cref="PeriodPresets"/>. Default <c>thisMonth</c>.</summary>
    public string? Preset { get; init; }

    public DateOnly? From { get; init; }

    public DateOnly? To { get; init; }

    public Guid? BranchId { get; init; }

    /// <summary><c>examination</c> or <c>consultation</c>; empty is both.</summary>
    public string? Type { get; init; }

    /// <summary>Compare with the previous period (BR-REV4). Default true.</summary>
    public bool? Compare { get; init; }
}

public sealed class AnalyticsQueryValidator : AbstractValidator<AnalyticsQuery>
{
    public AnalyticsQueryValidator()
    {
        RuleFor(x => x.Preset).OneOf(PeriodPresets.All).When(x => x.Preset is not null);
        RuleFor(x => x.Type).OneOf(SessionTypes.All).When(x => x.Type is not null);
        RuleFor(x => x.From).Required().When(x => x.Preset == PeriodPresets.Custom);
        RuleFor(x => x.To).Required().When(x => x.Preset == PeriodPresets.Custom);
        RuleFor(x => x)
            .Must(x => x.To >= x.From && x.To!.Value.DayNumber - x.From!.Value.DayNumber < PeriodPresets.MaxCustomDays)
            .WithName("to").WithErrorCode(ErrorCodes.OutOfRange).WithMessage("The range must end after it starts and be shorter than about two years.")
            .When(x => x.Preset == PeriodPresets.Custom && x.From is not null && x.To is not null);
    }
}

/// <summary>One non-deleted session reduced to what the analytics need.</summary>
public sealed record SessionRow(
    DateOnly Day,
    Guid BranchId,
    string Type,
    Guid PatientId,
    int PatientFeePiasters,
    int? ListPricePiasters,
    int FeePiasters,
    DateTime CreatedAt,
    string? PaymentMethod)
{
    public bool IsExamination => Type == SessionTypes.Examination;

    /// <summary>The visit price minus the amount charged, when the clinic charged less (BR-S10, section 6.14 "Discount").</summary>
    public int DiscountPiasters => ListPricePiasters is { } list && list > PatientFeePiasters ? list - PatientFeePiasters : 0;
}

public sealed record BookingRow(DateOnly Day, Guid BranchId, string Status, string Source, DateTime? CheckedInAt, DateTime? CalledAt);

/// <summary>Reads the rows the analytics pages work on, limited to the branches the caller may see (BR-AS13).</summary>
public sealed class AnalyticsData(AppDbContext db)
{
    /// <summary>
    /// The branch ids to filter by: the requested branch (when the caller may use it and it is the doctor's), the
    /// assistant's branches, or null for every branch. <c>Allowed</c> is false for a branch the caller can't use.
    /// </summary>
    public async Task<(IReadOnlyList<Guid>? Branches, bool Allowed)> BranchesAsync(
        ClinicCaller caller, Guid? requested, CancellationToken cancellationToken)
    {
        if (requested is { } branchId)
        {
            if (!caller.CanUseBranch(branchId) || !await db.Branches.AnyAsync(b => b.Id == branchId && b.DoctorId == caller.DoctorId, cancellationToken))
            {
                return (null, false);
            }

            return ([branchId], true);
        }

        return (caller.BranchScope?.ToList(), true);
    }

    public async Task<List<SessionRow>> SessionsAsync(
        Guid doctorId, DateOnly from, DateOnly to, IReadOnlyList<Guid>? branches, string? type, CancellationToken cancellationToken)
    {
        var sessions = db.Sessions.AsNoTracking().Where(s => s.DoctorId == doctorId && !s.Deleted && s.DayKey >= from && s.DayKey <= to);
        if (branches is not null)
        {
            sessions = sessions.Where(s => branches.Contains(s.BranchId));
        }

        if (type is not null)
        {
            sessions = sessions.Where(s => s.Type == type);
        }

        return await sessions
            .Select(s => new SessionRow(
                s.DayKey, s.BranchId, s.Type, s.PatientId, s.PatientFeePiasters, s.ListPricePiasters, s.FeePiasters, s.CreatedAt, s.PaymentMethod))
            .ToListAsync(cancellationToken);
    }

    public Task<List<BookingRow>> BookingsAsync(
        Guid doctorId, DateOnly from, DateOnly to, IReadOnlyList<Guid>? branches, CancellationToken cancellationToken)
    {
        var bookings = db.Appointments.AsNoTracking().Where(a => a.DoctorId == doctorId && a.LocalDate >= from && a.LocalDate <= to);
        if (branches is not null)
        {
            bookings = bookings.Where(a => branches.Contains(a.BranchId));
        }

        return bookings
            .Select(a => new BookingRow(a.LocalDate, a.BranchId, a.Status, a.Source, a.CheckedInAt, a.CalledAt))
            .ToListAsync(cancellationToken);
    }

    /// <summary>The Cairo day of each patient's first visit with the doctor (DoctorPatients.FirstSessionAt).</summary>
    public async Task<Dictionary<Guid, DateOnly>> FirstVisitsAsync(Guid doctorId, IReadOnlyCollection<Guid> patientIds, CancellationToken cancellationToken)
    {
        if (patientIds.Count == 0)
        {
            return [];
        }

        var rows = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.DoctorId == doctorId && l.FirstSessionAt != null && patientIds.Contains(l.PatientId))
            .Select(l => new { l.PatientId, At = l.FirstSessionAt!.Value })
            .ToListAsync(cancellationToken);
        return rows.ToDictionary(r => r.PatientId, r => CairoTime.DayOf(r.At));
    }
}

public static class Pct
{
    /// <summary>The change from <paramref name="previous"/> to <paramref name="current"/> in percent, or null when there is no base.</summary>
    public static double? Change(double current, double? previous) =>
        previous is > 0 ? Math.Round((current - previous.Value) / previous.Value * 100, 1) : null;

    public static double Round(double value) => Math.Round(value, 1, MidpointRounding.AwayFromZero);

    public static string Culture(double value) => value.ToString("0.#", CultureInfo.InvariantCulture);
}
