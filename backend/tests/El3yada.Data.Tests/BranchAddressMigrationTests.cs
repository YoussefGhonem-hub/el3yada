using System.Globalization;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace El3yada.Data.Tests;

/// <summary>
/// The data copy in BranchAddressDetailsAndMapUrl, on its own database stopped at the migration before it:
/// branches written with the old columns, then the migration up, then down.
/// </summary>
public sealed class BranchAddressMigrationTests : IAsyncLifetime
{
    private const string Before = "20261115205913_SoftDeleteMedicalProfileItems";
    private const string Migration = "20261116080453_BranchAddressDetailsAndMapUrl";

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
    public async Task Up_joins_the_old_parts_and_makes_the_pin_a_link_and_down_puts_them_back()
    {
        await using var db = MigratedDatabase.CreateContext(_connectionString);
        var doctorId = await CreateDoctorAsync(db);
        var full = await InsertOldBranchAsync(db, doctorId, "شارع 9", "12", "3", "5", 30.038m, 31.211m);
        var partial = await InsertOldBranchAsync(db, doctorId, "  شارع التحرير ", null, "  ", "شقة 4", null, null);
        var labelled = await InsertOldBranchAsync(db, doctorId, "عباس العقاد", "عمارة النور", "الدور الأول", null, -1.5m, null);

        await db.GetService<IMigrator>().MigrateAsync(Migration);

        db.ChangeTracker.Clear();
        var rows = await db.Branches.AsNoTracking().ToDictionaryAsync(b => b.Id);
        Assert.Equal("شارع 9، عمارة 12، الدور 3، شقة 5", rows[full].AddressDetails);
        Assert.Equal("https://www.google.com/maps/search/?api=1&query=30.038000,31.211000", rows[full].MapUrl);
        Assert.Equal("شارع التحرير، شقة 4", rows[partial].AddressDetails);
        Assert.Null(rows[partial].MapUrl);
        Assert.Equal("عباس العقاد، عمارة النور، الدور الأول", rows[labelled].AddressDetails);
        Assert.Null(rows[labelled].MapUrl); // a pin needs both numbers
        Assert.Empty(await db.Database.GetPendingMigrationsAsync());

        await db.GetService<IMigrator>().MigrateAsync(Before);

        var old = await db.Database
            .SqlQueryRaw<OldAddress>("SELECT [Id], [Street], [Building], [Floor], [Apartment], [Lat], [Lng] FROM [Branches]")
            .ToDictionaryAsync(b => b.Id);
        Assert.Equal("شارع 9، عمارة 12، الدور 3، شقة 5", old[full].Street);
        Assert.Null(old[full].Building);
        Assert.Equal(30.038m, old[full].Lat);
        Assert.Equal(31.211m, old[full].Lng);
        Assert.Equal("شارع التحرير، شقة 4", old[partial].Street);
        Assert.Null(old[partial].Lat);
        Assert.Null(old[labelled].Lng);
    }

    private sealed class OldAddress
    {
        public Guid Id { get; set; }
        public string Street { get; set; } = "";
        public string? Building { get; set; }
        public string? Floor { get; set; }
        public string? Apartment { get; set; }
        public decimal? Lat { get; set; }
        public decimal? Lng { get; set; }
    }

    private static async Task<Guid> InsertOldBranchAsync(
        AppDbContext db, Guid doctorId, string street, string? building, string? floor, string? apartment, decimal? lat, decimal? lng)
    {
        var id = Guid.NewGuid();
        // As text: a raw decimal parameter is sent as decimal(18,2), which would round the pin.
        var latText = lat?.ToString(CultureInfo.InvariantCulture);
        var lngText = lng?.ToString(CultureInfo.InvariantCulture);
        await db.Database.ExecuteSqlAsync($"""
            INSERT INTO [Branches] ([Id], [DoctorId], [NameAr], [Governorate], [City], [Street], [Building], [Floor], [Apartment], [Lat], [Lng])
            VALUES ({id}, {doctorId}, N'فرع المعادي', N'القاهرة', N'المعادي', {street}, {building}, {floor}, {apartment},
                CAST({latText} AS decimal(9, 6)), CAST({lngText} AS decimal(9, 6)))
            """);
        return id;
    }

    // Users and Doctors are the same before and after this migration, so the current model can write them.
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
