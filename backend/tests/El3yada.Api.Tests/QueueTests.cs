using System.Net.Http.Json;
using System.Text.Json;
using El3yada.Api.Features.Appointments;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Api.Infrastructure.Time;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests;

/// <summary>Doctor A's main branch runs a queue with room for the day (capacity 50 per period).</summary>
public sealed class QueueFixture : IAsyncLifetime
{
    public FeaturesApiFactory Api { get; } = new();
    public Guid Branch { get; private set; }

    public async Task InitializeAsync()
    {
        await ((IAsyncLifetime)Api).InitializeAsync();
        Branch = await Api.WithDbAsync(db => db.Branches.Where(b => b.DoctorId == Api.Demo.DoctorAUserId && b.IsDefault).Select(b => b.Id).SingleAsync());
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        (await doctor.PutAsJsonAsync($"/api/staff/branches/{Branch}/schedule", BookingFixture.Schedule("queue", capacity: 50))).EnsureSuccessStatusCode();
    }

    public async Task DisposeAsync() => await ((IAsyncLifetime)Api).DisposeAsync();
}

/// <summary>
/// BR-AP3, BR-AP16, AC-21 "Queue order" and "Reminders and turn": in queue mode the number is given at check-in,
/// in order of arrival. Tests that count numbers or patients ahead use a period of their own today (bookings put
/// there directly), so they don't see each other's patients.
/// </summary>
public sealed class QueueTests(QueueFixture fx) : IClassFixture<QueueFixture>
{
    private FeaturesApiFactory Api => fx.Api;

    private static DateOnly Today => CairoTime.Today(TimeProvider.System);

    private Task<HttpResponseMessage> StaffBook(HttpClient staff, DateOnly date, TimeOnly time, Guid? patientId = null, object? guest = null) =>
        staff.PostAsJsonAsync("/api/staff/appointments", new
        {
            branchId = fx.Branch, patientId, guest, visitType = "examination", date, time = time.ToString("HH:mm"), confirmWarnings = true,
        });

    private static async Task<AppointmentDto> Dto(HttpResponseMessage response)
    {
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<AppointmentDto>())!;
    }

    private static async Task<AppointmentDto> Act(HttpClient staff, Guid id, string action, string? reason = null) =>
        await Dto(await staff.PostAsJsonAsync($"/api/staff/appointments/{id}/{action}", new { reason }));

    /// <summary>A confirmed queue booking for today in <paramref name="period"/>, booked by doctor A, with no number.</summary>
    private async Task<Guid> SeedAsync(TimeOnly period, Guid? patientId = null, string status = "confirmed")
    {
        var id = Guid.NewGuid();
        var now = DateTime.UtcNow;
        await Api.WithDbAsync(async db =>
        {
            db.Appointments.Add(new Appointment
            {
                Id = id,
                DoctorId = Api.Demo.DoctorAUserId,
                BranchId = fx.Branch,
                PatientId = patientId,
                GuestName = patientId is null ? $"زائر {id.ToString()[..4]}" : null,
                GuestPhone = patientId is null ? "+201299990001" : null,   // nobody's phone: stays a guest at check-in
                VisitType = "examination",
                Mode = "queue",
                LocalDate = Today,
                PeriodStartLocal = period,
                StartUtc = CairoTime.ToUtc(Today, period),
                EndUtc = CairoTime.ToUtc(Today, period).AddHours(1),
                Status = status,
                Source = "staff",
                BookedBy = Api.Demo.DoctorAUserId,
                BookedByRole = "doctor",
                CreatedAt = now,
                UpdatedAt = now,
            });
            return await db.SaveChangesAsync();
        });
        return id;
    }

    private Task<Guid> OtherPatientUserAsync() =>
        Api.WithDbAsync(db => db.Patients.Where(p => p.Id == Api.Demo.OtherPatientId).Select(p => p.UserId).SingleAsync());

    private Task<List<Notification>> NotificationsAsync(Guid userId, string type, Guid appointmentId) =>
        Api.WithDbAsync(db => db.Notifications.AsNoTracking()
            .Where(n => n.RecipientUserId == userId && n.Type == type && n.Route == $"/patient/appointments/{appointmentId}")
            .ToListAsync());

    [Fact]
    public async Task AC21_B_checks_in_first_and_gets_the_turn_before_A_who_booked_first_then_a_walk_in()
    {
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var reception = await Api.ClientForAsync(Api.Demo.AssistantUserId);
        var period = BookingFixture.CurrentPeriod;

        // A books before B (reception, for phone calls). Neither has a number: it's a place on the period's list.
        var a = await Dto(await StaffBook(reception, Today, period, patientId: Api.Demo.PatientId));
        var b = await Dto(await StaffBook(reception, Today, period, patientId: Api.Demo.OtherPatientId));
        Assert.Null(a.QueueNumber);
        Assert.Null(b.QueueNumber);

        // Before check-in, the patient's app shows no number, no one ahead and no estimate (AC-21).
        var patientA = await Api.ClientForAsync(Api.Demo.PatientUserId);
        var seen = await patientA.GetFromJsonAsync<AppointmentDto>($"/api/patient/appointments/{a.Id}");
        Assert.Null(seen!.QueueNumber);
        Assert.Null(seen.Ahead);
        Assert.Null(seen.EstimatedTime);
        var listed = await patientA.GetFromJsonAsync<List<AppointmentDto>>("/api/patient/appointments?tab=upcoming");
        Assert.Null(listed!.Single(x => x.Id == a.Id).QueueNumber);

        // Expected is ordered by booking time; the cards have no number (D34).
        var before = await doctor.GetFromJsonAsync<BoardSnapshot>($"/api/staff/board?branchId={fx.Branch}");
        var expected = before!.Entries.Where(e => e.Stage == "expected").Select(e => e.AppointmentId).ToList();
        Assert.True(expected.IndexOf(a.Id) < expected.IndexOf(b.Id));
        Assert.All(before.Entries.Where(e => e.AppointmentId == a.Id || e.AppointmentId == b.Id), e => Assert.Null(e.QueueNumber));

        // B arrives first and gets the period's next number; A arrives next; a walk-in after them.
        var bIn = await Act(reception, b.Id, "check-in");
        var aIn = await Act(doctor, a.Id, "check-in");
        var walkIn = await Dto(await doctor.PostAsJsonAsync("/api/staff/board/walk-in", new
        {
            branchId = fx.Branch, guest = new { name = "زائر بدون حجز", phone = "01155556666" }, visitType = "examination",
        }));
        Assert.Equal(period, walkIn.Time);
        Assert.Equal(bIn.QueueNumber + 1, aIn.QueueNumber);
        Assert.Equal(aIn.QueueNumber + 1, walkIn.QueueNumber);

        // Waiting is ordered by number, the order of arrival: B, A, the walk-in.
        var after = await doctor.GetFromJsonAsync<BoardSnapshot>($"/api/staff/board?branchId={fx.Branch}");
        var waiting = after!.Entries.Where(e => e.Stage == "waiting").Select(e => e.AppointmentId).ToList();
        Assert.True(waiting.IndexOf(b.Id) < waiting.IndexOf(a.Id));
        Assert.True(waiting.IndexOf(a.Id) < waiting.IndexOf(walkIn.Id));
        var numbers = after.NextNumbers.ToList();
        Assert.True(numbers.IndexOf(bIn.QueueNumber!.Value) < numbers.IndexOf(aIn.QueueNumber!.Value));
        Assert.True(after.Entries.Single(e => e.AppointmentId == walkIn.Id).Flags.WalkIn);

        // The Firestore mirror carries the same cards in the same order, `order` being the place on the board.
        var mirrored = Api.Mirror.Published.Last(s => s.BranchId == fx.Branch);
        Assert.Equal(mirrored.Entries.Select(e => e.AppointmentId), mirrored.Entries.OrderBy(e => e.Order).Select(e => e.AppointmentId));
        Assert.Equal(Enumerable.Range(0, mirrored.Entries.Count), mirrored.Entries.Select(e => e.Order));
        Assert.Equal(aIn.QueueNumber, mirrored.Entries.Single(e => e.AppointmentId == a.Id).QueueNumber);

        // From check-in on, the patient's app has the number and the patients ahead (B at least).
        var now = await patientA.GetFromJsonAsync<AppointmentDto>($"/api/patient/appointments/{a.Id}");
        Assert.Equal(aIn.QueueNumber, now!.QueueNumber);
        Assert.True(now.Ahead >= 1);
        Assert.Equal(now.Ahead * 10, now.EstimatedWaitMinutes);
    }

    [Fact]
    public async Task Two_receptionists_checking_in_at_the_same_moment_get_different_numbers()
    {
        var period = new TimeOnly(1, 2);
        var ids = new List<Guid>();
        for (var i = 0; i < 10; i++) ids.Add(await SeedAsync(period));
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var reception = await Api.ClientForAsync(Api.Demo.AssistantUserId);

        var results = await Task.WhenAll(ids.Select((id, i) => (i % 2 == 0 ? doctor : reception).PostAsync($"/api/staff/appointments/{id}/check-in", null)));

        var numbers = new List<int>();
        foreach (var r in results) numbers.Add((await Dto(r)).QueueNumber!.Value);
        Assert.Equal(Enumerable.Range(1, 10), numbers.Order());
    }

    [Fact]
    public async Task Check_in_tells_the_patient_their_number_how_many_are_ahead_and_the_wait_and_priority_counts()
    {
        var period = new TimeOnly(1, 3);
        var guests = new List<Guid>();
        for (var i = 0; i < 3; i++) guests.Add(await SeedAsync(period));
        var patient = await SeedAsync(period, Api.Demo.PatientId);
        var late = await SeedAsync(period);
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);

        foreach (var (id, i) in guests.Select((id, i) => (id, i))) Assert.Equal(i + 1, (await Act(doctor, id, "check-in")).QueueNumber);

        var checkedIn = await Act(doctor, patient, "check-in");
        Assert.Equal(4, checkedIn.QueueNumber);
        Assert.Equal(3, checkedIn.Ahead);
        Assert.Equal(30, checkedIn.EstimatedWaitMinutes);   // 3 ahead × the branch's 10-minute average visit (6.12.2)

        // BR-AP16: «تم تسجيل حضورك — دورك رقم 7، وقبلك 3 مرضى», with the estimated wait. Guests get nothing (told at the desk).
        var told = Assert.Single(await NotificationsAsync(Api.Demo.PatientUserId, "checkedIn", patient));
        Assert.Equal("تم تسجيل حضورك", told.TitleAr);
        Assert.Equal("دورك رقم 4، وقبلك 3 مرضى. الانتظار المتوقع حوالي 30 دقيقة", told.BodyAr);
        Assert.Equal("Your number is 4, and 3 patients are ahead of you. Estimated wait about 30 minutes", told.BodyEn);

        // A later arrival moved up keeps their number and goes first: it now counts as ahead (BR-AP3).
        Assert.Equal(5, (await Act(doctor, late, "check-in")).QueueNumber);
        var moved = await Act(doctor, late, "priority", "مسن");
        Assert.Equal(5, moved.QueueNumber);
        Assert.True(moved.IsPriority);

        var app = await Api.ClientForAsync(Api.Demo.PatientUserId);
        var mine = await app.GetFromJsonAsync<AppointmentDto>($"/api/patient/appointments/{patient}");
        Assert.Equal(4, mine!.QueueNumber);
        Assert.Equal(4, mine.Ahead);
        Assert.Equal(40, mine.EstimatedWaitMinutes);

        var board = await doctor.GetFromJsonAsync<BoardSnapshot>($"/api/staff/board?branchId={fx.Branch}");
        var line = board!.Entries.Where(e => e.Stage == "waiting" && e.QueueNumber is not null
            && (guests.Contains(e.AppointmentId) || e.AppointmentId == patient || e.AppointmentId == late)).Select(e => e.QueueNumber!.Value);
        Assert.Equal([5, 1, 2, 3, 4], line);
    }

    [Fact]
    public async Task The_next_patient_hears_their_turn_is_next_when_the_one_before_goes_in_once()
    {
        var period = new TimeOnly(1, 4);
        var first = await SeedAsync(period);
        var second = await SeedAsync(period, Api.Demo.OtherPatientId);
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        await Act(doctor, first, "check-in");
        Assert.Equal(2, (await Act(doctor, second, "check-in")).QueueNumber);
        var user = await OtherPatientUserAsync();
        Assert.Empty(await NotificationsAsync(user, "nextInLine", second));

        await Act(doctor, first, "call-in");
        var told = Assert.Single(await NotificationsAsync(user, "nextInLine", second));
        Assert.Equal("دورك التالي", told.TitleAr);
        Assert.Contains("دورك رقم 2", told.BodyAr);

        // Sent back and called in again: not told twice.
        await Act(doctor, first, "send-back");
        await Act(doctor, first, "call-in");
        Assert.Single(await NotificationsAsync(user, "nextInLine", second));
        var board = await doctor.GetFromJsonAsync<BoardSnapshot>($"/api/staff/board?branchId={fx.Branch}");
        Assert.Equal(1, board!.NowServing);
    }

    [Fact]
    public async Task Undoing_a_no_show_checks_in_again_with_a_new_number_and_numbers_are_never_reused()
    {
        var period = new TimeOnly(1, 5);
        var missed = await SeedAsync(period);
        var left = await SeedAsync(period);
        var later = await SeedAsync(period);
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);

        Assert.Equal(1, (await Act(doctor, left, "check-in")).QueueNumber);
        var noShow = await Act(doctor, missed, "no-show");
        Assert.Equal("noShow", noShow.Status);
        Assert.Null(noShow.QueueNumber);

        var back = await Act(doctor, missed, "undo-no-show");
        Assert.Equal("checkedIn", back.Status);
        Assert.Equal(2, back.QueueNumber);

        // Number 1 left without being seen: the next arrival still gets 3.
        Assert.Equal("cancelled", (await Act(doctor, left, "left-without-seen")).Status);
        Assert.Equal(3, (await Act(doctor, later, "check-in")).QueueNumber);
    }

    [Fact]
    public async Task Rescheduling_keeps_a_queue_booking_without_a_number()
    {
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var day = Today.AddDays(4);
        var booked = await Dto(await StaffBook(doctor, day, BookingFixture.Evening, guest: new { name = "زائر يغير", phone = "01177778888" }));
        var moved = await Dto(await doctor.PostAsJsonAsync($"/api/staff/appointments/{booked.Id}/reschedule",
            new { branchId = fx.Branch, date = day.AddDays(1), time = "00:00", reason = "طلب المريض" }));
        Assert.Null(booked.QueueNumber);
        Assert.Null(moved.QueueNumber);
        Assert.Equal(1, moved.RescheduleCount);
    }

    [Fact]
    public async Task Reminders_on_the_day_say_turns_go_by_arrival_and_a_booking_made_an_hour_before_gets_none()
    {
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var day = Today.AddDays(6);
        var early = await Dto(await StaffBook(doctor, day, BookingFixture.Evening, patientId: Api.Demo.PatientId));
        var lastMinute = await Dto(await StaffBook(doctor, day, BookingFixture.Morning, patientId: Api.Demo.OtherPatientId));

        // `early` was booked three hours ago and starts in 110 minutes: the 24-hour reminder's time had passed when
        // it was booked, so only the day's reminder goes (case 27). `lastMinute` was booked an hour before: none.
        await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == early.Id).ExecuteUpdateAsync(u => u
            .SetProperty(a => a.LocalDate, Today)
            .SetProperty(a => a.PeriodStartLocal, new TimeOnly(18, 0))
            .SetProperty(a => a.StartUtc, DateTime.UtcNow.AddMinutes(110))
            .SetProperty(a => a.CreatedAt, DateTime.UtcNow.AddHours(-3))
            .SetProperty(a => a.RemindersSentJson, "[]")));
        await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == lastMinute.Id).ExecuteUpdateAsync(u => u
            .SetProperty(a => a.LocalDate, Today)
            .SetProperty(a => a.StartUtc, DateTime.UtcNow.AddMinutes(60))
            .SetProperty(a => a.CreatedAt, DateTime.UtcNow)
            .SetProperty(a => a.RemindersSentJson, "[]")));

        using (var scope = Api.Services.CreateScope())
        {
            var jobs = scope.ServiceProvider.GetRequiredService<AppointmentJobs>();
            await jobs.SendRemindersAsync(default);
            await jobs.SendRemindersAsync(default);   // idempotent
        }

        var reminder = Assert.Single(await NotificationsAsync(Api.Demo.PatientUserId, "bookingReminder", early.Id));
        Assert.StartsWith("اليوم موعدك في ", reminder.BodyAr);
        Assert.Contains("، الفترة المسائية من 6 مساءً. ", reminder.BodyAr);
        Assert.EndsWith("الدور بأسبقية الحضور: سجّل حضورك في الاستقبال عند وصولك.", reminder.BodyAr);
        Assert.Contains("Turns go in order of arrival", reminder.BodyEn);
        Assert.DoesNotContain("رقم", reminder.BodyAr);
        Assert.Empty(await NotificationsAsync(await OtherPatientUserAsync(), "bookingReminder", lastMinute.Id));
        var marked = await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == lastMinute.Id).Select(a => a.RemindersSentJson).SingleAsync());
        Assert.Equal([120, 1440], JsonSerializer.Deserialize<List<int>>(marked)!);
    }

    [Fact]
    public async Task A_booking_made_inside_the_reminder_window_starts_with_those_reminders_skipped()
    {
        // Staff book today's period: both reminders' times have passed, so they are marked at booking (case 27).
        var doctor = await Api.ClientForAsync(Api.Demo.DoctorAUserId);
        var booked = await Dto(await StaffBook(doctor, Today, BookingFixture.CurrentPeriod, guest: new { name = "زائر اليوم", phone = "01199990000" }));
        var marked = await Api.WithDbAsync(db => db.Appointments.Where(a => a.Id == booked.Id).Select(a => a.RemindersSentJson).SingleAsync());
        Assert.Equal([120, 1440], JsonSerializer.Deserialize<List<int>>(marked)!);
        Assert.Equal("الفترة المسائية", AppointmentTexts.PeriodName(new TimeOnly(18, 0)).Ar);
        Assert.Equal(("6:15 مساءً", "6:15 pm"), AppointmentTexts.Clock(new TimeOnly(18, 15)));
    }
}
