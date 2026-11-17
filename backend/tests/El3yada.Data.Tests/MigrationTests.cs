using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Data.Tests;

public class MigrationTests(MigratedDatabase database) : IClassFixture<MigratedDatabase>
{
    [Fact]
    public async Task Migrations_create_every_table_and_the_starting_data()
    {
        await using var db = database.CreateContext();

        var tables = await db.Database
            .SqlQueryRaw<int>("SELECT COUNT(*) AS Value FROM sys.tables WHERE name <> '__EFMigrationsHistory'")
            .SingleAsync();
        // The 55 tables of database/schema.sql, plus PendingUploads (Phase 3, migration MedicalFileStorage).
        Assert.Equal(56, tables);

        Assert.Empty(await db.Database.GetPendingMigrationsAsync());

        var settings = await db.AppSettings.SingleAsync();
        Assert.Equal(3000, settings.ExamFeePiasters);
        Assert.Equal(1500, settings.ConsultationFeePiasters);
        Assert.Equal(7, settings.GracePeriodDays);
        Assert.Equal(19, await db.Specialties.CountAsync());
    }

    [Fact]
    public void Model_and_migrations_are_in_sync()
    {
        // Fails when someone changes an entity without running `dotnet ef migrations add`.
        using var db = database.CreateContext();
        Assert.False(db.Database.HasPendingModelChanges());
    }

    [Fact]
    public void New_entities_start_with_the_spec_defaults()
    {
        var branch = new Branch();
        Assert.True(branch.SelfBooking);
        Assert.True(branch.AutoConfirm);
        Assert.Equal("queue", branch.BookingMode);
        Assert.Equal(15, branch.SlotMinutes);
        Assert.Equal(2, branch.MaxReschedules);
        Assert.Equal("pendingApproval", new Doctor().Status);
        Assert.Equal("ar", new User().Locale);
    }

    [Fact]
    public async Task False_and_zero_are_saved_as_set_not_replaced_by_the_database_default()
    {
        var branchId = await CreateBranchAsync(branch =>
        {
            branch.SelfBooking = false;     // DB default 1
            branch.AutoConfirm = false;     // DB default 1
            branch.MaxReschedules = 0;      // DB default 2
            branch.MinNoticeMinutes = 0;    // DB default 60
            branch.FreeCancelMinutes = 0;   // DB default 120
        });

        await using var db = database.CreateContext();
        var saved = await db.Branches.SingleAsync(b => b.Id == branchId);
        Assert.False(saved.SelfBooking);
        Assert.False(saved.AutoConfirm);
        Assert.Equal(0, saved.MaxReschedules);
        Assert.Equal(0, saved.MinNoticeMinutes);
        Assert.Equal(0, saved.FreeCancelMinutes);
    }

    [Fact]
    public async Task Audit_rows_get_their_id_from_the_identity_column()
    {
        await using var db = database.CreateContext();
        var first = new AuditLog { ActorRole = "system", Action = "test", TargetType = "user", At = DateTime.UtcNow };
        var second = new AuditLog { ActorRole = "system", Action = "test", TargetType = "user", At = DateTime.UtcNow };
        db.AuditLogs.AddRange(first, second);

        await db.SaveChangesAsync();

        Assert.True(first.Id > 0);
        Assert.True(second.Id > first.Id);
    }

    [Fact]
    public async Task A_doctor_can_have_more_than_one_branch()
    {
        var firstBranch = await CreateBranchAsync(_ => { });
        await using var db = database.CreateContext();
        var doctorId = await db.Branches.Where(b => b.Id == firstBranch).Select(b => b.DoctorId).SingleAsync();
        db.Branches.Add(new Branch
        {
            Id = Guid.NewGuid(), DoctorId = doctorId, NameAr = "فرع مدينة نصر", Governorate = "القاهرة", City = "مدينة نصر", AddressDetails = "عباس العقاد",
        });

        await db.SaveChangesAsync();

        Assert.Equal(2, await db.Branches.CountAsync(b => b.DoctorId == doctorId));
    }

    [Fact]
    public async Task Database_rejects_an_assistant_permission_without_its_dependency()
    {
        await using var db = database.CreateContext();
        var doctorId = await CreateDoctorAsync(db);
        var assistantUserId = Guid.NewGuid();
        db.Users.Add(new User { Id = assistantUserId, Role = "assistant", DisplayName = "سكرتير", Phone = "+201000000009" });
        db.Assistants.Add(new Assistant
        {
            UserId = assistantUserId,
            DoctorId = doctorId,
            FullName = "سكرتير",
            Phone = "+201000000009",
            CreatedBy = doctorId,
            BillingPay = true,   // needs BillingView (spec 6.10)
            BillingView = false,
        });

        var error = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        Assert.Contains("CK_Assistants_Deps", error.InnerException?.Message);
    }

    private async Task<Guid> CreateBranchAsync(Action<Branch> configure)
    {
        await using var db = database.CreateContext();
        var doctorId = await CreateDoctorAsync(db);
        var branch = new Branch
        {
            Id = Guid.NewGuid(),
            DoctorId = doctorId,
            NameAr = "فرع المعادي",
            Governorate = "القاهرة",
            City = "المعادي",
            AddressDetails = "شارع 9",
        };
        configure(branch);
        db.Branches.Add(branch);
        await db.SaveChangesAsync();
        return branch.Id;
    }

    private static async Task<Guid> CreateDoctorAsync(AppDbContext db)
    {
        var userId = Guid.NewGuid();
        var specialtyId = await db.Specialties.Select(s => s.Id).FirstAsync();
        db.Users.Add(new User { Id = userId, Role = "doctor", DisplayName = "د. تجربة", Email = $"{userId:N}@el3yada.dev" });
        db.Doctors.Add(new Doctor
        {
            UserId = userId,
            FullName = "د. تجربة",
            Title = "أخصائي",
            SpecialtyId = specialtyId,
            LicenseNumber = "12345",
            LicenseDocPath = $"doctors/{userId}/license/card.jpg",
        });
        await db.SaveChangesAsync();
        return userId;
    }
}
