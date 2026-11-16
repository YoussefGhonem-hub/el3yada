using El3yada.Api.Clinic;
using El3yada.Api.Doctors;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.ClinicAdmin;

/// <summary>A weekly period in answers: ISO weekday, "HH:mm" Cairo times.</summary>
public sealed record BranchPeriodView(int Weekday, string StartLocal, string EndLocal, bool EndsNextDay, string? Label, int? Capacity)
{
    public static BranchPeriodView Of(BranchPeriod p) =>
        new(p.Weekday, WeeklyHours.Format(p.StartLocal), WeeklyHours.Format(p.EndLocal), p.EndsNextDay, p.Label, p.Capacity);
}

/// <summary>
/// A branch's visit prices (section 6.15). <c>examinationPricePiasters</c> and <c>consultationPricePiasters</c> are
/// the branch's own (null = use the doctor's price for that visit type, BR-PR2). <c>effective…</c> is what
/// patients and staff see: the branch's price, else the doctor's, else null («يُرجى الاستفسار من العيادة», BR-PR6).
/// </summary>
public sealed record BranchPricesView(
    int? ExaminationPricePiasters, int? ConsultationPricePiasters, bool UsesDoctorPrices,
    int? EffectiveExaminationPricePiasters, int? EffectiveConsultationPricePiasters)
{
    public static BranchPricesView Of(int? branchExam, int? branchConsult, int? doctorExam, int? doctorConsult) =>
        new(branchExam, branchConsult, branchExam is null && branchConsult is null, branchExam ?? doctorExam, branchConsult ?? doctorConsult);
}

/// <summary>A D28 card.</summary>
public sealed record BranchCardView(
    Guid Id, string NameAr, string? NameEn, string Governorate, string City, string? Area,
    string Status, string? ClosedMessage, DateOnly? ReopenDate, bool IsDefault, bool Assigned,
    IReadOnlyList<BranchPeriodView> TodayPeriods, int UpcomingBookings);

/// <summary>
/// D28. <c>count</c> is the branches that are not archived, which is what <c>limit</c> (maxBranchesPerDoctor)
/// counts; <c>canAdd</c> is <c>count &lt; limit</c>. <c>today</c> and <c>todayWeekday</c> are the Cairo date the
/// cards' <c>todayPeriods</c> are for.
/// </summary>
public sealed record BranchListView(
    IReadOnlyList<BranchCardView> Items, int Count, int Limit, bool CanAdd, DateOnly Today, int TodayWeekday);

public sealed record BranchInfoView(string NameAr, string? NameEn, string? Description);

public sealed record BranchAddressView(
    string Governorate, string City, string? Area, string Details, string? Landmark, string? MapUrl);

public sealed record BranchContactView(IReadOnlyList<BranchPhoneView> Phones, string? Email);

/// <summary>
/// The Working hours tab. <c>bookingMode</c> (<c>queue</c> or <c>timed</c>, read-only until Phase 6) tells the
/// app whether to show each period's capacity; a period without one uses <c>defaultCapacity</c>.
/// </summary>
public sealed record BranchWorkingHoursView(string BookingMode, int DefaultCapacity, IReadOnlyList<BranchPeriodView> Periods);

public sealed record BranchClinicInfoView(BranchPricesView Prices, IReadOnlyList<string> PaymentMethods, IReadOnlyList<string> Amenities);

/// <summary>D29: every tab except booking settings and special dates (Phase 6) and photos ([S]).</summary>
public sealed record BranchDetailsView(
    Guid Id, bool IsDefault, string Status, string? ClosedMessage, DateOnly? ReopenDate, bool Assigned,
    BranchInfoView Info, BranchAddressView Address, BranchContactView Contact, BranchWorkingHoursView WorkingHours,
    BranchClinicInfoView ClinicInfo, DateTime CreatedAt, DateTime UpdatedAt);

/// <summary>A booking that stops a branch from closing or being archived (BR-BR9).</summary>
public sealed record BranchBookingView(
    Guid Id, DateOnly LocalDate, string PeriodStartLocal, DateTime StartUtc, string Status, string VisitType,
    Guid? PatientId, string? Name, bool IsGuest);

public static class BranchQueries
{
    /// <summary>The D29 view of one of the caller's doctor's branches, or null.</summary>
    public static async Task<BranchDetailsView?> LoadDetailsAsync(
        AppDbContext db, ClinicCaller caller, Guid branchId, CancellationToken cancellationToken)
    {
        var row = await db.Branches.AsNoTracking()
            .Where(b => b.Id == branchId && b.DoctorId == caller.DoctorId)
            .Select(b => new
            {
                Branch = b,
                Phones = b.BranchPhones.OrderBy(p => p.SortOrder).ToList(),
                Periods = b.BranchPeriods.OrderBy(p => p.Weekday).ThenBy(p => p.StartLocal).ToList(),
                b.Doctor.ExaminationPricePiasters,
                b.Doctor.ConsultationPricePiasters,
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (row is null)
        {
            return null;
        }

        var b = row.Branch;
        return new BranchDetailsView(
            b.Id, b.IsDefault, b.Status, b.ClosedMessage, b.ReopenDate, caller.CanUseBranch(b.Id),
            new BranchInfoView(b.NameAr, b.NameEn, b.Description),
            new BranchAddressView(b.Governorate, b.City, b.Area, b.AddressDetails, b.Landmark, b.MapUrl),
            new BranchContactView(row.Phones.Select(p => new BranchPhoneView(p.Number, p.Label, p.IsWhatsapp)).ToList(), b.Email),
            new BranchWorkingHoursView(b.BookingMode, b.DefaultCapacity, row.Periods.Select(BranchPeriodView.Of).ToList()),
            new BranchClinicInfoView(
                BranchPricesView.Of(b.ExaminationPricePiasters, b.ConsultationPricePiasters, row.ExaminationPricePiasters, row.ConsultationPricePiasters),
                BranchChecklists.Read(b.PaymentMethodsJson),
                BranchChecklists.Read(b.AmenitiesJson)),
            b.CreatedAt, b.UpdatedAt);
    }

    /// <summary>Branches that count toward maxBranchesPerDoctor: every branch that is not archived.</summary>
    public static Task<int> CountTowardLimitAsync(AppDbContext db, Guid doctorId, CancellationToken cancellationToken) =>
        db.Branches.CountAsync(b => b.DoctorId == doctorId && b.Status != BranchStatuses.Archived, cancellationToken);
}

/// <summary>
/// Bookings that still have to happen: pending, confirmed, checked in or with the doctor, from today (Cairo) on.
/// They are D28's "upcoming bookings" and what BR-BR9 lists before a branch closes or is archived.
/// Bookings come in Phase 6; until then there are none unless a test or the Development-only `add-booking` command
/// (Commands/AddBookingCommand.cs) inserts them.
/// </summary>
public static class BranchBookings
{
    public static readonly string[] OpenStatuses = ["pending", "confirmed", "checkedIn", "withDoctor"];

    /// <summary>Open bookings of the branch on <paramref name="from"/> or later, and before <paramref name="before"/> when set.</summary>
    public static IQueryable<Appointment> Open(AppDbContext db, Guid branchId, DateOnly from, DateOnly? before = null)
    {
        var query = db.Appointments.AsNoTracking()
            .Where(a => a.BranchId == branchId && OpenStatuses.Contains(a.Status) && a.LocalDate >= from);
        return before is { } end ? query.Where(a => a.LocalDate < end) : query;
    }

    /// <summary>The first <paramref name="take"/> of them, earliest first, with the patient's name in this clinic (or the guest's).</summary>
    public static async Task<List<BranchBookingView>> ListAsync(
        AppDbContext db, IQueryable<Appointment> bookings, Guid doctorId, int take, CancellationToken cancellationToken)
    {
        var rows = await bookings
            .OrderBy(a => a.StartUtc).ThenBy(a => a.QueueNumber)
            .Take(take)
            .Select(a => new
            {
                a.Id, a.LocalDate, a.PeriodStartLocal, a.StartUtc, a.Status, a.VisitType, a.PatientId, a.GuestName,
                LinkName = db.DoctorPatients.Where(l => l.DoctorId == doctorId && l.PatientId == a.PatientId)
                    .Select(l => l.PatientName).FirstOrDefault(),
            })
            .ToListAsync(cancellationToken);
        return rows.Select(a => new BranchBookingView(
            a.Id, a.LocalDate, WeeklyHours.Format(a.PeriodStartLocal), a.StartUtc, a.Status, a.VisitType,
            a.PatientId, a.PatientId is null ? a.GuestName : a.LinkName, a.PatientId is null)).ToList();
    }
}

internal static class ClinicLocks
{
    /// <summary>
    /// Locks the doctor's row until the transaction ends. Writes that check a per-doctor limit or rule (branch and
    /// assistant counts, the default and last active branch, price history) take it first, so two requests at the
    /// same moment run one after the other and the second sees the first one's result.
    /// </summary>
    public static Task LockDoctorAsync(AppDbContext db, Guid doctorId, CancellationToken cancellationToken) =>
        db.Database.SqlQuery<Guid>($"SELECT [UserId] AS [Value] FROM [Doctors] WITH (UPDLOCK, ROWLOCK) WHERE [UserId] = {doctorId}")
            .ToListAsync(cancellationToken);
}
