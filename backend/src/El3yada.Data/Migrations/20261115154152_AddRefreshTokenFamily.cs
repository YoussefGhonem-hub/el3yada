using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <summary>
    /// Phase 1: RefreshTokens.FamilyId, the sign-in a refresh token belongs to. Rotating a token keeps
    /// its family; a rotated token that comes back revokes the whole family (reuse detection).
    /// Existing rows become their own family. The column is added nullable, filled, then made NOT NULL,
    /// so no DEFAULT constraint is left behind.
    /// </summary>
    public partial class AddRefreshTokenFamily : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "FamilyId",
                table: "RefreshTokens",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.Sql("UPDATE [RefreshTokens] SET [FamilyId] = [Id] WHERE [FamilyId] IS NULL;");

            migrationBuilder.AlterColumn<Guid>(
                name: "FamilyId",
                table: "RefreshTokens",
                type: "uniqueidentifier",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_FamilyId",
                table: "RefreshTokens",
                column: "FamilyId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RefreshTokens_FamilyId",
                table: "RefreshTokens");

            migrationBuilder.DropColumn(
                name: "FamilyId",
                table: "RefreshTokens");
        }
    }
}
