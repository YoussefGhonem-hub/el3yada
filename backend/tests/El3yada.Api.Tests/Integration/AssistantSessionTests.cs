using System.Net;
using El3yada.Api.Clinic;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>AC-19, the parts about patients and sessions (BR-AS4–AS7, AS3–AS5).</summary>
[Collection(IntegrationCollection.Name)]
public sealed class AssistantSessionTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task Reception_adds_a_patient_and_records_an_examination_but_sees_no_diagnosis_or_notes_and_no_private_notes()
    {
        var (doctor, doctorClient, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        using var client = await Factory.SignedInClientAsync(reception);

        var (createdStatus, created) = await client.PostAsync("/api/patients/createPatient", TestData.PatientBody(TestData.Mobile()));
        Assert.Equal(HttpStatusCode.Created, createdStatus);
        Assert.Equal(8, created.Str("temporaryPassword").Length);
        var patientId = Guid.Parse(created.StrAt("patient.patientId")!);

        var (status, session) = await client.PostAsync("/api/sessions/createSession", new
        {
            patientId, branchId, type = "examination", chiefComplaint = "ألم في الظهر",
            vitals = new { bpSys = 130, bpDia = 85, weightKg = 82 }, amountChargedPiasters = 25_000, paymentMethod = "cash",
        });
        Assert.Equal(HttpStatusCode.Created, status);
        Assert.True(session.BoolAt("awaitingDoctor"));
        Assert.Equal("assistant", session.StrAt("recordedBy.role"));
        Assert.True(session.IsNullAt("clinical"));
        Assert.Equal(25_000, session.IntAt("amountChargedPiasters"));
        var sessionId = Guid.Parse(session.Str("sessionId"));
        var stored = await TestData.WithDbAsync(Factory, db => db.Sessions.SingleAsync(s => s.Id == sessionId));
        Assert.Equal("ألم في الظهر", stored.ChiefComplaint);
        Assert.Equal((short)130, stored.BpSys);
        Assert.Equal(reception.Id, stored.CreatedBy);

        await doctorClient.PostAsync("/api/sessions/updateClinical", new
        {
            sessionId, chiefComplaint = "ألم في الظهر", diagnosis = "انزلاق غضروفي", patientNotes = "راحة أسبوع",
        });
        await doctorClient.PostAsync("/api/sessions/setPrivateNote", new { sessionId, text = "متابعة نفسية" });

        var (_, detail) = await client.GetJsonAsync($"/api/sessions/{sessionId}");
        var (_, list) = await client.GetJsonAsync($"/api/patients/{patientId}/sessions");
        var (noteStatus, note) = await client.GetJsonAsync($"/api/sessions/{sessionId}/privateNote");
        var (profileStatus, profile) = await client.GetJsonAsync($"/api/patients/{patientId}/medicalProfile");

        Assert.True(detail.IsNullAt("clinical"));
        Assert.DoesNotContain("انزلاق", detail.ToString());
        Assert.DoesNotContain("راحة", detail.ToString());
        var row = Assert.Single(list.Items());
        Assert.True(row.IsNullAt("diagnosis"));
        Assert.True(row.IsNullAt("chiefComplaint"));
        Assert.Equal(HttpStatusCode.Forbidden, noteStatus);
        Assert.Equal("doctorOnly", note.Str("permission"));
        Assert.Equal(HttpStatusCode.Forbidden, profileStatus);
        Assert.Equal(ClinicPermissions.ClinicalView, profile.Str("permission"));
    }

    [Fact]
    public async Task An_assistant_may_not_send_the_doctors_clinical_fields()
    {
        var scene = await PatientScene.CreateAsync(Factory);
        var clinical = await TestData.CreateAssistantWithPresetAsync(Factory, scene.Doctor.Id, AssistantPresets.Clinical);
        using var client = await Factory.SignedInClientAsync(clinical);

        var (status, problem) = await client.PostAsync("/api/sessions/createSession", new
        {
            patientId = scene.PatientId, branchId = scene.BranchId, type = "examination", amountChargedPiasters = 0,
            diagnosis = "x", privateNote = "y",
        });
        var (editStatus, edit) = await client.PostAsync("/api/sessions/updateClinical", new { sessionId = scene.SessionId, diagnosis = "x" });

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(ErrorCodes.PermissionDenied, problem.Code());
        Assert.Equal("doctorOnly", problem.Str("permission"));
        Assert.Equal(["diagnosis", "privateNote"], problem.Items("fields").Select(f => f.GetString()));
        Assert.Equal(HttpStatusCode.Forbidden, editStatus);
        Assert.Equal("doctorOnly", edit.Str("permission"));
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Sessions.CountAsync(s => s.PatientId == scene.PatientId)));
    }

    [Fact]
    public async Task Assistant_sessions_count_in_the_doctors_totals_show_who_recorded_them_and_wait_for_the_doctor()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, 3000, 1500, 2);
        var (doctor, doctorClient, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        using var client = await Factory.SignedInClientAsync(assistant);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var sessionId = await TestData.RecordSessionAsync(client, patientId, branchId);

        var (_, summary) = await doctorClient.GetJsonAsync("/api/sessions/feeSummary");
        var (_, day) = await doctorClient.GetJsonAsync("/api/sessions/day");
        var row = Assert.Single(day.Items());

        Assert.Equal(1, summary.IntAt("today.examinationCount"));
        Assert.Equal(3000, summary.IntAt("today.totalPiasters"));
        Assert.Equal(3000, (await TestData.WithDbAsync(Factory, db => db.MonthlyStats.SingleAsync(m => m.DoctorId == doctor.Id))).AmountPiasters);
        Assert.Equal(assistant.Id.ToString(), row.StrAt("recordedBy.userId"));
        Assert.Equal("سارة محمود", row.StrAt("recordedBy.name"));
        Assert.Equal("assistant", row.StrAt("recordedBy.role"));
        Assert.True(row.BoolAt("awaitingDoctor"));

        // «بانتظار الطبيب» stays until the doctor saves the clinical part (BR-AS7).
        var (_, saved) = await doctorClient.PostAsync("/api/sessions/updateClinical", new { sessionId, diagnosis = "نزلة برد" });
        Assert.False(saved.BoolAt("awaitingDoctor"));
        var (_, after) = await doctorClient.GetJsonAsync("/api/sessions/day");
        Assert.False(Assert.Single(after.Items()).BoolAt("awaitingDoctor"));
    }

    [Fact]
    public async Task The_consultation_rule_applies_to_assistants()
    {
        await using var settings = await TestData.UseFeeSettingsAsync(Factory, maxConsecutiveConsultations: 2);
        var (doctor, _, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        using var client = await Factory.SignedInClientAsync(assistant);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        await TestData.RecordSessionAsync(client, patientId, branchId);
        await TestData.RecordSessionAsync(client, patientId, branchId, "consultation");
        await TestData.RecordSessionAsync(client, patientId, branchId, "consultation");

        var (status, problem) = await client.PostAsync("/api/sessions/createSession", TestData.SessionBody(patientId, branchId, "consultation"));

        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.ConsultationRequiresExam, problem.Code());
    }

    [Fact]
    public async Task Turning_off_sessions_create_refuses_the_next_request_without_signing_in_again()
    {
        var (doctor, _, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        using var client = await Factory.SignedInClientAsync(assistant);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        await TestData.RecordSessionAsync(client, patientId, branchId);

        await TestData.SetAssistantPermissionsAsync(Factory, assistant.Id,
            AssistantPresets.Permissions[AssistantPresets.Reception].Where(p => p != ClinicPermissions.SessionsCreate));
        var (status, problem) = await client.PostAsync("/api/sessions/createSession", TestData.SessionBody(patientId, branchId));
        var (infoStatus, _) = await client.GetJsonAsync($"/api/sessions/newSessionInfo?patientId={patientId}&branchId={branchId}");

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(ErrorCodes.PermissionDenied, problem.Code());
        Assert.Equal(ClinicPermissions.SessionsCreate, problem.Str("permission"));
        Assert.Equal(HttpStatusCode.Forbidden, infoStatus);
    }

    [Fact]
    public async Task A_session_in_a_branch_the_assistant_does_not_work_in_is_refused()
    {
        var (doctor, client, branchA) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var branchB = await TestData.AddBranchAsync(Factory, doctor.Id);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception, [branchA]);
        using var assistantClient = await Factory.SignedInClientAsync(assistant);

        var (status, problem) = await assistantClient.PostAsync("/api/sessions/createSession", TestData.SessionBody(patientId, branchB));
        var (okStatus, _) = await assistantClient.PostAsync("/api/sessions/createSession", TestData.SessionBody(patientId, branchA));

        Assert.Equal(HttpStatusCode.Forbidden, status);
        Assert.Equal(ErrorCodes.BranchNotAllowed, problem.Code());
        Assert.Equal(HttpStatusCode.Created, okStatus);
        // The patient file is doctor-wide: the same assistant still opens it (AC-20, BR-AS13).
        Assert.Equal(HttpStatusCode.OK, (await assistantClient.GetJsonAsync($"/api/patients/{patientId}")).Status);
    }
}
