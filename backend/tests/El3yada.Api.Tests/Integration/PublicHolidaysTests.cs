using System.Net;
using El3yada.Api.Audit;
using El3yada.Api.ClinicAdmin;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// AD13 [C]: the public holidays the admin manages (BR-AP13). Clinics see the coming ones as suggestions in D29's
/// Special dates tab; a branch closes on one only when its schedule adds the closure.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class PublicHolidaysTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    /// <summary>A date no other test of this run uses: the shared database keeps one holiday a date.</summary>
    private static DateOnly FreeDate(int daysAhead) => TestData.CairoToday().AddDays(daysAhead);

    [Fact]
    public async Task The_admin_keeps_the_list_one_holiday_a_date()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var client = await Factory.SignedInClientAsync(admin);
        var date = FreeDate(200);

        var (status, created) = await client.PostAsync("/api/admin/createPublicHoliday", new { date, nameAr = " شم النسيم ", nameEn = "Sham El-Nessim" });
        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal("شم النسيم", created.Str("nameAr"));
        var id = created.GetProperty("id").GetGuid();

        var (_, list) = await client.GetJsonAsync("/api/admin/publicHolidays");
        Assert.Contains(list.EnumerateArray(), h => h.GetProperty("id").GetGuid() == id && h.Str("date") == date.ToString("yyyy-MM-dd"));

        (status, var duplicate) = await client.PostAsync("/api/admin/createPublicHoliday", new { date, nameAr = "عيد", nameEn = "Feast" });
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.PublicHolidayExists, duplicate.Code());

        (status, var invalid) = await client.PostAsync("/api/admin/createPublicHoliday", new { date = FreeDate(201), nameAr = "", nameEn = new string('x', 101) });
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.Required, invalid.FieldCode("nameAr"));
        Assert.Equal(ErrorCodes.TooLong, invalid.FieldCode("nameEn"));

        (status, _) = await client.PostAsync("/api/admin/deletePublicHoliday", new { id });
        Assert.Equal(HttpStatusCode.NoContent, status);
        Assert.False(await TestData.WithDbAsync(Factory, db => db.PublicHolidays.AnyAsync(h => h.Id == id)));
        (status, _) = await client.PostAsync("/api/admin/deletePublicHoliday", new { id });
        Assert.Equal(HttpStatusCode.NotFound, status);

        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs.Where(a => a.TargetId == id.ToString()).Select(a => a.Action).ToListAsync());
        Assert.Equal([AuditActions.PublicHolidayCreated, AuditActions.PublicHolidayDeleted], audit.Order());
    }

    [Fact]
    public async Task Only_admins_manage_it()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        foreach (var user in new[] { doctor, patient })
        {
            using var client = await Factory.SignedInClientAsync(user);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.GetJsonAsync("/api/admin/publicHolidays")).Status);
            Assert.Equal(HttpStatusCode.Forbidden,
                (await client.PostAsync("/api/admin/createPublicHoliday", new { date = FreeDate(210), nameAr = "عيد", nameEn = "Feast" })).Status);
        }

        Assert.Equal(HttpStatusCode.Unauthorized, (await Factory.Client().GetJsonAsync("/api/admin/publicHolidays")).Status);
    }

    [Fact]
    public async Task Clinics_see_the_coming_holidays_as_suggestions_and_close_only_when_they_choose()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var adminClient = await Factory.SignedInClientAsync(admin);
        var holiday = FreeDate(220);
        var past = FreeDate(-3);
        var farAway = FreeDate(400);
        foreach (var (date, name) in new[] { (holiday, "عيد العمال"), (past, "عيد فات"), (farAway, "عيد بعيد") })
        {
            Assert.Equal(HttpStatusCode.Created, (await adminClient.PostAsync("/api/admin/createPublicHoliday", new { date, nameAr = name, nameEn = "Holiday" })).Status);
        }

        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);
        var week = Enumerable.Range(1, 7).Select(d => TestData.Period(d, "10:00", "14:00")).ToList();
        await client.PutScheduleAsync(branch, TestData.ScheduleBody(week));

        // The coming year's holidays are listed with the schedule; past and far-away ones aren't.
        var (status, schedule) = await client.GetJsonAsync($"/api/staff/branches/{branch}/schedule");
        Assert.Equal(HttpStatusCode.OK, status);
        var dates = schedule.GetProperty("holidays").EnumerateArray().Select(h => h.Str("date")).ToList();
        Assert.Contains(holiday.ToString("yyyy-MM-dd"), dates);
        Assert.DoesNotContain(past.ToString("yyyy-MM-dd"), dates);
        Assert.DoesNotContain(farAway.ToString("yyyy-MM-dd"), dates);

        // A suggestion closes nothing by itself.
        async Task<string?> ReasonOn(DateOnly day)
        {
            var (_, availability) = await client.GetJsonAsync($"/api/staff/availability?branchId={branch}&visitType=examination&from={day:yyyy-MM-dd}");
            var reason = availability.GetProperty("days")[0].GetProperty("reason");
            return reason.ValueKind == System.Text.Json.JsonValueKind.Null ? null : reason.GetString();
        }

        Assert.Null(await ReasonOn(holiday));

        // The doctor closes the branch on it (D29's "Close this day").
        var closed = TestData.ScheduleBody(week, closures:
        [
            new { id = (Guid?)null, fromLocal = holiday.ToDateTime(TimeOnly.MinValue), toLocal = holiday.AddDays(1).ToDateTime(TimeOnly.MinValue), reason = "عيد العمال", allBranches = false },
        ]);
        Assert.Equal(HttpStatusCode.OK, (await client.PutScheduleAsync(branch, closed)).Status);
        Assert.Equal("BRANCH_CLOSED", await ReasonOn(holiday));
    }
}
