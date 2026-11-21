using El3yada.Api.Common;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>Helpers for the branches, prices, profile, assistants and activity log tests.</summary>
public static partial class TestData
{
    private static int _queueCounter;

    public static DateOnly CairoToday() => CairoTime.Today(TimeProvider.System);

    /// <summary>A createBranch body with every group filled in.</summary>
    public static object NewBranchBody(string nameAr = "فرع الدقي") => new
    {
        info = new { nameAr, nameEn = "Dokki", description = "عيادة الأطفال بالدور الثاني" },
        address = new
        {
            governorate = "الجيزة", city = "الدقي", area = "ميدان المساحة",
            details = "  ١٢ شارع التحرير، الدور التاني، شقة ٤\n(الباب الشمال)  ", landmark = "بجوار البنك الأهلي",
            mapUrl = " https://maps.app.goo.gl/Dokki12345 ",
        },
        contact = new
        {
            phones = new object[]
            {
                new { number = "02 3335 1234", label = "landline", isWhatsapp = false },
                new { number = Local(Mobile()), label = "mobile", isWhatsapp = true },
            },
            email = "Dokki@Clinic.Test",
        },
        clinicInfo = new { paymentMethods = new[] { "instapay", "cash" }, amenities = new[] { "elevator" } },
    };

    /// <summary>
    /// A booking straight in the database (bookings come in Phase 6): a confirmed queue booking for a guest, or for
    /// <paramref name="patientId"/>, at 10:00 Cairo on <paramref name="localDate"/>.
    /// </summary>
    public static async Task<Guid> AddBookingAsync(
        IntegrationFactory factory, Guid doctorId, Guid branchId, DateOnly localDate, string status = "confirmed", Guid? patientId = null)
    {
        var id = Guid.NewGuid();
        var period = new TimeOnly(10, 0);
        var startUtc = TimeZoneInfo.ConvertTimeToUtc(localDate.ToDateTime(period, DateTimeKind.Unspecified), CairoTime.Zone);
        await WithDbAsync(factory, async db =>
        {
            db.Appointments.Add(new Appointment
            {
                Id = id, DoctorId = doctorId, BranchId = branchId, PatientId = patientId,
                GuestName = patientId is null ? "ضيف الاختبار" : null, GuestPhone = patientId is null ? Mobile() : null,
                VisitType = "examination", Mode = "queue", LocalDate = localDate, PeriodStartLocal = period, StartUtc = startUtc,
                QueueNumber = Interlocked.Increment(ref _queueCounter), Status = status, Source = "staff",
                BookedBy = doctorId, BookedByRole = "doctor", CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync();
        });
        return id;
    }

    /// <summary>A weekly period for <see cref="ScheduleBody"/>: ISO weekday, "HH:mm" Cairo times.</summary>
    public static object Period(int weekday, string start, string end, bool endsNextDay = false, string? label = null, int? capacity = null) =>
        new { weekday, start, end, endsNextDay, label, capacity };

    /// <summary>
    /// An <c>updateBranchSchedule</c> body (<c>PUT /api/staff/branches/{id}/schedule</c>, the only way to change a
    /// branch's hours): <paramref name="weekly"/> with the spec's default booking settings, no special dates and no
    /// closures. A dictionary, so a test can change <c>dryRun</c> or <c>decisions</c>.
    /// </summary>
    public static Dictionary<string, object?> ScheduleBody(
        IEnumerable<object> weekly, string mode = "queue", int slotMinutes = 15, bool staffOverbooking = true,
        IEnumerable<object>? dateOverrides = null, IEnumerable<object>? closures = null) => new()
    {
        ["weekly"] = weekly.ToList(),
        ["dateOverrides"] = (dateOverrides ?? []).ToList(),
        ["closures"] = (closures ?? []).ToList(),
        ["settings"] = new
        {
            mode, slotMinutes, examSlots = 1, consultationSlots = 1, defaultCapacity = 30, avgVisitMinutes = 10,
            selfBooking = true, autoConfirm = true, windowDays = 30, minNoticeMinutes = 0, sameDay = true, freeCancelMinutes = 120,
            maxReschedules = 2, maxUpcomingPerPatient = 1, noShowLimitCount = 3, noShowLimitDays = 90, reminderMinutes = new[] { 1440, 120 },
            staffOverbooking, waitingOrderByArrival = false,
        },
        ["dryRun"] = false,
        ["decisions"] = new List<object>(),
    };

    /// <summary>Sends a <see cref="ScheduleBody"/> for <paramref name="branchId"/>.</summary>
    public static Task<(System.Net.HttpStatusCode Status, System.Text.Json.JsonElement Body)> PutScheduleAsync(
        this HttpClient client, Guid branchId, Dictionary<string, object?> body) =>
        client.PutAsync($"/api/staff/branches/{branchId}/schedule", body);

    /// <summary>Sets maxAssistantsPerDoctor (AD13) straight in the database and returns the old value.</summary>
    public static Task<int> SetAssistantLimitAsync(IntegrationFactory factory, int limit) =>
        WithDbAsync(factory, async db =>
        {
            var settings = await db.AppSettings.SingleAsync();
            var before = settings.MaxAssistantsPerDoctor;
            settings.MaxAssistantsPerDoctor = limit;
            await db.SaveChangesAsync();
            return before;
        });

    public static Task<int> BranchLimitAsync(IntegrationFactory factory) =>
        WithDbAsync(factory, db => db.AppSettings.Select(s => s.MaxBranchesPerDoctor).SingleAsync());

    /// <summary>The clinic's audit rows with this action, newest first.</summary>
    public static Task<List<AuditLog>> ClinicAuditAsync(IntegrationFactory factory, Guid doctorId, string action) =>
        WithDbAsync(factory, db => db.AuditLogs.Where(a => a.DoctorId == doctorId && a.Action == action)
            .OrderByDescending(a => a.Id).ToListAsync());
}
