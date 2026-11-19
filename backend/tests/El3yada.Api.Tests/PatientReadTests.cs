using System.Net;
using System.Net.Http.Json;
using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Infrastructure.Paging;

namespace El3yada.Api.Tests;

/// <summary>
/// Phase 4 "done when": a patient linked to two doctors sees both files separately and together,
/// and never sees private notes, drafts or deleted rows (AC-11). These tests only read.
/// </summary>
public sealed class PatientReadTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    private Task<HttpClient> Patient() => api.ClientForAsync(api.Demo.PatientUserId);

    [Fact]
    public async Task Patient_sees_both_doctors()
    {
        var client = await Patient();
        var doctors = await client.GetFromJsonAsync<List<MyDoctorDto>>("/api/patient/doctors");

        Assert.NotNull(doctors);
        Assert.Equal(
            new[] { api.Demo.DoctorAUserId, api.Demo.DoctorBUserId }.Order(),
            doctors.Select(d => d.Doctor.Id).Order());
        Assert.All(doctors, d => Assert.True(d.FileNumber > 0));
    }

    [Fact]
    public async Task Visits_include_both_doctors_and_exclude_deleted_and_other_patients()
    {
        var client = await Patient();
        var all = await client.GetFromJsonAsync<PagedResult<VisitListItemDto>>("/api/patient/visits");

        Assert.NotNull(all);
        var ids = all.Items.Select(v => v.Id).ToList();
        Assert.Contains(api.Demo.VisibleSessionId, ids);
        Assert.Contains(api.Demo.OtherDoctorSessionId, ids);
        Assert.DoesNotContain(api.Demo.DeletedSessionId, ids);
        Assert.DoesNotContain(api.Demo.OtherPatientSessionId, ids);
        Assert.Equal(2, all.TotalCount);
        // Newest first.
        Assert.Equal(api.Demo.OtherDoctorSessionId, all.Items[0].Id);

        var onlyA = await client.GetFromJsonAsync<PagedResult<VisitListItemDto>>($"/api/patient/visits?doctorId={api.Demo.DoctorAUserId}");
        Assert.Equal([api.Demo.VisibleSessionId], onlyA!.Items.Select(v => v.Id));
    }

    [Fact]
    public async Task Visit_details_never_contain_private_notes()
    {
        var client = await Patient();
        var response = await client.GetAsync($"/api/patient/visits/{api.Demo.VisibleSessionId}");
        response.EnsureSuccessStatusCode();
        var raw = await response.Content.ReadAsStringAsync();

        Assert.DoesNotContain(api.Demo.PrivateNoteText, raw);
        Assert.DoesNotContain("privateNote", raw, StringComparison.OrdinalIgnoreCase);
        // Fees and the amount charged are clinic data, not the patient's medical file.
        Assert.DoesNotContain("piasters", raw, StringComparison.OrdinalIgnoreCase);

        var visit = await response.Content.ReadFromJsonAsync<VisitDetailDto>();
        Assert.Equal("ارتفاع ضغط الدم الأولي", visit!.Diagnosis);
        Assert.Equal((short)150, visit.Vitals.BpSys);
        Assert.NotEmpty(visit.Branch.Phones);
        // Only sent and cancelled documents of this visit, never the draft or the one under review.
        Assert.Equal(3, visit.Prescriptions.Count);
        Assert.DoesNotContain(visit.Prescriptions, p => p.Status is "draft" or "readyForReview");
        Assert.Single(visit.Files);
    }

    [Theory]
    [InlineData("deleted")]
    [InlineData("otherPatient")]
    public async Task Hidden_visits_are_not_found(string which)
    {
        var id = which == "deleted" ? api.Demo.DeletedSessionId : api.Demo.OtherPatientSessionId;
        var client = await Patient();

        var response = await client.GetAsync($"/api/patient/visits/{id}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<Dictionary<string, object>>();
        Assert.Equal("NOT_FOUND", problem!["code"].ToString());
    }

    [Fact]
    public async Task Prescriptions_are_sent_or_cancelled_only()
    {
        var client = await Patient();
        var all = await client.GetFromJsonAsync<PagedResult<PrescriptionListItemDto>>("/api/patient/prescriptions");

        Assert.All(all!.Items, p => Assert.Contains(p.Status, new[] { "sent", "cancelled" }));
        Assert.DoesNotContain(all.Items, p => p.Id == api.Demo.DraftRxId || p.Id == api.Demo.ReviewRxId);

        var medications = await client.GetFromJsonAsync<PagedResult<PrescriptionListItemDto>>("/api/patient/prescriptions?kind=medication");
        Assert.All(medications!.Items, p => Assert.Equal("medication", p.Kind));
        Assert.Equal(2, medications.TotalCount);

        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/patient/prescriptions/{api.Demo.DraftRxId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/patient/prescriptions/{api.Demo.ReviewRxId}")).StatusCode);
    }

    [Fact]
    public async Task Cancelled_prescription_points_to_its_replacement()
    {
        var client = await Patient();
        var cancelled = await client.GetFromJsonAsync<PrescriptionDetailDto>($"/api/patient/prescriptions/{api.Demo.CancelledRxId}");

        Assert.Equal("cancelled", cancelled!.Status);
        Assert.Equal("تعديل الجرعة", cancelled.CancelReason);
        Assert.Equal(api.Demo.ReplacementRxId, cancelled.ReplacedById);

        var replacement = await client.GetFromJsonAsync<PrescriptionDetailDto>($"/api/patient/prescriptions/{api.Demo.ReplacementRxId}");
        Assert.Equal(api.Demo.CancelledRxId, replacement!.ReplacesId);
        Assert.Equal(["Concor 5 mg", "Panadol"], replacement.Medications.Select(m => m.DrugName));
        Assert.True(replacement.HasPdf);
    }

    [Fact]
    public async Task Prescription_pdf_downloads_without_caching()
    {
        var client = await Patient();
        var response = await client.GetAsync($"/api/patient/prescriptions/{api.Demo.SentRxId}/pdf");

        response.EnsureSuccessStatusCode();
        Assert.Equal("application/pdf", response.Content.Headers.ContentType?.MediaType);
        Assert.Contains("no-store", response.Headers.CacheControl?.ToString());
        Assert.StartsWith("%PDF", System.Text.Encoding.ASCII.GetString(await response.Content.ReadAsByteArrayAsync())[..4]);
    }

    [Fact]
    public async Task Files_exclude_deleted_and_counts_match()
    {
        var client = await Patient();
        var records = await client.GetFromJsonAsync<PagedResult<RecordListItemDto>>("/api/patient/records");
        Assert.DoesNotContain(records!.Items, r => r.Id == api.Demo.DeletedRecordId);
        Assert.Equal(2, records.TotalCount);

        var counts = await client.GetFromJsonAsync<RecordCountsDto>("/api/patient/records/counts");
        Assert.Equal(new RecordCountsDto(0, 1, 0, 1), counts);

        var labs = await client.GetFromJsonAsync<PagedResult<RecordListItemDto>>("/api/patient/records?kind=lab");
        var lab = Assert.Single(labs!.Items);
        Assert.NotNull(lab.Cover);
        Assert.True(lab.Cover.HasThumbnail);

        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/patient/records/{api.Demo.DeletedRecordId}")).StatusCode);
    }

    [Fact]
    public async Task Attachment_and_thumbnail_download()
    {
        var client = await Patient();
        var url = $"/api/patient/records/{api.Demo.VisibleRecordId}/attachments/{api.Demo.VisibleAttachmentId}";

        var file = await client.GetAsync(url);
        file.EnsureSuccessStatusCode();
        Assert.Equal("image/png", file.Content.Headers.ContentType?.MediaType);
        Assert.Equal("nosniff", file.Headers.GetValues("X-Content-Type-Options").Single());

        var thumb = await client.GetAsync(url + "?thumbnail=true");
        thumb.EnsureSuccessStatusCode();
        Assert.Equal("image/jpeg", thumb.Content.Headers.ContentType?.MediaType);

        // The attachment id must belong to the record in the URL.
        var mismatched = await client.GetAsync($"/api/patient/records/{api.Demo.DeletedRecordId}/attachments/{api.Demo.VisibleAttachmentId}");
        Assert.Equal(HttpStatusCode.NotFound, mismatched.StatusCode);
    }

    [Fact]
    public async Task Doctor_info_lists_live_branches_with_price_fallback()
    {
        var client = await Patient();
        var info = await client.GetFromJsonAsync<DoctorInfoDto>($"/api/patient/doctors/{api.Demo.DoctorAUserId}");

        Assert.Equal(2, info!.Branches.Count);                     // the archived branch is hidden
        var main = info.Branches[0];
        Assert.True(main.IsDefault);
        Assert.Equal(35000, main.Prices.ExaminationPiasters);       // the branch's own price
        Assert.Equal(15000, main.Prices.ConsultationPiasters);      // falls back to the doctor's (BR-PR2)
        Assert.Equal(["cash", "instapay"], main.PaymentMethods);
        Assert.Equal(5, main.WorkingHours.Count);
        Assert.Equal("+201011111111", main.Phones[0].Number);
        var closed = info.Branches[1];
        Assert.Equal("temporarilyClosed", closed.Status);
        Assert.NotNull(closed.ClosedMessage);

        var doctorB = await client.GetFromJsonAsync<DoctorInfoDto>($"/api/patient/doctors/{api.Demo.DoctorBUserId}");
        Assert.Null(doctorB!.Branches.Single().Prices.ConsultationPiasters);   // BR-PR6: ask the clinic

        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/patient/doctors/{Guid.NewGuid()}")).StatusCode);
    }

    [Fact]
    public async Task Medical_profile_is_per_doctor()
    {
        var client = await Patient();
        var profile = await client.GetFromJsonAsync<MedicalProfileDto>("/api/patient/medical-profile");

        Assert.Equal("O+", profile!.Personal.BloodType);
        Assert.Equal(2, profile.Doctors.Count);
        var a = profile.Doctors.Single(d => d.Doctor.Id == api.Demo.DoctorAUserId);
        Assert.Equal(["البنسلين"], a.Allergies);
        Assert.Equal("السكر في العائلة", a.FamilyHistory);
        var b = profile.Doctors.Single(d => d.Doctor.Id == api.Demo.DoctorBUserId);
        Assert.Empty(b.Allergies);
        Assert.Single(b.Surgeries);
    }

    [Fact]
    public async Task Home_shows_latest_items_and_follow_up()
    {
        var client = await Patient();
        var home = await client.GetFromJsonAsync<PatientHomeDto>("/api/patient/home");

        Assert.Equal(api.Demo.OtherDoctorSessionId, home!.LatestVisit!.Id);
        Assert.NotNull(home.LatestPrescription);
        Assert.Equal(api.Demo.VisibleSessionId, home.NextFollowUp!.SessionId);
        Assert.Equal(2, home.RecentFiles.Count);

        var onlyB = await client.GetFromJsonAsync<PatientHomeDto>($"/api/patient/home?doctorId={api.Demo.DoctorBUserId}");
        Assert.Equal(api.Demo.OtherDoctorSessionId, onlyB!.LatestVisit!.Id);
        Assert.Null(onlyB.LatestPrescription);
        Assert.Null(onlyB.NextFollowUp);
    }

    [Fact]
    public async Task Timestamps_are_serialized_as_utc()
    {
        var client = await Patient();
        var raw = await client.GetStringAsync("/api/patient/visits");
        Assert.Matches("\"at\":\"\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z\"", raw);
    }

    [Fact]
    public async Task Invalid_filter_is_a_validation_error()
    {
        var client = await Patient();
        var response = await client.GetAsync("/api/patient/records?kind=bogus");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("VALIDATION_FAILED", body);
    }
}
