/* =============================================================================
   el3yada (العيادة) - starting data. Run once, after schema.sql.
   Safe to run again: it only inserts rows that are missing.
   ============================================================================= */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRANSACTION;

-- Platform settings (AD13). Defaults come from the column defaults in schema.sql:
-- examination 30 EGP, consultation 15 EGP, 7 grace days, 2 consultations in a row,
-- 50 MB uploads, 5 assistants and 5 branches per doctor.
IF NOT EXISTS (SELECT 1 FROM dbo.AppSettings WHERE Id = 1)
    INSERT INTO dbo.AppSettings (Id, MaintenanceMessageAr, MaintenanceMessageEn)
    VALUES (1, N'التطبيق تحت الصيانة، حاول مرة أخرى بعد قليل.', N'The app is under maintenance. Please try again shortly.');

-- Starting specialties (A4 step 2). The admin edits this list in AD13 and the profiles in AD19.
DECLARE @Specialties TABLE (SortOrder INT, NameAr NVARCHAR(100), NameEn NVARCHAR(100));
INSERT INTO @Specialties (SortOrder, NameAr, NameEn) VALUES
    (1,  N'باطنة',                   N'Internal Medicine'),
    (2,  N'أطفال وحديثي الولادة',     N'Pediatrics'),
    (3,  N'نساء وتوليد',              N'Obstetrics and Gynecology'),
    (4,  N'عظام',                    N'Orthopedics'),
    (5,  N'جلدية',                   N'Dermatology'),
    (6,  N'أنف وأذن وحنجرة',          N'ENT'),
    (7,  N'رمد',                     N'Ophthalmology'),
    (8,  N'قلب وأوعية دموية',         N'Cardiology'),
    (9,  N'مخ وأعصاب',               N'Neurology'),
    (10, N'مسالك بولية',              N'Urology'),
    (11, N'صدر',                     N'Chest and Pulmonology'),
    (12, N'جهاز هضمي وكبد',          N'Gastroenterology and Hepatology'),
    (13, N'غدد صماء وسكر',           N'Endocrinology and Diabetes'),
    (14, N'كلى',                     N'Nephrology'),
    (15, N'نفسية',                   N'Psychiatry'),
    (16, N'جراحة عامة',              N'General Surgery'),
    (17, N'أسنان',                   N'Dentistry'),
    (18, N'علاج طبيعي',              N'Physiotherapy'),
    (19, N'ممارس عام',               N'General Practice');

INSERT INTO dbo.Specialties (NameAr, NameEn, SortOrder)
SELECT s.NameAr, s.NameEn, s.SortOrder
FROM @Specialties AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.Specialties AS x WHERE x.NameEn = s.NameEn);

-- The first super admin is NOT created here: its password hash must come from the API's
-- password hasher. The API provides a one-time seed command for it (Phase 1 in PHASES.md).

COMMIT TRANSACTION;
PRINT 'el3yada seed data inserted.';
