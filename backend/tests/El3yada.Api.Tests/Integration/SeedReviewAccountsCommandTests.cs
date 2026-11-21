using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using El3yada.Api.Analytics;
using El3yada.Api.Auth;
using El3yada.Api.Commands;
using El3yada.Api.Storage;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary><c>dotnet run -- seed-review-accounts --patient-phone …</c>, called through its handler.</summary>
[Collection(IntegrationCollection.Name)]
public sealed partial class SeedReviewAccountsCommandTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [GeneratedRegex(@"Doctor password: (\S+)")]
    private static partial Regex DoctorPassword();

    [GeneratedRegex(@"Patient password: (\S+)")]
    private static partial Regex PatientPassword();

    private async Task<(int ExitCode, string Output)> RunAsync(params string[] args)
    {
        await using var scope = Factory.CreateScope();
        var output = new StringWriter();
        var code = await SeedReviewAccountsCommand.ExecuteAsync(
            scope.ServiceProvider.GetRequiredService<AppDbContext>(),
            scope.ServiceProvider.GetRequiredService<Passwords>(),
            scope.ServiceProvider.GetRequiredService<IFileStorage>(),
            scope.ServiceProvider.GetRequiredService<DailyMetricsBuilder>(),
            TimeProvider.System,
            [SeedReviewAccountsCommand.Name, .. args],
            output);
        return (code, output.ToString());
    }

    [Fact]
    public async Task Creates_a_doctor_and_a_patient_who_sign_in_straight_away_with_a_clinic_that_has_content()
    {
        var email = TestData.Email("review");
        var phone = TestData.Mobile();

        var (code, output) = await RunAsync("--patient-phone", TestData.Local(phone), "--doctor-email", email);

        Assert.Equal(0, code);
        var doctorPassword = DoctorPassword().Match(output).Groups[1].Value;
        var patientPassword = PatientPassword().Match(output).Groups[1].Value;
        Assert.Equal(SeedReviewAccountsCommand.PasswordLength, doctorPassword.Length);
        Assert.Equal(SeedReviewAccountsCommand.PasswordLength, patientPassword.Length);
        Assert.Contains($"Patient: {TestData.Local(phone)}", output);

        // The doctor: no password change, no terms step, a trial that outlasts any review, no fees.
        var doctorLogin = await Factory.LoginAsync(email, doctorPassword);
        Assert.False(doctorLogin.GetProperty("mustChangePassword").GetBoolean());
        Assert.False(doctorLogin.GetProperty("mustAcceptTerms").GetBoolean());
        Assert.Equal("active", doctorLogin.Str("doctorStatus"));
        var trial = doctorLogin.GetProperty("trial");
        Assert.False(trial.GetProperty("ended").GetBoolean());
        Assert.True(trial.GetProperty("daysLeft").GetInt32() > 365 * (SeedReviewAccountsCommand.TrialYears - 1));
        var doctor = Factory.Client(doctorLogin.Str("accessToken"));
        var patientId = await TestData.WithDbAsync(Factory, db => db.Patients.Where(p => p.Phone == phone).Select(p => p.Id).SingleAsync());
        var (profileStatus, profile) = await doctor.GetJsonAsync($"/api/patients/{patientId}");
        Assert.Equal(HttpStatusCode.OK, profileStatus);
        Assert.Equal(1, profile.GetProperty("fileNumber").GetInt32());
        var doctorUserId = await TestData.WithDbAsync(Factory, db => db.Users.Where(u => u.Email == email).Select(u => u.Id).SingleAsync());
        Assert.Equal(0, await TestData.WithDbAsync(Factory, db => db.Sessions.Where(s => s.DoctorId == doctorUserId).SumAsync(s => s.FeePiasters)));
        Assert.Equal(2, await TestData.WithDbAsync(Factory, db => db.Prescriptions.CountAsync(p => p.DoctorId == doctorUserId && p.Status == "draft")));

        // The patient signs in with the number as people type it, and finds visits, a follow-up and a booking.
        var patientLogin = await Factory.LoginAsync(phone, patientPassword);
        Assert.False(patientLogin.GetProperty("mustChangePassword").GetBoolean());
        Assert.False(patientLogin.GetProperty("mustAcceptTerms").GetBoolean());
        var patient = Factory.Client(patientLogin.Str("accessToken"));
        var (homeStatus, home) = await patient.GetJsonAsync("/api/patient/home");
        Assert.Equal(HttpStatusCode.OK, homeStatus);
        Assert.Equal(JsonValueKind.Object, home.GetProperty("latestVisit").ValueKind);
        Assert.Equal(JsonValueKind.Object, home.GetProperty("nextFollowUp").ValueKind);
        var (_, visits) = await patient.GetJsonAsync("/api/patient/visits");
        Assert.Equal(2, visits.GetProperty("totalCount").GetInt32());
        var (_, bookings) = await patient.GetJsonAsync("/api/patient/appointments");
        Assert.Equal(1, bookings.GetArrayLength());
        var (_, medical) = await patient.GetJsonAsync("/api/patient/medical-profile");
        Assert.Contains("البنسلين", medical.ToString());
    }

    [Fact]
    public async Task Refuses_an_email_or_number_that_already_has_an_account()
    {
        var email = TestData.Email("review");
        var phone = TestData.Mobile();
        Assert.Equal(0, (await RunAsync("--patient-phone", phone, "--doctor-email", email)).ExitCode);

        var (sameEmail, emailOutput) = await RunAsync("--patient-phone", TestData.Mobile(), "--doctor-email", email);
        var (samePhone, phoneOutput) = await RunAsync("--patient-phone", phone, "--doctor-email", TestData.Email("review"));

        Assert.Equal(1, sameEmail);
        Assert.Contains("Nothing was changed", emailOutput);
        Assert.Equal(1, samePhone);
        Assert.Contains("Nothing was changed", phoneOutput);
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Users.CountAsync(u => u.Phone == phone)));
    }

    [Theory]
    [InlineData]
    [InlineData("--patient-phone", "12345")]
    [InlineData("--patient-phone", "01012345678", "--doctor-email", "not-an-email")]
    [InlineData("--patient-phone", "01012345678", "--extra")]
    public async Task Explains_the_usage_when_the_arguments_are_wrong(params string[] args)
    {
        var (code, output) = await RunAsync(args);

        Assert.Equal(2, code);
        Assert.Contains("Usage:", output);
    }
}
