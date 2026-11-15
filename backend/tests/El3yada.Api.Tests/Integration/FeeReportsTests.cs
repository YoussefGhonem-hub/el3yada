using System.Net;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>Fee cards (D1, AC-4), today's sessions (D2, AS1) and the monthly summary (D3, BR-BR7).</summary>
[Collection(IntegrationCollection.Name)]
public sealed class FeeReportsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static DateOnly CairoToday => CairoTime.Today(TimeProvider.System);

    [Fact]
    public async Task AC4_two_examinations_and_three_consultations_today_are_105_pounds_and_yesterday_in_cairo_is_not_counted()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, 3000, 1500, 2);
        var (_, client, branchId) = await TestData.SignedInDoctorAsync(Factory);
        var first = await TestData.AddPatientViaApiAsync(client);
        var second = await TestData.AddPatientViaApiAsync(client);
        await TestData.RecordSessionAsync(client, first, branchId);
        await TestData.RecordSessionAsync(client, first, branchId, "consultation");
        await TestData.RecordSessionAsync(client, first, branchId, "consultation");
        await TestData.RecordSessionAsync(client, second, branchId);
        await TestData.RecordSessionAsync(client, second, branchId, "consultation");
        var third = await TestData.AddPatientViaApiAsync(client);
        var yesterday = await TestData.RecordSessionAsync(client, third, branchId);
        // The last minute of yesterday in Cairo: still today by UTC date in the evening, never today in Cairo.
        await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.Id == yesterday).ExecuteUpdateAsync(
            set => set.SetProperty(s => s.CreatedAt, CairoTime.StartUtc(CairoToday).AddMinutes(-1))
                .SetProperty(s => s.DayKey, CairoToday.AddDays(-1))
                .SetProperty(s => s.MonthKey, CairoTime.MonthKey(CairoToday.AddDays(-1)))));

        var (status, summary) = await client.GetJsonAsync("/api/sessions/feeSummary");
        var (_, day) = await client.GetJsonAsync("/api/sessions/day");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(CairoToday.ToString("yyyy-MM-dd"), summary.Str("day"));
        Assert.Equal(2, summary.IntAt("today.examinationCount"));
        Assert.Equal(3, summary.IntAt("today.consultationCount"));
        Assert.Equal(6000, summary.IntAt("today.examinationFeePiasters"));
        Assert.Equal(4500, summary.IntAt("today.consultationFeePiasters"));
        Assert.Equal(10_500, summary.IntAt("today.totalPiasters"));
        var sameMonth = CairoToday.Day > 1;
        Assert.Equal(sameMonth ? 13_500 : 10_500, summary.IntAt("thisMonth.totalPiasters"));

        Assert.Equal(5, day.Items().Count);
        Assert.Equal(10_500, day.IntAt("totals.totalPiasters"));
        Assert.Equal(2, day.IntAt("totals.examinationCount"));
        Assert.Equal(100_000, day.IntAt("amountChargedTotalPiasters"));
        var (_, yesterdayList) = await client.GetJsonAsync($"/api/sessions/day?day={CairoToday.AddDays(-1):yyyy-MM-dd}");
        Assert.Equal(yesterday.ToString(), Assert.Single(yesterdayList.Items()).Str("sessionId"));
    }

    [Fact]
    public async Task The_day_list_shows_each_session_newest_first_and_filters_by_type_and_recorder()
    {
        var scene = await PatientScene.CreateAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, scene.Doctor.Id, permissions: [ClinicPermissions.SessionsCreate], name: "هدى سمير");
        using var assistantClient = await Factory.SignedInClientAsync(assistant);
        var assistantSession = await TestData.RecordSessionAsync(assistantClient, scene.PatientId, scene.BranchId, "consultation", 5_000);

        var (_, all) = await scene.Client.GetJsonAsync("/api/sessions/day");
        var (_, consultations) = await scene.Client.GetJsonAsync("/api/sessions/day?type=consultation");
        var (_, byDoctor) = await scene.Client.GetJsonAsync($"/api/sessions/day?recordedBy={scene.Doctor.Id}");
        var (badStatus, bad) = await scene.Client.GetJsonAsync("/api/sessions/day?day=15-11-2026");

        var rows = all.Items();
        Assert.Equal([assistantSession.ToString(), scene.SessionId.ToString()], rows.Select(r => r.Str("sessionId")));
        var top = rows[0];
        Assert.Equal("consultation", top.Str("type"));
        Assert.Equal("منى حسن", top.Str("patientName"));
        Assert.Equal(1, top.IntAt("fileNumber"));
        Assert.Equal("هدى سمير", top.StrAt("recordedBy.name"));
        Assert.Equal("assistant", top.StrAt("recordedBy.role"));
        Assert.True(top.BoolAt("awaitingDoctor"));
        Assert.Equal(5_000, top.IntAt("amountChargedPiasters"));
        Assert.Equal(assistantSession.ToString(), Assert.Single(consultations.Items()).Str("sessionId"));
        Assert.Equal(scene.SessionId.ToString(), Assert.Single(byDoctor.Items()).Str("sessionId"));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("day"));
    }

    [Fact]
    public async Task An_assistant_sees_only_their_branches_sessions_and_amounts_need_revenue_view()
    {
        var (doctor, client, branchA) = await TestData.SignedInDoctorAsync(Factory);
        var branchB = await TestData.AddBranchAsync(Factory, doctor.Id);
        var patient = await TestData.AddPatientViaApiAsync(client);
        var other = await TestData.AddPatientViaApiAsync(client);
        var inA = await TestData.RecordSessionAsync(client, patient, branchA);
        await TestData.RecordSessionAsync(client, other, branchB);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.SessionsCreate], branchIds: [branchA]);
        using var assistantClient = await Factory.SignedInClientAsync(assistant);

        var (_, mine) = await assistantClient.GetJsonAsync("/api/sessions/day");
        var (deniedStatus, denied) = await assistantClient.GetJsonAsync($"/api/sessions/day?branchId={branchB}");
        var (_, doctorB) = await client.GetJsonAsync($"/api/sessions/day?branchId={branchB}");

        var row = Assert.Single(mine.Items());
        Assert.Equal(inA.ToString(), row.Str("sessionId"));
        Assert.True(row.IsNullAt("amountChargedPiasters"));
        Assert.True(mine.IsNullAt("amountChargedTotalPiasters"));
        Assert.Equal(1, mine.IntAt("totals.examinationCount"));
        Assert.Equal(HttpStatusCode.Forbidden, deniedStatus);
        Assert.Equal(ErrorCodes.BranchNotAllowed, denied.Code());
        Assert.Single(doctorB.Items());
    }

    [Fact]
    public async Task The_month_has_totals_per_branch_that_add_up_and_one_row_per_day()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, 3000, 1500, 2);
        var (doctor, client, branchA) = await TestData.SignedInDoctorAsync(Factory);
        var branchB = await TestData.AddBranchAsync(Factory, doctor.Id);
        var p1 = await TestData.AddPatientViaApiAsync(client);
        var p2 = await TestData.AddPatientViaApiAsync(client);
        await TestData.RecordSessionAsync(client, p1, branchA);
        await TestData.RecordSessionAsync(client, p1, branchB, "consultation");
        await TestData.RecordSessionAsync(client, p2, branchB);
        var officeManager = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.OfficeManager, [branchA]);
        using var managerClient = await Factory.SignedInClientAsync(officeManager);

        var (status, month) = await managerClient.GetJsonAsync("/api/sessions/month");
        var (_, onlyB) = await client.GetJsonAsync($"/api/sessions/month?branchId={branchB}");
        var (_, past) = await client.GetJsonAsync("/api/sessions/month?month=2020-02");
        var (_, future) = await client.GetJsonAsync($"/api/sessions/month?month={CairoToday.AddMonths(2):yyyy-MM}");
        var (badStatus, bad) = await client.GetJsonAsync("/api/sessions/month?month=2026-13");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(CairoTime.MonthKey(CairoToday), month.Str("month"));
        Assert.Equal(7500, month.IntAt("totals.totalPiasters"));
        Assert.Equal(2, month.IntAt("totals.examinationCount"));
        Assert.Equal(1, month.IntAt("totals.consultationCount"));
        // Billing is per doctor (BR-BR7): the office manager of branch A sees both branches.
        var branches = month.Items("branches");
        Assert.Equal([branchA.ToString(), branchB.ToString()], branches.Select(b => b.Str("branchId")));
        Assert.Equal(3000, branches[0].IntAt("totals.totalPiasters"));
        Assert.Equal(4500, branches[1].IntAt("totals.totalPiasters"));
        Assert.Equal(month.IntAt("totals.totalPiasters"), branches.Sum(b => b.IntAt("totals.totalPiasters")));
        var days = month.Items("days");
        Assert.Equal(CairoToday.Day, days.Count);
        Assert.Equal(CairoToday.ToString("yyyy-MM-dd"), days[^1].Str("day"));
        Assert.Equal(7500, days[^1].IntAt("totals.totalPiasters"));
        Assert.All(days.SkipLast(1), d => Assert.Equal(0, d.IntAt("totals.totalPiasters")));

        Assert.Equal(4500, onlyB.IntAt("totals.totalPiasters"));
        Assert.Equal([branchB.ToString()], onlyB.Items("branches").Select(b => b.Str("branchId")));
        Assert.Equal(29, past.Items("days").Count);
        Assert.Equal(0, past.IntAt("totals.totalPiasters"));
        Assert.Empty(future.Items("days"));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("month"));
    }

    [Fact]
    public async Task Fee_totals_are_per_clinic()
    {
        var a = await PatientScene.CreateAsync(Factory);
        var (_, clientB, _) = await TestData.SignedInDoctorAsync(Factory);

        var (_, summaryB) = await clientB.GetJsonAsync("/api/sessions/feeSummary");
        var (_, dayB) = await clientB.GetJsonAsync("/api/sessions/day");

        Assert.Equal(0, summaryB.IntAt("today.totalPiasters"));
        Assert.Empty(dayB.Items());
        _ = a;
    }
}
