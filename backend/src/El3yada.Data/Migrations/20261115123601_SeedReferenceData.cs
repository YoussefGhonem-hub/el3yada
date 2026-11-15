using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <summary>
    /// Starting data, same as database/seed.sql: the platform settings row (AD13) and the
    /// starting specialties (A4 step 2). Only inserts rows that are missing.
    /// The first super admin is created by a seed command in the API, not here, because its
    /// password hash must come from the API's password hasher.
    /// </summary>
    public partial class SeedReferenceData : Migration
    {
        private static readonly (int SortOrder, string NameAr, string NameEn)[] Specialties =
        [
            (1,  "باطنة",                 "Internal Medicine"),
            (2,  "أطفال وحديثي الولادة",   "Pediatrics"),
            (3,  "نساء وتوليد",            "Obstetrics and Gynecology"),
            (4,  "عظام",                  "Orthopedics"),
            (5,  "جلدية",                 "Dermatology"),
            (6,  "أنف وأذن وحنجرة",        "ENT"),
            (7,  "رمد",                   "Ophthalmology"),
            (8,  "قلب وأوعية دموية",       "Cardiology"),
            (9,  "مخ وأعصاب",             "Neurology"),
            (10, "مسالك بولية",            "Urology"),
            (11, "صدر",                   "Chest and Pulmonology"),
            (12, "جهاز هضمي وكبد",        "Gastroenterology and Hepatology"),
            (13, "غدد صماء وسكر",         "Endocrinology and Diabetes"),
            (14, "كلى",                   "Nephrology"),
            (15, "نفسية",                 "Psychiatry"),
            (16, "جراحة عامة",            "General Surgery"),
            (17, "أسنان",                 "Dentistry"),
            (18, "علاج طبيعي",            "Physiotherapy"),
            (19, "ممارس عام",             "General Practice"),
        ];

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Defaults (30 EGP examination, 15 EGP consultation, 7 grace days …) come from the columns.
            migrationBuilder.Sql("""
                IF NOT EXISTS (SELECT 1 FROM dbo.AppSettings WHERE Id = 1)
                    INSERT INTO dbo.AppSettings (Id, MaintenanceMessageAr, MaintenanceMessageEn)
                    VALUES (1, N'التطبيق تحت الصيانة، حاول مرة أخرى بعد قليل.', N'The app is under maintenance. Please try again shortly.');
                """);

            foreach (var (sortOrder, nameAr, nameEn) in Specialties)
            {
                migrationBuilder.Sql($"""
                    IF NOT EXISTS (SELECT 1 FROM dbo.Specialties WHERE NameEn = N'{nameEn}')
                        INSERT INTO dbo.Specialties (NameAr, NameEn, SortOrder) VALUES (N'{nameAr}', N'{nameEn}', {sortOrder});
                    """);
            }
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Specialties that doctors already use stay, because Doctors.SpecialtyId points to them.
            foreach (var (_, _, nameEn) in Specialties)
            {
                migrationBuilder.Sql($"""
                    DELETE FROM dbo.Specialties
                    WHERE NameEn = N'{nameEn}'
                      AND NOT EXISTS (SELECT 1 FROM dbo.Doctors d WHERE d.SpecialtyId = dbo.Specialties.Id)
                      AND NOT EXISTS (SELECT 1 FROM dbo.DoctorExtraSpecialties x WHERE x.SpecialtyId = dbo.Specialties.Id)
                      AND NOT EXISTS (SELECT 1 FROM dbo.SpecialtyProfileItems p WHERE p.SpecialtyId = dbo.Specialties.Id);
                    """);
            }

            migrationBuilder.Sql("DELETE FROM dbo.AppSettings WHERE Id = 1;");
        }
    }
}
