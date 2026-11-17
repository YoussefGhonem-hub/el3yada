using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <summary>
    /// The free trial (spec 6.16): <c>Doctors.TrialEndsAt</c>, set at approval (null = no trial, the service is active,
    /// which is what every doctor approved before this change gets), and <c>AppSettings.TrialDays</c> (1–90, default 14).
    /// </summary>
    public partial class DoctorFreeTrial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "TrialEndsAt",
                table: "Doctors",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TrialDays",
                table: "AppSettings",
                type: "int",
                nullable: false,
                defaultValue: 14);

            migrationBuilder.AddCheckConstraint(
                name: "CK_AppSettings_TrialDays",
                table: "AppSettings",
                sql: "([TrialDays]>=(1) AND [TrialDays]<=(90))");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_AppSettings_TrialDays",
                table: "AppSettings");

            migrationBuilder.DropColumn(
                name: "TrialEndsAt",
                table: "Doctors");

            migrationBuilder.DropColumn(
                name: "TrialDays",
                table: "AppSettings");
        }
    }
}
