using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace El3yada.Data.Tests;

/// <summary>
/// The data change in AccountDeletion (spec 6.17), on its own database stopped at the migration before it: the old
/// patient-only requests (pending, approved, rejected), then the migration up, then down.
/// </summary>
public sealed class AccountDeletionMigrationTests : IAsyncLifetime
{
    private const string Before = "20261121114803_QueueNumberAtCheckIn";
    private const string Migration = "20261121152316_AccountDeletion";

    private readonly string _connectionString = MigratedDatabase.NewConnectionString();

    public async Task InitializeAsync()
    {
        await using var db = MigratedDatabase.CreateContext(_connectionString);
        await db.GetService<IMigrator>().MigrateAsync(Before);
    }

    public async Task DisposeAsync()
    {
        await using var db = MigratedDatabase.CreateContext(_connectionString);
        await db.Database.EnsureDeletedAsync();
    }

    [Fact]
    public async Task Up_schedules_the_old_pending_requests_from_their_creation_and_down_puts_them_back()
    {
        await using var db = MigratedDatabase.CreateContext(_connectionString);
        var (doctorId, branchId) = await CreateClinicAsync(db);
        var adminId = await AddUserAsync(db, "admin", "superAdmin", "active", email: "admin@el3yada.dev");
        var createdAt = new DateTime(2026, 11, 10, 9, 0, 0, DateTimeKind.Utc);

        var (pendingUser, pendingPatient) = await AddPatientAsync(db, "+201011111111", "active", "active");
        var (approvedUser, approvedPatient) = await AddPatientAsync(db, "+201022222222", "disabled", "deleted");
        var (rejectedUser, rejectedPatient) = await AddPatientAsync(db, "+201033333333", "active", "active");
        var pending = await AddRequestAsync(db, pendingPatient, "pending", createdAt, null, null, null);
        var approved = await AddRequestAsync(db, approvedPatient, "approved", createdAt.AddDays(-40), adminId, createdAt.AddDays(-39), null);
        var rejected = await AddRequestAsync(db, rejectedPatient, "rejected", createdAt.AddDays(-5), adminId, createdAt.AddDays(-4), "طلب مكرر");

        // The pending patient is signed in on a device and has a booking next week and one last month.
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO [RefreshTokens] ([Id], [UserId], [FamilyId], [TokenHash], [CreatedAt], [ExpiresAt])
            VALUES ({Guid.NewGuid()}, {pendingUser}, {Guid.NewGuid()}, {new byte[32]}, SYSUTCDATETIME(), DATEADD(day, 30, SYSUTCDATETIME()));
            INSERT INTO [UserDevices] ([Id], [UserId], [DeviceId], [Platform], [AppVersion], [UpdatedAt])
            VALUES ({Guid.NewGuid()}, {pendingUser}, {"phone-1"}, {"android"}, {"1.0.0"}, SYSUTCDATETIME());
            """);
        var nextWeek = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(7));
        var lastMonth = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-30));
        var future = AddBooking(db, doctorId, branchId, pendingPatient, nextWeek, "confirmed");
        var past = AddBooking(db, doctorId, branchId, pendingPatient, lastMonth, "completed");
        await db.SaveChangesAsync();

        await db.GetService<IMigrator>().MigrateAsync(Migration);
        db.ChangeTracker.Clear();

        var rows = await db.DeletionRequests.AsNoTracking().ToDictionaryAsync(r => r.Id);
        var p = rows[pending];
        Assert.Equal("scheduled", p.Status);
        Assert.Equal(pendingUser, p.UserId);
        Assert.Equal("patient", p.Role);
        Assert.Equal(pendingUser, p.RequestedBy);
        Assert.Equal(createdAt, p.RequestedAt);
        Assert.Equal(createdAt.AddDays(30), p.ScheduledFor);
        Assert.Null(p.RestoredAt);

        var a = rows[approved];
        Assert.Equal("scheduled", a.Status);
        Assert.Equal(createdAt.AddDays(-10), a.ScheduledFor);
        Assert.Null(a.RestoredBy);

        var r = rows[rejected];
        Assert.Equal("restored", r.Status);
        Assert.Equal(adminId, r.RestoredBy);
        Assert.Equal(createdAt.AddDays(-4), r.RestoredAt);
        Assert.Equal("طلب مكرر", r.RestoreReason);

        // The scheduled accounts are in their grace period: out of every device, bookings ahead cancelled.
        var users = await db.Users.AsNoTracking().Where(u => u.Role == "patient").ToDictionaryAsync(u => u.Id, u => u.Status);
        Assert.Equal("pendingDeletion", users[pendingUser]);
        Assert.Equal("pendingDeletion", users[approvedUser]);
        Assert.Equal("active", users[rejectedUser]);
        Assert.Equal("active", await db.Patients.Where(x => x.Id == approvedPatient).Select(x => x.Status).SingleAsync());
        Assert.False(await db.RefreshTokens.AnyAsync(t => t.UserId == pendingUser && t.RevokedAt == null));
        Assert.False(await db.UserDevices.AnyAsync(d => d.UserId == pendingUser));
        var bookings = await db.Appointments.AsNoTracking().ToDictionaryAsync(x => x.Id);
        Assert.Equal("cancelled", bookings[future].Status);
        Assert.Equal("accountDeleted", bookings[future].CancelReason);
        Assert.Equal("completed", bookings[past].Status);
        Assert.True(await db.AppointmentHistories.AnyAsync(h => h.AppointmentId == future && h.Action == "cancelled"));
        Assert.Equal(30, await db.AppSettings.Select(s => s.AccountDeletionGraceDays).SingleAsync());

        // The new rule: one open deletion per account.
        db.DeletionRequests.Add(new DeletionRequest
        {
            Id = Guid.NewGuid(), UserId = pendingUser, Role = "patient", PatientId = pendingPatient, Status = "scheduled",
            RequestedBy = pendingUser, RequestedAt = DateTime.UtcNow, ScheduledFor = DateTime.UtcNow.AddDays(30),
        });
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();

        await db.GetService<IMigrator>().MigrateAsync(Before);
        var statuses = await db.Database.SqlQuery<string>($"SELECT [Status] AS [Value] FROM [DeletionRequests] ORDER BY [CreatedAt]").ToListAsync();
        Assert.Equal(["pending", "rejected", "pending"], statuses);
        Assert.Equal("active", await db.Database.SqlQuery<string>($"SELECT [Status] AS [Value] FROM [Users] WHERE [Id] = {pendingUser}").SingleAsync());
    }

    private static async Task<Guid> AddUserAsync(AppDbContext db, string role, string? adminRole, string status, string? phone = null, string? email = null)
    {
        var id = Guid.NewGuid();
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO [Users] ([Id], [Role], [AdminRole], [Status], [DisplayName], [Phone], [Email], [SecurityStamp], [CreatedAt], [UpdatedAt])
            VALUES ({id}, {role}, {adminRole}, {status}, {"تجربة"}, {phone}, {email}, NEWID(), SYSUTCDATETIME(), SYSUTCDATETIME())
            """);
        return id;
    }

    private static async Task<(Guid UserId, Guid PatientId)> AddPatientAsync(AppDbContext db, string phone, string userStatus, string patientStatus)
    {
        var userId = await AddUserAsync(db, "patient", null, userStatus, phone: phone);
        var patientId = Guid.NewGuid();
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO [Patients] ([Id], [UserId], [FullName], [Phone], [Gender], [DateOfBirth], [Status], [CreatedAt], [UpdatedAt])
            VALUES ({patientId}, {userId}, {"منى حسن"}, {phone}, {"female"}, {new DateOnly(1990, 1, 1)}, {patientStatus}, SYSUTCDATETIME(), SYSUTCDATETIME())
            """);
        return (userId, patientId);
    }

    private static async Task<Guid> AddRequestAsync(
        AppDbContext db, Guid patientId, string status, DateTime createdAt, Guid? reviewedBy, DateTime? reviewedAt, string? note)
    {
        var id = Guid.NewGuid();
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO [DeletionRequests] ([Id], [PatientId], [Reason], [Status], [ReviewedBy], [ReviewedAt], [ReviewNote], [CreatedAt])
            VALUES ({id}, {patientId}, {"مش محتاج التطبيق"}, {status}, {reviewedBy}, {reviewedAt}, {note}, {createdAt})
            """);
        return id;
    }

    private static Guid AddBooking(AppDbContext db, Guid doctorId, Guid branchId, Guid patientId, DateOnly day, string status)
    {
        var start = new DateTime(day.Year, day.Month, day.Day, 16, 0, 0, DateTimeKind.Utc);
        var booking = new Appointment
        {
            Id = Guid.NewGuid(), DoctorId = doctorId, BranchId = branchId, PatientId = patientId, VisitType = "examination", Mode = "queue",
            LocalDate = day, PeriodStartLocal = new TimeOnly(18, 0), StartUtc = start, EndUtc = start.AddHours(4),
            QueueNumber = status == "completed" ? 1 : null, Status = status, Source = "patientApp", BookedBy = doctorId, BookedByRole = "doctor",
            CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow,
        };
        db.Appointments.Add(booking);
        return booking.Id;
    }

    private static async Task<(Guid DoctorId, Guid BranchId)> CreateClinicAsync(AppDbContext db)
    {
        var userId = await AddUserAsync(db, "doctor", null, "active", email: $"{Guid.NewGuid():N}@el3yada.dev");
        var specialtyId = await db.Specialties.Select(s => s.Id).FirstAsync();
        var licensePath = $"doctors/{userId}/license/card.jpg";
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO [Doctors] ([UserId], [FullName], [Title], [SpecialtyId], [LicenseNumber], [LicenseDocPath], [CreatedAt], [UpdatedAt])
            VALUES ({userId}, {"د. تجربة"}, {"أخصائي"}, {specialtyId}, {"12345"}, {licensePath}, SYSUTCDATETIME(), SYSUTCDATETIME())
            """);
        var branch = new Branch { Id = Guid.NewGuid(), DoctorId = userId, NameAr = "فرع المعادي", Governorate = "القاهرة", City = "المعادي", AddressDetails = "شارع 9" };
        db.Branches.Add(branch);
        await db.SaveChangesAsync();
        return (userId, branch.Id);
    }
}
