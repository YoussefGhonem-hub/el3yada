using System.Net;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>D4 register (<c>getPatientsRegister</c>): search, filters, sorting, paging, columns by permission.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class PatientsRegisterTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task Search_finds_names_ignoring_arabic_letter_variants_and_phones_and_file_numbers()
    {
        var (_, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var ahmedPhone = TestData.Mobile();
        var ahmed = await TestData.AddPatientViaApiAsync(client, ahmedPhone, "أحمد مصطفى");
        var menna = await TestData.AddPatientViaApiAsync(client, name: "منة الله علي");
        var third = await TestData.AddPatientViaApiAsync(client, name: "سارة كمال");

        async Task<List<string>> Find(string search)
        {
            var (status, body) = await client.GetJsonAsync($"/api/patients/register?search={Uri.EscapeDataString(search)}");
            Assert.Equal(HttpStatusCode.OK, status);
            return body.Items().Select(i => i.Str("patientId")).ToList();
        }

        Assert.Equal([ahmed.ToString()], await Find("احمد"));
        Assert.Equal([ahmed.ToString()], await Find("مصطفي احمد"));
        Assert.Equal([menna.ToString()], await Find("منه"));
        var local = TestData.Local(ahmedPhone);
        Assert.Equal([ahmed.ToString()], await Find(local[^6..]));
        Assert.Equal([ahmed.ToString()], await Find(ToArabicDigits(local[^8..])));
        Assert.Equal([ahmed.ToString()], await Find("+20 " + local[1..]));
        Assert.Contains(third.ToString(), await Find("3"));
        Assert.Empty(await Find("زياد"));
    }

    [Fact]
    public async Task Last_visit_filters_use_cairo_dates()
    {
        var (_, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var never = await TestData.AddPatientViaApiAsync(client);
        var today = await TestData.AddPatientViaApiAsync(client);
        await TestData.RecordSessionAsync(client, today, branchId);
        var sevenMonths = await TestData.AddPatientViaApiAsync(client);
        var oldSession = await TestData.RecordSessionAsync(client, sevenMonths, branchId);
        var cairoToday = CairoTime.Today(TimeProvider.System);
        await TestData.MoveSessionToDayAsync(Factory, oldSession, cairoToday.AddMonths(-7));
        var fourMonths = await TestData.AddPatientViaApiAsync(client);
        var recentSession = await TestData.RecordSessionAsync(client, fourMonths, branchId);
        await TestData.MoveSessionToDayAsync(Factory, recentSession, cairoToday.AddMonths(-4));

        async Task<List<string>> Filter(string lastVisit) =>
            (await client.GetJsonAsync($"/api/patients/register?lastVisit={lastVisit}")).Body.Items().Select(i => i.Str("patientId")).ToList();

        Assert.Equal([never.ToString()], await Filter("never"));
        Assert.Equal([today.ToString()], await Filter("thisWeek"));
        Assert.Equal([today.ToString()], await Filter("thisMonth"));
        // AC-24: exactly the patients whose last visit is more than 6 months ago.
        Assert.Equal([sevenMonths.ToString()], await Filter("notSeen6m"));
        Assert.Equal(new[] { sevenMonths.ToString(), fourMonths.ToString() }.Order(), (await Filter("notSeen3m")).Order());
        Assert.Empty(await Filter("notSeen12m"));
    }

    [Fact]
    public async Task Rows_show_the_last_visit_and_sort_and_page()
    {
        var (_, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var first = await TestData.AddPatientViaApiAsync(client, name: "باسم علي");
        var second = await TestData.AddPatientViaApiAsync(client, name: "أمل سعيد");
        var third = await TestData.AddPatientViaApiAsync(client, name: "تامر حسن");
        await TestData.RecordSessionAsync(client, second, branchId);
        await TestData.RecordSessionAsync(client, first, branchId);
        await TestData.RecordSessionAsync(client, first, branchId, "consultation");

        var (_, byLastVisit) = await client.GetJsonAsync("/api/patients/register");
        var (_, byName) = await client.GetJsonAsync("/api/patients/register?sort=name");
        var (_, byVisits) = await client.GetJsonAsync("/api/patients/register?sort=visits&direction=asc");
        var (_, page2) = await client.GetJsonAsync("/api/patients/register?sort=fileNumber&pageSize=2&page=2");
        var (badStatus, bad) = await client.GetJsonAsync("/api/patients/register?sort=diagnosis");

        // Default: last visit, newest first, never-visited last (AC-24).
        Assert.Equal([first, second, third], byLastVisit.Items().Select(i => Guid.Parse(i.Str("patientId"))));
        var row = byLastVisit.Items()[0];
        Assert.Equal("consultation", row.StrAt("visits.lastVisit.type"));
        Assert.Equal(branchId.ToString(), row.StrAt("visits.lastVisit.branchId"));
        Assert.Equal(2, row.IntAt("visits.total"));
        Assert.Equal(1, row.IntAt("visits.examinations"));
        Assert.Equal(0, row.IntAt("filesCount"));
        Assert.Equal([second, first, third], byName.Items().Select(i => Guid.Parse(i.Str("patientId"))));
        Assert.Equal(third, Guid.Parse(byVisits.Items()[0].Str("patientId")));
        Assert.Equal(3, page2.IntAt("totalCount"));
        Assert.Equal(2, page2.IntAt("totalPages"));
        Assert.Equal(third, Guid.Parse(Assert.Single(page2.Items()).Str("patientId")));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("sort"));
    }

    [Fact]
    public async Task Branch_visit_count_and_new_this_month_filters()
    {
        var (doctor, client, branchA) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var branchB = await TestData.AddBranchAsync(Factory, doctor.Id);
        var inA = await TestData.AddPatientViaApiAsync(client);
        var inB = await TestData.AddPatientViaApiAsync(client);
        await TestData.RecordSessionAsync(client, inA, branchA);
        await TestData.RecordSessionAsync(client, inB, branchB);
        await TestData.RecordSessionAsync(client, inB, branchB, "consultation");
        var (_, other, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);

        var (_, onlyB) = await client.GetJsonAsync($"/api/patients/register?branchId={branchB}");
        var (_, twoPlus) = await client.GetJsonAsync("/api/patients/register?minVisits=2");
        var (_, atMostOne) = await client.GetJsonAsync("/api/patients/register?maxVisits=1");
        var (_, fresh) = await client.GetJsonAsync("/api/patients/register?newThisMonth=true");
        var (foreignStatus, _) = await other.GetJsonAsync($"/api/patients/register?branchId={branchB}");

        Assert.Equal([inB.ToString()], onlyB.Items().Select(i => i.Str("patientId")));
        Assert.Equal([inB.ToString()], twoPlus.Items().Select(i => i.Str("patientId")));
        Assert.Equal([inA.ToString()], atMostOne.Items().Select(i => i.Str("patientId")));
        Assert.Equal(2, fresh.Items().Count);
        Assert.Equal(HttpStatusCode.NotFound, foreignStatus);
    }

    [Fact]
    public async Task Money_and_clinical_columns_are_null_without_the_permission_and_their_filters_are_refused()
    {
        var (doctor, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var diabetic = await TestData.AddPatientViaApiAsync(client);
        var healthy = await TestData.AddPatientViaApiAsync(client);
        await TestData.RecordSessionAsync(client, diabetic, branchId, amountChargedPiasters: 30_000);
        await client.PostAsync("/api/patients/updateMedicalProfile", new
        {
            patientId = diabetic, allergies = new[] { "Sulfa" }, chronicDiseases = new[] { "سكر النوع الثاني", "ضغط" },
        });
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        using var receptionClient = await Factory.SignedInClientAsync(reception);
        var clinical = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Clinical);
        using var clinicalClient = await Factory.SignedInClientAsync(clinical);

        var (_, doctorRows) = await client.GetJsonAsync("/api/patients/register?sort=totalPaid");
        var (_, receptionRows) = await receptionClient.GetJsonAsync("/api/patients/register");
        var (_, clinicalRows) = await clinicalClient.GetJsonAsync("/api/patients/register?chronicDisease=سكر");
        var (_, anyChronic) = await clinicalClient.GetJsonAsync("/api/patients/register?hasChronicDisease=true&sort=allergies");
        var (chronicStatus, chronicDenied) = await receptionClient.GetJsonAsync("/api/patients/register?hasChronicDisease=true");
        var (sortStatus, sortDenied) = await clinicalClient.GetJsonAsync("/api/patients/register?sort=totalPaid");

        var top = doctorRows.Items()[0];
        Assert.Equal(diabetic.ToString(), top.Str("patientId"));
        Assert.Equal(30_000, top.IntAt("totalPaidPiasters"));
        Assert.True(top.BoolAt("hasAllergies"));
        Assert.Equal(["سكر النوع الثاني", "ضغط"], top.Items("chronicDiseases").Select(d => d.GetString()));
        Assert.Equal(0, doctorRows.Items()[1].IntAt("totalPaidPiasters"));
        Assert.False(doctorRows.Items()[1].BoolAt("hasAllergies"));

        Assert.All(receptionRows.Items(), r =>
        {
            Assert.True(r.IsNullAt("totalPaidPiasters"));
            Assert.True(r.IsNullAt("hasAllergies"));
            Assert.True(r.IsNullAt("chronicDiseases"));
        });
        var clinicalRow = Assert.Single(clinicalRows.Items());
        Assert.Equal(diabetic.ToString(), clinicalRow.Str("patientId"));
        Assert.True(clinicalRow.IsNullAt("totalPaidPiasters"));
        Assert.True(clinicalRow.BoolAt("hasAllergies"));
        Assert.Equal(diabetic.ToString(), Assert.Single(anyChronic.Items()).Str("patientId"));
        Assert.Equal(HttpStatusCode.Forbidden, chronicStatus);
        Assert.Equal(ClinicPermissions.ClinicalView, chronicDenied.Str("permission"));
        Assert.Equal(HttpStatusCode.Forbidden, sortStatus);
        Assert.Equal(ClinicPermissions.RevenueView, sortDenied.Str("permission"));
        _ = healthy;
    }

    [Fact]
    public async Task The_register_lists_only_the_callers_clinic()
    {
        var (_, clientA, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var (_, clientB, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var mine = await TestData.AddPatientViaApiAsync(clientA);
        await TestData.AddPatientViaApiAsync(clientB);

        var (_, body) = await clientA.GetJsonAsync("/api/patients/register");

        Assert.Equal([mine.ToString()], body.Items().Select(i => i.Str("patientId")));
        Assert.Equal(1, body.IntAt("totalCount"));
    }

    private static string ToArabicDigits(string digits) => new(digits.Select(c => (char)('٠' + (c - '0'))).ToArray());
}
