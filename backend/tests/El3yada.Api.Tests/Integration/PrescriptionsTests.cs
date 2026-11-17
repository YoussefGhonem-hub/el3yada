using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using Microsoft.EntityFrameworkCore;
using SkiaSharp;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// Prescriptions and requests (spec 6.4, D13–D15, AS7, AS8, AC-15): drafts, send with the app's PDF, cancel, new copy,
/// item history, templates, D22 print settings and branding, and the QR link. Contract: api-phase-3-prescriptions.md.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class PrescriptionsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static readonly byte[] Pdf = Encoding.ASCII.GetBytes("%PDF-1.7\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n");

    private static object Medicine(string name = "Panadol", string? strength = "500 mg", string? form = "tablet") => new
    {
        drugName = name, activeIngredient = "paracetamol", catalogId = "drug:123", form, strength, dose = "قرص",
        frequency = "3 مرات يومياً", timing = "afterFood", duration = "5 أيام", instructions = "بعد الأكل",
    };

    private static object Test(string category = "lab", string name = "CBC", string? loinc = "58410-2") =>
        new { category, name, loincCode = loinc, notes = "صائم 12 ساعة" };

    private async Task<(TestUser Doctor, HttpClient Client, Guid PatientId, Guid SessionId)> DoctorWithSessionAsync()
    {
        var (doctor, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var sessionId = await TestData.RecordSessionAsync(client, patientId, branchId);
        await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.Id == sessionId).ExecuteUpdateAsync(set => set
            .SetProperty(s => s.Diagnosis, "التهاب الحلق")
            .SetProperty(s => s.FollowUpDate, new DateOnly(2026, 12, 1))));
        return (doctor, client, patientId, sessionId);
    }

    private static async Task<Guid> DraftAsync(HttpClient client, Guid sessionId, string kind = "medication", object[]? items = null)
    {
        var (status, draft) = await client.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId, kind });
        Assert.True(status == HttpStatusCode.Created, $"createPrescriptionDraft failed: {status} {draft}");
        var id = draft.GetProperty("prescriptionId").GetGuid();
        if (items is not null)
        {
            var (updateStatus, body) = await client.PostAsync("/api/prescriptions/updatePrescriptionDraft", new
            {
                prescriptionId = id, diagnosis = draft.GetProperty("diagnosis").GetString(), advice = "راحة تامة",
                followUpDate = "2026-12-01", items,
            });
            Assert.True(updateStatus == HttpStatusCode.OK, $"updatePrescriptionDraft failed: {updateStatus} {body}");
        }

        return id;
    }

    private static async Task<(HttpStatusCode Status, JsonElement Body)> SendAsync(HttpClient client, Guid? prescriptionId, byte[]? pdf = null)
    {
        using var form = new MultipartFormDataContent();
        if (prescriptionId is not null)
        {
            form.Add(new StringContent(JsonSerializer.Serialize(new { prescriptionId }), Encoding.UTF8, "application/json"), "data");
        }

        if (pdf is not null)
        {
            var part = new ByteArrayContent(pdf);
            part.Headers.ContentType = new MediaTypeHeaderValue("application/pdf");
            form.Add(part, "pdf", "rx.pdf");
        }

        using var response = await client.PostAsync("/api/prescriptions/sendPrescription", form);
        return (response.StatusCode, await Http.BodyAsync(response));
    }

    [Fact]
    public async Task A_prescription_goes_from_draft_to_sent_to_cancelled_and_a_new_copy()
    {
        var (doctor, client, patientId, sessionId) = await DoctorWithSessionAsync();

        var (createStatus, draft) = await client.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId, kind = "medication" });
        Assert.Equal(HttpStatusCode.Created, createStatus);
        Assert.Equal("draft", draft.Str("status"));
        Assert.Equal("التهاب الحلق", draft.Str("diagnosis"));
        Assert.Equal("2026-12-01", draft.Str("followUpDate"));
        Assert.Equal(12, draft.Str("qrShortCode").Length);
        Assert.EndsWith($"/rx/{draft.Str("qrShortCode")}", draft.Str("qrUrl"));
        Assert.False(draft.GetProperty("hasPdf").GetBoolean());
        Assert.Equal("doctor", draft.GetProperty("preparedBy").Str("role"));
        var id = draft.GetProperty("prescriptionId").GetGuid();

        // Reordering is the order of the list.
        var (updateStatus, updated) = await client.PostAsync("/api/prescriptions/updatePrescriptionDraft", new
        {
            prescriptionId = id, diagnosis = "  التهاب الحلق\n", advice = "راحة", followUpDate = (string?)null,
            items = new[] { Medicine("Augmentin", "1 g"), Medicine("Panadol") },
        });
        Assert.Equal(HttpStatusCode.OK, updateStatus);
        Assert.Equal(["Augmentin", "Panadol"], updated.GetProperty("items").EnumerateArray().Select(i => i.Str("drugName")));
        Assert.Equal(JsonValueKind.Null, updated.GetProperty("followUpDate").ValueKind);

        var (sendStatus, sent) = await SendAsync(client, id, Pdf);
        Assert.Equal(HttpStatusCode.OK, sendStatus);
        Assert.Equal("sent", sent.Str("status"));
        Assert.True(sent.GetProperty("hasPdf").GetBoolean());
        using (var pdf = await client.GetAsync($"/api/prescriptions/{id}/pdf"))
        {
            Assert.Equal(HttpStatusCode.OK, pdf.StatusCode);
            Assert.Equal("application/pdf", pdf.Content.Headers.ContentType?.MediaType);
            Assert.Equal(Pdf, await pdf.Content.ReadAsByteArrayAsync());
        }

        var patientUserId = await TestData.WithDbAsync(Factory, db => db.Patients.Where(p => p.Id == patientId).Select(p => p.UserId).SingleAsync());
        var notification = await TestData.WithDbAsync(Factory, db => db.Notifications.SingleAsync(n => n.RecipientUserId == patientUserId && n.Type == "prescriptionSent"));
        Assert.Contains("روشتة علاج جديدة من د. أحمد علي", notification.BodyAr);
        Assert.DoesNotContain("الحلق", notification.BodyAr);
        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, "prescriptionSent"));
        Assert.DoesNotContain("Augmentin", audit.DetailsJson);
        Assert.DoesNotContain("الحلق", audit.DetailsJson);

        // Sent documents are read-only (BR-RX2).
        var (againStatus, again) = await SendAsync(client, id, Pdf);
        var (editStatus, edit) = await client.PostAsync("/api/prescriptions/updatePrescriptionDraft", new { prescriptionId = id, items = Array.Empty<object>() });
        Assert.Equal(HttpStatusCode.Conflict, againStatus);
        Assert.Equal(ErrorCodes.PrescriptionNotEditable, again.Code());
        Assert.Equal(HttpStatusCode.Conflict, editStatus);
        Assert.Equal("sent", edit.Str("status"));

        var (shortStatus, shortReason) = await client.PostAsync("/api/prescriptions/cancelPrescription", new { prescriptionId = id, reason = "x" });
        var (cancelStatus, cancelled) = await client.PostAsync("/api/prescriptions/cancelPrescription", new { prescriptionId = id, reason = "  جرعة   خطأ " });
        var (cancelAgain, cancelAgainBody) = await client.PostAsync("/api/prescriptions/cancelPrescription", new { prescriptionId = id, reason = "مرة أخرى" });
        Assert.Equal(HttpStatusCode.BadRequest, shortStatus);
        Assert.Equal(ErrorCodes.ReasonRequired, shortReason.FieldCode("reason"));
        Assert.Equal(HttpStatusCode.OK, cancelStatus);
        Assert.Equal("cancelled", cancelled.Str("status"));
        Assert.Equal("جرعة خطأ", cancelled.Str("cancelReason"));
        Assert.Equal(HttpStatusCode.Conflict, cancelAgain);
        Assert.Equal(ErrorCodes.PrescriptionNotSent, cancelAgainBody.Code());
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(n => n.RecipientUserId == patientUserId && n.Type == "prescriptionCancelled")));

        // Issue new copy (D15): the same content, pointing at the cancelled one.
        var (copyStatus, copy) = await client.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId, kind = "medication", copyFromId = id });
        Assert.Equal(HttpStatusCode.Created, copyStatus);
        Assert.Equal(id, copy.GetProperty("replacesRxId").GetGuid());
        Assert.Equal("التهاب الحلق", copy.Str("diagnosis"));
        Assert.Equal(["Augmentin", "Panadol"], copy.GetProperty("items").EnumerateArray().Select(i => i.Str("drugName")));
        Assert.NotEqual(cancelled.Str("qrShortCode"), copy.Str("qrShortCode"));
        var (_, original) = await client.GetJsonAsync($"/api/prescriptions/{id}");
        Assert.Equal(copy.GetProperty("prescriptionId").GetGuid(), original.GetProperty("replacedById").GetGuid());
        var (wrongKind, wrongKindBody) = await client.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId, kind = "investigations", copyFromId = id });
        Assert.Equal(HttpStatusCode.BadRequest, wrongKind);
        Assert.Equal(ErrorCodes.InvalidCopySource, wrongKindBody.FieldCode("copyFromId"));

        // D9 and D6 lists.
        var (_, forSession) = await client.GetJsonAsync($"/api/sessions/{sessionId}/prescriptions");
        var (_, forPatient) = await client.GetJsonAsync($"/api/patients/{patientId}/prescriptions?kind=medication");
        Assert.Equal(2, forSession.GetArrayLength());
        Assert.Equal(2, forPatient.GetProperty("totalCount").GetInt32());
        Assert.Equal(copy.GetProperty("prescriptionId").GetGuid(), forPatient.GetProperty("items")[0].GetProperty("prescriptionId").GetGuid());
    }

    [Fact]
    public async Task Items_are_checked_by_kind()
    {
        var (_, client, _, sessionId) = await DoctorWithSessionAsync();
        var medication = await DraftAsync(client, sessionId);
        var investigations = await DraftAsync(client, sessionId, "investigations");

        async Task<JsonElement> Bad(Guid id, object[] items, string? diagnosis = null)
        {
            var (status, problem) = await client.PostAsync("/api/prescriptions/updatePrescriptionDraft", new { prescriptionId = id, diagnosis, items });
            Assert.Equal(HttpStatusCode.BadRequest, status);
            return problem;
        }

        Assert.Equal(ErrorCodes.Required, (await Bad(medication, [new { drugName = " ", form = "tablet" }])).FieldCode("items[0].drugName"));
        Assert.Equal(ErrorCodes.InvalidValue, (await Bad(medication, [new { drugName = "Panadol", category = "lab" }])).FieldCode("items[0].category"));
        Assert.Equal(ErrorCodes.InvalidValue, (await Bad(medication, [new { drugName = "Panadol", timing = "atNight" }])).FieldCode("items[0].timing"));
        Assert.Equal(ErrorCodes.TooLong, (await Bad(medication, [new { drugName = "Panadol", dose = new string('x', 61) }])).FieldCode("items[0].dose"));
        Assert.Equal(ErrorCodes.TooMany, (await Bad(medication, Enumerable.Range(0, 31).Select(_ => Medicine()).ToArray())).FieldCode("items"));
        Assert.Equal(ErrorCodes.TooLong, (await Bad(medication, [], new string('x', 1001))).FieldCode("diagnosis"));
        Assert.Equal(ErrorCodes.Required, (await Bad(investigations, [new { category = "lab" }])).FieldCode("items[0].name"));
        Assert.Equal(ErrorCodes.InvalidValue, (await Bad(investigations, [new { category = "pathology", name = "Biopsy" }])).FieldCode("items[0].category"));
        Assert.Equal(ErrorCodes.InvalidValue, (await Bad(investigations, [new { category = "lab", name = "CBC", drugName = "x" }])).FieldCode("items[0].drugName"));

        var (okStatus, ok) = await client.PostAsync("/api/prescriptions/updatePrescriptionDraft", new
        {
            prescriptionId = investigations, items = new[] { Test(), Test("radiology", "Chest X-ray", null) },
        });
        Assert.Equal(HttpStatusCode.OK, okStatus);
        Assert.Equal("radiology", ok.GetProperty("items")[1].Str("category"));

        var (sessionStatus, sessionProblem) = await client.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId = Guid.NewGuid(), kind = "medication" });
        Assert.Equal(HttpStatusCode.BadRequest, sessionStatus);
        Assert.Equal(ErrorCodes.InvalidSession, sessionProblem.FieldCode("sessionId"));
    }

    [Fact]
    public async Task Sending_needs_items_and_a_real_pdf_of_at_most_10_mb()
    {
        var (_, client, _, sessionId) = await DoctorWithSessionAsync();
        var empty = await DraftAsync(client, sessionId);
        var full = await DraftAsync(client, sessionId, items: [Medicine()]);

        var (emptyStatus, emptyBody) = await SendAsync(client, empty, Pdf);
        var (noPdf, noPdfBody) = await SendAsync(client, full);
        var (notPdf, notPdfBody) = await SendAsync(client, full, Encoding.ASCII.GetBytes("this is not a pdf"));
        var big = new byte[(10 * 1024 * 1024) + 1];
        Pdf.CopyTo(big, 0);
        var (bigStatus, bigBody) = await SendAsync(client, full, big);
        var (noData, noDataBody) = await SendAsync(client, null, Pdf);

        Assert.Equal(HttpStatusCode.Conflict, emptyStatus);
        Assert.Equal(ErrorCodes.PrescriptionEmpty, emptyBody.Code());
        Assert.Equal(ErrorCodes.Required, noPdfBody.FieldCode("pdf"));
        Assert.Equal(ErrorCodes.FileTypeNotAllowed, notPdfBody.FieldCode("pdf"));
        Assert.True(bigStatus is HttpStatusCode.BadRequest or HttpStatusCode.RequestEntityTooLarge, $"{bigStatus} {bigBody}");
        Assert.Equal(ErrorCodes.Required, noDataBody.FieldCode("data.prescriptionId"));
        Assert.Equal(HttpStatusCode.BadRequest, noPdf);
        Assert.Equal(HttpStatusCode.BadRequest, notPdf);
        Assert.Equal("draft", await TestData.WithDbAsync(Factory, db => db.Prescriptions.Where(p => p.Id == full).Select(p => p.Status).SingleAsync()));
    }

    [Fact]
    public async Task Sending_counts_each_item_in_the_doctors_history()
    {
        var (doctor, client, _, sessionId) = await DoctorWithSessionAsync();
        var first = await DraftAsync(client, sessionId, items: [Medicine("Panadol"), Medicine("Augmentin", "1 g")]);
        var second = await DraftAsync(client, sessionId, items: [Medicine("PANADOL"), Medicine("Panadol", "1 g")]);
        var tests = await DraftAsync(client, sessionId, "investigations", [Test(), Test("radiology", "Chest X-ray", "36643-5")]);
        await SendAsync(client, first, Pdf);
        await SendAsync(client, second, Pdf);
        await SendAsync(client, tests, Pdf);

        var (status, history) = await client.GetJsonAsync("/api/prescriptions/itemHistory");

        Assert.Equal(HttpStatusCode.OK, status);
        var items = history.EnumerateArray().ToList();
        var top = items[0];
        Assert.Equal("Panadol", top.Str("name"));
        Assert.Equal("500 mg", top.Str("strength"));
        Assert.Equal(2, top.GetProperty("useCount").GetInt32());
        Assert.Equal("drug:123", top.Str("catalogId"));
        Assert.Contains(items, i => i.Str("kind") == "drug" && i.Str("strength") == "1 g" && i.Str("name") == "Panadol");
        Assert.Contains(items, i => i.Str("kind") == "lab" && i.Str("name") == "CBC" && i.Str("catalogId") == "58410-2");
        Assert.Contains(items, i => i.Str("kind") == "radiology" && i.Str("name") == "Chest X-ray");
        Assert.Equal(5, items.Count);

        var id = top.GetProperty("itemId").GetGuid();
        var (deleteStatus, _) = await client.PostAsync("/api/prescriptions/deleteHistoryItem", new { itemId = id });
        var (againStatus, _) = await client.PostAsync("/api/prescriptions/deleteHistoryItem", new { itemId = id });
        Assert.Equal(HttpStatusCode.NoContent, deleteStatus);
        Assert.Equal(HttpStatusCode.NotFound, againStatus);
        Assert.Equal(4, await TestData.WithDbAsync(Factory, db => db.DoctorItemHistories.CountAsync(h => h.DoctorId == doctor.Id)));
    }

    [Fact]
    public async Task Assistants_draft_or_print_by_permission_and_never_send()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        var branchId = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var patientId = await TestData.AddPatientViaApiAsync(asDoctor);
        var sessionId = await TestData.RecordSessionAsync(asDoctor, patientId, branchId);
        var clinical = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: AssistantPresets.Permissions[AssistantPresets.Clinical], name: "منى السيد");
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        var none = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.PatientsManage]);
        using var asClinical = await Factory.SignedInClientAsync(clinical);
        using var asReception = await Factory.SignedInClientAsync(reception);
        using var asNone = await Factory.SignedInClientAsync(none);

        // AS7: the clinical assistant prepares a draft and sends it for review.
        var draft = await DraftAsync(asClinical, sessionId, items: [Medicine()]);
        var (_, view) = await asClinical.GetJsonAsync($"/api/prescriptions/{draft}");
        Assert.Equal("assistant", view.GetProperty("preparedBy").Str("role"));
        Assert.Equal("منى السيد", view.GetProperty("preparedBy").Str("name"));
        var (submitStatus, submitted) = await asClinical.PostAsync("/api/prescriptions/submitDraftForReview", new { prescriptionId = draft });
        Assert.Equal(HttpStatusCode.OK, submitStatus);
        Assert.Equal("readyForReview", submitted.Str("status"));
        var notice = await TestData.WithDbAsync(Factory, db => db.Notifications.SingleAsync(n => n.RecipientUserId == doctor.Id && n.Type == "prescriptionReadyForReview"));
        Assert.Contains("منى حسن", notice.BodyAr);
        var (sendStatus, send) = await SendAsync(asClinical, draft, Pdf);
        Assert.Equal(HttpStatusCode.Forbidden, sendStatus);
        Assert.Equal("doctorOnly", send.Str("permission"));
        var (doctorSubmit, doctorSubmitBody) = await asDoctor.PostAsync("/api/prescriptions/submitDraftForReview", new { prescriptionId = draft });
        Assert.Equal(HttpStatusCode.Forbidden, doctorSubmit);
        Assert.Equal("assistantOnly", doctorSubmitBody.Str("permission"));

        // The doctor reviews and sends it; a second draft stays a draft.
        Assert.Equal(HttpStatusCode.OK, (await SendAsync(asDoctor, draft, Pdf)).Status);
        var other = await DraftAsync(asDoctor, sessionId, items: [Medicine()]);

        // AS8: reception (prescriptionsPrint, no clinicalView) sees sent documents only.
        var (receptionList, list) = await asReception.GetJsonAsync($"/api/patients/{patientId}/prescriptions");
        var (receptionDraft, _) = await asReception.GetJsonAsync($"/api/prescriptions/{other}");
        using var receptionPdf = await asReception.GetAsync($"/api/prescriptions/{draft}/pdf");
        var (receptionCreate, receptionCreateBody) = await asReception.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId, kind = "medication" });
        var (receptionHistory, _) = await asReception.GetJsonAsync("/api/prescriptions/itemHistory");
        Assert.Equal(HttpStatusCode.OK, receptionList);
        Assert.Equal([draft], list.GetProperty("items").EnumerateArray().Select(p => p.GetProperty("prescriptionId").GetGuid()));
        Assert.Equal(HttpStatusCode.NotFound, receptionDraft);
        Assert.Equal(HttpStatusCode.OK, receptionPdf.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, receptionCreate);
        Assert.Equal(ClinicPermissions.PrescriptionsDraft, receptionCreateBody.Str("permission"));
        Assert.Equal(HttpStatusCode.Forbidden, receptionHistory);

        // The clinical assistant (clinicalView) sees every status, but never cancels.
        var (_, clinicalList) = await asClinical.GetJsonAsync($"/api/sessions/{sessionId}/prescriptions");
        Assert.Equal(2, clinicalList.GetArrayLength());
        var (clinicalCancel, _) = await asClinical.PostAsync("/api/prescriptions/cancelPrescription", new { prescriptionId = draft, reason = "خطأ في الجرعة" });
        Assert.Equal(HttpStatusCode.Forbidden, clinicalCancel);

        var (noneList, noneBody) = await asNone.GetJsonAsync($"/api/patients/{patientId}/prescriptions");
        Assert.Equal(HttpStatusCode.Forbidden, noneList);
        Assert.Equal(ClinicPermissions.PrescriptionsPrint, noneBody.Str("permission"));
    }

    [Fact]
    public async Task Other_clinics_patients_and_admins_are_kept_out_and_a_suspended_doctor_reads_only()
    {
        var (doctor, client, patientId, sessionId) = await DoctorWithSessionAsync();
        var id = await DraftAsync(client, sessionId, items: [Medicine()]);
        await SendAsync(client, id, Pdf);
        var (_, other, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        var admin = await TestData.CreateAdminAsync(Factory);
        using var asPatient = await Factory.SignedInClientAsync(patient);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var (otherGet, _) = await other.GetJsonAsync($"/api/prescriptions/{id}");
        using var otherPdf = await other.GetAsync($"/api/prescriptions/{id}/pdf");
        var (otherDraft, otherDraftBody) = await other.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId, kind = "medication" });
        var (otherList, _) = await other.GetJsonAsync($"/api/patients/{patientId}/prescriptions");
        var (patientGet, patientBody) = await asPatient.GetJsonAsync($"/api/prescriptions/{id}");
        var (adminGet, adminBody) = await asAdmin.GetJsonAsync($"/api/prescriptions/{id}");
        Assert.Equal(HttpStatusCode.NotFound, otherGet);
        Assert.Equal(HttpStatusCode.NotFound, otherPdf.StatusCode);
        Assert.Equal(ErrorCodes.InvalidSession, otherDraftBody.FieldCode("sessionId"));
        Assert.Equal(HttpStatusCode.BadRequest, otherDraft);
        Assert.Equal(HttpStatusCode.NotFound, otherList);
        Assert.Equal(HttpStatusCode.Forbidden, patientGet);
        Assert.Equal(ErrorCodes.Forbidden, patientBody.Code());
        Assert.Equal(HttpStatusCode.Forbidden, adminGet);
        Assert.Equal(ErrorCodes.Forbidden, adminBody.Code());

        await TestData.SetDoctorStatusAsync(Factory, doctor.Id, DoctorStatuses.Suspended);
        var (suspendedDraft, suspendedBody) = await client.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId, kind = "medication" });
        var (suspendedRead, _) = await client.GetJsonAsync($"/api/prescriptions/{id}");
        var (suspendedCancel, _) = await client.PostAsync("/api/prescriptions/cancelPrescription", new { prescriptionId = id, reason = "تصحيح الجرعة" });
        Assert.Equal(HttpStatusCode.Forbidden, suspendedDraft);
        Assert.Equal(ErrorCodes.DoctorSuspended, suspendedBody.Code());
        Assert.Equal(HttpStatusCode.OK, suspendedRead);
        Assert.Equal(HttpStatusCode.OK, suspendedCancel);
    }

    [Fact]
    public async Task Drafts_can_be_discarded_but_sent_documents_cannot()
    {
        var (_, client, _, sessionId) = await DoctorWithSessionAsync();
        var draft = await DraftAsync(client, sessionId, items: [Medicine()]);
        var sent = await DraftAsync(client, sessionId, items: [Medicine()]);
        await SendAsync(client, sent, Pdf);

        var (deleteStatus, _) = await client.PostAsync("/api/prescriptions/deletePrescriptionDraft", new { prescriptionId = draft });
        var (sentStatus, sentBody) = await client.PostAsync("/api/prescriptions/deletePrescriptionDraft", new { prescriptionId = sent });

        Assert.Equal(HttpStatusCode.NoContent, deleteStatus);
        Assert.False(await TestData.WithDbAsync(Factory, db => db.Prescriptions.AnyAsync(p => p.Id == draft)));
        Assert.False(await TestData.WithDbAsync(Factory, db => db.PrescriptionMedicationItems.AnyAsync(i => i.PrescriptionId == draft)));
        Assert.Equal(HttpStatusCode.Conflict, sentStatus);
        Assert.Equal(ErrorCodes.PrescriptionNotEditable, sentBody.Code());
    }

    [Fact]
    public async Task Templates_are_the_doctors_own()
    {
        var (_, client, _, _) = await DoctorWithSessionAsync();
        var (_, other, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);

        var (createStatus, template) = await client.PostAsync("/api/prescriptionTemplates/createTemplate", new
        {
            name = "  نزلة   برد ", kind = "medication", items = new[] { Medicine(), Medicine("Augmentin", "1 g") }, advice = "سوائل دافئة",
        });
        var (badStatus, bad) = await client.PostAsync("/api/prescriptionTemplates/createTemplate", new { name = "x", kind = "investigations", items = new[] { new { drugName = "Panadol" } } });
        var (emptyStatus, empty) = await client.PostAsync("/api/prescriptionTemplates/createTemplate", new { name = "x", kind = "medication", items = Array.Empty<object>() });
        Assert.Equal(HttpStatusCode.Created, createStatus);
        Assert.Equal("نزلة برد", template.Str("name"));
        Assert.Equal(2, template.GetProperty("items").GetArrayLength());
        Assert.Equal("Augmentin", template.GetProperty("items")[1].Str("drugName"));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.Required, bad.FieldCode("items[0].category"));
        Assert.Equal(ErrorCodes.Required, empty.FieldCode("items"));
        var templateId = template.GetProperty("templateId").GetGuid();

        var (updateStatus, updated) = await client.PostAsync("/api/prescriptionTemplates/updateTemplate", new { templateId, name = "برد", items = new[] { Medicine() } });
        var (otherUpdate, _) = await other.PostAsync("/api/prescriptionTemplates/updateTemplate", new { templateId, name = "x", items = new[] { Medicine() } });
        var (_, list) = await client.GetJsonAsync("/api/prescriptionTemplates?kind=medication");
        var (_, otherList) = await other.GetJsonAsync("/api/prescriptionTemplates");
        Assert.Equal(HttpStatusCode.OK, updateStatus);
        Assert.Equal(1, updated.GetProperty("items").GetArrayLength());
        Assert.Equal(JsonValueKind.Null, updated.GetProperty("advice").ValueKind);
        Assert.Equal(HttpStatusCode.NotFound, otherUpdate);
        Assert.Equal(1, list.GetArrayLength());
        Assert.Equal(0, otherList.GetArrayLength());

        var (deleteStatus, _) = await client.PostAsync("/api/prescriptionTemplates/deleteTemplate", new { templateId });
        Assert.Equal(HttpStatusCode.NoContent, deleteStatus);
    }

    [Fact]
    public async Task Print_settings_have_brand_defaults_and_checked_ranges()
    {
        var (doctor, client, _, _) = await DoctorWithSessionAsync();

        var (_, defaults) = await client.GetJsonAsync("/api/doctor/rxSettings");
        Assert.Equal("ar", defaults.Str("language"));
        Assert.Equal("#0F4C45", defaults.Str("accentColor"));
        Assert.Equal("A5", defaults.Str("paperSize"));
        Assert.False(defaults.GetProperty("preprinted").GetBoolean());
        Assert.False(defaults.GetProperty("hasLogo").GetBoolean());

        var (customStatus, custom) = await client.PostAsync("/api/doctor/updateRxSettings", new
        {
            language = "en", accentColor = "#a1b2c3", paperSize = "custom", customWidthMm = 160.25m, customHeightMm = 220m,
            preprinted = true, marginTopMm = 35m, marginBottomMm = 20m, footerText = "  مواعيد العيادة يومياً ",
        });
        Assert.Equal(HttpStatusCode.OK, customStatus);
        Assert.Equal("#A1B2C3", custom.Str("accentColor"));
        Assert.Equal(160.3m, custom.GetProperty("customWidthMm").GetDecimal());
        Assert.Equal("مواعيد العيادة يومياً", custom.Str("footerText"));
        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, "rxSettingsUpdated"));
        Assert.Contains("paperSize", audit.DetailsJson);

        var (a4Status, a4) = await client.PostAsync("/api/doctor/updateRxSettings", new
        {
            language = "ar", accentColor = "#0F4C45", paperSize = "A4", customWidthMm = 160m, customHeightMm = 220m, preprinted = false,
        });
        Assert.Equal(HttpStatusCode.OK, a4Status);
        Assert.Equal(JsonValueKind.Null, a4.GetProperty("customWidthMm").ValueKind);

        async Task<JsonElement> Bad(object body)
        {
            var (status, problem) = await client.PostAsync("/api/doctor/updateRxSettings", body);
            Assert.Equal(HttpStatusCode.BadRequest, status);
            return problem;
        }

        Assert.Equal(ErrorCodes.Required, (await Bad(new { language = "ar", accentColor = "#0F4C45", paperSize = "custom", customHeightMm = 200m, preprinted = false })).FieldCode("customWidthMm"));
        Assert.Equal(ErrorCodes.OutOfRange, (await Bad(new { language = "ar", accentColor = "#0F4C45", paperSize = "custom", customWidthMm = 80m, customHeightMm = 200m, preprinted = false })).FieldCode("customWidthMm"));
        Assert.Equal(ErrorCodes.InvalidValue, (await Bad(new { language = "ar", accentColor = "green", paperSize = "A5", preprinted = false })).FieldCode("accentColor"));
        Assert.Equal(ErrorCodes.OutOfRange, (await Bad(new { language = "ar", accentColor = "#0F4C45", paperSize = "A5", preprinted = true, marginTopMm = 101m })).FieldCode("marginTopMm"));
        Assert.Equal(ErrorCodes.InvalidValue, (await Bad(new { language = "fr", accentColor = "#0F4C45", paperSize = "A5", preprinted = false })).FieldCode("language"));
    }

    [Fact]
    public async Task Logo_and_signature_are_stored_as_small_pngs()
    {
        var (doctor, client, _, _) = await DoctorWithSessionAsync();
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Clinical);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);

        async Task<(HttpStatusCode, JsonElement)> Upload(HttpClient c, string kind, byte[] bytes)
        {
            using var form = new MultipartFormDataContent { { new StringContent(kind), "kind" } };
            form.Add(new ByteArrayContent(bytes), "file", "image");
            using var response = await c.PostAsync("/api/doctor/uploadRxImage", form);
            return (response.StatusCode, await Http.BodyAsync(response));
        }

        var (logoStatus, logo) = await Upload(client, "logo", TestImages.Encode(3000, 1500, SKEncodedImageFormat.Jpeg));
        var (signatureStatus, _) = await Upload(client, "signature", TestImages.Encode(400, 120, SKEncodedImageFormat.Png, transparent: true));
        var (textStatus, text) = await Upload(client, "logo", Encoding.ASCII.GetBytes("not an image"));
        var (kindStatus, kind) = await Upload(client, "stamp", TestImages.Encode(10, 10, SKEncodedImageFormat.Png));
        var (assistantStatus, _) = await Upload(asAssistant, "logo", TestImages.Encode(10, 10, SKEncodedImageFormat.Png));

        Assert.Equal(HttpStatusCode.OK, logoStatus);
        Assert.True(logo.GetProperty("hasLogo").GetBoolean());
        Assert.Equal(HttpStatusCode.OK, signatureStatus);
        Assert.Equal(ErrorCodes.FileTypeNotAllowed, text.FieldCode("file"));
        Assert.Equal(HttpStatusCode.BadRequest, textStatus);
        Assert.Equal(ErrorCodes.InvalidValue, kind.FieldCode("kind"));
        Assert.Equal(HttpStatusCode.BadRequest, kindStatus);
        Assert.Equal(HttpStatusCode.Forbidden, assistantStatus);

        using (var stored = await client.GetAsync("/api/doctor/rxImage/logo"))
        {
            Assert.Equal("image/png", stored.Content.Headers.ContentType?.MediaType);
            using var bitmap = SKBitmap.Decode(await stored.Content.ReadAsByteArrayAsync());
            Assert.Equal(1000, bitmap.Width);
            Assert.Equal(500, bitmap.Height);
        }

        using (var signature = await client.GetAsync("/api/doctor/rxImage/signature"))
        {
            using var bitmap = SKBitmap.Decode(await signature.Content.ReadAsByteArrayAsync());
            Assert.Equal(0, bitmap.GetPixel(5, 5).Alpha); // transparency kept
        }

        var path = await TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctor.Id).Select(d => d.RxLogoPath).SingleAsync());
        Assert.Equal($"doctors/{doctor.Id}/branding/logo.png", path);
        var (deleteStatus, deleted) = await client.PostAsync("/api/doctor/deleteRxImage", new { kind = "logo" });
        Assert.Equal(HttpStatusCode.OK, deleteStatus);
        Assert.False(deleted.GetProperty("hasLogo").GetBoolean());
        Assert.False(File.Exists(Path.Combine(Factory.FilesDirectory, path!)));
        using var gone = await client.GetAsync("/api/doctor/rxImage/logo");
        Assert.Equal(HttpStatusCode.NotFound, gone.StatusCode);
    }

    [Fact]
    public async Task The_qr_link_sends_everyone_to_the_store_and_reveals_nothing()
    {
        var (_, client, _, sessionId) = await DoctorWithSessionAsync();
        var (_, draft) = await client.PostAsync("/api/prescriptions/createPrescriptionDraft", new { sessionId, kind = "medication" });
        var code = draft.Str("qrShortCode");
        using var anonymous = Factory.CreateClient(new Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

        async Task<string> Location(string path, string agent)
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, path);
            request.Headers.UserAgent.ParseAdd(agent);
            using var response = await anonymous.SendAsync(request);
            Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
            return response.Headers.Location!.ToString();
        }

        const string android = "Mozilla/5.0 (Linux; Android 14; Pixel 7) Chrome/120.0 Mobile";
        const string iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Safari/604.1";
        const string desktop = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0";
        Assert.StartsWith("https://play.google.com/", await Location($"/rx/{code}", android));
        Assert.StartsWith("https://apps.apple.com/", await Location($"/rx/{code}", iphone));
        Assert.Equal(await Location($"/rx/{code}", desktop), await Location("/rx/doesNotExist12", desktop));
        Assert.Equal(await Location($"/rx/{code}", android), await Location("/rx/zzzzzzzzzzzz", android));

        using var assetLinks = await anonymous.GetAsync("/.well-known/assetlinks.json");
        using var apple = await anonymous.GetAsync("/.well-known/apple-app-site-association");
        Assert.Equal(HttpStatusCode.OK, assetLinks.StatusCode);
        Assert.Equal(JsonValueKind.Array, (await Http.BodyAsync(assetLinks)).ValueKind);
        Assert.Equal("application/json", apple.Content.Headers.ContentType?.MediaType);
        Assert.True((await Http.BodyAsync(apple)).GetProperty("applinks").TryGetProperty("details", out _));
    }
}
