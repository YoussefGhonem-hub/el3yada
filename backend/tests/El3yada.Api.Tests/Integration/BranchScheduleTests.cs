using System.Net;
using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Common;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// D29 Working hours, Special dates and Booking settings, and AS17: <c>updateBranchSchedule</c>
/// (<c>PUT /api/staff/branches/{id}/schedule</c>) is the one way to change a branch's hours. The D29 hours rules
/// (spec 11) and BR-AP12: a change that strands bookings lists them, with a suggested new place, and applies
/// keep, move or cancel for each (case 14, AC-21 "Schedule change").
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class BranchScheduleTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    /// <summary>Same weekday as today, a week ahead: every evening slot on it is in the future.</summary>
    private static DateOnly NextWeek => TestData.CairoToday().AddDays(7);

    private static int Weekday(DateOnly day) => WeeklyHours.IsoWeekday(day);

    private static Task<(HttpStatusCode Status, JsonElement Body)> StaffBookAsync(
        HttpClient client, Guid branchId, DateOnly date, string time, Guid? patientId = null, string guestName = "زائر الجدول") =>
        client.PostAsync("/api/staff/appointments", new
        {
            branchId, patientId, guest = patientId is null ? new { name = guestName, phone = TestData.Local(TestData.Mobile()) } : null,
            visitType = "examination", date, time, confirmWarnings = true,
        });

    private static async Task<Guid> BookedAsync(HttpClient client, Guid branchId, DateOnly date, string time, Guid? patientId = null)
    {
        var (status, body) = await StaffBookAsync(client, branchId, date, time, patientId);
        Assert.True(status == HttpStatusCode.OK, $"{(int)status} {body}");
        return body.GetProperty("id").GetGuid();
    }

    private async Task<(string Status, DateOnly Date, TimeOnly Start, string? CancelReason)> BookingAsync(Guid id)
    {
        var a = await TestData.WithDbAsync(Factory, db => db.Appointments.Where(x => x.Id == id)
            .Select(x => new { x.Status, x.LocalDate, x.StartUtc, x.CancelReason }).SingleAsync());
        return (a.Status, a.LocalDate, TimeOnly.FromDateTime(CairoTime.ToCairo(a.StartUtc)), a.CancelReason);
    }

    // ---- The D29 working hours rules (moved here from updateBranchHours) -------------------------

    [Fact]
    public async Task Hours_replace_the_week_and_a_period_can_end_after_midnight()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);
        await client.PutScheduleAsync(branch, TestData.ScheduleBody([TestData.Period(1, "09:00", "12:00")]));

        var (status, body) = await client.PutScheduleAsync(branch, TestData.ScheduleBody(
        [
            TestData.Period(6, "20:00", "01:00", endsNextDay: true, label: "مسائي"),
            TestData.Period(7, "01:00", "03:00"),
            TestData.Period(6, "10:00", "14:00", label: " صباحي ", capacity: 25),
        ]));

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.True(body.GetProperty("applied").GetBoolean());
        var (_, details) = await client.GetJsonAsync($"/api/branches/{branch}");
        var periods = details.GetProperty("workingHours").GetProperty("periods").EnumerateArray().ToList();
        Assert.Equal(3, periods.Count);
        Assert.Equal((6, "10:00", "14:00"), (periods[0].GetProperty("weekday").GetInt32(), periods[0].Str("startLocal"), periods[0].Str("endLocal")));
        Assert.Equal(25, periods[0].GetProperty("capacity").GetInt32());
        Assert.Equal("صباحي", periods[0].Str("label"));
        Assert.True(periods[1].GetProperty("endsNextDay").GetBoolean());
        Assert.Equal("مسائي", periods[1].Str("label"));
        Assert.Equal(7, periods[2].GetProperty("weekday").GetInt32());
        var audit = await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.BranchScheduleUpdated);
        Assert.Equal(2, audit.Count);
        Assert.Contains("\"periods\":3", audit[0].DetailsJson);
        Assert.Equal(AuditTargets.Branch, audit[0].TargetType);

        // An empty week closes every day.
        (status, _) = await client.PutScheduleAsync(branch, TestData.ScheduleBody([]));
        Assert.Equal(HttpStatusCode.OK, status);
        (_, details) = await client.GetJsonAsync($"/api/branches/{branch}");
        Assert.Empty(details.GetProperty("workingHours").GetProperty("periods").EnumerateArray());
    }

    [Fact]
    public async Task Hours_are_checked_for_order_length_and_overlaps()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PutScheduleAsync(branch, TestData.ScheduleBody(
        [
            TestData.Period(6, "10:00", "14:00"),
            TestData.Period(8, "10:00", "11:00", capacity: 0),
            TestData.Period(0, "10:00", "11:00", label: new string('ص', 31)),
        ]));

        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("weekly[1].weekday"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("weekly[1].capacity"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("weekly[2].weekday"));
        Assert.Equal(ErrorCodes.TooLong, body.FieldCode("weekly[2].label"));

        // Once every weekday is readable, the whole week is checked, on the period each problem is about.
        (status, body) = await client.PutScheduleAsync(branch, TestData.ScheduleBody(
        [
            TestData.Period(6, "10:00", "14:00"),
            TestData.Period(6, "13:00", "16:00"),
            TestData.Period(1, "18:00", "10:00"),
            TestData.Period(2, "10:00", "10:10"),
            TestData.Period(5, "22:00", "02:00", endsNextDay: true),
            TestData.Period(6, "01:00", "03:00"),
        ]));
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.PeriodsOverlap, body.FieldCode("weekly[1]"));
        Assert.Equal(ErrorCodes.PeriodEndBeforeStart, body.FieldCode("weekly[2].end"));
        Assert.Equal(ErrorCodes.PeriodLengthOutOfRange, body.FieldCode("weekly[3].end"));
        Assert.Equal(ErrorCodes.PeriodsOverlap, body.FieldCode("weekly[5]"));

        // More than 10 periods in a day, and a special date's periods follow the same rules.
        (status, body) = await client.PutScheduleAsync(branch, TestData.ScheduleBody(
            Enumerable.Range(0, 11).Select(i => TestData.Period(6, $"{i:00}:00", $"{i:00}:30")),
            dateOverrides: [new { date = NextWeek, periods = new[] { new { start = "10:00", end = "10:05", endsNextDay = false } } }]));
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("weekly"));
        Assert.Equal(ErrorCodes.PeriodLengthOutOfRange, body.FieldCode("dateOverrides[0].periods[0].end"));
        Assert.Equal(0, await TestData.WithDbAsync(Factory, db => db.BranchPeriods.CountAsync(p => p.BranchId == branch)));
    }

    [Fact]
    public async Task An_assistant_with_scheduleManage_changes_hours_only_in_their_branches()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branchA = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var branchB = await TestData.AddBranchAsync(Factory, doctor.Id);
        var assistant = await TestData.CreateAssistantAsync(
            Factory, doctor.Id, permissions: ClinicPermissions.WithDependencies([ClinicPermissions.ScheduleManage]), branchIds: [branchA]);
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, "reception");
        using var client = await Factory.SignedInClientAsync(assistant);
        using var receptionClient = await Factory.SignedInClientAsync(reception);
        var week = TestData.ScheduleBody([TestData.Period(6, "10:00", "14:00")]);

        var (statusA, _) = await client.PutScheduleAsync(branchA, week);
        var (statusB, bodyB) = await client.PutScheduleAsync(branchB, week);
        var (noPermission, noPermissionBody) = await receptionClient.PutScheduleAsync(branchA, week);

        Assert.Equal(HttpStatusCode.OK, statusA);
        Assert.Equal(HttpStatusCode.Forbidden, statusB);
        Assert.Equal(ErrorCodes.PermissionDenied, bodyB.Code());
        Assert.Equal(HttpStatusCode.Forbidden, noPermission);
        Assert.Equal(ErrorCodes.PermissionDenied, noPermissionBody.Code());
        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.BranchScheduleUpdated));
        Assert.Equal(assistant.Id, audit.ActorUserId);
        Assert.Equal("assistant", audit.ActorRole);
    }

    [Fact]
    public async Task Another_clinic_patients_and_admins_cannot_change_a_schedule_and_the_old_endpoint_is_gone()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var other = await TestData.CreateDoctorAsync(Factory);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var admin = await TestData.CreateAdminAsync(Factory);
        var week = TestData.ScheduleBody([TestData.Period(6, "10:00", "14:00")]);

        foreach (var user in new[] { other, patient, admin })
        {
            using var client = await Factory.SignedInClientAsync(user);
            var (status, _) = await client.PutScheduleAsync(branch, week);
            Assert.Equal(HttpStatusCode.Forbidden, status);
        }

        Assert.Equal(0, await TestData.WithDbAsync(Factory, db => db.BranchPeriods.CountAsync(p => p.BranchId == branch)));

        // updateBranchHours is retired: hours change only with the conflicts check.
        using var doctorClient = await Factory.SignedInClientAsync(doctor);
        var (retired, _) = await doctorClient.PostAsync("/api/branches/updateBranchHours", new
        {
            branchId = branch, periods = new[] { new { weekday = 6, startLocal = "10:00", endLocal = "14:00" } },
        });
        Assert.True(retired is HttpStatusCode.NotFound or HttpStatusCode.MethodNotAllowed, retired.ToString());
        Assert.Equal(0, await TestData.WithDbAsync(Factory, db => db.BranchPeriods.CountAsync(p => p.BranchId == branch)));
    }

    // ---- BR-AP12: no booking disappears silently ----------------------------------------------

    [Fact]
    public async Task Shortening_a_day_lists_the_stranded_bookings_with_suggestions_and_applies_keep_move_and_cancel()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var (patientUser, patientId) = await TestData.CreatePatientAsync(Factory);
        await TestData.LinkAsync(Factory, doctor.Id, patientId);
        using var client = await Factory.SignedInClientAsync(doctor);
        var day = NextWeek;
        var evening = TestData.ScheduleBody([TestData.Period(Weekday(day), "18:00", "22:00")], mode: "timed", slotMinutes: 30, staffOverbooking: false);
        Assert.Equal(HttpStatusCode.OK, (await client.PutScheduleAsync(branch, evening)).Status);

        var early = await BookedAsync(client, branch, day, "18:30");
        var keep = await BookedAsync(client, branch, day, "20:00");
        var move = await BookedAsync(client, branch, day, "20:30");
        var cancel = await BookedAsync(client, branch, day, "21:00", patientId);

        // AC-21: Saturday 18–22 becomes 18–20, so the bookings after 20:00 are listed.
        var shorter = TestData.ScheduleBody([TestData.Period(Weekday(day), "18:00", "20:00")], mode: "timed", slotMinutes: 30, staffOverbooking: false);
        shorter["dryRun"] = true;
        var (status, preview) = await client.PutScheduleAsync(branch, shorter);
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.False(preview.GetProperty("applied").GetBoolean());
        var conflicts = preview.GetProperty("conflicts").EnumerateArray().ToList();
        Assert.Equal([keep, move, cancel], conflicts.Select(c => c.GetProperty("appointmentId").GetGuid()));
        Assert.All(conflicts, c => Assert.Equal(branch, c.GetProperty("branchId").GetGuid()));
        Assert.Equal("21:00", conflicts[2].Str("time")[..5]);
        Assert.Equal("examination", conflicts[2].Str("visitType"));

        // Each gets a free place in the new hours, closest to its time, never one already taken or suggested.
        var suggested = conflicts.Select(c => c.GetProperty("suggestion")).ToList();
        Assert.All(suggested, s => Assert.Equal(day.ToString("yyyy-MM-dd"), s.Str("date")));
        var times = suggested.Select(s => s.Str("time")[..5]).ToList();
        Assert.Equal(["19:30", "19:00", "18:00"], times);
        // Nothing changed yet.
        Assert.Equal(new TimeOnly(22, 0), await TestData.WithDbAsync(Factory, db => db.BranchPeriods.Where(p => p.BranchId == branch).Select(p => p.EndLocal).SingleAsync()));

        // Without a decision for each, nothing is applied.
        shorter["dryRun"] = false;
        (status, var undecided) = await client.PutScheduleAsync(branch, shorter);
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal("SCHEDULE_CONFLICTS", undecided.Code());

        // Keep one as an exception, move one to its suggestion, cancel one. A decision for a booking that isn't
        // affected (the 18:30 one) is ignored.
        shorter["decisions"] = new List<object>
        {
            new { appointmentId = keep, action = "keep" },
            new { appointmentId = move, action = "move", date = day, time = times[1] },
            new { appointmentId = cancel, action = "cancel" },
            new { appointmentId = early, action = "cancel" },
        };
        (status, var applied) = await client.PutScheduleAsync(branch, shorter);
        Assert.True(status == HttpStatusCode.OK, $"{(int)status} {applied}");
        Assert.True(applied.GetProperty("applied").GetBoolean());

        Assert.Equal(("confirmed", new TimeOnly(18, 30)), await BookingAsync(early) is var e ? (e.Status, e.Start) : default);
        Assert.Equal(("confirmed", new TimeOnly(20, 0)), await BookingAsync(keep) is var k ? (k.Status, k.Start) : default);
        var moved = await BookingAsync(move);
        Assert.Equal(("confirmed", day, new TimeOnly(19, 0)), (moved.Status, moved.Date, moved.Start));
        var cancelled = await BookingAsync(cancel);
        Assert.Equal(("cancelled", "scheduleChange"), (cancelled.Status, cancelled.CancelReason));
        Assert.Equal(new TimeOnly(20, 0), await TestData.WithDbAsync(Factory, db => db.BranchPeriods.Where(p => p.BranchId == branch).Select(p => p.EndLocal).SingleAsync()));

        // The move is a clinic reschedule in the booking's history; the cancelled patient gets a rebook link.
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AppointmentHistories.AnyAsync(h => h.AppointmentId == move && h.Action == "rescheduled" && h.Reason == "scheduleChange")));
        var notice = await TestData.WithDbAsync(Factory, db => db.Notifications
            .Where(n => n.RecipientUserId == patientUser.Id && n.Type == "bookingCancelled").SingleAsync());
        Assert.Equal("/patient/appointments/book", notice.Route);
        var audit = (await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.BranchScheduleUpdated))[0];
        Assert.Contains("\"kept\":1", audit.DetailsJson);
        Assert.Contains("\"moved\":1", audit.DetailsJson);
        Assert.Contains("\"cancelled\":1", audit.DetailsJson);
    }

    [Fact]
    public async Task A_move_that_fails_rolls_the_whole_change_back()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);
        var day = NextWeek;
        var evening = TestData.ScheduleBody([TestData.Period(Weekday(day), "18:00", "22:00")], mode: "timed", slotMinutes: 30, staffOverbooking: false);
        await client.PutScheduleAsync(branch, evening);
        var taken = await BookedAsync(client, branch, day, "18:30");
        var late = await BookedAsync(client, branch, day, "21:30");

        // Moving the 21:30 booking onto the taken 18:30 slot is refused, and nothing changes.
        var shorter = TestData.ScheduleBody([TestData.Period(Weekday(day), "18:00", "20:00")], mode: "timed", slotMinutes: 30, staffOverbooking: false);
        shorter["decisions"] = new List<object> { new { appointmentId = late, action = "move", date = day, time = "18:30" } };
        var (status, body) = await client.PutScheduleAsync(branch, shorter);

        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal("SLOT_TAKEN", body.Code());
        Assert.Equal(new TimeOnly(22, 0), await TestData.WithDbAsync(Factory, db => db.BranchPeriods.Where(p => p.BranchId == branch).Select(p => p.EndLocal).SingleAsync()));
        Assert.Equal(new TimeOnly(21, 30), (await BookingAsync(late)).Start);
        Assert.Equal("confirmed", (await BookingAsync(taken)).Status);

        // A move needs its new place.
        shorter["decisions"] = new List<object> { new { appointmentId = late, action = "move" } };
        (status, body) = await client.PutScheduleAsync(branch, shorter);
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.Required, body.FieldCode("decisions[0].date"));
    }

    [Fact]
    public async Task A_closure_over_booked_days_lists_them_too()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);
        var day = NextWeek;
        var week = Enumerable.Range(1, 7).Select(d => TestData.Period(d, "10:00", "14:00", label: "صباحي")).ToList();
        await client.PutScheduleAsync(branch, TestData.ScheduleBody(week));
        var booked = await BookedAsync(client, branch, day, "10:00");

        // Case 15: a vacation over a booked day. In queue mode the suggestion is the nearest open period.
        var vacation = TestData.ScheduleBody(week, closures:
        [
            new { id = (Guid?)null, fromLocal = day.ToDateTime(TimeOnly.MinValue), toLocal = day.AddDays(1).ToDateTime(TimeOnly.MinValue), reason = "إجازة", allBranches = true },
        ]);
        vacation["dryRun"] = true;
        var (status, preview) = await client.PutScheduleAsync(branch, vacation);

        Assert.Equal(HttpStatusCode.OK, status);
        var conflict = Assert.Single(preview.GetProperty("conflicts").EnumerateArray());
        Assert.Equal(booked, conflict.GetProperty("appointmentId").GetGuid());
        var suggestion = conflict.GetProperty("suggestion");
        Assert.Equal(day.AddDays(1).ToString("yyyy-MM-dd"), suggestion.Str("date"));
        Assert.Equal("10:00", suggestion.Str("time")[..5]);
    }
}
