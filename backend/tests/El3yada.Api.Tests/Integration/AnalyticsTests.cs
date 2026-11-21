using System.Net;
using System.Text.Json;
using El3yada.Api.Analytics;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Billing;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Controllers;
using El3yada.Api.Features.Appointments;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace El3yada.Api.Tests.Integration;

public static partial class TestData
{
    private static int _queueNumber;

    /// <summary>A booking straight in the database (queue mode, so a booking that has arrived or passed has its number).</summary>
    public static async Task<Guid> AddAppointmentAsync(
        IntegrationFactory factory, Guid doctorId, Guid patientId, DateOnly day, string status = "confirmed", string source = "staff",
        Guid? branchId = null, string visitType = "examination", DateTime? checkedInAt = null, DateTime? calledAt = null)
    {
        var id = Guid.NewGuid();
        await WithDbAsync(factory, async db =>
        {
            var branch = branchId ?? await db.Doctors.Where(d => d.UserId == doctorId).Select(d => d.DefaultBranchId!.Value).SingleAsync();
            var start = CairoTime.StartUtc(day).AddHours(12);
            db.Appointments.Add(new Appointment
            {
                Id = id, DoctorId = doctorId, BranchId = branch, PatientId = patientId, VisitType = visitType, Mode = "queue", LocalDate = day,
                PeriodStartLocal = new TimeOnly(12, 0), QueueNumber = status is "cancelled" or "rejected" or "pending" ? null : Interlocked.Increment(ref _queueNumber), StartUtc = start, EndUtc = start.AddHours(3), Status = status, Source = source,
                BookedBy = doctorId, BookedByRole = "doctor", CheckedInAt = checkedInAt, CalledAt = calledAt,
                CreatedAt = start.AddDays(-2), UpdatedAt = start.AddDays(-2),
            });
            await db.SaveChangesAsync();
        });
        return id;
    }
}

/// <summary>
/// Phase 7 analytics: the dashboard (D1), the revenue report (D35), the patients register's booking columns (D4), the nightly
/// metrics, and the admin's view of the doctors (AC-12, AC-23, AC-24). Money never reaches an admin or an assistant without
/// <c>revenueView</c>.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class AnalyticsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private const string October = "preset=custom&from=2026-10-01&to=2026-10-31";

    private static readonly DateOnly Oct5 = new(2026, 10, 5);

    private async Task<(TestUser Doctor, Guid PatientId, Guid BranchA, Guid BranchB)> ClinicAsync()
    {
        var (doctor, patient) = await TestData.CreateDoctorWithPatientAsync(Factory);
        var a = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var b = await TestData.AddBranchAsync(Factory, doctor.Id);
        return (doctor, patient, a, b);
    }

    private static double Value(JsonElement tile) => tile.GetProperty("value").GetDouble();

    // ---- AC-23 -------------------------------------------------------------------------------------------------

    [Fact]
    public async Task A_visit_charged_below_the_visit_price_gives_revenue_discount_fee_and_net()
    {
        var (doctor, patient, _, _) = await ClinicAsync();
        // Visit price 300 EGP, charged 250 EGP, platform fee 30 EGP (the spec's example).
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5, "examination", feePiasters: 3000, patientFeePiasters: 25000, listPricePiasters: 30000);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        var (_, dashboard) = await asDoctor.GetJsonAsync($"/api/dashboard?{October}");
        Assert.Equal(25000, Value(dashboard.GetProperty("tiles").GetProperty("revenue")));
        Assert.Equal(3000, Value(dashboard.GetProperty("tiles").GetProperty("platformFees")));
        Assert.Equal(22000, Value(dashboard.GetProperty("tiles").GetProperty("netIncome")));
        Assert.Equal(1, Value(dashboard.GetProperty("tiles").GetProperty("visits")));

        var (_, report) = await asDoctor.GetJsonAsync("/api/revenue?year=2026");
        var month = report.GetProperty("months").EnumerateArray().Single(m => m.Str("monthKey") == "2026-10").GetProperty("row");
        Assert.Equal(25000, month.GetProperty("revenuePiasters").GetInt32());
        Assert.Equal(5000, month.GetProperty("discountPiasters").GetInt32());
        Assert.Equal(1, month.GetProperty("discountedVisits").GetInt32());
        Assert.Equal(3000, month.GetProperty("platformFeesPiasters").GetInt32());
        Assert.Equal(22000, month.GetProperty("netPiasters").GetInt32());
    }

    [Fact]
    public async Task The_filters_change_every_tile_and_chart_and_the_totals_match_the_revenue_page()
    {
        var (doctor, patient, a, b) = await ClinicAsync();
        var (_, other) = await TestData.CreatePatientAsync(Factory);
        await TestData.LinkAsync(Factory, doctor.Id, other, "علي محمود");
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5, "examination", 3000, 30000, branchId: a);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5.AddDays(1), "consultation", 1500, 15000, branchId: a);
        await TestData.AddSessionAsync(Factory, doctor.Id, other, Oct5.AddDays(2), "examination", 3000, 20000, branchId: b);
        await TestData.AddSessionAsync(Factory, doctor.Id, other, Oct5.AddDays(3), "examination", 3000, 40000, branchId: a);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        var (_, all) = await asDoctor.GetJsonAsync($"/api/dashboard?{October}");
        var (_, branchA) = await asDoctor.GetJsonAsync($"/api/dashboard?{October}&branchId={a}");
        var (_, branchAExams) = await asDoctor.GetJsonAsync($"/api/dashboard?{October}&branchId={a}&type=examination");
        Assert.Equal(4, Value(all.GetProperty("tiles").GetProperty("visits")));
        Assert.Equal(105000, Value(all.GetProperty("tiles").GetProperty("revenue")));
        Assert.Equal(3, Value(branchA.GetProperty("tiles").GetProperty("visits")));
        Assert.Equal(85000, Value(branchA.GetProperty("tiles").GetProperty("revenue")));
        Assert.Equal(2, Value(branchAExams.GetProperty("tiles").GetProperty("visits")));
        Assert.Equal(70000, Value(branchAExams.GetProperty("tiles").GetProperty("revenue")));
        Assert.Equal(2, Value(branchAExams.GetProperty("tiles").GetProperty("uniquePatients")));
        // The charts follow the same filter: C1 adds up to the revenue tile, C7 and C8 agree.
        Assert.Equal(70000, branchAExams.GetProperty("revenueSeries").EnumerateArray().Sum(p => p.GetProperty("examinationPiasters").GetInt32() + p.GetProperty("consultationPiasters").GetInt32()));
        Assert.Equal(0, branchAExams.GetProperty("typeSplit").GetProperty("consultations").GetInt32());
        Assert.Equal(2, all.GetProperty("branches").GetArrayLength());

        // D35 with the same filters gives the same totals.
        var (_, report) = await asDoctor.GetJsonAsync($"/api/revenue?from=2026-10-01&to=2026-10-31&branchId={a}&type=examination");
        var totals = report.GetProperty("totals");
        Assert.Equal(70000, totals.GetProperty("revenuePiasters").GetInt32());
        Assert.Equal(2, totals.GetProperty("examinations").GetInt32());
        Assert.Equal(0, totals.GetProperty("consultations").GetInt32());
        Assert.Equal(2, totals.GetProperty("uniquePatients").GetInt32());

        // Another doctor's branch is refused.
        var (strangerStatus, _) = await asDoctor.GetJsonAsync($"/api/dashboard?{October}&branchId={Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Forbidden, strangerStatus);
    }

    [Fact]
    public async Task Compare_shows_the_change_against_the_previous_period_of_the_same_length()
    {
        var (doctor, patient, _, _) = await ClinicAsync();
        // October (31 days) is compared with the 31 days before it.
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 9, 20), "examination", 3000, 20000);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5, "examination", 3000, 25000);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        var (_, on) = await asDoctor.GetJsonAsync($"/api/dashboard?{October}");
        var revenue = on.GetProperty("tiles").GetProperty("revenue");
        Assert.Equal(25000, revenue.GetProperty("value").GetDouble());
        Assert.Equal(20000, revenue.GetProperty("previous").GetDouble());
        Assert.Equal(25, revenue.GetProperty("changePct").GetDouble());
        Assert.Equal("2026-09-30", on.GetProperty("period").Str("previousTo"));
        Assert.Contains(on.GetProperty("insights").EnumerateArray(), i => i.Str("code") == "revenueChange");

        var (_, off) = await asDoctor.GetJsonAsync($"/api/dashboard?{October}&compare=false");
        Assert.Equal(JsonValueKind.Null, off.GetProperty("tiles").GetProperty("revenue").GetProperty("previous").ValueKind);
        Assert.DoesNotContain(off.GetProperty("insights").EnumerateArray(), i => i.Str("code") == "revenueChange");
    }

    [Fact]
    public async Task Today_is_live_as_soon_as_a_session_is_saved()
    {
        var (doctor, patient, _, _) = await ClinicAsync();
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, CairoTime.Today(TimeProvider.System), "examination", 3000, 30000);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        var (_, live) = await asDoctor.GetJsonAsync("/api/dashboard?preset=today");
        Assert.Equal(30000, Value(live.GetProperty("tiles").GetProperty("revenue")));
        Assert.Equal(1, Value(live.GetProperty("tiles").GetProperty("visits")));
    }

    [Fact]
    public async Task The_three_busiest_and_three_quietest_months_of_the_year_are_highlighted()
    {
        var (doctor, patient, _, _) = await ClinicAsync();
        var today = CairoTime.Today(TimeProvider.System);
        // Twelve months: 1 visit in some, more in others, so there is a clear top and bottom three.
        var counts = new[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
        for (var i = 0; i < 12; i++)
        {
            var month = new DateOnly(today.Year, today.Month, 1).AddMonths(i - 11).AddDays(2);
            for (var n = 0; n < counts[i]; n++)
            {
                await TestData.AddSessionAsync(Factory, doctor.Id, patient, month, "examination", 3000, 30000);
            }
        }

        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        var (_, live) = await asDoctor.GetJsonAsync("/api/dashboard?preset=today");
        var months = live.GetProperty("months").EnumerateArray().ToList();
        Assert.Equal(12, months.Count);
        Assert.Equal([9, 10, 11], months.Select((m, i) => (m, i)).Where(x => x.m.GetProperty("busiest").GetBoolean()).Select(x => x.i).ToArray());
        Assert.Equal([0, 1, 2], months.Select((m, i) => (m, i)).Where(x => x.m.GetProperty("quietest").GetBoolean()).Select(x => x.i).ToArray());
    }

    // ---- BR-REV1 ---------------------------------------------------------------------------------------------------

    [Fact]
    public async Task Money_is_hidden_from_assistants_without_revenue_view_and_admins_get_403()
    {
        var (doctor, patient, _, _) = await ClinicAsync();
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5, "examination", 3000, 25000, 30000);
        var noMoney = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.AppointmentsView, ClinicPermissions.BillingView]);
        var withMoney = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.RevenueView]);
        var nothing = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.PatientsManage]);
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asNoMoney = await Factory.SignedInClientAsync(noMoney);
        using var asWithMoney = await Factory.SignedInClientAsync(withMoney);
        using var asNothing = await Factory.SignedInClientAsync(nothing);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var (status, body) = await asNoMoney.GetJsonAsync($"/api/dashboard?{October}");
        Assert.Equal(HttpStatusCode.OK, status);
        var tiles = body.GetProperty("tiles");
        foreach (var money in new[] { "revenue", "netIncome", "averageRevenuePerVisit" })
        {
            Assert.Equal(JsonValueKind.Null, tiles.GetProperty(money).ValueKind);
        }

        Assert.Equal(JsonValueKind.Null, body.GetProperty("revenueSeries").ValueKind);
        Assert.Equal(1, Value(tiles.GetProperty("visits")));
        Assert.Equal(3000, Value(tiles.GetProperty("platformFees")));   // billingView
        Assert.Equal(JsonValueKind.Null, body.GetProperty("typeSplit").GetProperty("examinationRevenuePiasters").ValueKind);
        Assert.Equal(HttpStatusCode.Forbidden, (await asNoMoney.GetJsonAsync("/api/revenue")).Status);

        // revenueView alone shows the money and none of the patient counts or the fee cards.
        var (_, moneyOnly) = await asWithMoney.GetJsonAsync($"/api/dashboard?{October}");
        Assert.Equal(25000, Value(moneyOnly.GetProperty("tiles").GetProperty("revenue")));
        Assert.Equal(JsonValueKind.Null, moneyOnly.GetProperty("tiles").GetProperty("visits").ValueKind);
        Assert.Equal(JsonValueKind.Null, moneyOnly.GetProperty("tiles").GetProperty("platformFees").ValueKind);
        Assert.Equal(HttpStatusCode.OK, (await asWithMoney.GetJsonAsync("/api/revenue?year=2026")).Status);

        Assert.Equal(HttpStatusCode.Forbidden, (await asNothing.GetJsonAsync("/api/dashboard")).Status);
        // AC-23: an admin asking for a doctor's revenue is refused.
        foreach (var route in new[] { "/api/dashboard", "/api/revenue", "/api/revenue/month", "/api/revenue/day" })
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await asAdmin.GetJsonAsync(route)).Status);
        }
    }

    [Fact]
    public async Task An_assistant_sees_only_the_numbers_of_their_own_branches()
    {
        var (doctor, patient, a, b) = await ClinicAsync();
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5, "examination", 3000, 10000, branchId: a);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5, "examination", 3000, 90000, branchId: b);
        var assistant = await TestData.CreateAssistantAsync(
            Factory, doctor.Id, permissions: [ClinicPermissions.RevenueView, ClinicPermissions.AppointmentsView], branchIds: [a]);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);

        var (_, body) = await asAssistant.GetJsonAsync($"/api/dashboard?{October}");
        Assert.Equal(10000, Value(body.GetProperty("tiles").GetProperty("revenue")));
        Assert.Equal(HttpStatusCode.Forbidden, (await asAssistant.GetJsonAsync($"/api/dashboard?{October}&branchId={b}")).Status);
        var (_, report) = await asAssistant.GetJsonAsync("/api/revenue?year=2026");
        Assert.Equal(10000, report.GetProperty("totals").GetProperty("revenuePiasters").GetInt32());
    }

    // ---- D35 ---------------------------------------------------------------------------------------------------

    [Fact]
    public async Task The_revenue_page_drills_from_the_year_to_the_month_to_the_day_and_links_the_invoice()
    {
        var (doctor, patient, _, _) = await ClinicAsync();
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 9, 10), "examination", 3000, 20000);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5, "examination", 3000, 30000);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, Oct5, "consultation", 1500, 0, listPricePiasters: 15000);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 10, 9), "examination", 3000, 40000);
        await using (var scope = Factory.CreateScope())
        {
            await TestData.BillingAt(scope, new DateTimeOffset(2026, 11, 1, 0, 5, 0, TimeSpan.FromHours(2))).MonthlyCloseAsync("2026-10", CancellationToken.None);
        }

        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        var (_, report) = await asDoctor.GetJsonAsync("/api/revenue?from=2026-09-01&to=2026-10-31");
        var months = report.GetProperty("months").EnumerateArray().ToList();
        Assert.Equal(["2026-09", "2026-10"], months.Select(m => m.Str("monthKey")).ToArray());
        Assert.Equal(70000, months[1].GetProperty("row").GetProperty("revenuePiasters").GetInt32());
        Assert.Equal(250, months[1].GetProperty("changePct").GetDouble());
        Assert.Equal(1, months[1].GetProperty("row").GetProperty("freeVisits").GetInt32());
        Assert.Equal(JsonValueKind.String, months[1].GetProperty("invoiceId").ValueKind);   // the doctor has billingView
        Assert.Equal("2026-10", report.Str("bestMonth"));
        Assert.Equal("2026-09", report.Str("worstMonth"));
        Assert.Equal(90000, report.GetProperty("totals").GetProperty("revenuePiasters").GetInt32());
        Assert.Equal(2, report.GetProperty("byType").GetArrayLength());

        var (_, month) = await asDoctor.GetJsonAsync("/api/revenue/month?month=2026-10");
        var days = month.GetProperty("days").EnumerateArray().ToList();
        Assert.Equal(31, days.Count);
        var fifth = days.Single(d => d.Str("day") == "2026-10-05").GetProperty("row");
        Assert.Equal((1, 1), (fifth.GetProperty("examinations").GetInt32(), fifth.GetProperty("consultations").GetInt32()));
        Assert.Equal(70000, month.GetProperty("totals").GetProperty("revenuePiasters").GetInt32());

        var (_, day) = await asDoctor.GetJsonAsync("/api/revenue/day?day=2026-10-05");
        var sessions = day.GetProperty("sessions").EnumerateArray().ToList();
        Assert.Equal(2, sessions.Count);
        var free = sessions.Single(s => s.Str("type") == "consultation");
        Assert.Equal(15000, free.GetProperty("discountPiasters").GetInt32());
        Assert.Equal("منى حسن", free.Str("patientName"));

        // An assistant with revenueView but no billingView doesn't get the invoice links.
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.RevenueView]);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);
        var (_, limited) = await asAssistant.GetJsonAsync("/api/revenue?from=2026-09-01&to=2026-10-31");
        Assert.Equal(JsonValueKind.Null, limited.GetProperty("months")[1].GetProperty("invoiceId").ValueKind);
    }

    // ---- D4, AC-24 -------------------------------------------------------------------------------------------------

    [Fact]
    public async Task The_not_seen_for_6_months_bar_and_the_register_filter_list_the_same_patients_with_their_bookings()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var today = CairoTime.Today(TimeProvider.System);
        var patients = new List<Guid>();
        foreach (var monthsAgo in new[] { 1, 7, 9, 14 })
        {
            var (_, id) = await TestData.CreatePatientAsync(Factory);
            await TestData.LinkAsync(Factory, doctor.Id, id, $"مريض {monthsAgo}");
            var day = today.AddMonths(-monthsAgo);
            await TestData.AddSessionAsync(Factory, doctor.Id, id, day);
            await TestData.WithDbAsync(Factory, db => db.DoctorPatients.Where(l => l.DoctorId == doctor.Id && l.PatientId == id)
                .ExecuteUpdateAsync(set => set.SetProperty(l => l.LastSessionAt, CairoTime.StartUtc(day).AddHours(10)).SetProperty(l => l.FirstSessionAt, CairoTime.StartUtc(day).AddHours(10))
                    .SetProperty(l => l.SessionCount, 1)));
            patients.Add(id);
        }

        await TestData.AddAppointmentAsync(Factory, doctor.Id, patients[0], today.AddDays(2), "confirmed");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, patients[0], today.AddDays(5), "pending");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, patients[1], today.AddDays(-20), "noShow");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, patients[1], today.AddDays(-40), "noShow");
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        var (_, dashboard) = await asDoctor.GetJsonAsync("/api/dashboard?preset=thisYear");
        var bar = dashboard.GetProperty("notSeen").EnumerateArray().Single(b => b.GetProperty("months").GetInt32() == 6);
        Assert.Equal(3, bar.GetProperty("patients").GetInt32());
        Assert.Equal("notSeen6m", bar.Str("filter"));
        Assert.Contains(dashboard.GetProperty("insights").EnumerateArray(), i => i.Str("code") == "notSeen6Months" && i.Str("filter") == "notSeen6m");

        var (_, register) = await asDoctor.GetJsonAsync($"/api/patients/register?lastVisit={bar.Str("filter")}");
        Assert.Equal(3, register.GetProperty("totalCount").GetInt32());

        var (_, all) = await asDoctor.GetJsonAsync("/api/patients/register?pageSize=50");
        var first = all.GetProperty("items").EnumerateArray().Single(r => r.GetProperty("patientId").GetGuid() == patients[0]);
        Assert.Equal(today.AddDays(2).ToString("yyyy-MM-dd"), first.GetProperty("nextBooking").Str("date"));
        Assert.Equal("confirmed", first.GetProperty("nextBooking").Str("status"));
        var second = all.GetProperty("items").EnumerateArray().Single(r => r.GetProperty("patientId").GetGuid() == patients[1]);
        Assert.Equal(2, second.GetProperty("noShowCount").GetInt32());
        Assert.Equal(JsonValueKind.Null, second.GetProperty("nextBooking").ValueKind);

        Assert.Equal(1, (await asDoctor.GetJsonAsync("/api/patients/register?hasUpcomingBooking=true")).Body.GetProperty("totalCount").GetInt32());
        Assert.Equal(1, (await asDoctor.GetJsonAsync("/api/patients/register?hasNoShows=true")).Body.GetProperty("totalCount").GetInt32());
    }

    // ---- BR-AP10 -----------------------------------------------------------------------------------------------------

    [Fact]
    public async Task A_session_started_from_a_checked_in_booking_completes_it()
    {
        var (doctor, patient) = await TestData.CreateDoctorWithPatientAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var today = CairoTime.Today(TimeProvider.System);
        var booking = await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, today, "checkedIn", checkedInAt: DateTime.UtcNow.AddMinutes(-20));
        var stranger = await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, today, "checkedIn");
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        object Body(Guid? appointment) => new
        {
            patientId = patient, branchId = branch, type = "examination", amountChargedPiasters = 20000, appointmentId = appointment,
        };

        var (wrongBranch, _) = await asDoctor.PostAsync("/api/sessions/createSession", new
        {
            patientId = patient, branchId = await TestData.AddBranchAsync(Factory, doctor.Id), type = "examination", amountChargedPiasters = 20000, appointmentId = booking,
        });
        Assert.Equal(HttpStatusCode.NotFound, wrongBranch);   // the booking belongs to another branch than the one sent

        var (created, session) = await asDoctor.PostAsync("/api/sessions/createSession", Body(booking));
        Assert.Equal(HttpStatusCode.Created, created);
        var row = await TestData.WithDbAsync(Factory, db => db.Appointments.SingleAsync(a => a.Id == booking));
        Assert.Equal("completed", row.Status);
        Assert.NotNull(row.SessionId);
        Assert.Equal(booking, await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.Id == row.SessionId).Select(s => s.AppointmentId).SingleAsync()));

        // The same booking can't complete twice.
        var (again, _) = await asDoctor.PostAsync("/api/sessions/createSession", Body(booking));
        Assert.Equal(HttpStatusCode.Conflict, again);
        Assert.Equal("checkedIn", await TestData.WithDbAsync(Factory, db => db.Appointments.Where(a => a.Id == stranger).Select(a => a.Status).SingleAsync()));
    }

    // ---- buildDailyMetrics -------------------------------------------------------------------------------------------

    [Fact]
    public async Task The_nightly_metrics_hold_the_day_per_branch_and_rebuild_the_same_rows_when_run_again_or_after_a_deletion()
    {
        var (doctor, patient, a, b) = await ClinicAsync();
        var day = new DateOnly(2026, 10, 12);
        var at = CairoTime.StartUtc(day).AddHours(10);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, day, "examination", 3000, 25000, 30000, branchId: a);
        var removable = await TestData.AddSessionAsync(Factory, doctor.Id, patient, day, "consultation", 1500, 0, 15000, branchId: a);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, day, "examination", 3000, 20000, branchId: b);
        await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, day, "completed", "patientApp", a, checkedInAt: at, calledAt: at.AddMinutes(30));
        await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, day, "noShow", "staff", a);
        await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, day, "cancelled", "patientApp", a);
        await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, day, "completed", "walkIn", a);

        async Task<int> BuildAsync()
        {
            await using var scope = Factory.CreateScope();
            var services = scope.ServiceProvider;
            return await new DailyMetricsBuilder(services.GetRequiredService<AppDbContext>(), new StoppedClock(DateTimeOffset.UtcNow), NullLogger<DailyMetricsBuilder>.Instance)
                .BuildDayAsync(day, doctor.Id, CancellationToken.None);
        }

        Assert.Equal(2, await BuildAsync());
        var rows = await TestData.WithDbAsync(Factory, db => db.DoctorDailyMetrics.Where(m => m.DoctorId == doctor.Id && m.Date == day).ToListAsync());
        var branchA = rows.Single(r => r.BranchId == a);
        Assert.Equal((1, 1, 25000, 5000 + 15000, 4500), (branchA.ExamCount, branchA.ConsultationCount, branchA.PatientRevenuePiasters, branchA.DiscountPiasters, branchA.PlatformFeesPiasters));
        Assert.Equal(1, branchA.UniquePatients);
        Assert.Equal(1, branchA.FreeVisits);
        Assert.Equal((3, 2, 1, 1, 1, 1), (branchA.Bookings, branchA.CompletedBookings, branchA.NoShows, branchA.Cancellations, branchA.AppBookings, branchA.WalkIns));
        Assert.Equal(30m, branchA.AvgWaitMinutes);
        Assert.Equal(2, JsonSerializer.Deserialize<int[]>(branchA.VisitsByHourJson)!.Sum());
        Assert.Equal(20000, rows.Single(r => r.BranchId == b).PatientRevenuePiasters);

        // A second run changes nothing.
        Assert.Equal(2, await BuildAsync());
        Assert.Equal(2, await TestData.WithDbAsync(Factory, db => db.DoctorDailyMetrics.CountAsync(m => m.DoctorId == doctor.Id && m.Date == day)));

        // A session deleted afterwards: the changed day is rebuilt by the job.
        await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.Id == removable)
            .ExecuteUpdateAsync(set => set.SetProperty(s => s.Deleted, true).SetProperty(s => s.DeletedAt, DateTime.UtcNow)
                .SetProperty(s => s.DeletedBy, doctor.Id).SetProperty(s => s.DeleteReason, "خطأ").SetProperty(s => s.UpdatedAt, DateTime.UtcNow)));
        await using (var scope = Factory.CreateScope())
        {
            var services = scope.ServiceProvider;
            var builder = new DailyMetricsBuilder(services.GetRequiredService<AppDbContext>(), new StoppedClock(DateTimeOffset.UtcNow), NullLogger<DailyMetricsBuilder>.Instance);
            Assert.True(await builder.RebuildChangedDaysAsync(TimeSpan.FromHours(1), CancellationToken.None) >= 2);
        }

        var after = await TestData.WithDbAsync(Factory, db => db.DoctorDailyMetrics.SingleAsync(m => m.DoctorId == doctor.Id && m.Date == day && m.BranchId == a));
        Assert.Equal(0, after.ConsultationCount);
        Assert.Equal(3000, after.PlatformFeesPiasters);
    }

    // ---- AD1, AD4, AD5 ---------------------------------------------------------------------------------------------

    [Fact]
    public async Task The_admin_dashboard_has_the_platform_numbers_and_no_clinic_revenue()
    {
        var (doctor, patient, _, _) = await ClinicAsync();
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, CairoTime.Today(TimeProvider.System), "examination", 3000, 77777);
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        var response = await asAdmin.GetAsync("/api/admin/dashboard");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var text = await response.Content.ReadAsStringAsync();
        var body = JsonDocument.Parse(text).RootElement;
        Assert.True(body.GetProperty("doctors").GetProperty("active").GetInt32() >= 1);
        Assert.True(body.GetProperty("sessionsToday").GetProperty("examinations").GetInt32() >= 1);
        Assert.True(body.GetProperty("expectedFeesThisMonthPiasters").GetInt32() >= 3000);
        Assert.Equal(30, body.GetProperty("sessionsPerDay").GetArrayLength());
        Assert.Equal(12, body.GetProperty("invoicedVsCollected").GetArrayLength());
        Assert.DoesNotContain("77777", text);   // the amount the clinic charged never reaches the admin (BR-REV1)
        Assert.Equal(HttpStatusCode.Forbidden, (await asDoctor.GetAsync("/api/admin/dashboard")).StatusCode);
    }

    [Fact]
    public async Task The_doctor_directory_lists_sessions_and_debt_and_the_activity_tab_masks_patient_names()
    {
        var (doctor, patient, _, _) = await ClinicAsync();
        var thisMonth = CairoTime.Today(TimeProvider.System);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, thisMonth, "examination", 3000, 88888);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, thisMonth, "consultation", 1500, 0, deleted: true);
        var invoiceId = Guid.NewGuid();
        await TestData.WithDbAsync(Factory, async db =>
        {
            db.Invoices.Add(new Invoice
            {
                Id = invoiceId, DoctorId = doctor.Id, MonthKey = "2026-08", PeriodStart = new DateOnly(2026, 8, 1), PeriodEnd = new DateOnly(2026, 8, 31),
                ExamCount = 1, ExamAmountPiasters = 4000, TotalDuePiasters = 4000, DueDate = new DateOnly(2026, 9, 7), Status = "overdue",
            });
            await db.SaveChangesAsync();
        });
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var (_, list) = await asAdmin.GetJsonAsync($"/api/admin/doctors?search={Uri.EscapeDataString("أحمد")}&pageSize=100&sort=outstanding");
        var row = list.GetProperty("items").EnumerateArray().Single(d => d.GetProperty("doctorId").GetGuid() == doctor.Id);
        Assert.Equal(1, row.GetProperty("sessionsThisMonth").GetInt32());
        Assert.Equal(4000, row.GetProperty("outstandingPiasters").GetInt32());
        Assert.Equal("active", row.Str("status"));

        var response = await asAdmin.GetAsync($"/api/admin/doctors/{doctor.Id}/activity");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var text = await response.Content.ReadAsStringAsync();
        var activity = JsonDocument.Parse(text).RootElement;
        var session = activity.GetProperty("sessions").GetProperty("items").EnumerateArray().Single();
        Assert.Equal("م*** ح***", session.Str("patientMasked"));
        Assert.DoesNotContain("منى", text);
        Assert.DoesNotContain("88888", text);
        Assert.Equal(1, activity.GetProperty("months").EnumerateArray().Sum(m => m.GetProperty("examinations").GetInt32()));

        var (_, audit) = await asAdmin.GetJsonAsync($"/api/admin/doctors/{doctor.Id}/audit");
        var deleted = audit.GetProperty("deletedSessions").GetProperty("items").EnumerateArray().Single();
        Assert.Equal("خطأ في الإدخال", deleted.Str("reason"));
        Assert.Equal("م*** ح***", deleted.Str("patientMasked"));

        var (noteStatus, _) = await asAdmin.PostAsync("/api/admin/doctors/addDoctorNote", new { doctorId = doctor.Id, text = "اتصل بنا بخصوص الفاتورة" });
        Assert.Equal(HttpStatusCode.Created, noteStatus);
        var (_, notes) = await asAdmin.GetJsonAsync($"/api/admin/doctors/{doctor.Id}/notes");
        Assert.Equal("اتصل بنا بخصوص الفاتورة", notes[0].Str("text"));
        Assert.Equal(HttpStatusCode.OK, (await asAdmin.GetJsonAsync($"/api/admin/doctors/{doctor.Id}/branches")).Status);
        Assert.Equal(HttpStatusCode.OK, (await asAdmin.GetJsonAsync($"/api/admin/doctors/{doctor.Id}/appointments")).Status);
        Assert.Equal(HttpStatusCode.OK, (await asAdmin.GetJsonAsync($"/api/admin/doctors/{doctor.Id}/assistants")).Status);

        // Only admins: the doctor, an assistant and a patient are refused.
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        Assert.Equal(HttpStatusCode.Forbidden, (await asDoctor.GetJsonAsync($"/api/admin/doctors/{doctor.Id}/activity")).Status);
        Assert.Equal(HttpStatusCode.Forbidden, (await asDoctor.GetJsonAsync("/api/admin/doctors")).Status);
    }

    [Fact]
    public async Task Disabling_a_doctor_cancels_future_bookings_blocks_sign_in_and_can_be_undone()
    {
        var (doctor, patient) = await TestData.CreateDoctorWithPatientAsync(Factory);
        var today = CairoTime.Today(TimeProvider.System);
        var future = await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, today.AddDays(3), "confirmed");
        var pending = await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, today.AddDays(4), "pending");
        var past = await TestData.AddAppointmentAsync(Factory, doctor.Id, patient, today.AddDays(-3), "completed");
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await asAdmin.PostAsync("/api/admin/setDoctorStatus", new { doctorId = doctor.Id, status = "disabled", reason = "مخالفة شروط الاستخدام" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("disabled", body.Str("status"));

        var rows = await TestData.WithDbAsync(Factory, db => db.Appointments.Where(a => a.DoctorId == doctor.Id).ToDictionaryAsync(a => a.Id));
        Assert.Equal("cancelled", rows[future].Status);
        Assert.Equal("system", rows[future].CancelledByRole);
        Assert.Equal("cancelled", rows[pending].Status);
        Assert.Equal("completed", rows[past].Status);
        var cancelledIds = new[] { future.ToString(), pending.ToString() };
        Assert.Equal(2, await TestData.WithDbAsync(Factory, db => db.Notifications.CountAsync(n => n.DataJson != null
            && (n.DataJson.Contains(cancelledIds[0]) || n.DataJson.Contains(cancelledIds[1])))));
        Assert.Contains(AuditActions.DoctorDisabled, await TestData.WithDbAsync(Factory, db => db.AuditLogs.Where(a => a.DoctorId == doctor.Id).Select(a => a.Action).ToListAsync()));

        // The doctor's token stops working at once; a disabled doctor can only be reactivated, not suspended.
        Assert.Equal(HttpStatusCode.Forbidden, (await asDoctor.GetJsonAsync("/api/clinic/me")).Status);
        Assert.Equal(HttpStatusCode.Conflict, (await asAdmin.PostAsync("/api/admin/setDoctorStatus", new { doctorId = doctor.Id, status = "suspended", reason = "سبب ما" })).Status);
        var (reactivated, active) = await asAdmin.PostAsync("/api/admin/setDoctorStatus", new { doctorId = doctor.Id, status = "active", reason = "تمت المراجعة" });
        Assert.Equal(HttpStatusCode.OK, reactivated);
        Assert.Equal("active", active.Str("status"));
        Assert.Equal(HttpStatusCode.OK, (await asDoctor.GetJsonAsync("/api/clinic/me")).Status);
    }
}
