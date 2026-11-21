using System.Net;
using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>D28 and D29: branches, working hours, status and the default (BR-BR1–BR10, AC-20 branch parts).</summary>
[Collection(IntegrationCollection.Name)]
public sealed class BranchesTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task The_list_shows_cards_with_today_periods_bookings_and_the_count()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var main = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var second = await TestData.AddBranchAsync(Factory, doctor.Id);
        var today = TestData.CairoToday();
        var weekday = WeeklyHours.IsoWeekday(today);
        var tomorrow = WeeklyHours.IsoWeekday(today.AddDays(1));
        using var client = await Factory.SignedInClientAsync(doctor);
        await client.PutScheduleAsync(main, TestData.ScheduleBody(
        [
            TestData.Period(weekday, "18:00", "22:00", label: "مسائي"),
            TestData.Period(weekday, "10:00", "14:00", label: "صباحي", capacity: 20),
            TestData.Period(tomorrow, "10:00", "14:00"),
        ]));
        await TestData.AddBookingAsync(Factory, doctor.Id, main, today.AddDays(3));
        await TestData.AddBookingAsync(Factory, doctor.Id, main, today.AddDays(4), status: "cancelled");
        await TestData.AddBookingAsync(Factory, doctor.Id, main, today.AddDays(-1));

        var (status, body) = await client.GetJsonAsync("/api/branches");

        Assert.Equal(HttpStatusCode.OK, status);
        var items = body.GetProperty("items").EnumerateArray().ToList();
        Assert.Equal([main.ToString(), second.ToString()], items.Select(b => b.Str("id")));
        var card = items[0];
        Assert.True(card.GetProperty("isDefault").GetBoolean());
        Assert.Equal("المعادي", card.Str("city"));
        Assert.Equal("active", card.Str("status"));
        Assert.True(card.GetProperty("assigned").GetBoolean());
        Assert.Equal(["10:00", "18:00"], card.GetProperty("todayPeriods").EnumerateArray().Select(p => p.Str("startLocal")));
        Assert.Equal(20, card.GetProperty("todayPeriods")[0].GetProperty("capacity").GetInt32());
        Assert.Equal(1, card.GetProperty("upcomingBookings").GetInt32());
        Assert.Empty(items[1].GetProperty("todayPeriods").EnumerateArray());
        Assert.False(items[1].GetProperty("isDefault").GetBoolean());
        Assert.Equal(2, body.GetProperty("count").GetInt32());
        Assert.Equal(await TestData.BranchLimitAsync(Factory), body.GetProperty("limit").GetInt32());
        Assert.True(body.GetProperty("canAdd").GetBoolean());
        Assert.Equal(today.ToString("yyyy-MM-dd"), body.Str("today"));
        Assert.Equal(weekday, body.GetProperty("todayWeekday").GetInt32());
    }

    [Fact]
    public async Task An_assistant_sees_every_branch_and_which_are_theirs()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var main = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var second = await TestData.AddBranchAsync(Factory, doctor.Id);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, branchIds: [second]);
        using var client = await Factory.SignedInClientAsync(assistant);

        var (_, list) = await client.GetJsonAsync("/api/branches");
        var (status, details) = await client.GetJsonAsync($"/api/branches/{main}");

        var assigned = list.GetProperty("items").EnumerateArray().ToDictionary(b => b.Str("id"), b => b.GetProperty("assigned").GetBoolean());
        Assert.False(assigned[main.ToString()]);
        Assert.True(assigned[second.ToString()]);
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.False(details.GetProperty("assigned").GetBoolean());
    }

    [Fact]
    public async Task Create_adds_a_branch_that_is_not_the_default_with_every_field()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/branches/createBranch", TestData.NewBranchBody());

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.False(body.GetProperty("isDefault").GetBoolean());
        Assert.Equal("active", body.Str("status"));
        Assert.Equal("فرع الدقي", body.GetProperty("info").Str("nameAr"));
        Assert.Equal("عيادة الأطفال بالدور الثاني", body.GetProperty("info").Str("description"));
        var address = body.GetProperty("address");
        Assert.Equal("الجيزة", address.Str("governorate"));
        Assert.Equal("١٢ شارع التحرير، الدور التاني، شقة ٤\n(الباب الشمال)", address.Str("details"));
        Assert.Equal("بجوار البنك الأهلي", address.Str("landmark"));
        Assert.Equal("https://maps.app.goo.gl/Dokki12345", address.Str("mapUrl"));
        Assert.False(address.TryGetProperty("street", out _));
        Assert.False(address.TryGetProperty("lat", out _));
        var contact = body.GetProperty("contact");
        Assert.Equal("dokki@clinic.test", contact.Str("email"));
        var phones = contact.GetProperty("phones").EnumerateArray().ToList();
        Assert.Equal("+20233351234", phones[0].Str("number"));
        Assert.Equal("landline", phones[0].Str("label"));
        Assert.True(phones[1].GetProperty("isWhatsapp").GetBoolean());
        var clinicInfo = body.GetProperty("clinicInfo");
        Assert.Equal(["cash", "instapay"], clinicInfo.GetProperty("paymentMethods").EnumerateArray().Select(m => m.GetString()));
        Assert.Equal(["elevator"], clinicInfo.GetProperty("amenities").EnumerateArray().Select(m => m.GetString()));
        Assert.True(clinicInfo.GetProperty("prices").GetProperty("usesDoctorPrices").GetBoolean());
        Assert.Equal("queue", body.GetProperty("workingHours").Str("bookingMode"));
        Assert.Empty(body.GetProperty("workingHours").GetProperty("periods").EnumerateArray());

        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.BranchCreated));
        Assert.Equal(body.Str("id"), audit.TargetId);
        Assert.Equal(doctor.Id, audit.ActorUserId);
    }

    [Fact]
    public async Task Create_checks_the_fields()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/branches/createBranch", new
        {
            info = new { nameAr = "ف" },
            address = new { governorate = "القاهرة", city = "", details = "   ", mapUrl = "https://www.facebook.com/maps/clinic" },
            contact = new { phones = Array.Empty<object>() },
            clinicInfo = new { paymentMethods = new[] { "bitcoin" } },
        });

        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("info.nameAr"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("address.city"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("address.details"));
        Assert.Equal(ErrorCodes.InvalidMapLink, body.FieldCode("address.mapUrl"));
        Assert.Equal(ErrorCodes.PhoneRequired, body.FieldCode("contact.phones"));
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("clinicInfo.paymentMethods"));

        (status, body) = await client.PostAsync("/api/branches/createBranch", new
        {
            info = new { nameAr = "فرع" },
            address = new
            {
                governorate = "القاهرة", city = "المعادي", details = new string('ع', 301),
                mapUrl = "https://maps.app.goo.gl/" + new string('x', 480),
            },
            contact = new { phones = new[] { new { number = "123", label = "fax" }, new { number = "0100", label = "mobile" } } },
        });
        Assert.Equal(ErrorCodes.TooLong, body.FieldCode("address.details"));
        Assert.Equal(ErrorCodes.TooLong, body.FieldCode("address.mapUrl"));
        Assert.Equal(ErrorCodes.InvalidPhone, body.FieldCode("contact.phones[0].number"));
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("contact.phones[0].label"));
        Assert.Equal(ErrorCodes.InvalidPhone, body.FieldCode("contact.phones[1].number"));

        (status, body) = await client.PostAsync("/api/branches/createBranch", new { });
        Assert.Equal(ErrorCodes.Required, body.FieldCode("info"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("address"));
        Assert.Equal(ErrorCodes.Required, body.FieldCode("contact"));
    }

    [Fact]
    public async Task Create_stops_at_the_branch_limit_and_archived_branches_do_not_count()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var limit = await TestData.BranchLimitAsync(Factory);
        var extra = new List<Guid>();
        for (var i = 1; i < limit; i++)
        {
            extra.Add(await TestData.AddBranchAsync(Factory, doctor.Id, $"فرع رقم {i}"));
        }

        using var client = await Factory.SignedInClientAsync(doctor);
        var (status, body) = await client.PostAsync("/api/branches/createBranch", TestData.NewBranchBody());
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.BranchLimitReached, body.Code());
        var (_, list) = await client.GetJsonAsync("/api/branches");
        Assert.False(list.GetProperty("canAdd").GetBoolean());

        (status, _) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = extra[0], status = "archived" });
        Assert.Equal(HttpStatusCode.OK, status);
        (status, _) = await client.PostAsync("/api/branches/createBranch", TestData.NewBranchBody());
        Assert.Equal(HttpStatusCode.Created, status);

        // Bringing the archived branch back would go over the limit.
        (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = extra[0], status = "active" });
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.BranchLimitReached, body.Code());
    }

    [Fact]
    public async Task Update_replaces_only_the_groups_sent()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);
        var (_, created) = await client.PostAsync("/api/branches/createBranch", TestData.NewBranchBody());
        var branchId = created.Str("id");

        var (status, body) = await client.PostAsync("/api/branches/updateBranch", new
        {
            branchId,
            info = new { nameAr = "فرع الدقي الجديد" },
            contact = new { phones = new[] { new { number = "19123", label = "reception", isWhatsapp = false } } },
        });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("فرع الدقي الجديد", body.GetProperty("info").Str("nameAr"));
        Assert.Equal(JsonValueKind.Null, body.GetProperty("info").GetProperty("nameEn").ValueKind);
        Assert.Equal(JsonValueKind.Null, body.GetProperty("contact").GetProperty("email").ValueKind);
        Assert.Equal(["19123"], body.GetProperty("contact").GetProperty("phones").EnumerateArray().Select(p => p.Str("number")));
        Assert.Equal("https://maps.app.goo.gl/Dokki12345", body.GetProperty("address").Str("mapUrl"));
        Assert.Equal(["cash", "instapay"], body.GetProperty("clinicInfo").GetProperty("paymentMethods").EnumerateArray().Select(m => m.GetString()));
        var audit = await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.BranchUpdated);
        Assert.Contains("contact", audit[0].DetailsJson);

        (status, body) = await client.PostAsync("/api/branches/updateBranch", new { branchId });
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.Required, body.FieldCode("body"));
    }

    [Fact]
    public async Task The_address_group_replaces_the_details_and_a_map_link_left_out_is_cleared()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);
        var (_, created) = await client.PostAsync("/api/branches/createBranch", TestData.NewBranchBody());
        var branchId = created.Str("id");

        var (status, body) = await client.PostAsync("/api/branches/updateBranch", new
        {
            branchId,
            address = new { governorate = "الجيزة", city = "الدقي", details = "٥ شارع مصدق، الدور الأول" },
        });

        Assert.Equal(HttpStatusCode.OK, status);
        var address = body.GetProperty("address");
        Assert.Equal("٥ شارع مصدق، الدور الأول", address.Str("details"));
        Assert.Equal(JsonValueKind.Null, address.GetProperty("mapUrl").ValueKind);
        Assert.Equal(JsonValueKind.Null, address.GetProperty("area").ValueKind);

        (status, body) = await client.PostAsync("/api/branches/updateBranch", new
        {
            branchId,
            address = new
            {
                governorate = "الجيزة", city = "الدقي", details = "٥ شارع مصدق",
                mapUrl = "https://www.google.com.eg/maps/place/Dokki/@30.038,31.211,17z",
            },
        });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("https://www.google.com.eg/maps/place/Dokki/@30.038,31.211,17z", body.GetProperty("address").Str("mapUrl"));

        (status, body) = await client.PostAsync("/api/branches/updateBranch", new
        {
            branchId,
            address = new { governorate = "الجيزة", city = "الدقي", details = "٥ شارع مصدق", mapUrl = "Clinic https://maps.app.goo.gl/abc" },
        });
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidMapLink, body.FieldCode("address.mapUrl"));
    }

    [Fact]
    public async Task Closing_needs_a_message_and_shows_it_with_the_reopening_date()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var second = await TestData.AddBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);
        var reopen = TestData.CairoToday().AddDays(10).ToString("yyyy-MM-dd");

        var (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = second, status = "temporarilyClosed" });
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.Required, body.FieldCode("closedMessage"));

        (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new
        {
            branchId = second, status = "temporarilyClosed", closedMessage = "مغلق للتجديدات", reopenDate = TestData.CairoToday().AddDays(-1).ToString("yyyy-MM-dd"),
        });
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("reopenDate"));

        (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new
        {
            branchId = second, status = "temporarilyClosed", closedMessage = "مغلق للتجديدات", reopenDate = reopen,
        });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("temporarilyClosed", body.Str("status"));
        Assert.Equal("مغلق للتجديدات", body.Str("closedMessage"));
        Assert.Equal(reopen, body.Str("reopenDate"));

        (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = second, status = "active" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(JsonValueKind.Null, body.GetProperty("closedMessage").ValueKind);
        Assert.Equal(JsonValueKind.Null, body.GetProperty("reopenDate").ValueKind);
        Assert.Equal(2, (await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.BranchStatusChanged)).Count);
    }

    [Fact]
    public async Task The_default_branch_and_the_last_active_branch_cannot_be_archived()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var main = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var second = await TestData.AddBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = main, status = "archived" });
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.CannotArchiveDefaultBranch, body.Code());

        // The default is the only active branch once the other one is closed.
        (status, _) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = second, status = "temporarilyClosed", closedMessage = "مغلق" });
        Assert.Equal(HttpStatusCode.OK, status);
        (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = main, status = "temporarilyClosed", closedMessage = "مغلق" });
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.LastActiveBranch, body.Code());
    }

    [Fact]
    public async Task A_branch_with_future_bookings_cannot_be_archived_or_closed()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var second = await TestData.AddBranchAsync(Factory, doctor.Id);
        var (_, patientId) = await TestData.CreatePatientAsync(Factory);
        await TestData.LinkAsync(Factory, doctor.Id, patientId, "منى حسن");
        var today = TestData.CairoToday();
        await TestData.AddBookingAsync(Factory, doctor.Id, second, today.AddDays(2));
        await TestData.AddBookingAsync(Factory, doctor.Id, second, today.AddDays(5), patientId: patientId);
        await TestData.AddBookingAsync(Factory, doctor.Id, second, today.AddDays(20));
        await TestData.AddBookingAsync(Factory, doctor.Id, second, today.AddDays(3), status: "cancelled");
        await TestData.AddBookingAsync(Factory, doctor.Id, second, today.AddDays(-2));
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = second, status = "archived" });

        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.BranchHasBookings, body.Code());
        Assert.Equal(3, body.GetProperty("totalCount").GetInt32());
        var bookings = body.GetProperty("bookings").EnumerateArray().ToList();
        Assert.Equal(3, bookings.Count);
        Assert.Equal(today.AddDays(2).ToString("yyyy-MM-dd"), bookings[0].Str("localDate"));
        Assert.True(bookings[0].GetProperty("isGuest").GetBoolean());
        Assert.Equal("منى حسن", bookings[1].Str("name"));
        Assert.Equal(patientId.ToString(), bookings[1].Str("patientId"));
        Assert.Equal("10:00", bookings[1].Str("periodStartLocal"));
        var stored = await TestData.WithDbAsync(Factory, db => db.Branches.Where(b => b.Id == second).Select(b => b.Status).SingleAsync());
        Assert.Equal("active", stored);

        // A closure until a reopening date only needs the bookings before it handled.
        (status, body) = await client.PostAsync("/api/branches/setBranchStatus", new
        {
            branchId = second, status = "temporarilyClosed", closedMessage = "مغلق", reopenDate = today.AddDays(10).ToString("yyyy-MM-dd"),
        });
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(2, body.GetProperty("totalCount").GetInt32());
        (status, _) = await client.PostAsync("/api/branches/setBranchStatus", new
        {
            branchId = second, status = "temporarilyClosed", closedMessage = "مغلق", reopenDate = today.AddDays(1).ToString("yyyy-MM-dd"),
        });
        Assert.Equal(HttpStatusCode.OK, status);
    }

    [Fact]
    public async Task The_default_moves_to_an_active_branch_only()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var main = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var second = await TestData.AddBranchAsync(Factory, doctor.Id);
        var third = await TestData.AddBranchAsync(Factory, doctor.Id, "فرع ثالث");
        using var client = await Factory.SignedInClientAsync(doctor);
        await client.PostAsync("/api/branches/setBranchStatus", new { branchId = third, status = "temporarilyClosed", closedMessage = "مغلق" });

        var (status, body) = await client.PostAsync("/api/branches/setDefaultBranch", new { branchId = third });
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.BranchNotActive, body.Code());

        (status, body) = await client.PostAsync("/api/branches/setDefaultBranch", new { branchId = second });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.True(body.GetProperty("isDefault").GetBoolean());
        Assert.Equal(second, await TestData.DefaultBranchAsync(Factory, doctor.Id));
        var (_, list) = await client.GetJsonAsync("/api/branches");
        var defaults = list.GetProperty("items").EnumerateArray().Where(b => b.GetProperty("isDefault").GetBoolean()).ToList();
        Assert.Equal(second.ToString(), Assert.Single(defaults).Str("id"));

        // The old default can be archived now.
        (status, _) = await client.PostAsync("/api/branches/setBranchStatus", new { branchId = main, status = "archived" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.DefaultBranchChanged));
    }
}
