using System.Net;
using System.Text.Json;
using El3yada.Api.Common;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary>Helpers for the patients and sessions tests (Phase 2).</summary>
public static partial class TestData
{
    /// <summary>
    /// Sets the platform fees and the consultation limit (AppSettings is one row for every test) and puts the
    /// old values back when disposed, so a test's numbers don't depend on another test's settings.
    /// </summary>
    public static async Task<IAsyncDisposable> UseFeeSettingsAsync(
        IntegrationFactory factory, int examFeePiasters = 3000, int consultationFeePiasters = 1500, int maxConsecutiveConsultations = 2)
    {
        var old = await WithDbAsync(factory, db => db.AppSettings.AsNoTracking().SingleAsync());
        await SetFeeSettingsAsync(factory, examFeePiasters, consultationFeePiasters, maxConsecutiveConsultations);
        return new Restore(() => SetFeeSettingsAsync(factory, old.ExamFeePiasters, old.ConsultationFeePiasters, old.MaxConsecutiveConsultations));
    }

    public static Task SetFeeSettingsAsync(IntegrationFactory factory, int examFeePiasters, int consultationFeePiasters, int maxConsecutiveConsultations) =>
        WithDbAsync(factory, db => db.AppSettings.ExecuteUpdateAsync(set => set
            .SetProperty(s => s.ExamFeePiasters, examFeePiasters)
            .SetProperty(s => s.ConsultationFeePiasters, consultationFeePiasters)
            .SetProperty(s => s.MaxConsecutiveConsultations, maxConsecutiveConsultations)));

    /// <summary>createPatient through the API. Returns the patient ID.</summary>
    public static async Task<Guid> AddPatientViaApiAsync(HttpClient client, string? phone = null, string name = "منى حسن")
    {
        var (status, body) = await client.PostAsync("/api/patients/createPatient", PatientBody(phone ?? Mobile(), name));
        Assert.True(status == HttpStatusCode.Created, $"createPatient failed: {status} {body}");
        return Guid.Parse(body.GetProperty("patient").Str("patientId"));
    }

    public static object PatientBody(string phone, string name = "منى حسن", string gender = "female") =>
        new { fullName = name, phone, gender, dateOfBirth = "1990-05-01" };

    /// <summary>
    /// createSession through the API. Test doctors have no visit prices, so an amount is sent unless
    /// <paramref name="amountChargedPiasters"/> is null.
    /// </summary>
    public static async Task<Guid> RecordSessionAsync(
        HttpClient client, Guid patientId, Guid branchId, string type = "examination", int? amountChargedPiasters = 20_000)
    {
        var (status, body) = await client.PostAsync("/api/sessions/createSession", SessionBody(patientId, branchId, type, amountChargedPiasters));
        Assert.True(status == HttpStatusCode.Created, $"createSession failed: {status} {body}");
        return Guid.Parse(body.Str("sessionId"));
    }

    public static Dictionary<string, object?> SessionBody(Guid patientId, Guid branchId, string type = "examination", int? amountChargedPiasters = 20_000)
    {
        var body = new Dictionary<string, object?> { ["patientId"] = patientId, ["branchId"] = branchId, ["type"] = type };
        if (amountChargedPiasters is not null)
        {
            body["amountChargedPiasters"] = amountChargedPiasters;
        }

        return body;
    }

    /// <summary>A doctor, signed in, with their default branch.</summary>
    public static async Task<(TestUser Doctor, HttpClient Client, Guid BranchId)> SignedInDoctorAsync(
        IntegrationFactory factory, string status = Auth.DoctorStatuses.Active)
    {
        var doctor = await CreateDoctorAsync(factory, status);
        return (doctor, await factory.SignedInClientAsync(doctor), await DefaultBranchAsync(factory, doctor.Id));
    }

    /// <summary>Moves a session to another Cairo day, as if it had been recorded then (for BR-S7 and AC-4).</summary>
    public static Task MoveSessionToDayAsync(IntegrationFactory factory, Guid sessionId, DateOnly day) =>
        WithDbAsync(factory, async db =>
        {
            var at = CairoTime.StartUtc(day).AddHours(10);
            await db.Sessions.Where(s => s.Id == sessionId).ExecuteUpdateAsync(set => set
                .SetProperty(s => s.CreatedAt, at)
                .SetProperty(s => s.DayKey, day)
                .SetProperty(s => s.MonthKey, CairoTime.MonthKey(day)));
            await db.DoctorPatients.Where(l => l.LastSessionId == sessionId).ExecuteUpdateAsync(set => set.SetProperty(l => l.LastSessionAt, at));
        });

    public static Task SetDoctorPricesAsync(IntegrationFactory factory, Guid doctorId, int? examination, int? consultation) =>
        WithDbAsync(factory, db => db.Doctors.Where(d => d.UserId == doctorId).ExecuteUpdateAsync(set => set
            .SetProperty(d => d.ExaminationPricePiasters, examination)
            .SetProperty(d => d.ConsultationPricePiasters, consultation)));

    public static Task SetBranchPricesAsync(IntegrationFactory factory, Guid branchId, int? examination, int? consultation) =>
        WithDbAsync(factory, db => db.Branches.Where(b => b.Id == branchId).ExecuteUpdateAsync(set => set
            .SetProperty(b => b.ExaminationPricePiasters, examination)
            .SetProperty(b => b.ConsultationPricePiasters, consultation)));

    public static Task SetBranchStatusAsync(IntegrationFactory factory, Guid branchId, string status) =>
        WithDbAsync(factory, db => db.Branches.Where(b => b.Id == branchId).ExecuteUpdateAsync(set => set.SetProperty(b => b.Status, status)));

    private sealed class Restore(Func<Task> restore) : IAsyncDisposable
    {
        public async ValueTask DisposeAsync() => await restore();
    }
}

/// <summary>Reading answers by dotted path: <c>body.IntAt("visits.total")</c>.</summary>
public static class JsonPaths
{
    public static JsonElement At(this JsonElement element, string path)
    {
        foreach (var part in path.Split('.'))
        {
            element = element.GetProperty(part);
        }

        return element;
    }

    public static bool IsNullAt(this JsonElement element, string path) => element.At(path).ValueKind == JsonValueKind.Null;

    public static int IntAt(this JsonElement element, string path) => element.At(path).GetInt32();

    public static string? StrAt(this JsonElement element, string path) => element.At(path).GetString();

    public static bool BoolAt(this JsonElement element, string path) => element.At(path).GetBoolean();

    public static List<JsonElement> Items(this JsonElement element, string path = "items") => element.At(path).EnumerateArray().ToList();
}

/// <summary>A doctor's clinic with one patient and that patient's first examination, for the tests that need one ready.</summary>
public sealed record PatientScene(TestUser Doctor, HttpClient Client, Guid BranchId, Guid PatientId, Guid SessionId)
{
    public static async Task<PatientScene> CreateAsync(IntegrationFactory factory)
    {
        var (doctor, client, branchId) = await TestData.SignedInDoctorAsync(factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var sessionId = await TestData.RecordSessionAsync(client, patientId, branchId);
        return new PatientScene(doctor, client, branchId, patientId, sessionId);
    }
}
