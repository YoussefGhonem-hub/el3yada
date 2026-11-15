using System.Net;
using System.Net.Http.Json;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>Patients: createPatient (BR-P1–P6, AC-10), lookup, identity, phone, password, archive, medical profile.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class PatientsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task A_new_number_gets_an_account_a_temporary_password_shown_once_and_file_number_one()
    {
        var (doctor, client, _) = await TestData.SignedInDoctorAsync(Factory);
        var phone = TestData.Mobile();

        using var response = await client.PostAsJsonAsync("/api/patients/createPatient", new
        {
            fullName = "  منى   حسن ", phone = TestData.Local(phone), gender = "female", dateOfBirth = "1990-05-01",
            nationalId = "٢٩٠٠٥٠١٠١٢٣٤٥٦", address = "المعادي", bloodType = "A+", emergencyContactName = "حسن علي",
            emergencyContactPhone = "02 2358 1234",
        });
        var body = await Http.BodyAsync(response);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        Assert.False(body.BoolAt("linked"));
        var password = body.Str("temporaryPassword");
        Assert.Equal(8, password.Length);
        var patient = body.GetProperty("patient");
        Assert.Equal(1, patient.IntAt("fileNumber"));
        Assert.Equal("منى حسن", patient.Str("fullName"));
        Assert.Equal(phone, patient.Str("phone"));
        Assert.Equal("29005010123456", patient.Str("nationalId"));
        Assert.Equal("+20223581234", patient.Str("emergencyContactPhone"));
        Assert.False(patient.BoolAt("dateOfBirthEstimated"));
        Assert.Equal(0, patient.IntAt("visits.total"));
        Assert.True(patient.IsNullAt("visits.lastVisit"));

        // AC-10: the patient must change the temporary password at first sign-in.
        var session = await Factory.LoginAsync(phone, password);
        Assert.True(session.BoolAt("mustChangePassword"));
        Assert.Equal("patient", session.Str("role"));

        var second = await TestData.AddPatientViaApiAsync(client);
        var secondNumber = await TestData.WithDbAsync(Factory, db =>
            db.DoctorPatients.Where(l => l.DoctorId == doctor.Id && l.PatientId == second).Select(l => l.FileNumber).SingleAsync());
        Assert.Equal(2, secondNumber);

        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs
            .Where(a => a.DoctorId == doctor.Id && a.Action == AuditActions.PatientCreated).CountAsync());
        Assert.Equal(2, audit);
    }

    [Fact]
    public async Task Another_clinic_adding_the_number_links_the_same_account_and_sees_none_of_the_first_clinics_records()
    {
        var a = await PatientScene.CreateAsync(Factory);
        var phone = await TestData.WithDbAsync(Factory, db => db.Patients.Where(p => p.Id == a.PatientId).Select(p => p.Phone).SingleAsync());
        await a.Client.PostAsync("/api/sessions/setPrivateNote", new { sessionId = a.SessionId, text = "ملاحظة سرية" });
        var (_, clientB, _) = await TestData.SignedInDoctorAsync(Factory);

        var (status, body) = await clientB.PostAsync("/api/patients/createPatient", TestData.PatientBody(phone, "اسم آخر", "male"));

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.True(body.BoolAt("linked"));
        Assert.True(body.IsNullAt("temporaryPassword"));
        var patient = body.GetProperty("patient");
        Assert.Equal(a.PatientId.ToString(), patient.Str("patientId"));
        // BR-P3: the existing identity is kept.
        Assert.Equal("منى حسن", patient.Str("fullName"));
        Assert.Equal("female", patient.Str("gender"));
        Assert.Equal(1, patient.IntAt("fileNumber"));
        Assert.Equal(0, patient.IntAt("visits.total"));

        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Users.CountAsync(u => u.Phone == phone && u.Role == "patient")));
        Assert.Equal(2, await TestData.WithDbAsync(Factory, db => db.DoctorPatients.CountAsync(l => l.PatientId == a.PatientId)));

        var (_, sessions) = await clientB.GetJsonAsync($"/api/patients/{a.PatientId}/sessions");
        Assert.Empty(sessions.Items());
        var (sessionStatus, _) = await clientB.GetJsonAsync($"/api/sessions/{a.SessionId}");
        Assert.Equal(HttpStatusCode.NotFound, sessionStatus);
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.AuditLogs.CountAsync(x =>
            x.Action == AuditActions.PatientLinked && x.PatientId == a.PatientId)));
    }

    [Fact]
    public async Task An_existing_number_is_linked_with_the_phone_alone_but_a_new_one_needs_the_identity()
    {
        var (_, clientA, _) = await TestData.SignedInDoctorAsync(Factory);
        var (_, clientB, _) = await TestData.SignedInDoctorAsync(Factory);
        var phone = TestData.Mobile();
        var patientId = await TestData.AddPatientViaApiAsync(clientA, phone);

        var (linkStatus, linked) = await clientB.PostAsync("/api/patients/createPatient", new { phone = TestData.Local(phone) });
        var (newStatus, missing) = await clientB.PostAsync("/api/patients/createPatient", new { phone = TestData.Mobile() });

        Assert.Equal(HttpStatusCode.Created, linkStatus);
        Assert.True(linked.BoolAt("linked"));
        Assert.Equal(patientId.ToString(), linked.StrAt("patient.patientId"));
        Assert.Equal(HttpStatusCode.BadRequest, newStatus);
        Assert.Equal(ErrorCodes.Required, missing.FieldCode("fullName"));
        Assert.Equal(ErrorCodes.Required, missing.FieldCode("gender"));
        Assert.Equal(ErrorCodes.Required, missing.FieldCode("dateOfBirth"));
    }

    [Fact]
    public async Task Adding_your_own_patient_again_is_a_conflict_that_names_the_patient()
    {
        var (_, client, _) = await TestData.SignedInDoctorAsync(Factory);
        var phone = TestData.Mobile();
        var patientId = await TestData.AddPatientViaApiAsync(client, phone);

        var (status, body) = await client.PostAsync("/api/patients/createPatient", TestData.PatientBody(phone));

        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.PatientAlreadyLinked, body.Code());
        Assert.Equal(patientId.ToString(), body.Str("patientId"));
        Assert.Equal(1, body.IntAt("fileNumber"));
    }

    [Fact]
    public async Task Lookup_phone_says_new_yours_or_elsewhere_and_nothing_about_another_clinics_patient()
    {
        var (_, clientA, _) = await TestData.SignedInDoctorAsync(Factory);
        var (_, clientB, _) = await TestData.SignedInDoctorAsync(Factory);
        var phone = TestData.Mobile();
        var patientId = await TestData.AddPatientViaApiAsync(clientA, phone, "منى حسن");

        var (_, fresh) = await clientA.GetJsonAsync($"/api/patients/lookupPhone?phone={TestData.Local(TestData.Mobile())}");
        var (_, mine) = await clientA.GetJsonAsync($"/api/patients/lookupPhone?phone={Uri.EscapeDataString(phone)}");
        var (_, elsewhere) = await clientB.GetJsonAsync($"/api/patients/lookupPhone?phone={TestData.Local(phone)}");
        var (badStatus, bad) = await clientA.GetJsonAsync("/api/patients/lookupPhone?phone=123");

        Assert.Equal("new", fresh.Str("status"));
        Assert.Equal("linkedToYou", mine.Str("status"));
        Assert.Equal(patientId.ToString(), mine.Str("patientId"));
        Assert.Equal(1, mine.IntAt("fileNumber"));
        Assert.Equal("منى حسن", mine.Str("fullName"));
        Assert.Equal("existsElsewhere", elsewhere.Str("status"));
        Assert.True(elsewhere.IsNullAt("patientId"));
        Assert.True(elsewhere.IsNullAt("fullName"));
        Assert.True(elsewhere.IsNullAt("fileNumber"));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidMobile, bad.FieldCode("phone"));
    }

    [Fact]
    public async Task An_age_instead_of_a_date_of_birth_is_stored_as_an_estimate()
    {
        var (_, client, _) = await TestData.SignedInDoctorAsync(Factory);

        var (status, body) = await client.PostAsync("/api/patients/createPatient", new
        {
            fullName = "كريم سامي", phone = TestData.Mobile(), gender = "male", ageYears = 40,
        });

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.True(body.BoolAt("patient.dateOfBirthEstimated"));
        Assert.Equal(40, body.IntAt("patient.ageYears"));

        // Saving the same age again keeps the stored date.
        var patientId = body.StrAt("patient.patientId");
        var dob = body.StrAt("patient.dateOfBirth");
        var (_, updated) = await client.PostAsync("/api/patients/updatePatient", new
        {
            patientId, fullName = "كريم سامي", gender = "male", ageYears = 40,
        });
        Assert.Equal(dob, updated.Str("dateOfBirth"));
    }

    [Theory]
    [InlineData("fullName", "منى", ErrorCodes.InvalidName)]
    [InlineData("phone", "123", ErrorCodes.InvalidMobile)]
    [InlineData("gender", "other", ErrorCodes.InvalidValue)]
    [InlineData("dateOfBirth", "2999-01-01", ErrorCodes.InvalidDateOfBirth)]
    [InlineData("dateOfBirth", "1800-01-01", ErrorCodes.InvalidDateOfBirth)]
    [InlineData("nationalId", "123", ErrorCodes.InvalidNationalId)]
    [InlineData("bloodType", "C+", ErrorCodes.InvalidValue)]
    [InlineData("emergencyContactPhone", "12", ErrorCodes.InvalidPhone)]
    public async Task Fields_follow_the_validation_rules(string field, string value, string code)
    {
        var (_, client, _) = await TestData.SignedInDoctorAsync(Factory);
        var body = new Dictionary<string, object?>
        {
            ["fullName"] = "منى حسن", ["phone"] = TestData.Mobile(), ["gender"] = "female", ["dateOfBirth"] = "1990-05-01",
            [field] = value,
        };

        var (status, problem) = await client.PostAsync("/api/patients/createPatient", body);

        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(code, problem.FieldCode(field));
    }

    [Fact]
    public async Task Date_of_birth_or_age_is_required_but_not_both()
    {
        var (_, client, _) = await TestData.SignedInDoctorAsync(Factory);

        var (_, neither) = await client.PostAsync("/api/patients/createPatient", new { fullName = "منى حسن", phone = TestData.Mobile(), gender = "female" });
        var (_, both) = await client.PostAsync("/api/patients/createPatient", new
        {
            fullName = "منى حسن", phone = TestData.Mobile(), gender = "female", dateOfBirth = "1990-01-01", ageYears = 30,
        });
        var (_, old) = await client.PostAsync("/api/patients/createPatient", new { fullName = "منى حسن", phone = TestData.Mobile(), gender = "female", ageYears = 121 });

        Assert.Equal(ErrorCodes.Required, neither.FieldCode("dateOfBirth"));
        Assert.Equal(ErrorCodes.InvalidValue, both.FieldCode("ageYears"));
        Assert.Equal(ErrorCodes.OutOfRange, old.FieldCode("ageYears"));
    }

    [Fact]
    public async Task Patients_added_at_the_same_moment_get_different_file_numbers()
    {
        var (doctor, client, _) = await TestData.SignedInDoctorAsync(Factory);

        var results = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ =>
            client.PostAsync("/api/patients/createPatient", TestData.PatientBody(TestData.Mobile()))));

        Assert.All(results, r => Assert.Equal(HttpStatusCode.Created, r.Status));
        var numbers = await TestData.WithDbAsync(Factory, db =>
            db.DoctorPatients.Where(l => l.DoctorId == doctor.Id).Select(l => l.FileNumber).OrderBy(n => n).ToListAsync());
        Assert.Equal([1, 2, 3, 4, 5, 6], numbers);
        Assert.Equal(7, await TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctor.Id).Select(d => d.NextFileNumber).SingleAsync()));
    }

    [Fact]
    public async Task Two_clinics_adding_one_new_number_at_the_same_moment_make_one_account()
    {
        var (_, clientA, _) = await TestData.SignedInDoctorAsync(Factory);
        var (_, clientB, _) = await TestData.SignedInDoctorAsync(Factory);
        var phone = TestData.Mobile();

        var results = await Task.WhenAll(
            clientA.PostAsync("/api/patients/createPatient", TestData.PatientBody(phone)),
            clientB.PostAsync("/api/patients/createPatient", TestData.PatientBody(phone)));

        Assert.All(results, r => Assert.Equal(HttpStatusCode.Created, r.Status));
        Assert.Equal([false, true], results.Select(r => r.Body.BoolAt("linked")).Order());
        Assert.Single(results.Select(r => r.Body.StrAt("patient.patientId")).Distinct());
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Patients.CountAsync(p => p.Phone == phone)));
    }

    [Fact]
    public async Task Updating_the_identity_changes_the_name_on_every_clinics_link()
    {
        var (doctorA, clientA, _) = await TestData.SignedInDoctorAsync(Factory);
        var (_, clientB, _) = await TestData.SignedInDoctorAsync(Factory);
        var phone = TestData.Mobile();
        var patientId = await TestData.AddPatientViaApiAsync(clientA, phone);
        await TestData.AddPatientViaApiAsync(clientB, phone);

        var (status, body) = await clientA.PostAsync("/api/patients/updatePatient", new
        {
            patientId, fullName = "أميرة   سعيد", gender = "female", dateOfBirth = "1991-02-03", address = "مدينة نصر",
        });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("أميرة سعيد", body.Str("fullName"));
        Assert.Equal("1991-02-03", body.Str("dateOfBirth"));
        Assert.Equal("مدينة نصر", body.Str("address"));
        var links = await TestData.WithDbAsync(Factory, db => db.DoctorPatients.Where(l => l.PatientId == patientId).ToListAsync());
        Assert.All(links, l =>
        {
            Assert.Equal("أميرة سعيد", l.PatientName);
            Assert.Equal("اميره سعيد", l.SearchName);
        });
        var (_, register) = await clientB.GetJsonAsync("/api/patients/register?search=اميرة");
        Assert.Equal(patientId.ToString(), Assert.Single(register.Items()).Str("patientId"));
        var details = await TestData.WithDbAsync(Factory, db => db.AuditLogs
            .Where(a => a.DoctorId == doctorA.Id && a.Action == AuditActions.PatientUpdated).Select(a => a.DetailsJson).SingleAsync());
        Assert.Contains("fullName", details);
        Assert.DoesNotContain("أميرة", details);
        Assert.Equal("أميرة سعيد", await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Phone == phone && u.Role == "patient").Select(u => u.DisplayName).SingleAsync()));
    }

    [Fact]
    public async Task A_phone_change_checks_other_patients_and_updates_the_login_and_every_link()
    {
        var (_, clientA, _) = await TestData.SignedInDoctorAsync(Factory);
        var (_, clientB, _) = await TestData.SignedInDoctorAsync(Factory);
        var (_, notLinked) = await TestData.CreatePatientAsync(Factory);
        var phoneOfA = TestData.Mobile();
        var patientA = await TestData.AddPatientViaApiAsync(clientA, phoneOfA);
        var (_, linkedB) = await clientB.PostAsync("/api/patients/createPatient", TestData.PatientBody(phoneOfA));
        Assert.True(linkedB.BoolAt("linked"));
        var taken = TestData.Mobile();
        await TestData.AddPatientViaApiAsync(clientA, taken);
        var fresh = TestData.Mobile();

        var (takenStatus, takenBody) = await clientA.PostAsync("/api/patients/updatePatientPhone", new { patientId = patientA, phone = TestData.Local(taken) });
        var (status, body) = await clientA.PostAsync("/api/patients/updatePatientPhone", new { patientId = patientA, phone = TestData.Local(fresh) });

        Assert.Equal(HttpStatusCode.Conflict, takenStatus);
        Assert.Equal(ErrorCodes.PatientPhoneTaken, takenBody.Code());
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(fresh, body.Str("phone"));
        Assert.Equal(fresh, await TestData.WithDbAsync(Factory, db => db.Patients.Where(p => p.Id == patientA).Select(p => p.User.Phone).SingleAsync()));
        Assert.All(
            await TestData.WithDbAsync(Factory, db => db.DoctorPatients.Where(l => l.PatientId == patientA).Select(l => l.PatientPhone).ToListAsync()),
            p => Assert.Equal(fresh, p));
        var (otherStatus, _) = await clientA.PostAsync("/api/patients/updatePatientPhone", new { patientId = notLinked, phone = TestData.Mobile() });
        Assert.Equal(HttpStatusCode.NotFound, otherStatus);
        // The new number is the login now.
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Users.CountAsync(u => u.Phone == fresh && u.Role == "patient")));
    }

    [Fact]
    public async Task A_password_reset_gives_a_new_temporary_password_and_signs_the_patient_out()
    {
        var (_, client, _) = await TestData.SignedInDoctorAsync(Factory);
        var phone = TestData.Mobile();
        var (_, created) = await client.PostAsync("/api/patients/createPatient", TestData.PatientBody(phone));
        var patientId = created.StrAt("patient.patientId");
        var patientSession = await Factory.LoginAsync(phone, created.Str("temporaryPassword"));
        using var patientClient = Factory.Client(patientSession.Str("accessToken"));
        Assert.Equal(HttpStatusCode.OK, (await patientClient.GetJsonAsync("/api/auth/me")).Status);

        using var response = await client.PostAsJsonAsync("/api/patients/resetPatientPassword", new { patientId });
        var body = await Http.BodyAsync(response);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        var password = body.Str("temporaryPassword");
        Assert.Equal(8, password.Length);
        var (meStatus, me) = await patientClient.GetJsonAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, meStatus);
        Assert.Equal(ErrorCodes.SessionRevoked, me.Code());
        Assert.True((await Factory.LoginAsync(phone, password)).BoolAt("mustChangePassword"));
    }

    [Fact]
    public async Task Archiving_hides_the_patient_from_the_default_register_and_keeps_everything()
    {
        var scene = await PatientScene.CreateAsync(Factory);

        var (status, body) = await scene.Client.PostAsync("/api/patients/setArchived", new { patientId = scene.PatientId, archived = true });
        var (_, active) = await scene.Client.GetJsonAsync("/api/patients/register");
        var (_, archived) = await scene.Client.GetJsonAsync("/api/patients/register?archived=true");
        var (_, again) = await scene.Client.PostAsync("/api/patients/setArchived", new { patientId = scene.PatientId, archived = false });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.True(body.BoolAt("archived"));
        Assert.False(body.IsNullAt("archivedAt"));
        Assert.Empty(active.Items());
        Assert.Equal(scene.PatientId.ToString(), Assert.Single(archived.Items()).Str("patientId"));
        Assert.False(again.BoolAt("archived"));
        Assert.Equal(1, again.IntAt("visits.total"));
        var actions = await TestData.WithDbAsync(Factory, db => db.AuditLogs
            .Where(a => a.PatientId == scene.PatientId && a.Action.StartsWith("patient") && a.Action.EndsWith("archived")).Select(a => a.Action).ToListAsync());
        Assert.Equal([AuditActions.PatientArchived, AuditActions.PatientUnarchived], actions.Order());
    }

    [Fact]
    public async Task The_medical_profile_is_replaced_in_order_and_kept_per_clinic()
    {
        var (_, clientA, _) = await TestData.SignedInDoctorAsync(Factory);
        var (_, clientB, _) = await TestData.SignedInDoctorAsync(Factory);
        var phone = TestData.Mobile();
        var patientId = await TestData.AddPatientViaApiAsync(clientA, phone);
        await TestData.AddPatientViaApiAsync(clientB, phone);

        var (status, profile) = await clientA.PostAsync("/api/patients/updateMedicalProfile", new
        {
            patientId,
            allergies = new[] { "Penicillin", " بنسلين  الحساسية ", "penicillin" },
            chronicDiseases = new[] { "سكر", "ضغط" },
            currentMedications = new[] { "Metformin 500" },
            surgeries = Array.Empty<string>(),
            familyHistory = "الأب: سكر",
            notes = "لا شيء",
        });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.True(profile.BoolAt("hasAllergies"));
        Assert.Equal(["Penicillin", "بنسلين الحساسية"], profile.Items("allergies").Select(i => i.Str("text")));
        Assert.Equal(["سكر", "ضغط"], profile.Items("chronicDiseases").Select(i => i.Str("text")));
        Assert.Empty(profile.Items("surgeries"));
        Assert.Equal("الأب: سكر", profile.Str("familyHistory"));
        Assert.Equal("لا شيء", profile.Str("notes"));
        var keptId = profile.Items("chronicDiseases")[1].Str("id");

        var (_, second) = await clientA.PostAsync("/api/patients/updateMedicalProfile", new
        {
            patientId, chronicDiseases = new[] { "ضغط", "ربو" },
        });
        Assert.Empty(second.Items("allergies"));
        Assert.False(second.BoolAt("hasAllergies"));
        Assert.Equal(["ضغط", "ربو"], second.Items("chronicDiseases").Select(i => i.Str("text")));
        Assert.Equal(keptId, second.Items("chronicDiseases")[0].Str("id"));
        Assert.True(second.IsNullAt("familyHistory"));

        var (_, read) = await clientA.GetJsonAsync($"/api/patients/{patientId}/medicalProfile");
        Assert.Equal(["ضغط", "ربو"], read.Items("chronicDiseases").Select(i => i.Str("text")));
        var (_, other) = await clientB.GetJsonAsync($"/api/patients/{patientId}/medicalProfile");
        Assert.Empty(other.Items("chronicDiseases"));

        var audit = await TestData.WithDbAsync(Factory, db => db.AuditLogs
            .Where(a => a.PatientId == patientId && a.Action == AuditActions.PatientMedicalProfileUpdated)
            .OrderBy(a => a.Id).Select(a => a.DetailsJson!).ToListAsync());
        Assert.Equal(2, audit.Count);
        Assert.DoesNotContain("سكر", audit[0]);
        Assert.Contains("\"added\":5", audit[0]);
    }

    [Fact]
    public async Task Profile_items_are_checked()
    {
        var (_, client, _) = await TestData.SignedInDoctorAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);

        var (_, empty) = await client.PostAsync("/api/patients/updateMedicalProfile", new { patientId, allergies = new[] { " " } });
        var (_, tooLong) = await client.PostAsync("/api/patients/updateMedicalProfile", new { patientId, surgeries = new[] { new string('x', 201) } });
        var (_, tooMany) = await client.PostAsync("/api/patients/updateMedicalProfile", new
        {
            patientId, currentMedications = Enumerable.Range(0, 51).Select(i => $"drug {i}").ToArray(),
        });

        Assert.Equal(ErrorCodes.Required, empty.FieldCode("allergies[0]"));
        Assert.Equal(ErrorCodes.TooLong, tooLong.FieldCode("surgeries[0]"));
        Assert.Equal(ErrorCodes.OutOfRange, tooMany.FieldCode("currentMedications"));
    }

    [Fact]
    public async Task The_patient_summary_counts_visits_and_hides_money_and_allergies_by_permission()
    {
        var scene = await PatientScene.CreateAsync(Factory);
        await TestData.RecordSessionAsync(scene.Client, scene.PatientId, scene.BranchId, "consultation", 5_000);
        await scene.Client.PostAsync("/api/patients/updateMedicalProfile", new { patientId = scene.PatientId, allergies = new[] { "Aspirin" } });
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, scene.Doctor.Id, AssistantPresets.Reception);
        using var receptionClient = await Factory.SignedInClientAsync(reception);
        var money = await TestData.CreateAssistantAsync(Factory, scene.Doctor.Id,
            permissions: [ClinicPermissions.RevenueView, ClinicPermissions.ClinicalView]);
        using var moneyClient = await Factory.SignedInClientAsync(money);

        var (_, doctorView) = await scene.Client.GetJsonAsync($"/api/patients/{scene.PatientId}");
        var (_, receptionView) = await receptionClient.GetJsonAsync($"/api/patients/{scene.PatientId}");
        var (_, moneyView) = await moneyClient.GetJsonAsync($"/api/patients/{scene.PatientId}");

        Assert.Equal(2, doctorView.IntAt("visits.total"));
        Assert.Equal(1, doctorView.IntAt("visits.examinations"));
        Assert.Equal(1, doctorView.IntAt("visits.consultations"));
        Assert.Equal(1, doctorView.IntAt("visits.consultationsSinceExam"));
        Assert.Equal("consultation", doctorView.StrAt("visits.lastVisit.type"));
        Assert.Equal(0, doctorView.IntAt("visits.lastVisit.daysAgo"));
        Assert.Equal("فرع المعادي", doctorView.StrAt("visits.lastVisit.branchNameAr"));
        Assert.Equal(25_000, doctorView.IntAt("totalPaidPiasters"));
        Assert.True(doctorView.BoolAt("hasAllergies"));
        Assert.Equal(0, doctorView.IntAt("files.total"));
        Assert.Equal(0, doctorView.IntAt("prescriptionCount"));
        Assert.True(doctorView.IsNullAt("nextBooking"));
        Assert.Equal(0, doctorView.IntAt("noShowCount"));

        Assert.True(receptionView.IsNullAt("totalPaidPiasters"));
        Assert.True(receptionView.IsNullAt("hasAllergies"));
        Assert.Equal(2, receptionView.IntAt("visits.total"));

        Assert.Equal(25_000, moneyView.IntAt("totalPaidPiasters"));
        Assert.True(moneyView.BoolAt("hasAllergies"));
    }
}
