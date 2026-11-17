using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <summary>
    /// Phase 3 prescriptions and catalogs:
    /// <list type="bullet">
    /// <item><c>Prescriptions.FollowUpDate</c>: «موعد المتابعة» / «إحضار النتائج في» on the printed page (spec 6.4.1 zone 6).</item>
    /// <item>The clinic colour default becomes the brand pine #0F4C45 (D22). Doctors still on the old default move with it:
    /// nobody could pick a colour before Phase 3.</item>
    /// <item>The General specialty profile (BR-CAT3): a Specialties row "General" / «عام», inactive so sign-up never
    /// lists it. Its items come from <c>seed-specialty-profiles</c> or AD19.</item>
    /// </list>
    /// </summary>
    public partial class PrescriptionsAndCatalogs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateOnly>(
                name: "FollowUpDate",
                table: "Prescriptions",
                type: "date",
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "RxAccentColor",
                table: "Doctors",
                type: "char(7)",
                unicode: false,
                fixedLength: true,
                maxLength: 7,
                nullable: false,
                defaultValue: "#0F4C45",
                oldClrType: typeof(string),
                oldType: "char(7)",
                oldUnicode: false,
                oldFixedLength: true,
                oldMaxLength: 7,
                oldDefaultValue: "#0B5C8E");

            migrationBuilder.Sql("UPDATE [Doctors] SET [RxAccentColor] = '#0F4C45' WHERE [RxAccentColor] = '#0B5C8E';");
            migrationBuilder.Sql("""
                IF NOT EXISTS (SELECT 1 FROM [Specialties] WHERE [NameEn] = N'General')
                    INSERT INTO [Specialties] ([NameAr], [NameEn], [Active], [SortOrder], [IncludeGeneral])
                    VALUES (N'عام', N'General', 0, 0, 0);
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DELETE i FROM [SpecialtyProfileItems] i JOIN [Specialties] s ON s.[Id] = i.[SpecialtyId] WHERE s.[NameEn] = N'General';
                DELETE FROM [Specialties] WHERE [NameEn] = N'General'
                    AND NOT EXISTS (SELECT 1 FROM [Doctors] d WHERE d.[SpecialtyId] = [Specialties].[Id]);
                """);

            migrationBuilder.DropColumn(
                name: "FollowUpDate",
                table: "Prescriptions");

            migrationBuilder.AlterColumn<string>(
                name: "RxAccentColor",
                table: "Doctors",
                type: "char(7)",
                unicode: false,
                fixedLength: true,
                maxLength: 7,
                nullable: false,
                defaultValue: "#0B5C8E",
                oldClrType: typeof(string),
                oldType: "char(7)",
                oldUnicode: false,
                oldFixedLength: true,
                oldMaxLength: 7,
                oldDefaultValue: "#0F4C45");
        }
    }
}
