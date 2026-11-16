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
