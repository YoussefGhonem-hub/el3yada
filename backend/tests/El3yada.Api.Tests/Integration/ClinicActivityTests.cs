using System.Net;
using System.Text.Json;
using El3yada.Api.Common;
using El3yada.Api.Controllers;
using El3yada.Data.Entities;

namespace El3yada.Api.Tests.Integration;

/// <summary>D27 activity log (spec 9.1 getClinicActivity, BR-AS10, AC-19 "Activity log").</summary>
[Collection(IntegrationCollection.Name)]
public sealed class ClinicActivityTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private Task AddRowAsync(Guid doctorId, Guid? actor, string role, string action, DateTime at, Guid? patientId = null) =>
        TestData.WithDbAsync(Factory, async db =>
        {
            db.AuditLogs.Add(new AuditLog
            {
                ActorUserId = actor, ActorRole = role, DoctorId = doctorId, PatientId = patientId, Action = action,
                TargetType = "patient", TargetId = patientId?.ToString(), DetailsJson = "{\"fileNumber\":7}", At = at,
            });
            await db.SaveChangesAsync();
        });

    [Fact]
    public async Task The_doctor_sees_what_they_and_their_assistants_did_newest_first()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var assistant = await TestData.CreateAssistantAsync(
            Factory, doctor.Id, permissions: ["scheduleManage", "appointmentsManage", "appointmentsView"], name: "منى سمير");
        var other = await TestData.CreateDoctorAsync(Factory);
        var admin = await TestData.CreateAdminAsync(Factory);
        using var assistantClient = await Factory.SignedInClientAsync(assistant);
        using var doctorClient = await Factory.SignedInClientAsync(doctor);
        await doctorClient.PostAsync("/api/prices/updatePrices", new { examinationPricePiasters = 20000 });
        await assistantClient.PostAsync("/api/branches/updateBranchHours", new
        {
            branchId = branch, periods = new[] { new { weekday = 6, startLocal = "10:00", endLocal = "14:00" } },
        });
        await AddRowAsync(doctor.Id, admin.Id, "admin", "doctorLicenseViewed", DateTime.UtcNow);
        using var otherClient = await Factory.SignedInClientAsync(other);
        await otherClient.PostAsync("/api/prices/updatePrices", new { examinationPricePiasters = 1 });

        var (status, body) = await doctorClient.GetJsonAsync("/api/clinic/activity");

        Assert.Equal(HttpStatusCode.OK, status);
        var items = body.GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(["branchHoursUpdated", "pricesUpdated"], items.Select(i => i.Str("action")));
        var hours = items[0];
        Assert.Equal(assistant.Id.ToString(), hours.GetProperty("actor").Str("userId"));
        Assert.Equal("منى سمير", hours.GetProperty("actor").Str("name"));
        Assert.Equal("assistant", hours.GetProperty("actor").Str("role"));
        Assert.Equal("branch", hours.Str("targetType"));
        Assert.Equal(branch.ToString(), hours.Str("targetId"));
        Assert.Equal(1, hours.GetProperty("details").GetProperty("periods").GetInt32());
        Assert.Equal(JsonValueKind.Null, hours.GetProperty("patient").ValueKind);
        Assert.Equal("doctor", items[1].GetProperty("actor").Str("role"));
        Assert.Equal(2, body.GetProperty("totalCount").GetInt32());
        Assert.Equal(["branchHoursUpdated", "pricesUpdated"], body.GetProperty("actions").EnumerateArray().Select(a => a.GetString()));
    }

    [Fact]
    public async Task Each_row_shows_the_patient_by_their_name_and_file_number_in_this_clinic()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var (_, patientId) = await TestData.CreatePatientAsync(Factory, name: "منى حسن");
        await TestData.LinkAsync(Factory, doctor.Id, patientId, "منى حسن علي");
        await AddRowAsync(doctor.Id, doctor.Id, "doctor", "patientCreated", DateTime.UtcNow, patientId);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (_, body) = await client.GetJsonAsync($"/api/clinic/activity?patientId={patientId}");

        var row = Assert.Single(body.GetProperty("items").EnumerateArray());
        Assert.Equal("patientCreated", row.Str("action"));
        var patient = row.GetProperty("patient");
        Assert.Equal(patientId.ToString(), patient.Str("id"));
        Assert.Equal("منى حسن علي", patient.Str("name"));
        Assert.Equal(1, patient.GetProperty("fileNumber").GetInt32());
        Assert.Equal(7, row.GetProperty("details").GetProperty("fileNumber").GetInt32());
    }

    [Fact]
    public async Task Filters_by_person_action_and_Cairo_dates()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id);
        var day = new DateOnly(2026, 11, 10);
        var start = CairoTime.StartUtc(day);
        var next = CairoTime.StartUtc(day.AddDays(1));
        await AddRowAsync(doctor.Id, doctor.Id, "doctor", "sessionCreated", start.AddMinutes(-1));
        await AddRowAsync(doctor.Id, assistant.Id, "assistant", "sessionCreated", start.AddMinutes(30));
        await AddRowAsync(doctor.Id, doctor.Id, "doctor", "patientCreated", next.AddMinutes(-30));
        await AddRowAsync(doctor.Id, assistant.Id, "assistant", "patientCreated", next);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (_, onDay) = await client.GetJsonAsync("/api/clinic/activity?from=2026-11-10&to=2026-11-10");
        var (_, byAssistant) = await client.GetJsonAsync($"/api/clinic/activity?actorUserId={assistant.Id}");
        var (_, byAction) = await client.GetJsonAsync("/api/clinic/activity?action=patientCreated&from=2026-11-10");
        var (_, paged) = await client.GetJsonAsync("/api/clinic/activity?page=2&pageSize=3");

        Assert.Equal(["patientCreated", "sessionCreated"], onDay.GetProperty("items").EnumerateArray().Select(i => i.Str("action")));
        Assert.Equal(2, byAssistant.GetProperty("totalCount").GetInt32());
        Assert.All(byAssistant.GetProperty("items").EnumerateArray(), i => Assert.Equal("assistant", i.GetProperty("actor").Str("role")));
        Assert.Equal(2, byAction.GetProperty("totalCount").GetInt32());
        Assert.Equal(4, paged.GetProperty("totalCount").GetInt32());
        Assert.Equal(2, paged.GetProperty("totalPages").GetInt32());
        Assert.Equal("doctor", Assert.Single(paged.GetProperty("items").EnumerateArray()).GetProperty("actor").Str("role"));
    }

    [Fact]
    public async Task People_for_the_filter_include_removed_assistants()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var active = await TestData.CreateAssistantAsync(Factory, doctor.Id, name: "سارة محمود");
        var removed = await TestData.CreateAssistantAsync(Factory, doctor.Id, status: "removed", name: "منى سمير");
        await TestData.CreateAssistantAsync(Factory, (await TestData.CreateDoctorAsync(Factory)).Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (_, body) = await client.GetJsonAsync("/api/clinic/activity");

        var people = body.GetProperty("people").EnumerateArray().ToList();
        Assert.Equal([doctor.Id.ToString(), active.Id.ToString(), removed.Id.ToString()], people.Select(p => p.Str("userId")));
        Assert.Equal("doctor", people[0].Str("role"));
        Assert.Equal("أحمد علي", people[0].Str("name"));
        Assert.Equal("removed", people[2].Str("status"));
        Assert.Empty(body.GetProperty("items").EnumerateArray());
    }

    [Fact]
    public async Task Bad_filters_are_refused()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.GetJsonAsync("/api/clinic/activity?from=15/11/2026&pageSize=0");
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("from"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("pageSize"));

        (status, body) = await client.GetJsonAsync("/api/clinic/activity?from=2026-11-10&to=2026-11-09");
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("to"));
    }
}

public sealed class ClinicActivityQueryTests
{
    [Fact]
    public void Dates_are_YYYY_MM_DD()
    {
        Assert.Equal(new DateOnly(2026, 11, 15), ClinicActivityQuery.Day("2026-11-15"));
        Assert.Null(ClinicActivityQuery.Day("15/11/2026"));
        Assert.Null(ClinicActivityQuery.Day("2026-11-15T10:00"));
    }
}
