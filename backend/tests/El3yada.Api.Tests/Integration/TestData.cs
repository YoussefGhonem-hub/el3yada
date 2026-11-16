using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MimeKit;

namespace El3yada.Api.Tests.Integration;

/// <summary>An account made for a test, and how to sign in with it.</summary>
public sealed record TestUser(Guid Id, string Identifier, string Password, string? Phone = null);

/// <summary>Arranges data straight in the database, for accounts whose endpoints come in later phases (patients, assistants).</summary>
public static partial class TestData
{
    public const string Password = "Passw0rd1";

    private static int _phoneCounter = Random.Shared.Next(0, 50_000_000);

    public static string Email(string prefix = "user") => $"{prefix}-{Guid.NewGuid():N}"[..(prefix.Length + 13)] + "@el3yada.test";

    /// <summary>A fresh Egyptian mobile in E.164 (+2011XXXXXXXX).</summary>
    public static string Mobile() => $"+2011{Interlocked.Increment(ref _phoneCounter) % 100_000_000:D8}";

    /// <summary>+2011XXXXXXXX → 011XXXXXXXX.</summary>
    public static string Local(string e164) => "0" + e164[3..];

    public static async Task<Guid> AnySpecialtyAsync(IntegrationFactory factory, int skip = 0)
    {
        await using var scope = factory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        return await db.Specialties.OrderBy(s => s.SortOrder).Skip(skip).Select(s => s.Id).FirstAsync();
    }

    public static async Task<TestUser> CreateAdminAsync(
        IntegrationFactory factory, string adminRole = AdminRoles.SuperAdmin, string status = AccountStatuses.Active, bool mustChangePassword = false)
    {
        var email = Email("admin");
        var id = await AddUserAsync(factory, new User
        {
            Role = Roles.Admin, AdminRole = adminRole, Status = status, DisplayName = "Test Admin", Email = email,
            MustChangePassword = mustChangePassword,
        });
        return new TestUser(id, email, Password);
    }

    public static async Task<TestUser> CreateDoctorAsync(
        IntegrationFactory factory, string status = DoctorStatuses.Active, string? reason = null, string userStatus = AccountStatuses.Active)
    {
        var email = Email("doctor");
        var phone = Mobile();
        var specialtyId = await AnySpecialtyAsync(factory);
        var id = await AddUserAsync(factory, new User
        {
            Role = Roles.Doctor, Status = userStatus, DisplayName = "أحمد علي", Email = email, Phone = phone,
        }, async (db, userId) =>
        {
            db.Doctors.Add(new Doctor
            {
                UserId = userId, FullName = "أحمد علي", Title = "أخصائي", SpecialtyId = specialtyId, LicenseNumber = "12345",
                LicenseDocPath = $"doctors/{userId}/license/{Guid.NewGuid()}.jpg", Status = status, StatusReason = reason,
            });
            await db.SaveChangesAsync();
            var branchId = Guid.NewGuid();
            db.Branches.Add(new Branch
            {
                Id = branchId, DoctorId = userId, NameAr = "فرع المعادي", Governorate = "القاهرة", City = "المعادي",
                AddressDetails = "شارع 9", IsDefault = true,
                BranchPhones = { new BranchPhone { Id = Guid.NewGuid(), Number = Mobile(), Label = "reception" } },
            });
            await db.SaveChangesAsync();
            var doctor = await db.Doctors.SingleAsync(d => d.UserId == userId);
            doctor.DefaultBranchId = branchId;
        });
        return new TestUser(id, email, Password, phone);
    }

    /// <summary>A patient account (role patient + Patients row) on <paramref name="phone"/>.</summary>
    public static async Task<(TestUser User, Guid PatientId)> CreatePatientAsync(
        IntegrationFactory factory, string? phone = null, string password = Password, bool mustChangePassword = false,
        bool acceptedTerms = true, string name = "منى حسن")
    {
        phone ??= Mobile();
        var patientId = Guid.NewGuid();
        var id = await AddUserAsync(factory, new User
        {
            Role = Roles.Patient, DisplayName = name, Phone = phone, MustChangePassword = mustChangePassword,
            AcceptedTermsAt = acceptedTerms ? DateTime.UtcNow : null,
        }, (db, userId) =>
        {
            db.Patients.Add(new Patient
            {
                Id = patientId, UserId = userId, FullName = name, Phone = phone, Gender = "female",
                DateOfBirth = new DateOnly(1990, 1, 1),
            });
            return Task.CompletedTask;
        }, password);
        return (new TestUser(id, phone, password, phone), patientId);
    }

    public static async Task LinkAsync(IntegrationFactory factory, Guid doctorId, Guid patientId, string patientName = "منى حسن")
    {
        await using var scope = factory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var phone = await db.Patients.Where(p => p.Id == patientId).Select(p => p.Phone).SingleAsync();
        var fileNumber = await db.DoctorPatients.CountAsync(l => l.DoctorId == doctorId) + 1;
        db.DoctorPatients.Add(new DoctorPatient
        {
            Id = Guid.NewGuid(), DoctorId = doctorId, PatientId = patientId, FileNumber = fileNumber,
            PatientName = patientName, PatientPhone = phone, SearchName = patientName, LinkedBy = doctorId, LinkedAt = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();
    }

    /// <summary>
    /// An assistant of <paramref name="doctorId"/>. <paramref name="permissions"/> are <c>ClinicPermissions</c>
    /// keys, used as given (no dependencies added). <paramref name="branchIds"/> null means all branches.
    /// </summary>
    public static async Task<TestUser> CreateAssistantAsync(
        IntegrationFactory factory, Guid doctorId, string? phone = null, string password = Password,
        bool patientsResetPassword = false, string status = "active",
        IEnumerable<string>? permissions = null, IEnumerable<Guid>? branchIds = null, string name = "سارة محمود")
    {
        phone ??= Mobile();
        var keys = new HashSet<string>(permissions ?? []);
        if (patientsResetPassword)
        {
            keys.Add(ClinicPermissions.PatientsResetPassword);
        }

        var id = await AddUserAsync(factory, new User { Role = Roles.Assistant, DisplayName = name, Phone = phone }, async (db, userId) =>
        {
            var assistant = new Assistant
            {
                UserId = userId, DoctorId = doctorId, FullName = name, Phone = phone, CreatedBy = doctorId,
                Status = status, AllBranches = branchIds is null, Preset = AssistantPresets.Match(keys),
            };
            ClinicPermissions.Apply(assistant, keys);
            if (branchIds is not null)
            {
                var ids = branchIds.ToList();
                foreach (var branch in await db.Branches.Where(b => ids.Contains(b.Id)).ToListAsync())
                {
                    assistant.Branches.Add(branch);
                }
            }

            db.Assistants.Add(assistant);
        }, password);
        return new TestUser(id, phone, password, phone);
    }

    /// <summary>An assistant with one of the spec's presets (reception, clinical, officeManager).</summary>
    public static Task<TestUser> CreateAssistantWithPresetAsync(
        IntegrationFactory factory, Guid doctorId, string preset, IEnumerable<Guid>? branchIds = null) =>
        CreateAssistantAsync(factory, doctorId, permissions: AssistantPresets.Permissions[preset], branchIds: branchIds);

    /// <summary>The doctor's default branch (every test doctor has one).</summary>
    public static Task<Guid> DefaultBranchAsync(IntegrationFactory factory, Guid doctorId) =>
        WithDbAsync(factory, db => db.Doctors.Where(d => d.UserId == doctorId).Select(d => d.DefaultBranchId!.Value).SingleAsync());

    /// <summary>Adds another active branch to the doctor.</summary>
    public static async Task<Guid> AddBranchAsync(IntegrationFactory factory, Guid doctorId, string name = "فرع مدينة نصر")
    {
        var branchId = Guid.NewGuid();
        await WithDbAsync(factory, async db =>
        {
            db.Branches.Add(new Branch
            {
                Id = branchId, DoctorId = doctorId, NameAr = name, Governorate = "القاهرة", City = "مدينة نصر",
                AddressDetails = "شارع عباس العقاد",
                BranchPhones = { new BranchPhone { Id = Guid.NewGuid(), Number = Mobile(), Label = "reception" } },
            });
            await db.SaveChangesAsync();
        });
        return branchId;
    }

    /// <summary>Changes Doctors.Status straight in the database (suspension comes with billing in Phase 7).</summary>
    public static Task SetDoctorStatusAsync(IntegrationFactory factory, Guid doctorId, string status) =>
        WithDbAsync(factory, db => db.Doctors.Where(d => d.UserId == doctorId)
            .ExecuteUpdateAsync(set => set.SetProperty(d => d.Status, status)));

    /// <summary>Sets the assistant's permissions straight in the database (what the doctor does in D26).</summary>
    public static Task SetAssistantPermissionsAsync(IntegrationFactory factory, Guid assistantUserId, IEnumerable<string> permissions) =>
        WithDbAsync(factory, async db =>
        {
            var assistant = await db.Assistants.SingleAsync(a => a.UserId == assistantUserId);
            ClinicPermissions.Apply(assistant, permissions.ToHashSet());
            await db.SaveChangesAsync();
        });

    public static async Task<T> WithDbAsync<T>(IntegrationFactory factory, Func<AppDbContext, Task<T>> action)
    {
        await using var scope = factory.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    public static async Task WithDbAsync(IntegrationFactory factory, Func<AppDbContext, Task> action)
    {
        await using var scope = factory.CreateScope();
        await action(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    private static async Task<Guid> AddUserAsync(
        IntegrationFactory factory, User user, Func<AppDbContext, Guid, Task>? more = null, string password = Password)
    {
        await using var scope = factory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        user.Id = Guid.NewGuid();
        user.SecurityStamp = Guid.NewGuid();
        user.PasswordHash = scope.ServiceProvider.GetRequiredService<Passwords>().Hash(user, password);
        db.Users.Add(user);
        await db.SaveChangesAsync();
        if (more is not null)
        {
            await more(db, user.Id);
            await db.SaveChangesAsync();
        }

        return user.Id;
    }

    [GeneratedRegex(@"token=([A-Za-z0-9_\-%]+)")]
    private static partial Regex TokenInLink();

    /// <summary>Waits for the .eml written for <paramref name="toAddress"/> (emails are sent in the background).</summary>
    public static async Task<MimeMessage> WaitForEmailAsync(IntegrationFactory factory, string toAddress, string kind)
    {
        var deadline = DateTime.UtcNow.AddSeconds(15);
        while (DateTime.UtcNow < deadline)
        {
            if (Directory.Exists(factory.MailDirectory))
            {
                foreach (var file in Directory.GetFiles(factory.MailDirectory, $"*-{kind}-*.eml"))
                {
                    var message = await MimeMessage.LoadAsync(file);
                    if (message.To.Mailboxes.Any(m => m.Address == toAddress))
                    {
                        return message;
                    }
                }
            }

            await Task.Delay(100);
        }

        throw new TimeoutException($"No {kind} email for {toAddress}.");
    }

    public static bool HasEmail(IntegrationFactory factory, string toAddress) =>
        Directory.Exists(factory.MailDirectory)
        && Directory.GetFiles(factory.MailDirectory, "*.eml").Any(file =>
            MimeMessage.Load(file).To.Mailboxes.Any(m => m.Address == toAddress));

    public static string TokenFrom(MimeMessage message) =>
        Uri.UnescapeDataString(TokenInLink().Match(message.TextBody ?? "").Groups[1].Value);
}

/// <summary>HTTP helpers for the integration tests.</summary>
public static class Http
{
    public static HttpClient Client(this IntegrationFactory factory, string? accessToken = null)
    {
        var client = factory.CreateClient();
        if (accessToken is not null)
        {
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        }

        return client;
    }

    public static async Task<(HttpStatusCode Status, JsonElement Body)> PostAsync(this HttpClient client, string url, object? body = null)
    {
        using var response = await client.PostAsJsonAsync(url, body ?? new { });
        return (response.StatusCode, await BodyAsync(response));
    }

    public static async Task<(HttpStatusCode Status, JsonElement Body)> GetJsonAsync(this HttpClient client, string url)
    {
        using var response = await client.GetAsync(url);
        return (response.StatusCode, await BodyAsync(response));
    }

    public static async Task<JsonElement> BodyAsync(HttpResponseMessage response)
    {
        var text = await response.Content.ReadAsStringAsync();
        return string.IsNullOrEmpty(text) ? default : JsonDocument.Parse(text).RootElement.Clone();
    }

    /// <summary>Signs in and returns the signedIn body (fails the test otherwise).</summary>
    public static async Task<JsonElement> LoginAsync(this IntegrationFactory factory, string identifier, string password, object? device = null)
    {
        var (status, body) = await factory.Client().PostAsync("/api/auth/login", new { identifier, password, device });
        Assert.True(status == HttpStatusCode.OK, $"Login failed: {status} {body}");
        Assert.Equal("signedIn", body.GetProperty("result").GetString());
        return body;
    }

    public static async Task<HttpClient> SignedInClientAsync(this IntegrationFactory factory, TestUser user) =>
        factory.Client((await factory.LoginAsync(user.Identifier, user.Password)).GetProperty("accessToken").GetString());

    public static string? Code(this JsonElement problem) =>
        problem.TryGetProperty("code", out var code) ? code.GetString() : null;

    public static string? FieldCode(this JsonElement problem, string field) =>
        problem.GetProperty("errorCodes").TryGetProperty(field, out var codes) ? codes[0].GetString() : null;

    public static string Str(this JsonElement element, string property) => element.GetProperty(property).GetString()!;
}
