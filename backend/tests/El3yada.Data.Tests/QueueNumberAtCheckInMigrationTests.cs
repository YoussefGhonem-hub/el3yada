using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace El3yada.Data.Tests;

/// <summary>
/// The data change in QueueNumberAtCheckIn (BR-AP3: the number is given at check-in), on its own database stopped
/// at the migration before it: bookings numbered the old way, then the migration up, then down.
/// </summary>
public sealed class QueueNumberAtCheckInMigrationTests : IAsyncLifetime
{
    private const string Before = "20261117080454_PrescriptionsAndCatalogs";
    private const string Migration = "20261121114803_QueueNumberAtCheckIn";

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
    public async Task Up_takes_the_number_off_bookings_not_yet_checked_in_and_down_numbers_them_again()
    {
        await using var db = MigratedDatabase.CreateContext(_connectionString);
        var (doctorId, branchId) = await CreateClinicAsync(db);
        var day = new DateOnly(2026, 11, 22);
        var evening = new TimeOnly(18, 0);
        var at = new DateTime(2026, 11, 20, 9, 0, 0, DateTimeKind.Utc);

        // The old model: numbers in booking order.
        var confirmed = Add(db, doctorId, branchId, day, evening, 1, "confirmed", at);
        var pending = Add(db, doctorId, branchId, day, evening, 2, "pending", at.AddMinutes(1));
        var checkedIn = Add(db, doctorId, branchId, day, evening, 3, "checkedIn", at.AddMinutes(2));
        var priority = Add(db, doctorId, branchId, day, evening, 4, "confirmed", at.AddMinutes(3), isPriority: true, boardOrder: -1);
        var cancelled = Add(db, doctorId, branchId, day, evening, 5, "cancelled", at.AddMinutes(4));
        var timed = Add(db, doctorId, branchId, day, evening, null, "confirmed", at.AddMinutes(5), mode: "timed", boardOrder: 1080);
        await db.SaveChangesAsync();

        await db.GetService<IMigrator>().MigrateAsync(Migration);

        db.ChangeTracker.Clear();
        var up = await db.Appointments.AsNoTracking().ToDictionaryAsync(a => a.Id);
        Assert.Null(up[confirmed].QueueNumber);
        Assert.Equal(0, up[confirmed].BoardOrder);
        Assert.Null(up[pending].QueueNumber);
        Assert.Equal(3, up[checkedIn].QueueNumber);   // arrived: keeps its number
        Assert.Equal(3, up[checkedIn].BoardOrder);
        Assert.Null(up[priority].QueueNumber);
        Assert.Equal(-1, up[priority].BoardOrder);    // a priority move keeps its place
        Assert.Equal(5, up[cancelled].QueueNumber);   // numbers are never reused
        Assert.Null(up[timed].QueueNumber);
        Assert.Equal(1080, up[timed].BoardOrder);

        // The new rule: a confirmed queue booking may have no number; a checked-in one must have one.
        db.Appointments.Add(NewAppointment(doctorId, branchId, day, evening, null, "confirmed", at.AddMinutes(6)));
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        db.Appointments.Add(NewAppointment(doctorId, branchId, day, evening, null, "checkedIn", at.AddMinutes(7)));
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();

        await db.GetService<IMigrator>().MigrateAsync(Before);

        var down = await db.Appointments.AsNoTracking().ToDictionaryAsync(a => a.Id);
        // After the period's highest (5), in booking order: the confirmed one, the priority one, the new one.
        Assert.Equal(6, down[confirmed].QueueNumber);
        Assert.Equal(6, down[confirmed].BoardOrder);
        Assert.Equal(7, down[priority].QueueNumber);
        Assert.Equal(-1, down[priority].BoardOrder);
        Assert.Null(down[pending].QueueNumber);       // the old rule let pending bookings go without
        Assert.Equal(3, down[checkedIn].QueueNumber);
        Assert.Null(down[timed].QueueNumber);
        Assert.Equal(8, down.Values.Single(a => a.CreatedAt == at.AddMinutes(6)).QueueNumber);
    }

    private static Guid Add(AppDbContext db, Guid doctorId, Guid branchId, DateOnly day, TimeOnly period, int? number, string status, DateTime createdAt,
        string mode = "queue", bool isPriority = false, int? boardOrder = null)
    {
        var a = NewAppointment(doctorId, branchId, day, period, number, status, createdAt, mode);
        a.IsPriority = isPriority;
        a.BoardOrder = boardOrder ?? number ?? 0;
        db.Appointments.Add(a);
        return a.Id;
    }

    private static Appointment NewAppointment(Guid doctorId, Guid branchId, DateOnly day, TimeOnly period, int? number, string status, DateTime createdAt,
        string mode = "queue") => new()
    {
        Id = Guid.NewGuid(),
        DoctorId = doctorId,
        BranchId = branchId,
        GuestName = "زائر تجربة",
        GuestPhone = "+201011111111",
        VisitType = "examination",
        Mode = mode,
        LocalDate = day,
        PeriodStartLocal = period,
        StartUtc = new DateTime(2026, 11, 22, 16, 0, 0, DateTimeKind.Utc),
        EndUtc = new DateTime(2026, 11, 22, 20, 0, 0, DateTimeKind.Utc),
        QueueNumber = number,
        Status = status,
        Source = "staff",
        BookedBy = doctorId,
        BookedByRole = "doctor",
        CancelledByRole = status == "cancelled" ? "clinic" : null,
        CreatedAt = createdAt,
        UpdatedAt = createdAt,
    };

    private static async Task<(Guid DoctorId, Guid BranchId)> CreateClinicAsync(AppDbContext db)
    {
        var userId = Guid.NewGuid();
        var specialtyId = await db.Specialties.Select(s => s.Id).FirstAsync();
        db.Users.Add(new User { Id = userId, Role = "doctor", DisplayName = "د. تجربة", Email = $"{userId:N}@el3yada.dev" });
        await db.SaveChangesAsync();
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
