using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <summary>
    /// Phase 3 medical files: <c>PendingUploads</c> (files waiting for createRecord, 24 hours at most) and
    /// <c>MedicalRecordAttachments.StoredSizeBytes</c> (the size on disk, smaller when gzip-compressed).
    /// </summary>
    public partial class MedicalFileStorage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<long>(
                name: "StoredSizeBytes",
                table: "MedicalRecordAttachments",
                type: "bigint",
                nullable: false,
                defaultValue: 0L);

            migrationBuilder.CreateTable(
                name: "PendingUploads",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UploadedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Path = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: false),
                    ThumbPath = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    FileName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    MimeType = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    StoredSizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    OriginalSizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    PageCount = table.Column<int>(type: "int", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PendingUploads", x => x.Id);
                    table.CheckConstraint("CK_PendingUploads_Sizes", "([SizeBytes]>(0) AND [StoredSizeBytes]>(0) AND [OriginalSizeBytes]>(0))");
                    table.ForeignKey(
                        name: "FK_PendingUploads_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_PendingUploads_UploadedBy",
                        column: x => x.UploadedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            // Files saved before this change were stored as uploaded.
            migrationBuilder.Sql("UPDATE [MedicalRecordAttachments] SET [StoredSizeBytes] = [SizeBytes];");

            migrationBuilder.AddCheckConstraint(
                name: "CK_MedicalRecordAttachments_StoredSize",
                table: "MedicalRecordAttachments",
                sql: "([StoredSizeBytes]>(0))");

            migrationBuilder.CreateIndex(
                name: "IX_PendingUploads_DoctorId",
                table: "PendingUploads",
                column: "DoctorId");

            migrationBuilder.CreateIndex(
                name: "IX_PendingUploads_ExpiresAt",
                table: "PendingUploads",
                column: "ExpiresAt");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PendingUploads");

            migrationBuilder.DropCheckConstraint(
                name: "CK_MedicalRecordAttachments_StoredSize",
                table: "MedicalRecordAttachments");

            migrationBuilder.DropColumn(
                name: "StoredSizeBytes",
                table: "MedicalRecordAttachments");
        }
    }
}
