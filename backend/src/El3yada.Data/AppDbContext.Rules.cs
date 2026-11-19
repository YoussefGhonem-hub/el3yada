using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Conventions;

namespace El3yada.Data;

/// <summary>
/// Model rules that AppDbContext.cs (generated from database/schema.sql) can't express:
/// CHECK constraints, zero defaults, an INCLUDE index, and how defaults are sent.
/// </summary>
public partial class AppDbContext
{
    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        // Indexes are chosen per query in the schema design, so EF must not add one for every foreign key.
        configurationBuilder.Conventions.Remove(typeof(ForeignKeyIndexConvention));
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder)
    {
        // The audit log key is an IDENTITY column (BIGINT, high volume, ordered by insert).
        modelBuilder.Entity<AuditLog>().Property(e => e.Id).UseIdentityColumn();

        // Covering index for the month totals (D3, month close).
        modelBuilder.Entity<Session>()
            .HasIndex(e => new { e.DoctorId, e.MonthKey, e.Deleted }, "IX_Sessions_Doctor_Month")
            .IncludeProperties(e => new { e.Type, e.FeePiasters, e.BranchId });

        // CHECK constraints (enums, ranges, permission dependencies). See CheckConstraints.cs.
        foreach (var (table, name, sql) in CheckConstraints.All)
        {
            modelBuilder.Entity(EntityFor(modelBuilder, table).Name)
                .ToTable(table, t => t.HasCheckConstraint(name, sql));
        }

        // DEFAULT 0 / DEFAULT false columns. See ZeroDefaults.cs.
        foreach (var (table, column) in ZeroDefaults.All)
        {
            var entityType = EntityFor(modelBuilder, table);
            var property = entityType.GetProperties().Single(p => p.GetColumnName() == column);
            modelBuilder.Entity(entityType.Name).Property(property.Name)
                .HasDefaultValue(Activator.CreateInstance(property.ClrType));
        }

        // Columns with a constant database default (for example SelfBooking = 1, MaxReschedules = 2)
        // are always sent by the app. Otherwise EF skips false / 0 on insert and the database
        // default wins, so a doctor who switches self-booking off would get it on.
        // The entity classes start with the same defaults as the database.
        foreach (var entityType in modelBuilder.Model.GetEntityTypes().Where(e => !e.IsPropertyBag))
        {
            foreach (var property in entityType.GetProperties().Where(p => p.GetDefaultValue() is not null))
            {
                modelBuilder.Entity(entityType.Name).Property(property.Name).ValueGeneratedNever();
            }
        }

        // The model treats keys as set by the app (GUID keys: see NewId in the API). The audit
        // log key is the exception: SQL Server fills the IDENTITY, so EF must not send a value.
        modelBuilder.Entity<AuditLog>().Property(e => e.Id).ValueGeneratedOnAdd();
    }

    private static Microsoft.EntityFrameworkCore.Metadata.IMutableEntityType EntityFor(ModelBuilder modelBuilder, string table) =>
        modelBuilder.Model.GetEntityTypes().Single(e => !e.IsPropertyBag && e.GetTableName() == table);
}
