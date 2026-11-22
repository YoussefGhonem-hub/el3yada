using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <summary>
    /// Account deletion for every role (spec 6.17), replacing the patient-only request and approval of Phase 4:
    /// <list type="bullet">
    /// <item><c>DeletionRequests</c> becomes one row per deletion of any account: UserId, Role, PatientId / DoctorId /
    /// AssistantId, Reason, Status (<c>scheduled</c>, <c>waitingPayment</c>, <c>restored</c>, <c>completed</c>), RequestedBy,
    /// RequestedAt (was CreatedAt), ScheduledFor, RestoredAt / RestoredBy / RestoreReason (were the review columns),
    /// CompletedAt and FinalInvoiceId. One open deletion per account (UQ_DeletionRequests_User_Open).</item>
    /// <item>Users.Status gains <c>pendingDeletion</c> and <c>deleted</c> (the column grows to 16 characters).</item>
    /// <item>Invoices.IsFinal (a month closed early by a doctor's deletion) and InvoiceAdjustments.CarriedMonthKey
    /// (fees carried from a final invoice; such lines have no CreatedBy, which becomes nullable).</item>
    /// <item>AppSettings.AccountDeletionGraceDays (7–90, default 30).</item>
    /// </list>
    /// <para>
    /// Existing rows: a <c>pending</c> request becomes <c>scheduled</c>, its grace period counted from its CreatedAt, and
    /// the account is put in the grace period as a new request would be (signed out, push devices removed, future
    /// bookings cancelled). An <c>approved</c> one (disabled but never erased) is treated the same way, so the daily job
    /// erases it once its grace period has passed. A <c>rejected</c> one becomes <c>restored</c>, keeping the reviewer and
    /// note as RestoredBy and RestoreReason.
    /// </para>
    /// </summary>
    public partial class AccountDeletion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DeletionRequests_ReviewedBy",
                table: "DeletionRequests");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Users_Status",
                table: "Users");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Users",
                type: "varchar(16)",
                unicode: false,
                maxLength: 16,
                nullable: false,
                defaultValue: "active",
                oldClrType: typeof(string),
                oldType: "varchar(10)",
                oldUnicode: false,
                oldMaxLength: 10,
                oldDefaultValue: "active");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Users_Status",
                table: "Users",
                sql: "([Status]='deleted' OR [Status]='pendingDeletion' OR [Status]='disabled' OR [Status]='active')");

            migrationBuilder.DropIndex(
                name: "IX_DeletionRequests_Status",
                table: "DeletionRequests");

            migrationBuilder.DropCheckConstraint(
                name: "CK_DeletionRequests_Status",
                table: "DeletionRequests");

            migrationBuilder.RenameColumn(
                name: "ReviewedBy",
                table: "DeletionRequests",
                newName: "RestoredBy");

            migrationBuilder.RenameColumn(
                name: "ReviewedAt",
                table: "DeletionRequests",
                newName: "RestoredAt");

            migrationBuilder.RenameColumn(
                name: "ReviewNote",
                table: "DeletionRequests",
                newName: "RestoreReason");

            migrationBuilder.RenameColumn(
                name: "CreatedAt",
                table: "DeletionRequests",
                newName: "RequestedAt");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "DeletionRequests",
                type: "varchar(14)",
                unicode: false,
                maxLength: 14,
                nullable: false,
                defaultValue: "scheduled",
                oldClrType: typeof(string),
                oldType: "varchar(8)",
                oldUnicode: false,
                oldMaxLength: 8,
                oldDefaultValue: "pending");

            migrationBuilder.AlterColumn<Guid>(
                name: "PatientId",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier");

            migrationBuilder.AddColumn<Guid>(
                name: "AssistantId",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CompletedAt",
                table: "DeletionRequests",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "DoctorId",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "FinalInvoiceId",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: true);

            // Required columns start nullable, are filled from the old rows below, then become NOT NULL.
            migrationBuilder.AddColumn<Guid>(
                name: "RequestedBy",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Role",
                table: "DeletionRequests",
                type: "varchar(10)",
                unicode: false,
                maxLength: 10,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ScheduledFor",
                table: "DeletionRequests",
                type: "datetime2(3)",
                precision: 3,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "UserId",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsFinal",
                table: "Invoices",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AlterColumn<Guid>(
                name: "CreatedBy",
                table: "InvoiceAdjustments",
                type: "uniqueidentifier",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier");

            migrationBuilder.AddColumn<string>(
                name: "CarriedMonthKey",
                table: "InvoiceAdjustments",
                type: "char(7)",
                unicode: false,
                fixedLength: true,
                maxLength: 7,
                nullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "CK_InvoiceAdjustments_CarriedMonthKey",
                table: "InvoiceAdjustments",
                sql: "([CarriedMonthKey] IS NULL OR [CarriedMonthKey] like '[12][0-9][0-9][0-9]-[01][0-9]')");

            migrationBuilder.AddColumn<int>(
                name: "AccountDeletionGraceDays",
                table: "AppSettings",
                type: "int",
                nullable: false,
                defaultValue: 30);

            migrationBuilder.AddCheckConstraint(
                name: "CK_AppSettings_DeletionGraceDays",
                table: "AppSettings",
                sql: "([AccountDeletionGraceDays]>=(7) AND [AccountDeletionGraceDays]<=(90))");

            // The old rows, all patients'. Pending and approved: scheduled, counted from CreatedAt. Rejected: restored.
            migrationBuilder.Sql("""
                UPDATE r SET
                    r.[UserId] = p.[UserId],
                    r.[Role] = 'patient',
                    r.[RequestedBy] = p.[UserId],
                    r.[ScheduledFor] = DATEADD(day, COALESCE((SELECT TOP (1) [AccountDeletionGraceDays] FROM [AppSettings]), 30), r.[RequestedAt])
                FROM [DeletionRequests] r
                JOIN [Patients] p ON p.[Id] = r.[PatientId];

                UPDATE [DeletionRequests]
                SET [Status] = 'restored', [RestoredAt] = COALESCE([RestoredAt], [RequestedAt])
                WHERE [Status] = 'rejected';

                UPDATE [DeletionRequests]
                SET [Status] = 'scheduled', [RestoredAt] = NULL, [RestoredBy] = NULL, [RestoreReason] = NULL
                WHERE [Status] IN ('pending', 'approved');

                -- One open deletion per account: an older open row (never expected) counts as restored.
                WITH [ranked] AS (
                    SELECT [Id], ROW_NUMBER() OVER (PARTITION BY [UserId] ORDER BY [RequestedAt] DESC, [Id] DESC) AS [n]
                    FROM [DeletionRequests] WHERE [Status] = 'scheduled')
                UPDATE r SET r.[Status] = 'restored', r.[RestoredAt] = r.[RequestedAt]
                FROM [DeletionRequests] r JOIN [ranked] ON [ranked].[Id] = r.[Id]
                WHERE [ranked].[n] > 1;
                """);

            // Their accounts enter the grace period as a new request's would (BR-DEL2, BR-AP18).
            migrationBuilder.Sql("""
                DECLARE @now datetime2(3) = SYSUTCDATETIME();
                DECLARE @today date = CAST(CAST(@now AS datetimeoffset) AT TIME ZONE 'Egypt Standard Time' AS date);

                UPDATE u SET u.[Status] = 'pendingDeletion', u.[SecurityStamp] = NEWID(), u.[UpdatedAt] = @now
                FROM [Users] u JOIN [DeletionRequests] r ON r.[UserId] = u.[Id]
                WHERE r.[Status] = 'scheduled';

                -- The old approval marked the patient deleted without erasing anything; erasure does that now.
                UPDATE p SET p.[Status] = 'active', p.[DeletedAt] = NULL
                FROM [Patients] p JOIN [DeletionRequests] r ON r.[PatientId] = p.[Id]
                WHERE r.[Status] = 'scheduled' AND p.[Status] = 'deleted';

                UPDATE t SET t.[RevokedAt] = @now
                FROM [RefreshTokens] t JOIN [DeletionRequests] r ON r.[UserId] = t.[UserId]
                WHERE r.[Status] = 'scheduled' AND t.[RevokedAt] IS NULL;

                DELETE d FROM [UserDevices] d JOIN [DeletionRequests] r ON r.[UserId] = d.[UserId]
                WHERE r.[Status] = 'scheduled';

                INSERT INTO [AppointmentHistory] ([Id], [AppointmentId], [At], [ByRole], [Action], [Reason])
                SELECT NEWID(), a.[Id], @now, 'system', 'cancelled', 'accountDeleted'
                FROM [Appointments] a JOIN [DeletionRequests] r ON r.[PatientId] = a.[PatientId]
                WHERE r.[Status] = 'scheduled' AND a.[LocalDate] >= @today AND a.[Status] IN ('pending', 'confirmed');

                UPDATE a SET a.[Status] = 'cancelled', a.[CancelledAt] = @now, a.[CancelledByRole] = 'system',
                    a.[CancelReason] = 'accountDeleted', a.[UpdatedAt] = @now
                FROM [Appointments] a JOIN [DeletionRequests] r ON r.[PatientId] = a.[PatientId]
                WHERE r.[Status] = 'scheduled' AND a.[LocalDate] >= @today AND a.[Status] IN ('pending', 'confirmed');
                """);

            migrationBuilder.AlterColumn<Guid>(
                name: "UserId",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "RequestedBy",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Role",
                table: "DeletionRequests",
                type: "varchar(10)",
                unicode: false,
                maxLength: 10,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "varchar(10)",
                oldUnicode: false,
                oldMaxLength: 10,
                oldNullable: true);

            migrationBuilder.AlterColumn<DateTime>(
                name: "ScheduledFor",
                table: "DeletionRequests",
                type: "datetime2(3)",
                precision: 3,
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "datetime2(3)",
                oldPrecision: 3,
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_DeletionRequests_Status",
                table: "DeletionRequests",
                columns: new[] { "Status", "ScheduledFor" });

            migrationBuilder.CreateIndex(
                name: "IX_DeletionRequests_User",
                table: "DeletionRequests",
                columns: new[] { "UserId", "RequestedAt" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "UQ_DeletionRequests_User_Open",
                table: "DeletionRequests",
                column: "UserId",
                unique: true,
                filter: "([Status] IN ('scheduled', 'waitingPayment'))");

            migrationBuilder.AddCheckConstraint(
                name: "CK_DeletionRequests_Role",
                table: "DeletionRequests",
                sql: "([Role]='patient' AND [PatientId] IS NOT NULL OR [Role]='doctor' AND [DoctorId] IS NOT NULL OR [Role]='assistant' AND [AssistantId] IS NOT NULL OR [Role]='admin')");

            migrationBuilder.AddCheckConstraint(
                name: "CK_DeletionRequests_Status",
                table: "DeletionRequests",
                sql: "([Status]='completed' OR [Status]='restored' OR [Status]='waitingPayment' OR [Status]='scheduled')");

            migrationBuilder.AddForeignKey(
                name: "FK_DeletionRequests_AssistantId",
                table: "DeletionRequests",
                column: "AssistantId",
                principalTable: "Assistants",
                principalColumn: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_DeletionRequests_DoctorId",
                table: "DeletionRequests",
                column: "DoctorId",
                principalTable: "Doctors",
                principalColumn: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_DeletionRequests_FinalInvoiceId",
                table: "DeletionRequests",
                column: "FinalInvoiceId",
                principalTable: "Invoices",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_DeletionRequests_RequestedBy",
                table: "DeletionRequests",
                column: "RequestedBy",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_DeletionRequests_RestoredBy",
                table: "DeletionRequests",
                column: "RestoredBy",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_DeletionRequests_UserId",
                table: "DeletionRequests",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DeletionRequests_AssistantId",
                table: "DeletionRequests");

            migrationBuilder.DropForeignKey(
                name: "FK_DeletionRequests_DoctorId",
                table: "DeletionRequests");

            migrationBuilder.DropForeignKey(
                name: "FK_DeletionRequests_FinalInvoiceId",
                table: "DeletionRequests");

            migrationBuilder.DropForeignKey(
                name: "FK_DeletionRequests_RequestedBy",
                table: "DeletionRequests");

            migrationBuilder.DropForeignKey(
                name: "FK_DeletionRequests_RestoredBy",
                table: "DeletionRequests");

            migrationBuilder.DropForeignKey(
                name: "FK_DeletionRequests_UserId",
                table: "DeletionRequests");

            migrationBuilder.DropIndex(
                name: "IX_DeletionRequests_Status",
                table: "DeletionRequests");

            migrationBuilder.DropIndex(
                name: "IX_DeletionRequests_User",
                table: "DeletionRequests");

            migrationBuilder.DropIndex(
                name: "UQ_DeletionRequests_User_Open",
                table: "DeletionRequests");

            migrationBuilder.DropCheckConstraint(
                name: "CK_DeletionRequests_Role",
                table: "DeletionRequests");

            migrationBuilder.DropCheckConstraint(
                name: "CK_DeletionRequests_Status",
                table: "DeletionRequests");

            // Back to the patient-only queue: an open deletion is a pending request again (the account active, as the
            // old flow kept it until approval), an erased one approved, a restored one rejected. Other roles' rows
            // can't be expressed and are dropped; carried lines lose their marker, final invoices their flag.
            migrationBuilder.Sql("""
                UPDATE u SET u.[Status] = 'active'
                FROM [Users] u JOIN [DeletionRequests] r ON r.[UserId] = u.[Id]
                WHERE r.[Status] IN ('scheduled', 'waitingPayment') AND u.[Status] = 'pendingDeletion';

                UPDATE [Users] SET [Status] = 'disabled' WHERE [Status] IN ('pendingDeletion', 'deleted');

                DELETE FROM [DeletionRequests] WHERE [Role] <> 'patient';

                UPDATE [DeletionRequests] SET [Status] = CASE [Status]
                    WHEN 'completed' THEN 'approved'
                    WHEN 'restored' THEN 'rejected'
                    ELSE 'pending' END;

                UPDATE a SET a.[CreatedBy] = i.[DoctorId]
                FROM [InvoiceAdjustments] a JOIN [Invoices] i ON i.[Id] = a.[InvoiceId]
                WHERE a.[CreatedBy] IS NULL;
                """);

            migrationBuilder.DropCheckConstraint(
                name: "CK_Users_Status",
                table: "Users");

            migrationBuilder.DropCheckConstraint(
                name: "CK_InvoiceAdjustments_CarriedMonthKey",
                table: "InvoiceAdjustments");

            migrationBuilder.DropCheckConstraint(
                name: "CK_AppSettings_DeletionGraceDays",
                table: "AppSettings");

            migrationBuilder.DropColumn(
                name: "IsFinal",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "CarriedMonthKey",
                table: "InvoiceAdjustments");

            migrationBuilder.DropColumn(
                name: "AssistantId",
                table: "DeletionRequests");

            migrationBuilder.DropColumn(
                name: "CompletedAt",
                table: "DeletionRequests");

            migrationBuilder.DropColumn(
                name: "DoctorId",
                table: "DeletionRequests");

            migrationBuilder.DropColumn(
                name: "FinalInvoiceId",
                table: "DeletionRequests");

            migrationBuilder.DropColumn(
                name: "RequestedBy",
                table: "DeletionRequests");

            migrationBuilder.DropColumn(
                name: "Role",
                table: "DeletionRequests");

            migrationBuilder.DropColumn(
                name: "ScheduledFor",
                table: "DeletionRequests");

            migrationBuilder.DropColumn(
                name: "UserId",
                table: "DeletionRequests");

            migrationBuilder.DropColumn(
                name: "AccountDeletionGraceDays",
                table: "AppSettings");

            migrationBuilder.RenameColumn(
                name: "RestoredBy",
                table: "DeletionRequests",
                newName: "ReviewedBy");

            migrationBuilder.RenameColumn(
                name: "RestoredAt",
                table: "DeletionRequests",
                newName: "ReviewedAt");

            migrationBuilder.RenameColumn(
                name: "RestoreReason",
                table: "DeletionRequests",
                newName: "ReviewNote");

            migrationBuilder.RenameColumn(
                name: "RequestedAt",
                table: "DeletionRequests",
                newName: "CreatedAt");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Users",
                type: "varchar(10)",
                unicode: false,
                maxLength: 10,
                nullable: false,
                defaultValue: "active",
                oldClrType: typeof(string),
                oldType: "varchar(16)",
                oldUnicode: false,
                oldMaxLength: 16,
                oldDefaultValue: "active");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Users_Status",
                table: "Users",
                sql: "([Status]='disabled' OR [Status]='active')");

            migrationBuilder.AlterColumn<Guid>(
                name: "CreatedBy",
                table: "InvoiceAdjustments",
                type: "uniqueidentifier",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "DeletionRequests",
                type: "varchar(8)",
                unicode: false,
                maxLength: 8,
                nullable: false,
                defaultValue: "pending",
                oldClrType: typeof(string),
                oldType: "varchar(14)",
                oldUnicode: false,
                oldMaxLength: 14,
                oldDefaultValue: "scheduled");

            migrationBuilder.AlterColumn<Guid>(
                name: "PatientId",
                table: "DeletionRequests",
                type: "uniqueidentifier",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_DeletionRequests_Status",
                table: "DeletionRequests",
                columns: new[] { "Status", "CreatedAt" });

            migrationBuilder.AddCheckConstraint(
                name: "CK_DeletionRequests_Status",
                table: "DeletionRequests",
                sql: "([Status]='rejected' OR [Status]='approved' OR [Status]='pending')");

            migrationBuilder.AddForeignKey(
                name: "FK_DeletionRequests_ReviewedBy",
                table: "DeletionRequests",
                column: "ReviewedBy",
                principalTable: "Users",
                principalColumn: "Id");
        }
    }
}
