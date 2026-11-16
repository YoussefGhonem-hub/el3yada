using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <summary>
    /// A branch's address: Street, Building, Floor and Apartment become one text, <c>AddressDetails</c>
    /// («العنوان بالتفصيل»), and the Lat/Lng pin becomes an optional Google Maps link, <c>MapUrl</c>.
    /// Existing rows are copied before the old columns go: the four parts joined with Arabic labels and «، »
    /// (empty parts skipped), and the pin as a Google Maps search link.
    /// </summary>
    public partial class BranchAddressDetailsAndMapUrl : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Nullable until it is filled, so no default constraint is left behind.
            migrationBuilder.AddColumn<string>(
                name: "AddressDetails",
                table: "Branches",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MapUrl",
                table: "Branches",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            // «شارع 9، عمارة 12، الدور 3، شقة 5». A part that already starts with its label is not labelled twice.
            // STUFF drops the first «، »; it gives NULL for an empty text, hence the COALESCE.
            migrationBuilder.Sql("""
                UPDATE b SET
                    [AddressDetails] = LEFT(COALESCE(STUFF(
                          COALESCE(N'، ' + p.[Street], N'')
                        + COALESCE(N'، ' + CASE WHEN p.[Building] LIKE N'عمارة%' OR p.[Building] LIKE N'عقار%' OR p.[Building] LIKE N'برج%'
                                                THEN p.[Building] ELSE N'عمارة ' + p.[Building] END, N'')
                        + COALESCE(N'، ' + CASE WHEN p.[Floor] LIKE N'الدور%' OR p.[Floor] LIKE N'دور%'
                                                THEN p.[Floor] ELSE N'الدور ' + p.[Floor] END, N'')
                        + COALESCE(N'، ' + CASE WHEN p.[Apartment] LIKE N'شقة%'
                                                THEN p.[Apartment] ELSE N'شقة ' + p.[Apartment] END, N''),
                        1, 2, N''), N''), 300),
                    [MapUrl] = CASE WHEN b.[Lat] IS NOT NULL AND b.[Lng] IS NOT NULL
                        THEN N'https://www.google.com/maps/search/?api=1&query='
                            + CONVERT(nvarchar(20), b.[Lat]) + N',' + CONVERT(nvarchar(20), b.[Lng]) END
                FROM [Branches] AS b
                CROSS APPLY (SELECT
                    NULLIF(LTRIM(RTRIM(b.[Street])), N'') AS [Street],
                    NULLIF(LTRIM(RTRIM(b.[Building])), N'') AS [Building],
                    NULLIF(LTRIM(RTRIM(b.[Floor])), N'') AS [Floor],
                    NULLIF(LTRIM(RTRIM(b.[Apartment])), N'') AS [Apartment]) AS p;
                """);

            migrationBuilder.AlterColumn<string>(
                name: "AddressDetails",
                table: "Branches",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(300)",
                oldMaxLength: 300,
                oldNullable: true);

            migrationBuilder.DropColumn(
                name: "Apartment",
                table: "Branches");

            migrationBuilder.DropColumn(
                name: "Building",
                table: "Branches");

            migrationBuilder.DropColumn(
                name: "Floor",
                table: "Branches");

            migrationBuilder.DropColumn(
                name: "Lat",
                table: "Branches");

            migrationBuilder.DropColumn(
                name: "Lng",
                table: "Branches");

            migrationBuilder.DropColumn(
                name: "Street",
                table: "Branches");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Apartment",
                table: "Branches",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Building",
                table: "Branches",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Floor",
                table: "Branches",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Lat",
                table: "Branches",
                type: "decimal(9,6)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Lng",
                table: "Branches",
                type: "decimal(9,6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Street",
                table: "Branches",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: true);

            // The detailed address can't be split again, so it goes back to Street whole (up to 150 characters)
            // and Building, Floor and Apartment stay empty. A pin comes back only from the kind of link Up makes
            // (…/maps/search/?api=1&query=<lat>,<lng>); any other link is lost.
            migrationBuilder.Sql("""
                UPDATE b SET
                    [Street] = LEFT(b.[AddressDetails], 150),
                    [Lat] = CASE WHEN pin.[Lng] IS NOT NULL THEN pin.[Lat] END,
                    [Lng] = CASE WHEN pin.[Lat] IS NOT NULL THEN pin.[Lng] END
                FROM [Branches] AS b
                CROSS APPLY (SELECT CASE WHEN b.[MapUrl] LIKE N'https://www.google.com/maps/search/?api=1&query=%'
                    THEN SUBSTRING(b.[MapUrl], LEN(N'https://www.google.com/maps/search/?api=1&query=') + 1, 100) END AS [Query]) AS q
                CROSS APPLY (SELECT
                    CASE WHEN CHARINDEX(N',', q.[Query]) > 1
                        THEN TRY_CONVERT(decimal(9, 6), LEFT(q.[Query], CHARINDEX(N',', q.[Query]) - 1)) END AS [Lat],
                    CASE WHEN CHARINDEX(N',', q.[Query]) > 1
                        THEN TRY_CONVERT(decimal(9, 6), SUBSTRING(q.[Query], CHARINDEX(N',', q.[Query]) + 1, 50)) END AS [Lng]) AS pin;
                """);

            migrationBuilder.AlterColumn<string>(
                name: "Street",
                table: "Branches",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(150)",
                oldMaxLength: 150,
                oldNullable: true);

            migrationBuilder.DropColumn(
                name: "AddressDetails",
                table: "Branches");

            migrationBuilder.DropColumn(
                name: "MapUrl",
                table: "Branches");
        }
    }
}
