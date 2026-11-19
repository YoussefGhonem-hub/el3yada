using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using El3yada.Api.Features.Appointments;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Api.Infrastructure.Time;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests;

/// <summary>
/// Shared setup: doctor A's main branch runs a queue (capacity 3, two periods covering the whole
/// day); doctor B's branch runs 15-minute timed slots. Both open every day.
/// </summary>
public sealed class BookingFixture : IAsyncLifetime
{
    public ApiFactory Api { get; } = new();
    public Guid QueueBranch { get; private set; }
    public Guid TimedBranch { get; private set; }

    public static readonly TimeOnly Morning = new(0, 0);
    public static readonly TimeOnly Evening = new(12, 0);

    public static DateOnly Tomorrow => CairoTime.Today(TimeProvider.System).AddDays(1);
    public static DateOnly Today => CairoTime.Today(TimeProvider.System);
    public static TimeOnly CurrentPeriod => TimeOnly.FromDateTime(CairoTime.Now(TimeProvider.System)) < Evening ? Morning : Evening;

    public static object Schedule(string mode, int capacity = 3, bool autoConfirm = true, bool staffOverbooking = true, IEnumerable<int>? weekdays = null) => new
    {
        weekly = (weekdays ?? Enumerable.Range(1, 7)).SelectMany(d => new object[]
        {
            new { weekday = d, start = "00:00", end = "11:59", endsNextDay = false, label = "صباحي", capacity = (int?)null },
            new { weekday = d, start = "12:00", end = "23:59", endsNextDay = false, label = "مسائي", capacity = (int?)null },
        }),
        dateOverrides = Array.Empty<object>(),
        closures = Array.Empty<object>(),
        settings = new
        {
            mode, slotMinutes = 15, examSlots = 1, consultationSlots = 1, defaultCapacity = capacity, avgVisitMinutes = 10,
            selfBooking = true, autoConfirm, windowDays = 30, minNoticeMinutes = 0, sameDay = true, freeCancelMinutes = 120,
            maxReschedules = 2, maxUpcomingPerPatient = 1, noShowLimitCount = 3, noShowLimitDays = 90, reminderMinutes = new[] { 1440, 120 },
            staffOverbooking, waitingOrderByArrival = false,
        },
        dryRun = false,
        decisions = Array.Empty<object>(),
    };

    public async Task InitializeAsync()
    {
        await ((IAsyncLifetime)Api).InitializeAsync();
        QueueBranch = await Api.WithDbAsync(db => db.Branches.Where(b => b.DoctorId == Api.Demo.DoctorAUserId && b.IsDefault).Select(b => b.Id).SingleAsync());
        TimedBranch = await Api.WithDbAsync(db => db.Branches.Where(b => b.DoctorId == Api.Demo.DoctorBUserId).Select(b => b.Id).SingleAsync());
        var a = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        (await a.PutAsJsonAsync($"/api/staff/branches/{QueueBranch}/schedule", Schedule("queue"))).EnsureSuccessStatusCode();
        var b = await Api.ClientForAsync(Api.Demo.DoctorBUserId);
        (await b.PutAsJsonAsync($"/api/staff/branches/{TimedBranch}/schedule", Schedule("timed", staffOverbooking: false))).EnsureSuccessStatusCode();
    }

    public async Task DisposeAsync() => await ((IAsyncLifetime)Api).DisposeAsync();
}

public sealed class AppointmentTests(BookingFixture fx) : IClassFixture<BookingFixture>
{
    private ApiFactory Api => fx.Api;

    private static object Guest(string name, string phone) => new { name, phone };

    private static async Task<string> CodeOf(HttpResponseMessage response)
    {
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        return json.TryGetProperty("code", out var code) ? code.GetString()! : response.StatusCode.ToString();
    }

    private Task<HttpResponseMessage> StaffBook(HttpClient staff, Guid branch, DateOnly date, TimeOnly time, object? guest = null, Guid? patientId = null,
        string visitType = "examination", bool overbook = false, bool confirmWarnings = false) =>
        staff.PostAsJsonAsync("/api/staff/appointments", new
        {
            branchId = branch, patientId, guest, visitType, date, time = time.ToString("HH:mm"), overbook, confirmWarnings,
        });

    [Fact]
    public async Task Patient_books_and_the_upcoming_limit_applies()
    {
        var patient = await Api.ClientForAsync(Api.Demo.PatientUserId);
        var options = await patient.GetFromJsonAsync<BookingOptionsDto>($"/api/patient/doctors/{Api.Demo.DoctorBUserId}/booking-options");
        Assert.True(options!.CanBook);
        Assert.False(options.IsNewPatient);
        Assert.True(options.ConsultationAllowed);

        var slots = await patient.GetFromJsonAsync<AvailabilityDto>($"/api/patient/availability?branchId={fx.TimedBranch}&visitType=consultation&from={BookingFixture.Tomorrow:yyyy-MM-dd}");
        var free = slots!.Days[0].Slots.First(s => s.Available);

        var created = await patient.PostAsJsonAsync("/api/patient/appointments", new
        {
            branchId = fx.TimedBranch, visitType = "consultation", date = BookingFixture.Tomorrow, time = free.Start.ToString("HH:mm"), reason = "متابعة",
        });
        created.EnsureSuccessStatusCode();
        var booking = await created.Content.ReadFromJsonAsync<AppointmentDto>();
        Assert.Equal("confirmed", booking!.Status);
        Assert.Null(booking.Phone);         // no staff-only fields for patients
        Assert.Null(booking.StaffNotes);
        Assert.True(booking.CanChange);

        // AC-21: a second upcoming booking with the same doctor is refused, with a link to the first.
        var second = await patient.PostAsJsonAsync("/api/patient/appointments", new
        {
            branchId = fx.TimedBranch, visitType = "examination", date = BookingFixture.Tomorrow.AddDays(1), time = free.Start.ToString("HH:mm"),
        });
        Assert.Equal("UPCOMING_LIMIT", await CodeOf(second));
        Assert.Contains(booking.Id.ToString(), await second.Content.ReadAsStringAsync());

        // Staff see the warning too, and can confirm it (BR-AP21).
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorBUserId);
        var warn = await StaffBook(doctor, fx.TimedBranch, BookingFixture.Tomorrow.AddDays(2), free.Start, patientId: Api.Demo.PatientId);
        Assert.Equal("UPCOMING_LIMIT", await CodeOf(warn));
        (await StaffBook(doctor, fx.TimedBranch, BookingFixture.Tomorrow.AddDays(2), free.Start, patientId: Api.Demo.PatientId, confirmWarnings: true)).EnsureSuccessStatusCode();

        var mine = await patient.GetFromJsonAsync<List<AppointmentDto>>("/api/patient/appointments?tab=upcoming");
        Assert.True(mine!.Count >= 2);
    }

    [Fact]
    public async Task Visit_type_rules_new_patients_and_guests_are_examinations()
    {
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var guest = await StaffBook(doctor, fx.QueueBranch, BookingFixture.Tomorrow.AddDays(3), BookingFixture.Evening, Guest("زائر جديد", "01111111111"), visitType: "consultation");
        Assert.Equal("CONSULTATION_REQUIRES_EXAM", await CodeOf(guest));

        // The second demo patient has no visits counted with doctor A yet.
        var newPatient = await StaffBook(doctor, fx.QueueBranch, BookingFixture.Tomorrow.AddDays(3), BookingFixture.Evening, patientId: Api.Demo.OtherPatientId, visitType: "consultation");
        Assert.Equal("CONSULTATION_REQUIRES_EXAM", await CodeOf(newPatient));
    }

    [Fact]
    public async Task Queue_capacity_and_staff_overbooking()
    {
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var date = BookingFixture.Tomorrow.AddDays(5);
        for (var i = 0; i < 3; i++)
        {
            var ok = await StaffBook(doctor, fx.QueueBranch, date, BookingFixture.Morning, Guest($"زائر رقم{i}", $"0122000000{i}"));
            ok.EnsureSuccessStatusCode();
            Assert.Equal(i + 1, (await ok.Content.ReadFromJsonAsync<AppointmentDto>())!.QueueNumber);
        }

        var warning = await StaffBook(doctor, fx.QueueBranch, date, BookingFixture.Morning, Guest("زائر رابع", "01220000009"));
        Assert.Equal("OVERBOOKING_WARNING", await CodeOf(warning));
        var overbooked = await StaffBook(doctor, fx.QueueBranch, date, BookingFixture.Morning, Guest("زائر رابع", "01220000009"), overbook: true);
        overbooked.EnsureSuccessStatusCode();
        Assert.True((await overbooked.Content.ReadFromJsonAsync<AppointmentDto>())!.Overbooked);

        // Patients just get PERIOD_FULL (AC-21).
        var patient = await Api.ClientForAsync(Api.Demo.PatientUserId);
        var full = await patient.PostAsJsonAsync("/api/patient/appointments", new { branchId = fx.QueueBranch, visitType = "examination", date, time = "00:00" });
        Assert.Equal("PERIOD_FULL", await CodeOf(full));
    }

    [Fact]
    public async Task Concurrent_bookings_never_double_book()
    {
        var doctorB = await Api.ClientForAsync(Api.Demo.DoctorBUserId);
        var date = BookingFixture.Tomorrow.AddDays(6);

        // Timed: twelve requests for the same slot at the same moment: exactly one wins (AC-21, case 1).
        var slot = new TimeOnly(10, 15);
        var timed = await Task.WhenAll(Enumerable.Range(0, 12).Select(i =>
            StaffBook(doctorB, fx.TimedBranch, date, slot, Guest($"سباق توقيت{i}", $"015000000{i:00}"))));
        Assert.Single(timed, r => r.IsSuccessStatusCode);
        foreach (var r in timed.Where(r => !r.IsSuccessStatusCode)) Assert.Equal("SLOT_TAKEN", await CodeOf(r));

        // Queue: capacity 3, ten at once: exactly three places, numbers 1–3 (BR-AP2, BR-AP3).
        var doctorA = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        await doctorA.PutAsJsonAsync($"/api/staff/branches/{fx.QueueBranch}/schedule", BookingFixture.Schedule("queue", staffOverbooking: false));
        try
        {
            var queue = await Task.WhenAll(Enumerable.Range(0, 10).Select(i =>
                StaffBook(doctorA, fx.QueueBranch, date, BookingFixture.Evening, Guest($"سباق دور{i}", $"012760000{i:00}"))));
            var winners = queue.Where(r => r.IsSuccessStatusCode).ToList();
            Assert.Equal(3, winners.Count);
            var numbers = new List<int>();
            foreach (var w in winners) numbers.Add((await w.Content.ReadFromJsonAsync<AppointmentDto>())!.QueueNumber!.Value);
            Assert.Equal([1, 2, 3], numbers.Order());
            foreach (var r in queue.Where(r => !r.IsSuccessStatusCode)) Assert.Equal("PERIOD_FULL", await CodeOf(r));
        }
        finally
        {
            await doctorA.PutAsJsonAsync($"/api/staff/branches/{fx.QueueBranch}/schedule", BookingFixture.Schedule("queue"));
        }
    }

    [Fact]
    public async Task Reschedule_twice_then_max_and_a_failed_move_keeps_the_old_place()
    {
        var other = await Api.WithDbAsync(db => db.Patients.Where(p => p.Id == Api.Demo.OtherPatientId).Select(p => p.UserId).SingleAsync());
        var patient = await Api.ClientForAsync(other);
        var date = BookingFixture.Tomorrow.AddDays(8);
        var created = await patient.PostAsJsonAsync("/api/patient/appointments", new { branchId = fx.QueueBranch, visitType = "examination", date, time = "12:00" });
        created.EnsureSuccessStatusCode();
        var id = (await created.Content.ReadFromJsonAsync<AppointmentDto>())!.Id;

        // A move into a full period fails, and the booking stays where it was.
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var fullDay = date.AddDays(1);
        for (var i = 0; i < 3; i++) (await StaffBook(doctor, fx.QueueBranch, fullDay, BookingFixture.Morning, Guest($"ممتلئ رقم{i}", $"0123000000{i}"))).EnsureSuccessStatusCode();
        var refused = await patient.PostAsJsonAsync($"/api/patient/appointments/{id}/reschedule", new { branchId = fx.QueueBranch, date = fullDay, time = "00:00" });
        Assert.Equal("PERIOD_FULL", await CodeOf(refused));
        var unchanged = await patient.GetFromJsonAsync<AppointmentDto>($"/api/patient/appointments/{id}");
        Assert.Equal(date, unchanged!.Date);
        Assert.Equal(0, unchanged.RescheduleCount);

        for (var i = 1; i <= 2; i++)
        {
            var moved = await patient.PostAsJsonAsync($"/api/patient/appointments/{id}/reschedule", new { branchId = fx.QueueBranch, date = date.AddDays(i + 1), time = "12:00" });
            moved.EnsureSuccessStatusCode();
            Assert.Equal(i, (await moved.Content.ReadFromJsonAsync<AppointmentDto>())!.RescheduleCount);
        }
        var third = await patient.PostAsJsonAsync($"/api/patient/appointments/{id}/reschedule", new { branchId = fx.QueueBranch, date = date.AddDays(5), time = "12:00" });
        Assert.Equal("MAX_RESCHEDULES", await CodeOf(third));

        var history = await patient.GetFromJsonAsync<AppointmentDto>($"/api/patient/appointments/{id}");
        Assert.Equal(3, history!.History!.Count);     // created + 2 reschedules
        Assert.All(history.History, h => Assert.Null(h.ByName));   // patients don't see staff names

        // Free cancel works days ahead; within 2 hours it is refused (AC-21).
        (await patient.PostAsJsonAsync($"/api/patient/appointments/{id}/cancel", new { reason = "سفر" })).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Late_cancel_is_refused_for_patients_only()
    {
        var patient = await Api.ClientForAsync(Api.Demo.PatientUserId);
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var created = await StaffBook(doctor, fx.QueueBranch, BookingFixture.Tomorrow.AddDays(12), BookingFixture.Morning, patientId: Api.Demo.PatientId, confirmWarnings: true);
        created.EnsureSuccessStatusCode();
        var id = (await created.Content.ReadFromJsonAsync<AppointmentDto>())!.Id;

        await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == id)
            .ExecuteUpdateAsync(u => u.SetProperty(a => a.StartUtc, DateTime.UtcNow.AddMinutes(60))));
        var late = await patient.PostAsJsonAsync($"/api/patient/appointments/{id}/cancel", new { reason = (string?)null });
        Assert.Equal("CANCEL_WINDOW_PASSED", await CodeOf(late));
        Assert.False((await patient.GetFromJsonAsync<AppointmentDto>($"/api/patient/appointments/{id}"))!.CanChange);

        (await doctor.PostAsJsonAsync($"/api/staff/appointments/{id}/cancel", new { reason = "الطبيب مسافر" })).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Board_flow_first_action_wins_and_the_mirror_has_no_phone_numbers()
    {
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var assistant = await Api.ClientForAsync(Api.Demo.AssistantUserId);
        var created = await StaffBook(assistant, fx.QueueBranch, BookingFixture.Today, BookingFixture.CurrentPeriod, Guest("زائر اللوحة", "01277777777"));
        created.EnsureSuccessStatusCode();
        var id = (await created.Content.ReadFromJsonAsync<AppointmentDto>())!.Id;

        // AC-25: two people press Check in at once: one succeeds, the other learns who did it.
        var both = await Task.WhenAll(
            doctor.PostAsync($"/api/staff/appointments/{id}/check-in", null),
            assistant.PostAsync($"/api/staff/appointments/{id}/check-in", null));
        Assert.Single(both, r => r.IsSuccessStatusCode);
        var loser = both.Single(r => !r.IsSuccessStatusCode);
        Assert.Equal("ALREADY_HANDLED", await CodeOf(loser));

        var board = await doctor.GetFromJsonAsync<JsonElement>($"/api/staff/board?branchId={fx.QueueBranch}");
        var raw = board.GetRawText();
        Assert.DoesNotContain("+201277777777", raw);
        var entry = board.GetProperty("entries").EnumerateArray().Single(e => e.GetProperty("appointmentId").GetGuid() == id);
        Assert.Equal("waiting", entry.GetProperty("stage").GetString());
        Assert.True(entry.GetProperty("flags").GetProperty("guest").GetBoolean());

        // Every change is mirrored (Firestore when configured).
        var mirrored = Api.Mirror.Published.LastOrDefault(s => s.BranchId == fx.QueueBranch);
        Assert.NotNull(mirrored);
        Assert.Contains(mirrored.Entries, e => e.AppointmentId == id && e.Stage == "waiting");

        var called = await doctor.PostAsync($"/api/staff/appointments/{id}/call-in", null);
        called.EnsureSuccessStatusCode();
        Assert.Equal("withDoctor", (await called.Content.ReadFromJsonAsync<AppointmentDto>())!.Status);
        var after = await doctor.GetFromJsonAsync<BoardSnapshot>($"/api/staff/board?branchId={fx.QueueBranch}");
        Assert.NotNull(after!.NowServing);

        (await doctor.PostAsync($"/api/staff/appointments/{id}/send-back", null)).EnsureSuccessStatusCode();
        var left = await doctor.PostAsJsonAsync($"/api/staff/appointments/{id}/left-without-seen", new { reason = (string?)null });
        Assert.Equal("cancelled", (await left.Content.ReadFromJsonAsync<AppointmentDto>())!.Status);
    }

    [Fact]
    public async Task Walk_in_gets_the_next_number_and_completing_happens_once()
    {
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var walkIn = await doctor.PostAsJsonAsync("/api/staff/board/walk-in", new
        {
            branchId = fx.QueueBranch, patientId = Api.Demo.PatientId, visitType = "examination",
        });
        walkIn.EnsureSuccessStatusCode();
        var w = await walkIn.Content.ReadFromJsonAsync<AppointmentDto>();
        Assert.Equal("checkedIn", w!.Status);
        Assert.Equal("walkIn", w.Source);
        Assert.NotNull(w.QueueNumber);

        // BR-AP10 / AC-22: the session completes the booking exactly once.
        using var scope = Api.Services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<BoardActionsService>();
        var db = scope.ServiceProvider.GetRequiredService<El3yada.Data.AppDbContext>();
        await service.CompleteWithSessionAsync(w.Id, Api.Demo.VisibleSessionId, Api.Demo.DoctorAUserId, default);
        await db.SaveChangesAsync();
        var again = await Assert.ThrowsAsync<El3yada.Api.Infrastructure.Errors.ApiException>(() =>
            service.CompleteWithSessionAsync(w.Id, Api.Demo.VisibleSessionId, Api.Demo.DoctorAUserId, default));
        Assert.Equal("ALREADY_HANDLED", again.Code);
    }

    [Fact]
    public async Task Jobs_mark_no_shows_block_self_booking_expire_pending_and_send_reminders()
    {
        var doctorB = await Api.ClientForAsync(Api.Demo.DoctorBUserId);
        var ids = new List<Guid>();
        for (var i = 0; i < 3; i++)
        {
            var r = await StaffBook(doctorB, fx.TimedBranch, BookingFixture.Tomorrow.AddDays(20 + i), new TimeOnly(9, 0), patientId: Api.Demo.PatientId, confirmWarnings: true);
            r.EnsureSuccessStatusCode();
            ids.Add((await r.Content.ReadFromJsonAsync<AppointmentDto>())!.Id);
        }
        // They "happened" yesterday and nobody came.
        for (var i = 0; i < ids.Count; i++)
        {
            var (id, hours) = (ids[i], -26 - i);
            await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == id).ExecuteUpdateAsync(u => u
                .SetProperty(a => a.StartUtc, DateTime.UtcNow.AddHours(hours))
                .SetProperty(a => a.EndUtc, DateTime.UtcNow.AddHours(hours + 1))));
        }

        using (var scope = Api.Services.CreateScope())
        {
            var jobs = scope.ServiceProvider.GetRequiredService<AppointmentJobs>();
            Assert.True(await jobs.MarkNoShowsAsync(default) >= 3);
            Assert.Equal(0, await jobs.MarkNoShowsAsync(default));    // idempotent
        }
        Assert.True(await Api.WithDbAsync(db => db.DoctorPatients.AnyAsync(l => l.DoctorId == Api.Demo.DoctorBUserId && l.PatientId == Api.Demo.PatientId && l.SelfBookingBlocked)));

        var patient = await Api.ClientForAsync(Api.Demo.PatientUserId);
        var blocked = await patient.PostAsJsonAsync("/api/patient/appointments", new { branchId = fx.TimedBranch, visitType = "examination", date = BookingFixture.Tomorrow.AddDays(25), time = "11:00" });
        Assert.Equal("SELF_BOOKING_BLOCKED", await CodeOf(blocked));

        // Staff turn it back on (BR-AP8).
        (await doctorB.PutAsJsonAsync($"/api/staff/patients/{Api.Demo.PatientId}/self-booking", new { enabled = true, reason = (string?)null })).EnsureSuccessStatusCode();

        // Pending bookings nobody confirmed expire at the minimum-notice time (BR-AP9).
        var doctorA = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        await doctorA.PutAsJsonAsync($"/api/staff/branches/{fx.QueueBranch}/schedule", BookingFixture.Schedule("queue", autoConfirm: false));
        var otherUser = await Api.WithDbAsync(db => db.Patients.Where(p => p.Id == Api.Demo.OtherPatientId).Select(p => p.UserId).SingleAsync());
        var other = await Api.ClientForAsync(otherUser);
        var pending = await other.PostAsJsonAsync("/api/patient/appointments", new { branchId = fx.QueueBranch, visitType = "examination", date = BookingFixture.Tomorrow.AddDays(27), time = "12:00" });
        pending.EnsureSuccessStatusCode();
        var pendingDto = await pending.Content.ReadFromJsonAsync<AppointmentDto>();
        Assert.Equal("pending", pendingDto!.Status);
        await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == pendingDto.Id).ExecuteUpdateAsync(u => u.SetProperty(a => a.StartUtc, DateTime.UtcNow.AddMinutes(-1))));
        await doctorA.PutAsJsonAsync($"/api/staff/branches/{fx.QueueBranch}/schedule", BookingFixture.Schedule("queue"));

        // Reminders: 24 hours before, once.
        var remind = await StaffBook(doctorB, fx.TimedBranch, BookingFixture.Tomorrow.AddDays(28), new TimeOnly(9, 0), patientId: Api.Demo.PatientId, confirmWarnings: true);
        var remindId = (await remind.Content.ReadFromJsonAsync<AppointmentDto>())!.Id;
        await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == remindId).ExecuteUpdateAsync(u => u
            .SetProperty(a => a.StartUtc, DateTime.UtcNow.AddHours(23))
            .SetProperty(a => a.CreatedAt, DateTime.UtcNow.AddDays(-3))));

        using (var scope = Api.Services.CreateScope())
        {
            var jobs = scope.ServiceProvider.GetRequiredService<AppointmentJobs>();
            Assert.True(await jobs.ExpirePendingAsync(default) >= 1);
            Assert.True(await jobs.SendRemindersAsync(default) >= 1);
            Assert.Equal(0, await jobs.SendRemindersAsync(default));
        }
        Assert.Equal("cancelled", await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == pendingDto.Id).Select(a => a.Status).SingleAsync()));
        Assert.True(await Api.WithDbAsync(db => db.Notifications.AnyAsync(n => n.RecipientUserId == Api.Demo.PatientUserId && n.Type == "bookingReminder")));
        Assert.True(await Api.WithDbAsync(db => db.Notifications.AnyAsync(n => n.RecipientUserId == otherUser && n.Type == "bookingExpired")));
    }

    [Fact]
    public async Task Schedule_changes_list_affected_bookings_and_need_a_decision()
    {
        var doctorB = await Api.ClientForAsync(Api.Demo.DoctorBUserId);
        var date = BookingFixture.Tomorrow.AddDays(14);
        var r = await StaffBook(doctorB, fx.TimedBranch, date, new TimeOnly(13, 0), Guest("متأثر بالتغيير", "01288888888"));
        r.EnsureSuccessStatusCode();
        var id = (await r.Content.ReadFromJsonAsync<AppointmentDto>())!.Id;

        // Drop that weekday's hours.
        var weekday = CairoTime.IsoWeekday(date);
        var change = BookingFixture.Schedule("timed", staffOverbooking: false, weekdays: Enumerable.Range(1, 7).Where(d => d != weekday));
        var dry = JsonSerializer.SerializeToElement(change);
        var dryRun = JsonSerializer.Deserialize<Dictionary<string, object>>(dry.GetRawText())!;
        dryRun["dryRun"] = true;
        var preview = await (await doctorB.PutAsJsonAsync($"/api/staff/branches/{fx.TimedBranch}/schedule", dryRun)).Content.ReadFromJsonAsync<UpdateScheduleResult>();
        Assert.False(preview!.Applied);
        Assert.Contains(preview.Conflicts, c => c.AppointmentId == id);

        var undecided = await doctorB.PutAsJsonAsync($"/api/staff/branches/{fx.TimedBranch}/schedule", change);
        Assert.Equal("SCHEDULE_CONFLICTS", await CodeOf(undecided));

        var decided = JsonSerializer.Deserialize<Dictionary<string, object>>(dry.GetRawText())!;
        decided["decisions"] = preview.Conflicts.Select(c => new { appointmentId = c.AppointmentId, action = "cancel" }).ToList();
        (await doctorB.PutAsJsonAsync($"/api/staff/branches/{fx.TimedBranch}/schedule", decided)).EnsureSuccessStatusCode();
        Assert.Equal("cancelled", await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == id).Select(a => a.Status).SingleAsync()));

        (await doctorB.PutAsJsonAsync($"/api/staff/branches/{fx.TimedBranch}/schedule", BookingFixture.Schedule("timed", staffOverbooking: false))).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Access_rules_and_search()
    {
        var doctorA = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var r = await StaffBook(doctorA, fx.QueueBranch, BookingFixture.Tomorrow.AddDays(16), BookingFixture.Evening, Guest("بحث عن زائر", "01299999999"));
        var id = (await r.Content.ReadFromJsonAsync<AppointmentDto>())!.Id;

        // The reception assistant books and searches, but can't edit the schedule (no scheduleManage).
        var assistant = await Api.ClientForAsync(Api.Demo.AssistantUserId);
        var found = await assistant.GetFromJsonAsync<SearchResultDto>("/api/staff/appointments?q=" + Uri.EscapeDataString("بحث عن"));
        Assert.Contains(found!.Page.Items, a => a.Id == id);
        Assert.True(found.StatusCounts["confirmed"] >= 1);
        var byPhone = await assistant.GetFromJsonAsync<SearchResultDto>("/api/staff/appointments?q=01299999999&guestsOnly=true");
        Assert.Single(byPhone!.Page.Items);
        var schedule = await assistant.PutAsJsonAsync($"/api/staff/branches/{fx.QueueBranch}/schedule", BookingFixture.Schedule("queue"));
        Assert.Equal(HttpStatusCode.Forbidden, schedule.StatusCode);

        // Another clinic, the admin and patients can't see it.
        var doctorB = await Api.ClientForAsync(Api.Demo.DoctorBUserId);
        Assert.Equal(HttpStatusCode.NotFound, (await doctorB.GetAsync($"/api/staff/appointments/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await doctorB.GetAsync($"/api/staff/board?branchId={fx.QueueBranch}")).StatusCode);
        var admin = await Api.ClientForAsync(Api.Demo.AdminUserId);
        Assert.Equal(HttpStatusCode.Forbidden, (await admin.GetAsync("/api/staff/appointments")).StatusCode);
        var patient = await Api.ClientForAsync(Api.Demo.PatientUserId);
        Assert.Equal(HttpStatusCode.NotFound, (await patient.GetAsync($"/api/patient/appointments/{id}")).StatusCode);

        // The staff-only patient panel works for the doctor.
        var summary = await doctorA.GetFromJsonAsync<BoardPatientSummaryDto>($"/api/staff/board/{id}/summary");
        Assert.True(summary!.IsGuest);
    }

    [Fact]
    public async Task Suspended_doctor_takes_no_new_bookings()
    {
        await Api.WithDbAsync(db => db.Doctors.Where(d => d.UserId == Api.Demo.DoctorBUserId).ExecuteUpdateAsync(u => u.SetProperty(d => d.Status, "suspended")));
        try
        {
            var patient = await Api.ClientForAsync(Api.Demo.PatientUserId);
            var r = await patient.PostAsJsonAsync("/api/patient/appointments", new { branchId = fx.TimedBranch, visitType = "examination", date = BookingFixture.Tomorrow.AddDays(29), time = "11:00" });
            Assert.Equal("BOOKING_UNAVAILABLE", await CodeOf(r));
            var doctor = await Api.ClientForAsync(Api.Demo.DoctorBUserId);
            var staff = await StaffBook(doctor, fx.TimedBranch, BookingFixture.Tomorrow.AddDays(29), new TimeOnly(11, 0), Guest("زائر موقوف", "01244444444"));
            Assert.Equal("DOCTOR_SUSPENDED", await CodeOf(staff));
        }
        finally
        {
            await Api.WithDbAsync(db => db.Doctors.Where(d => d.UserId == Api.Demo.DoctorBUserId).ExecuteUpdateAsync(u => u.SetProperty(d => d.Status, "active")));
        }
    }
}
