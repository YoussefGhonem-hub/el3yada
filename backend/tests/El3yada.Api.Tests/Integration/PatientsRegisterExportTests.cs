using System.Net;
using System.Text;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Patients;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// D4 gaps: the unread chat badge (the caller's own count), sorting by the booking and chat columns, and
/// [S] "Export CSV" (the same filters, permission-shaped columns, doctor only, audited, safe in a spreadsheet).
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class PatientsRegisterExportTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static DateOnly Today => CairoTime.Today(TimeProvider.System);

    /// <summary><paramref name="count"/> unread messages for <paramref name="userId"/> in the link's chat (made if missing).</summary>
    private Task SetUnreadAsync(Guid doctorId, Guid patientId, Guid userId, int count) =>
        TestData.WithDbAsync(Factory, async db =>
        {
            var link = await db.DoctorPatients.SingleAsync(l => l.DoctorId == doctorId && l.PatientId == patientId);
            var chat = await db.Chats.SingleOrDefaultAsync(c => c.LinkId == link.Id);
            if (chat is null)
            {
                chat = new Chat { Id = Guid.NewGuid(), LinkId = link.Id, DoctorId = doctorId, PatientId = patientId, CreatedAt = DateTime.UtcNow };
                db.Chats.Add(chat);
            }

            db.ChatReadStates.Add(new ChatReadState { ChatId = chat.Id, UserId = userId, UnreadCount = count });
            await db.SaveChangesAsync();
        });

    private static List<Guid> Ids(System.Text.Json.JsonElement body) => body.Items().Select(i => Guid.Parse(i.Str("patientId"))).ToList();

    [Fact]
    public async Task The_unread_badge_is_the_callers_own_count_and_needs_chat()
    {
        var (doctor, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var quiet = await TestData.AddPatientViaApiAsync(client, name: "باسم علي");
        var chatty = await TestData.AddPatientViaApiAsync(client, name: "أمل سعيد");
        var withChat = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.Chat]);
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        await SetUnreadAsync(doctor.Id, chatty, doctor.Id, 3);
        await SetUnreadAsync(doctor.Id, chatty, withChat.Id, 1);
        using var asChat = await Factory.SignedInClientAsync(withChat);
        using var asReception = await Factory.SignedInClientAsync(reception);

        var (_, mine) = await client.GetJsonAsync("/api/patients/register?sort=unreadChat");
        var (_, theirs) = await asChat.GetJsonAsync("/api/patients/register?sort=unreadChat");
        var (_, plain) = await asReception.GetJsonAsync("/api/patients/register");
        var (deniedStatus, denied) = await asReception.GetJsonAsync("/api/patients/register?sort=unreadChat");

        Assert.Equal([chatty, quiet], Ids(mine));
        Assert.Equal(3, mine.Items()[0].IntAt("unreadChatCount"));
        Assert.Equal(0, mine.Items()[1].IntAt("unreadChatCount"));
        Assert.Equal(1, theirs.Items()[0].IntAt("unreadChatCount"));
        Assert.All(plain.Items(), row => Assert.True(row.IsNullAt("unreadChatCount")));
        Assert.Equal(HttpStatusCode.Forbidden, deniedStatus);
        Assert.Equal(ClinicPermissions.Chat, denied.Str("permission"));
    }

    [Fact]
    public async Task Sorting_by_next_booking_keeps_patients_without_one_last_and_no_shows_sort_largest_first()
    {
        var (doctor, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var none = await TestData.AddPatientViaApiAsync(client, name: "بدون حجز");
        var later = await TestData.AddPatientViaApiAsync(client, name: "حجز بعدين");
        var soon = await TestData.AddPatientViaApiAsync(client, name: "حجز قريب");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, later, Today.AddDays(9), "pending");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, soon, Today.AddDays(2), "confirmed");
        // Past and cancelled bookings are not "next".
        await TestData.AddAppointmentAsync(Factory, doctor.Id, none, Today.AddDays(-3), "noShow");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, none, Today.AddDays(-10), "noShow");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, none, Today.AddDays(4), "cancelled");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, later, Today.AddDays(-30), "noShow");

        var (_, ascending) = await client.GetJsonAsync("/api/patients/register?sort=nextBooking");
        var (_, descending) = await client.GetJsonAsync("/api/patients/register?sort=nextBooking&direction=desc");
        var (_, noShows) = await client.GetJsonAsync("/api/patients/register?sort=noShows");

        Assert.Equal([soon, later, none], Ids(ascending));
        Assert.Equal([later, soon, none], Ids(descending));
        Assert.Equal([none, later, soon], Ids(noShows));
        Assert.Equal(2, noShows.Items()[0].IntAt("noShowCount"));
    }

    [Fact]
    public async Task Export_has_the_registers_filters_and_order_in_arabic_with_a_bom()
    {
        var (doctor, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var phone = TestData.Mobile();
        var seen = await TestData.AddPatientViaApiAsync(client, phone, "أحمد مصطفى");
        await TestData.RecordSessionAsync(client, seen, branchId, amountChargedPiasters: 35_000);
        var never = await TestData.AddPatientViaApiAsync(client, name: "منة الله علي");
        await TestData.AddAppointmentAsync(Factory, doctor.Id, never, Today.AddDays(3), "confirmed");
        await client.PostAsync("/api/patients/updateMedicalProfile", new { patientId = seen, allergies = new[] { "Sulfa" }, chronicDiseases = new[] { "ضغط", "سكر" } });

        using var response = await client.GetAsync("/api/patients/register/export");
        var bytes = await response.Content.ReadAsByteArrayAsync();
        var text = Encoding.UTF8.GetString(bytes);
        var lines = text.TrimStart('﻿').Split("\r\n", StringSplitOptions.RemoveEmptyEntries);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/csv", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal($"patients-{Today:yyyy-MM-dd}.csv", response.Content.Headers.ContentDisposition?.FileNameStar ?? response.Content.Headers.ContentDisposition?.FileName?.Trim('"'));
        Assert.Equal(Encoding.UTF8.GetPreamble(), bytes[..3]);
        Assert.Equal(3, lines.Length);
        Assert.StartsWith("رقم الملف,الاسم,الموبايل,النوع,السن,أول زيارة,آخر زيارة", lines[0]);
        Assert.EndsWith("إجمالي المدفوع (ج.م),حساسية,أمراض مزمنة,تاريخ الإضافة", lines[0]);
        // Default order: last visit, newest first, never-visited last.
        var local = "0" + phone[3..];
        Assert.StartsWith($"1,أحمد مصطفى,{local[..3]} {local[3..7]} {local[7..]},أنثى,", lines[1]);
        // The Arabic comma (،) needs no quotes; the ASCII one does.
        Assert.Contains($",{Today:yyyy-MM-dd},كشف,فرع المعادي,1,1,0,,0,0,350.00,نعم,ضغط، سكر,", lines[1]);
        Assert.StartsWith("2,منة الله علي,", lines[2]);
        Assert.Contains($",,,,,0,0,0,{Today.AddDays(3):yyyy-MM-dd},0,0,0.00,لا,,", lines[2]);

        // The same filters as the list, and English on request.
        using var english = await client.GetAsync("/api/patients/register/export?lang=en&lastVisit=never");
        var englishLines = (await english.Content.ReadAsStringAsync()).TrimStart('﻿').Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
        Assert.StartsWith("File number,Name,Mobile,Gender,Age,First visit,Last visit,Last visit type", englishLines[0]);
        Assert.StartsWith("2,منة الله علي,", Assert.Single(englishLines[1..]));
        Assert.Contains(",Female,", englishLines[1]);

        var audit = await TestData.ClinicAuditAsync(Factory, doctor.Id, "patientsExported");
        Assert.Equal(2, audit.Count);
        Assert.Contains("\"rows\":1", audit[0].DetailsJson);
        Assert.Contains("\"lastVisit\":\"never\"", audit[0].DetailsJson);
        Assert.DoesNotContain("أحمد", audit[1].DetailsJson);
        Assert.Contains("\"rows\":2", audit[1].DetailsJson);
    }

    [Fact]
    public async Task Export_is_doctor_only_and_shaped_by_the_doctors_permissions()
    {
        var (doctor, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        await TestData.AddPatientViaApiAsync(client);
        var manager = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.OfficeManager);
        using var asManager = await Factory.SignedInClientAsync(manager);
        var (_, otherDoctor, otherBranch) = await TestData.SignedInDoctorWithBranchAsync(Factory);

        var (assistantStatus, assistantBody) = await asManager.GetJsonAsync("/api/patients/register/export");
        var (anonymousStatus, _) = await Factory.CreateClient().GetJsonAsync("/api/patients/register/export");
        var (foreignBranchStatus, _) = await otherDoctor.GetJsonAsync($"/api/patients/register/export?branchId={await TestData.DefaultBranchAsync(Factory, doctor.Id)}");
        var (badSortStatus, badSort) = await client.GetJsonAsync("/api/patients/register/export?sort=diagnosis");
        using var otherExport = await otherDoctor.GetAsync($"/api/patients/register/export?branchId={otherBranch}");
        var otherLines = (await otherExport.Content.ReadAsStringAsync()).TrimStart('﻿').Split("\r\n", StringSplitOptions.RemoveEmptyEntries);

        Assert.Equal(HttpStatusCode.Forbidden, assistantStatus);
        Assert.Equal(ErrorCodes.PermissionDenied, assistantBody.Code());
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousStatus);
        Assert.Equal(HttpStatusCode.NotFound, foreignBranchStatus);
        Assert.Equal(HttpStatusCode.BadRequest, badSortStatus);
        Assert.Equal(ErrorCodes.InvalidValue, badSort.FieldCode("sort"));
        // Another clinic's export holds only its own (no) patients: the header alone.
        Assert.Single(otherLines);
    }

    [Theory]
    [InlineData("أحمد", "أحمد")]
    [InlineData("=HYPERLINK(\"x\")", "\"'=HYPERLINK(\"\"x\"\")\"")]
    [InlineData("+20100", "'+20100")]
    [InlineData("-1", "'-1")]
    [InlineData("@SUM(A1)", "'@SUM(A1)")]
    [InlineData("ضغط، سكر", "ضغط، سكر")]
    [InlineData("a,b", "\"a,b\"")]
    [InlineData("line\nbreak", "\"line\nbreak\"")]
    public void Cells_are_quoted_and_never_run_as_formulas(string value, string expected) =>
        Assert.Equal(expected, PatientsRegisterCsv.Escape(value));

    [Theory]
    [InlineData("+201012345678", "010 1234 5678")]
    [InlineData("+1555123", "+1555123")]
    public void Phones_keep_their_leading_zero_in_spreadsheets(string e164, string expected) =>
        Assert.Equal(expected, PatientsRegisterCsv.LocalPhone(e164));
}
