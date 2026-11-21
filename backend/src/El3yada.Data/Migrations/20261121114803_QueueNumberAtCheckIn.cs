using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <summary>
    /// BR-AP3 (product owner, 17 Nov): in queue mode the number is given at check-in, in order of arrival, not at
    /// booking. <c>CK_Appointments_Queue</c> now lets a confirmed booking (and a no-show, which never arrived) have
    /// no number; checked-in, with-the-doctor and completed queue bookings still must have one.
    /// <para>
    /// Data: queue bookings still <c>pending</c> or <c>confirmed</c> lose the number they got at booking, and their
    /// board order goes back to 0 (Expected is ordered by booking time), unless staff moved them up. They get a
    /// number when they are checked in. Down gives a number back to every queue booking the old rule needs one
    /// for, after the period's highest, in booking order.
    /// </para>
    /// </summary>
    public partial class QueueNumberAtCheckIn : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Appointments_Queue",
                table: "Appointments");

            migrationBuilder.Sql("""
                UPDATE [Appointments]
                SET [QueueNumber] = NULL,
                    [BoardOrder] = CASE WHEN [IsPriority] = 1 THEN [BoardOrder] ELSE 0 END
                WHERE [Mode] = 'queue' AND [Status] IN ('pending', 'confirmed') AND [QueueNumber] IS NOT NULL;
                """);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Appointments_Queue",
                table: "Appointments",
                sql: "([Mode]='timed' OR [QueueNumber] IS NOT NULL OR ([Status]='noShow' OR [Status]='confirmed' OR [Status]='cancelled' OR [Status]='rejected' OR [Status]='pending'))");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Appointments_Queue",
                table: "Appointments");

            migrationBuilder.Sql("""
                WITH [Numbered] AS (
                    SELECT [QueueNumber], [BoardOrder], [IsPriority], [Status],
                        ROW_NUMBER() OVER (
                            PARTITION BY [BranchId], [LocalDate], [PeriodStartLocal],
                                CASE WHEN [QueueNumber] IS NULL AND [Status] NOT IN ('cancelled', 'rejected', 'pending') THEN 1 ELSE 0 END
                            ORDER BY [CreatedAt], [Id]) AS [Seq],
                        MAX([QueueNumber]) OVER (PARTITION BY [BranchId], [LocalDate], [PeriodStartLocal]) AS [Highest]
                    FROM [Appointments]
                    WHERE [Mode] = 'queue')
                UPDATE [Numbered]
                SET [QueueNumber] = COALESCE([Highest], 0) + [Seq],
                    [BoardOrder] = CASE WHEN [IsPriority] = 1 THEN [BoardOrder] ELSE COALESCE([Highest], 0) + [Seq] END
                WHERE [QueueNumber] IS NULL AND [Status] NOT IN ('cancelled', 'rejected', 'pending');
                """);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Appointments_Queue",
                table: "Appointments",
                sql: "([Mode]='timed' OR [QueueNumber] IS NOT NULL OR ([Status]='cancelled' OR [Status]='rejected' OR [Status]='pending'))");
        }
    }
}
