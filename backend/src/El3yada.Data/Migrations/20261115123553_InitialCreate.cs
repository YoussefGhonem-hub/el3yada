using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace El3yada.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PublicHolidays",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    Date = table.Column<DateOnly>(type: "date", nullable: false),
                    NameAr = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    NameEn = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PublicHolidays", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Specialties",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    NameAr = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    NameEn = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Active = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    SortOrder = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    IncludeGeneral = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Specialties", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    Role = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    AdminRole = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: true),
                    Status = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false, defaultValue: "active"),
                    DisplayName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Phone = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: true),
                    Email = table.Column<string>(type: "nvarchar(254)", maxLength: 254, nullable: true),
                    EmailVerifiedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    PasswordHash = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    SecurityStamp = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newid())"),
                    MustChangePassword = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    AccessFailedCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    LockoutEndAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    Locale = table.Column<string>(type: "varchar(2)", unicode: false, maxLength: 2, nullable: false, defaultValue: "ar"),
                    ThemeMode = table.Column<string>(type: "varchar(6)", unicode: false, maxLength: 6, nullable: false, defaultValue: "system"),
                    NotifyChat = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    NotifyReminders = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    NotifyShowPreview = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    NotifyBookings = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    AcceptedTermsAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    LastLoginAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                    table.CheckConstraint("CK_Users_AdminRole", "([Role]='admin' AND ([AdminRole]='admin' OR [AdminRole]='superAdmin') OR [Role]<>'admin' AND [AdminRole] IS NULL)");
                    table.CheckConstraint("CK_Users_Identifier", "([Phone] IS NOT NULL OR [Email] IS NOT NULL)");
                    table.CheckConstraint("CK_Users_Locale", "([Locale]='en' OR [Locale]='ar')");
                    table.CheckConstraint("CK_Users_Phone", "([Phone] IS NULL OR [Phone] like '+20[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')");
                    table.CheckConstraint("CK_Users_Role", "([Role]='patient' OR [Role]='assistant' OR [Role]='doctor' OR [Role]='admin')");
                    table.CheckConstraint("CK_Users_Status", "([Status]='disabled' OR [Status]='active')");
                    table.CheckConstraint("CK_Users_ThemeMode", "([ThemeMode]='dark' OR [ThemeMode]='light' OR [ThemeMode]='system')");
                });

            migrationBuilder.CreateTable(
                name: "SpecialtyProfileItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    SpecialtyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ItemType = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    Value = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SpecialtyProfileItems", x => x.Id);
                    table.CheckConstraint("CK_SpecialtyProfileItems_ItemType", "([ItemType]='radiologyCode' OR [ItemType]='radiologyModality' OR [ItemType]='radiologyRegion' OR [ItemType]='labCode' OR [ItemType]='route' OR [ItemType]='drugGroup')");
                    table.ForeignKey(
                        name: "FK_SpecialtyProfileItems_SpecialtyId",
                        column: x => x.SpecialtyId,
                        principalTable: "Specialties",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "CatalogCustomItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    Type = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    NameEn = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    NameAr = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    ActiveIngredient = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    DrugGroupId = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: true),
                    Route = table.Column<string>(type: "varchar(50)", unicode: false, maxLength: 50, nullable: true),
                    LoincCode = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: true),
                    AliasesJson = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    Active = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CatalogCustomItems", x => x.Id);
                    table.CheckConstraint("CK_CatalogCustomItems_Aliases", "([AliasesJson] IS NULL OR isjson([AliasesJson])=(1))");
                    table.CheckConstraint("CK_CatalogCustomItems_Type", "([Type]='radiology' OR [Type]='lab' OR [Type]='drug')");
                    table.ForeignKey(
                        name: "FK_CatalogCustomItems_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "CatalogVersions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    VersionNumber = table.Column<int>(type: "int", nullable: false),
                    SchemaVersion = table.Column<int>(type: "int", nullable: false),
                    StoragePath = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: false),
                    Sha256 = table.Column<string>(type: "char(64)", unicode: false, fixedLength: true, maxLength: 64, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    DrugCount = table.Column<int>(type: "int", nullable: false),
                    LabCount = table.Column<int>(type: "int", nullable: false),
                    RadiologyCount = table.Column<int>(type: "int", nullable: false),
                    DrugDatasetDate = table.Column<DateOnly>(type: "date", nullable: true),
                    LoincRelease = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: true),
                    PublishedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    PublishedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CatalogVersions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CatalogVersions_PublishedBy",
                        column: x => x.PublishedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Notifications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    RecipientUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Type = table.Column<string>(type: "varchar(50)", unicode: false, maxLength: 50, nullable: false),
                    TitleAr = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    TitleEn = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    BodyAr = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    BodyEn = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Route = table.Column<string>(type: "varchar(200)", unicode: false, maxLength: 200, nullable: true),
                    DataJson = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    IsRead = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    ReadAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Notifications", x => x.Id);
                    table.CheckConstraint("CK_Notifications_Data", "([DataJson] IS NULL OR isjson([DataJson])=(1))");
                    table.ForeignKey(
                        name: "FK_Notifications_RecipientUserId",
                        column: x => x.RecipientUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "RefreshTokens",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DeviceId = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: true),
                    TokenHash = table.Column<byte[]>(type: "binary(32)", fixedLength: true, maxLength: 32, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false),
                    RevokedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    ReplacedByTokenId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedByIp = table.Column<string>(type: "varchar(45)", unicode: false, maxLength: 45, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RefreshTokens", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RefreshTokens_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "SettingsHistory",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    Field = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: false),
                    BeforeValue = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    AfterValue = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ChangedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ChangedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SettingsHistory", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SettingsHistory_ChangedBy",
                        column: x => x.ChangedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "UserDevices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DeviceId = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: false),
                    Platform = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    FcmToken = table.Column<string>(type: "varchar(512)", unicode: false, maxLength: 512, nullable: true),
                    AppVersion = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserDevices", x => x.Id);
                    table.CheckConstraint("CK_UserDevices_Platform", "([Platform]='macos' OR [Platform]='windows' OR [Platform]='ios' OR [Platform]='android')");
                    table.ForeignKey(
                        name: "FK_UserDevices_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "UserTokens",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Purpose = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    TokenHash = table.Column<byte[]>(type: "binary(32)", fixedLength: true, maxLength: 32, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false),
                    UsedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserTokens", x => x.Id);
                    table.CheckConstraint("CK_UserTokens_Purpose", "([Purpose]='emailVerify' OR [Purpose]='setPassword' OR [Purpose]='passwordReset')");
                    table.ForeignKey(
                        name: "FK_UserTokens_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "AppSettings",
                columns: table => new
                {
                    Id = table.Column<byte>(type: "tinyint", nullable: false),
                    ExamFeePiasters = table.Column<int>(type: "int", nullable: false, defaultValue: 3000),
                    ConsultationFeePiasters = table.Column<int>(type: "int", nullable: false, defaultValue: 1500),
                    GracePeriodDays = table.Column<int>(type: "int", nullable: false, defaultValue: 7),
                    MaxConsecutiveConsultations = table.Column<int>(type: "int", nullable: false, defaultValue: 2),
                    MaxUploadMb = table.Column<int>(type: "int", nullable: false, defaultValue: 50),
                    MaxAssistantsPerDoctor = table.Column<int>(type: "int", nullable: false, defaultValue: 5),
                    MaxBranchesPerDoctor = table.Column<int>(type: "int", nullable: false, defaultValue: 5),
                    InstapayAddress = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    InstapayAccountName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    InstapayInstructionsAr = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    InstapayInstructionsEn = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    CurrentCatalogVersionId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    SupportPhone = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: true),
                    SupportWhatsapp = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: true),
                    SupportEmail = table.Column<string>(type: "nvarchar(254)", maxLength: 254, nullable: true),
                    MinVersionAndroid = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false, defaultValue: "0.0.0"),
                    MinVersionIos = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false, defaultValue: "0.0.0"),
                    MinVersionWindows = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false, defaultValue: "0.0.0"),
                    MinVersionMacos = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false, defaultValue: "0.0.0"),
                    MaintenanceEnabled = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    MaintenanceMessageAr = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    MaintenanceMessageEn = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    TermsAr = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    TermsEn = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PrivacyAr = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PrivacyEn = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AppSettings", x => x.Id);
                    table.CheckConstraint("CK_AppSettings_Fees", "([ExamFeePiasters]>=(0) AND [ExamFeePiasters]<=(1000000) AND ([ConsultationFeePiasters]>=(0) AND [ConsultationFeePiasters]<=(1000000)))");
                    table.CheckConstraint("CK_AppSettings_Grace", "([GracePeriodDays]>=(0) AND [GracePeriodDays]<=(31))");
                    table.CheckConstraint("CK_AppSettings_Limits", "([MaxAssistantsPerDoctor]>=(0) AND [MaxAssistantsPerDoctor]<=(50) AND ([MaxBranchesPerDoctor]>=(1) AND [MaxBranchesPerDoctor]<=(50)))");
                    table.CheckConstraint("CK_AppSettings_MaxConsults", "([MaxConsecutiveConsultations]>=(1) AND [MaxConsecutiveConsultations]<=(5))");
                    table.CheckConstraint("CK_AppSettings_MaxUpload", "([MaxUploadMb]>=(1) AND [MaxUploadMb]<=(200))");
                    table.CheckConstraint("CK_AppSettings_SingleRow", "([Id]=(1))");
                    table.ForeignKey(
                        name: "FK_AppSettings_CurrentCatalogVersionId",
                        column: x => x.CurrentCatalogVersionId,
                        principalTable: "CatalogVersions",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_AppSettings_UpdatedBy",
                        column: x => x.UpdatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "AppointmentHistory",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    AppointmentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    At = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    ByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ByRole = table.Column<string>(type: "varchar(9)", unicode: false, maxLength: 9, nullable: false),
                    Action = table.Column<string>(type: "varchar(30)", unicode: false, maxLength: 30, nullable: false),
                    FromValue = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    ToValue = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    Reason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AppointmentHistory", x => x.Id);
                    table.CheckConstraint("CK_AppointmentHistory_ByRole", "([ByRole]='system' OR [ByRole]='assistant' OR [ByRole]='doctor' OR [ByRole]='patient')");
                    table.ForeignKey(
                        name: "FK_AppointmentHistory_ByUserId",
                        column: x => x.ByUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Appointments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    GuestName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    GuestPhone = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: true),
                    VisitType = table.Column<string>(type: "varchar(12)", unicode: false, maxLength: 12, nullable: false),
                    Mode = table.Column<string>(type: "varchar(5)", unicode: false, maxLength: 5, nullable: false),
                    LocalDate = table.Column<DateOnly>(type: "date", nullable: false),
                    PeriodStartLocal = table.Column<TimeOnly>(type: "time(0)", precision: 0, nullable: false),
                    StartUtc = table.Column<DateTime>(type: "datetime2(0)", precision: 0, nullable: false),
                    EndUtc = table.Column<DateTime>(type: "datetime2(0)", precision: 0, nullable: true),
                    QueueNumber = table.Column<int>(type: "int", nullable: true),
                    Status = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    BoardOrder = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    IsPriority = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    PriorityReason = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    Source = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    BookedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BookedByRole = table.Column<string>(type: "varchar(9)", unicode: false, maxLength: 9, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    StaffNotes = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    Overbooked = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    RescheduleCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    CheckedInAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CalledAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    RejectReason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    CancelledAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CancelledByRole = table.Column<string>(type: "varchar(7)", unicode: false, maxLength: 7, nullable: true),
                    CancelReason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    NoShowAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    FlaggedNoSession = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    RemindersSentJson = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: false, defaultValue: "[]"),
                    AttendanceConfirmedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Appointments", x => x.Id);
                    table.CheckConstraint("CK_Appointments_BookedByRole", "([BookedByRole]='assistant' OR [BookedByRole]='doctor' OR [BookedByRole]='patient')");
                    table.CheckConstraint("CK_Appointments_CancelledByRole", "([CancelledByRole] IS NULL OR ([CancelledByRole]='system' OR [CancelledByRole]='clinic' OR [CancelledByRole]='patient'))");
                    table.CheckConstraint("CK_Appointments_Mode", "([Mode]='timed' OR [Mode]='queue')");
                    table.CheckConstraint("CK_Appointments_Queue", "([Mode]='timed' OR [QueueNumber] IS NOT NULL OR ([Status]='cancelled' OR [Status]='rejected' OR [Status]='pending'))");
                    table.CheckConstraint("CK_Appointments_Reminders", "(isjson([RemindersSentJson])=(1))");
                    table.CheckConstraint("CK_Appointments_Source", "([Source]='walkIn' OR [Source]='staff' OR [Source]='patientApp')");
                    table.CheckConstraint("CK_Appointments_Status", "([Status]='rejected' OR [Status]='noShow' OR [Status]='cancelled' OR [Status]='completed' OR [Status]='withDoctor' OR [Status]='checkedIn' OR [Status]='confirmed' OR [Status]='pending')");
                    table.CheckConstraint("CK_Appointments_VisitType", "([VisitType]='consultation' OR [VisitType]='examination')");
                    table.CheckConstraint("CK_Appointments_Who", "([PatientId] IS NOT NULL AND [GuestName] IS NULL AND [GuestPhone] IS NULL OR [PatientId] IS NULL AND [GuestName] IS NOT NULL AND [GuestPhone] IS NOT NULL)");
                    table.ForeignKey(
                        name: "FK_Appointments_BookedBy",
                        column: x => x.BookedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "AssistantBranches",
                columns: table => new
                {
                    AssistantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AssistantBranches", x => new { x.AssistantId, x.BranchId });
                });

            migrationBuilder.CreateTable(
                name: "Assistants",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Phone = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    Preset = table.Column<string>(type: "varchar(13)", unicode: false, maxLength: 13, nullable: false, defaultValue: "custom"),
                    AllBranches = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    PatientsManage = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    PatientsResetPassword = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    SessionsCreate = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    SessionsDelete = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    ClinicalView = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    ClinicalEditProfile = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    FilesManage = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    PrescriptionsPrint = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    PrescriptionsDraft = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    Chat = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    BillingView = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    BillingPay = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    AppointmentsView = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    AppointmentsManage = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    ScheduleManage = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    RevenueView = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    PricesManage = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    Status = table.Column<string>(type: "varchar(8)", unicode: false, maxLength: 8, nullable: false, defaultValue: "active"),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    LastActiveAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    RemovedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Assistants", x => x.UserId);
                    table.CheckConstraint("CK_Assistants_Deps", "(([ClinicalEditProfile]=(0) OR [ClinicalView]=(1)) AND ([PrescriptionsDraft]=(0) OR [ClinicalView]=(1)) AND ([BillingPay]=(0) OR [BillingView]=(1)) AND ([AppointmentsManage]=(0) OR [AppointmentsView]=(1)) AND ([ScheduleManage]=(0) OR [AppointmentsManage]=(1)))");
                    table.CheckConstraint("CK_Assistants_Preset", "([Preset]='custom' OR [Preset]='officeManager' OR [Preset]='clinical' OR [Preset]='reception')");
                    table.CheckConstraint("CK_Assistants_Status", "([Status]='removed' OR [Status]='disabled' OR [Status]='active')");
                    table.ForeignKey(
                        name: "FK_Assistants_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Assistants_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "AuditLogs",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ActorUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ActorRole = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Action = table.Column<string>(type: "varchar(50)", unicode: false, maxLength: 50, nullable: false),
                    TargetType = table.Column<string>(type: "varchar(30)", unicode: false, maxLength: 30, nullable: false),
                    TargetId = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: true),
                    DetailsJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    At = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AuditLogs", x => x.Id);
                    table.CheckConstraint("CK_AuditLogs_ActorRole", "([ActorRole]='system' OR [ActorRole]='patient' OR [ActorRole]='assistant' OR [ActorRole]='doctor' OR [ActorRole]='admin')");
                    table.CheckConstraint("CK_AuditLogs_Details", "([DetailsJson] IS NULL OR isjson([DetailsJson])=(1))");
                    table.ForeignKey(
                        name: "FK_AuditLogs_ActorUserId",
                        column: x => x.ActorUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "BranchClosures",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    FromLocal = table.Column<DateTime>(type: "datetime2(0)", precision: 0, nullable: false),
                    ToLocal = table.Column<DateTime>(type: "datetime2(0)", precision: 0, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BranchClosures", x => x.Id);
                    table.CheckConstraint("CK_BranchClosures_Range", "([ToLocal]>[FromLocal])");
                    table.ForeignKey(
                        name: "FK_BranchClosures_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "BranchDateOverridePeriods",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    OverrideId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StartLocal = table.Column<TimeOnly>(type: "time(0)", precision: 0, nullable: false),
                    EndLocal = table.Column<TimeOnly>(type: "time(0)", precision: 0, nullable: false),
                    EndsNextDay = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    Label = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    Capacity = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BranchDateOverridePeriods", x => x.Id);
                    table.CheckConstraint("CK_BranchDateOverridePeriods_Capacity", "([Capacity] IS NULL OR [Capacity]>=(1) AND [Capacity]<=(200))");
                    table.CheckConstraint("CK_BranchDateOverridePeriods_Order", "([EndsNextDay]=(1) OR [EndLocal]>[StartLocal])");
                });

            migrationBuilder.CreateTable(
                name: "BranchDateOverrides",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Date = table.Column<DateOnly>(type: "date", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BranchDateOverrides", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BranchDateOverrides_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "BranchDayStates",
                columns: table => new
                {
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocalDate = table.Column<DateOnly>(type: "date", nullable: false),
                    PeriodStartLocal = table.Column<TimeOnly>(type: "time(0)", precision: 0, nullable: false),
                    NowServingNumber = table.Column<int>(type: "int", nullable: true),
                    DelayMinutes = table.Column<int>(type: "int", nullable: true),
                    DelayNoticeSentAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BranchDayStates", x => new { x.BranchId, x.LocalDate, x.PeriodStartLocal });
                });

            migrationBuilder.CreateTable(
                name: "Branches",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    NameAr = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    NameEn = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    IsDefault = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    Governorate = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    City = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Area = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    Street = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Building = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    Floor = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    Apartment = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    Landmark = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: true),
                    Lat = table.Column<decimal>(type: "decimal(9,6)", nullable: true),
                    Lng = table.Column<decimal>(type: "decimal(9,6)", nullable: true),
                    Email = table.Column<string>(type: "nvarchar(254)", maxLength: 254, nullable: true),
                    ExaminationPricePiasters = table.Column<int>(type: "int", nullable: true),
                    ConsultationPricePiasters = table.Column<int>(type: "int", nullable: true),
                    PaymentMethodsJson = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false, defaultValue: "[\"cash\"]"),
                    AmenitiesJson = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    Status = table.Column<string>(type: "varchar(17)", unicode: false, maxLength: 17, nullable: false, defaultValue: "active"),
                    ClosedMessage = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    ReopenDate = table.Column<DateOnly>(type: "date", nullable: true),
                    BookingMode = table.Column<string>(type: "varchar(5)", unicode: false, maxLength: 5, nullable: false, defaultValue: "queue"),
                    SlotMinutes = table.Column<int>(type: "int", nullable: false, defaultValue: 15),
                    ExamSlots = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)1),
                    ConsultationSlots = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)1),
                    DefaultCapacity = table.Column<int>(type: "int", nullable: false, defaultValue: 30),
                    AvgVisitMinutes = table.Column<int>(type: "int", nullable: false, defaultValue: 10),
                    SelfBooking = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    AutoConfirm = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    WindowDays = table.Column<int>(type: "int", nullable: false, defaultValue: 30),
                    MinNoticeMinutes = table.Column<int>(type: "int", nullable: false, defaultValue: 60),
                    SameDay = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    FreeCancelMinutes = table.Column<int>(type: "int", nullable: false, defaultValue: 120),
                    MaxReschedules = table.Column<int>(type: "int", nullable: false, defaultValue: 2),
                    MaxUpcomingPerPatient = table.Column<int>(type: "int", nullable: false, defaultValue: 1),
                    NoShowLimitCount = table.Column<int>(type: "int", nullable: false, defaultValue: 3),
                    NoShowLimitDays = table.Column<int>(type: "int", nullable: false, defaultValue: 90),
                    ReminderMinutesJson = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: false, defaultValue: "[1440,120]"),
                    StaffOverbooking = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    WaitingOrderByArrival = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    WaitAmberMinutes = table.Column<int>(type: "int", nullable: false, defaultValue: 20),
                    WaitRedMinutes = table.Column<int>(type: "int", nullable: false, defaultValue: 40),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Branches", x => x.Id);
                    table.CheckConstraint("CK_Branches_BookingMode", "([BookingMode]='timed' OR [BookingMode]='queue')");
                    table.CheckConstraint("CK_Branches_Cancel", "([FreeCancelMinutes]>=(0) AND [FreeCancelMinutes]<=(2880) AND ([MaxReschedules]>=(0) AND [MaxReschedules]<=(5)))");
                    table.CheckConstraint("CK_Branches_Capacity", "([DefaultCapacity]>=(1) AND [DefaultCapacity]<=(200) AND ([AvgVisitMinutes]>=(1) AND [AvgVisitMinutes]<=(240)))");
                    table.CheckConstraint("CK_Branches_Json", "(isjson([PaymentMethodsJson])=(1) AND isjson([ReminderMinutesJson])=(1) AND ([AmenitiesJson] IS NULL OR isjson([AmenitiesJson])=(1)))");
                    table.CheckConstraint("CK_Branches_Name", "(len([NameAr])>=(2))");
                    table.CheckConstraint("CK_Branches_NoShow", "([NoShowLimitCount]>=(1) AND [NoShowLimitCount]<=(20) AND ([NoShowLimitDays]>=(1) AND [NoShowLimitDays]<=(365)))");
                    table.CheckConstraint("CK_Branches_Prices", "(([ExaminationPricePiasters] IS NULL OR [ExaminationPricePiasters]>=(0) AND [ExaminationPricePiasters]<=(10000000)) AND ([ConsultationPricePiasters] IS NULL OR [ConsultationPricePiasters]>=(0) AND [ConsultationPricePiasters]<=(10000000)))");
                    table.CheckConstraint("CK_Branches_Slot", "([SlotMinutes]>=(5) AND [SlotMinutes]<=(120) AND ([ExamSlots]>=(1) AND [ExamSlots]<=(8)) AND ([ConsultationSlots]>=(1) AND [ConsultationSlots]<=(8)))");
                    table.CheckConstraint("CK_Branches_Status", "([Status]='archived' OR [Status]='temporarilyClosed' OR [Status]='active')");
                    table.CheckConstraint("CK_Branches_Upcoming", "([MaxUpcomingPerPatient]>=(1) AND [MaxUpcomingPerPatient]<=(5))");
                    table.CheckConstraint("CK_Branches_Window", "([WindowDays]>=(1) AND [WindowDays]<=(180) AND ([MinNoticeMinutes]>=(0) AND [MinNoticeMinutes]<=(1440)))");
                });

            migrationBuilder.CreateTable(
                name: "BranchPeriods",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Weekday = table.Column<byte>(type: "tinyint", nullable: false),
                    StartLocal = table.Column<TimeOnly>(type: "time(0)", precision: 0, nullable: false),
                    EndLocal = table.Column<TimeOnly>(type: "time(0)", precision: 0, nullable: false),
                    EndsNextDay = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    Label = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    Capacity = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BranchPeriods", x => x.Id);
                    table.CheckConstraint("CK_BranchPeriods_Capacity", "([Capacity] IS NULL OR [Capacity]>=(1) AND [Capacity]<=(200))");
                    table.CheckConstraint("CK_BranchPeriods_Order", "([EndsNextDay]=(1) OR [EndLocal]>[StartLocal])");
                    table.CheckConstraint("CK_BranchPeriods_Weekday", "([Weekday]>=(1) AND [Weekday]<=(7))");
                    table.ForeignKey(
                        name: "FK_BranchPeriods_BranchId",
                        column: x => x.BranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "BranchPhones",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Number = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    Label = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false, defaultValue: "reception"),
                    IsWhatsapp = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BranchPhones", x => x.Id);
                    table.CheckConstraint("CK_BranchPhones_Label", "([Label]='landline' OR [Label]='mobile' OR [Label]='reception')");
                    table.ForeignKey(
                        name: "FK_BranchPhones_BranchId",
                        column: x => x.BranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "BranchPhotos",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Path = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BranchPhotos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BranchPhotos_BranchId",
                        column: x => x.BranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Doctors",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    FullNameEn = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    Title = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    TitleEn = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: true),
                    DegreesAr = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    DegreesEn = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    SpecialtyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LicenseNumber = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    LicenseDocPath = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: false),
                    DefaultBranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ExaminationPricePiasters = table.Column<int>(type: "int", nullable: true),
                    ConsultationPricePiasters = table.Column<int>(type: "int", nullable: true),
                    RxLogoPath = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    RxSignaturePath = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    RxFooterText = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    RxLanguage = table.Column<string>(type: "varchar(2)", unicode: false, maxLength: 2, nullable: false, defaultValue: "ar"),
                    RxAccentColor = table.Column<string>(type: "char(7)", unicode: false, fixedLength: true, maxLength: 7, nullable: false, defaultValue: "#0B5C8E"),
                    RxPaperSize = table.Column<string>(type: "varchar(6)", unicode: false, maxLength: 6, nullable: false, defaultValue: "A5"),
                    RxCustomWidthMm = table.Column<decimal>(type: "decimal(5,1)", nullable: true),
                    RxCustomHeightMm = table.Column<decimal>(type: "decimal(5,1)", nullable: true),
                    RxPreprinted = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    RxMarginTopMm = table.Column<decimal>(type: "decimal(5,1)", nullable: true),
                    RxMarginBottomMm = table.Column<decimal>(type: "decimal(5,1)", nullable: true),
                    Status = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false, defaultValue: "pendingApproval"),
                    StatusReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    StatusChangedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    ApprovedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    ApprovedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    NextFileNumber = table.Column<int>(type: "int", nullable: false, defaultValue: 1),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Doctors", x => x.UserId);
                    table.CheckConstraint("CK_Doctors_License", "(len([LicenseNumber])>=(3) AND len([LicenseNumber])<=(20))");
                    table.CheckConstraint("CK_Doctors_Prices", "(([ExaminationPricePiasters] IS NULL OR [ExaminationPricePiasters]>=(0) AND [ExaminationPricePiasters]<=(10000000)) AND ([ConsultationPricePiasters] IS NULL OR [ConsultationPricePiasters]>=(0) AND [ConsultationPricePiasters]<=(10000000)))");
                    table.CheckConstraint("CK_Doctors_RxAccent", "([RxAccentColor] like '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')");
                    table.CheckConstraint("CK_Doctors_RxLanguage", "([RxLanguage]='en' OR [RxLanguage]='ar')");
                    table.CheckConstraint("CK_Doctors_RxPaperSize", "([RxPaperSize]='custom' OR [RxPaperSize]='A4' OR [RxPaperSize]='A5')");
                    table.CheckConstraint("CK_Doctors_Status", "([Status]='disabled' OR [Status]='suspended' OR [Status]='rejected' OR [Status]='active' OR [Status]='pendingApproval')");
                    table.ForeignKey(
                        name: "FK_Doctors_ApprovedBy",
                        column: x => x.ApprovedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Doctors_DefaultBranchId",
                        column: x => x.DefaultBranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Doctors_SpecialtyId",
                        column: x => x.SpecialtyId,
                        principalTable: "Specialties",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Doctors_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "CatalogReports",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Type = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    ItemRef = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: true),
                    Status = table.Column<string>(type: "varchar(4)", unicode: false, maxLength: 4, nullable: false, defaultValue: "open"),
                    HandledBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    HandledAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CatalogReports", x => x.Id);
                    table.CheckConstraint("CK_CatalogReports_Status", "([Status]='done' OR [Status]='open')");
                    table.CheckConstraint("CK_CatalogReports_Type", "([Type]='other' OR [Type]='wrong' OR [Type]='missing')");
                    table.ForeignKey(
                        name: "FK_CatalogReports_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_CatalogReports_HandledBy",
                        column: x => x.HandledBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "DailyStats",
                columns: table => new
                {
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DayKey = table.Column<DateOnly>(type: "date", nullable: false),
                    MonthKey = table.Column<string>(type: "char(7)", unicode: false, fixedLength: true, maxLength: 7, nullable: false),
                    ExamCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    ConsultationCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    AmountPiasters = table.Column<int>(type: "int", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DailyStats", x => new { x.DoctorId, x.DayKey });
                    table.ForeignKey(
                        name: "FK_DailyStats_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                });

            migrationBuilder.CreateTable(
                name: "DoctorAdminNotes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Text = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DoctorAdminNotes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DoctorAdminNotes_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_DoctorAdminNotes_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                });

            migrationBuilder.CreateTable(
                name: "DoctorDailyMetrics",
                columns: table => new
                {
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Date = table.Column<DateOnly>(type: "date", nullable: false),
                    ExamCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    ConsultationCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    PatientRevenuePiasters = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    DiscountPiasters = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    PlatformFeesPiasters = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    UniquePatients = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    NewPatients = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    FreeVisits = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    Bookings = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    CompletedBookings = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    NoShows = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    Cancellations = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    AppBookings = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    WalkIns = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    VisitsByHourJson = table.Column<string>(type: "varchar(200)", unicode: false, maxLength: 200, nullable: false, defaultValue: "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]"),
                    AvgWaitMinutes = table.Column<decimal>(type: "decimal(6,1)", nullable: true),
                    BuiltAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DoctorDailyMetrics", x => new { x.DoctorId, x.BranchId, x.Date });
                    table.CheckConstraint("CK_DoctorDailyMetrics_Hours", "(isjson([VisitsByHourJson])=(1))");
                    table.ForeignKey(
                        name: "FK_DoctorDailyMetrics_BranchId",
                        column: x => x.BranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_DoctorDailyMetrics_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                });

            migrationBuilder.CreateTable(
                name: "DoctorExtraSpecialties",
                columns: table => new
                {
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SpecialtyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DoctorExtraSpecialties", x => new { x.DoctorId, x.SpecialtyId });
                    table.ForeignKey(
                        name: "FK_DoctorExtraSpecialties_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_DoctorExtraSpecialties_SpecialtyId",
                        column: x => x.SpecialtyId,
                        principalTable: "Specialties",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "DoctorItemHistory",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Kind = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CatalogId = table.Column<string>(type: "varchar(50)", unicode: false, maxLength: 50, nullable: true),
                    Form = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false, defaultValue: ""),
                    Strength = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false, defaultValue: ""),
                    UseCount = table.Column<int>(type: "int", nullable: false, defaultValue: 1),
                    LastUsedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DoctorItemHistory", x => x.Id);
                    table.CheckConstraint("CK_DoctorItemHistory_Kind", "([Kind]='radiology' OR [Kind]='lab' OR [Kind]='drug')");
                    table.ForeignKey(
                        name: "FK_DoctorItemHistory_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                });

            migrationBuilder.CreateTable(
                name: "Invoices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MonthKey = table.Column<string>(type: "char(7)", unicode: false, fixedLength: true, maxLength: 7, nullable: false),
                    PeriodStart = table.Column<DateOnly>(type: "date", nullable: false),
                    PeriodEnd = table.Column<DateOnly>(type: "date", nullable: false),
                    ExamCount = table.Column<int>(type: "int", nullable: false),
                    ConsultationCount = table.Column<int>(type: "int", nullable: false),
                    ExamAmountPiasters = table.Column<int>(type: "int", nullable: false),
                    ConsultationAmountPiasters = table.Column<int>(type: "int", nullable: false),
                    AdjustmentsPiasters = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    TotalDuePiasters = table.Column<int>(type: "int", nullable: false),
                    DueDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Status = table.Column<string>(type: "varchar(13)", unicode: false, maxLength: 13, nullable: false, defaultValue: "unpaid"),
                    PaidAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    PaidMethod = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    ClosedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Invoices", x => x.Id);
                    table.CheckConstraint("CK_Invoices_MonthKey", "([MonthKey] like '[12][0-9][0-9][0-9]-[01][0-9]')");
                    table.CheckConstraint("CK_Invoices_Period", "([PeriodEnd]>=[PeriodStart])");
                    table.CheckConstraint("CK_Invoices_Status", "([Status]='noCharge' OR [Status]='waived' OR [Status]='overdue' OR [Status]='rejected' OR [Status]='paid' OR [Status]='pendingReview' OR [Status]='unpaid')");
                    table.ForeignKey(
                        name: "FK_Invoices_ClosedBy",
                        column: x => x.ClosedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Invoices_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                });

            migrationBuilder.CreateTable(
                name: "MonthlyStats",
                columns: table => new
                {
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MonthKey = table.Column<string>(type: "char(7)", unicode: false, fixedLength: true, maxLength: 7, nullable: false),
                    ExamCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    ConsultationCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    AmountPiasters = table.Column<int>(type: "int", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MonthlyStats", x => new { x.DoctorId, x.MonthKey });
                    table.ForeignKey(
                        name: "FK_MonthlyStats_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                });

            migrationBuilder.CreateTable(
                name: "Patients",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Phone = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    Gender = table.Column<string>(type: "varchar(6)", unicode: false, maxLength: 6, nullable: false),
                    DateOfBirth = table.Column<DateOnly>(type: "date", nullable: false),
                    DateOfBirthEstimated = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    NationalId = table.Column<string>(type: "char(14)", unicode: false, fixedLength: true, maxLength: 14, nullable: true),
                    Address = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    BloodType = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: true),
                    EmergencyContactName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    EmergencyContactPhone = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: true),
                    CreatedByDoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Status = table.Column<string>(type: "varchar(8)", unicode: false, maxLength: 8, nullable: false, defaultValue: "active"),
                    DeletedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Patients", x => x.Id);
                    table.CheckConstraint("CK_Patients_BloodType", "([BloodType] IS NULL OR ([BloodType]='O-' OR [BloodType]='O+' OR [BloodType]='AB-' OR [BloodType]='AB+' OR [BloodType]='B-' OR [BloodType]='B+' OR [BloodType]='A-' OR [BloodType]='A+'))");
                    table.CheckConstraint("CK_Patients_Gender", "([Gender]='female' OR [Gender]='male')");
                    table.CheckConstraint("CK_Patients_NationalId", "([NationalId] IS NULL OR NOT [NationalId] like '%[^0-9]%')");
                    table.CheckConstraint("CK_Patients_Status", "([Status]='deleted' OR [Status]='disabled' OR [Status]='active')");
                    table.ForeignKey(
                        name: "FK_Patients_CreatedByDoctorId",
                        column: x => x.CreatedByDoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_Patients_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "PrescriptionTemplates",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Kind = table.Column<string>(type: "varchar(14)", unicode: false, maxLength: 14, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    ItemsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Advice = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PrescriptionTemplates", x => x.Id);
                    table.CheckConstraint("CK_PrescriptionTemplates_Items", "(isjson([ItemsJson])=(1))");
                    table.CheckConstraint("CK_PrescriptionTemplates_Kind", "([Kind]='investigations' OR [Kind]='medication')");
                    table.ForeignKey(
                        name: "FK_PrescriptionTemplates_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                });

            migrationBuilder.CreateTable(
                name: "PriceHistory",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    BeforeExaminationPiasters = table.Column<int>(type: "int", nullable: true),
                    BeforeConsultationPiasters = table.Column<int>(type: "int", nullable: true),
                    AfterExaminationPiasters = table.Column<int>(type: "int", nullable: true),
                    AfterConsultationPiasters = table.Column<int>(type: "int", nullable: true),
                    ChangedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ChangedByRole = table.Column<string>(type: "varchar(9)", unicode: false, maxLength: 9, nullable: false),
                    ChangedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PriceHistory", x => x.Id);
                    table.CheckConstraint("CK_PriceHistory_Role", "([ChangedByRole]='assistant' OR [ChangedByRole]='doctor')");
                    table.ForeignKey(
                        name: "FK_PriceHistory_BranchId",
                        column: x => x.BranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_PriceHistory_ChangedBy",
                        column: x => x.ChangedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_PriceHistory_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                });

            migrationBuilder.CreateTable(
                name: "InvoiceAdjustments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    InvoiceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AmountPiasters = table.Column<int>(type: "int", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InvoiceAdjustments", x => x.Id);
                    table.CheckConstraint("CK_InvoiceAdjustments_Amount", "([AmountPiasters]<>(0))");
                    table.ForeignKey(
                        name: "FK_InvoiceAdjustments_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_InvoiceAdjustments_InvoiceId",
                        column: x => x.InvoiceId,
                        principalTable: "Invoices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "InvoiceBranchBreakdown",
                columns: table => new
                {
                    InvoiceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExamCount = table.Column<int>(type: "int", nullable: false),
                    ConsultationCount = table.Column<int>(type: "int", nullable: false),
                    AmountPiasters = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InvoiceBranchBreakdown", x => new { x.InvoiceId, x.BranchId });
                    table.ForeignKey(
                        name: "FK_InvoiceBranchBreakdown_BranchId",
                        column: x => x.BranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_InvoiceBranchBreakdown_InvoiceId",
                        column: x => x.InvoiceId,
                        principalTable: "Invoices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "InvoiceStatusHistory",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    InvoiceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Status = table.Column<string>(type: "varchar(13)", unicode: false, maxLength: 13, nullable: false),
                    Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ChangedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ChangedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InvoiceStatusHistory", x => x.Id);
                    table.CheckConstraint("CK_InvoiceStatusHistory_Status", "([Status]='noCharge' OR [Status]='waived' OR [Status]='overdue' OR [Status]='rejected' OR [Status]='paid' OR [Status]='pendingReview' OR [Status]='unpaid')");
                    table.ForeignKey(
                        name: "FK_InvoiceStatusHistory_ChangedBy",
                        column: x => x.ChangedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_InvoiceStatusHistory_InvoiceId",
                        column: x => x.InvoiceId,
                        principalTable: "Invoices",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Payments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    InvoiceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AmountPiasters = table.Column<int>(type: "int", nullable: false),
                    TransferDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Reference = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    SenderName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Status = table.Column<string>(type: "varchar(13)", unicode: false, maxLength: 13, nullable: false, defaultValue: "pendingReview"),
                    SubmittedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SubmittedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    ReviewedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ReviewedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    RejectionReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Payments", x => x.Id);
                    table.CheckConstraint("CK_Payments_Amount", "([AmountPiasters]>(0))");
                    table.CheckConstraint("CK_Payments_Reject", "([Status]<>'rejected' OR [RejectionReason] IS NOT NULL)");
                    table.CheckConstraint("CK_Payments_Status", "([Status]='rejected' OR [Status]='approved' OR [Status]='pendingReview')");
                    table.ForeignKey(
                        name: "FK_Payments_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_Payments_InvoiceId",
                        column: x => x.InvoiceId,
                        principalTable: "Invoices",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Payments_ReviewedBy",
                        column: x => x.ReviewedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Payments_SubmittedBy",
                        column: x => x.SubmittedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "DeletionRequests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Status = table.Column<string>(type: "varchar(8)", unicode: false, maxLength: 8, nullable: false, defaultValue: "pending"),
                    ReviewedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ReviewedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    ReviewNote = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeletionRequests", x => x.Id);
                    table.CheckConstraint("CK_DeletionRequests_Status", "([Status]='rejected' OR [Status]='approved' OR [Status]='pending')");
                    table.ForeignKey(
                        name: "FK_DeletionRequests_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_DeletionRequests_ReviewedBy",
                        column: x => x.ReviewedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "PaymentScreenshots",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    PaymentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Path = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: false),
                    SortOrder = table.Column<byte>(type: "tinyint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PaymentScreenshots", x => x.Id);
                    table.CheckConstraint("CK_PaymentScreenshots_Order", "([SortOrder]>=(1) AND [SortOrder]<=(3))");
                    table.ForeignKey(
                        name: "FK_PaymentScreenshots_PaymentId",
                        column: x => x.PaymentId,
                        principalTable: "Payments",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ChatMessages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    ChatId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SenderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SenderRole = table.Column<string>(type: "varchar(9)", unicode: false, maxLength: 9, nullable: false),
                    SenderName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Type = table.Column<string>(type: "varchar(5)", unicode: false, maxLength: 5, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: true),
                    AttachmentPath = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    AttachmentFileName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    AttachmentMimeType = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: true),
                    AttachmentSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                    ReadAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatMessages", x => x.Id);
                    table.CheckConstraint("CK_ChatMessages_Content", "([Type]='text' AND [Text] IS NOT NULL OR [Type]<>'text' AND [AttachmentPath] IS NOT NULL)");
                    table.CheckConstraint("CK_ChatMessages_SenderRole", "([SenderRole]='patient' OR [SenderRole]='assistant' OR [SenderRole]='doctor')");
                    table.CheckConstraint("CK_ChatMessages_Type", "([Type]='file' OR [Type]='image' OR [Type]='text')");
                    table.ForeignKey(
                        name: "FK_ChatMessages_SenderId",
                        column: x => x.SenderId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ChatReadStates",
                columns: table => new
                {
                    ChatId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UnreadCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    LastReadAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatReadStates", x => new { x.ChatId, x.UserId });
                    table.ForeignKey(
                        name: "FK_ChatReadStates_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Chats",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    LinkId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Enabled = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    LastMessageText = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    LastMessageType = table.Column<string>(type: "varchar(5)", unicode: false, maxLength: 5, nullable: true),
                    LastMessageSenderId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    LastMessageAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Chats", x => x.Id);
                    table.CheckConstraint("CK_Chats_LastMessageType", "([LastMessageType] IS NULL OR ([LastMessageType]='file' OR [LastMessageType]='image' OR [LastMessageType]='text'))");
                    table.ForeignKey(
                        name: "FK_Chats_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_Chats_LastMessageSenderId",
                        column: x => x.LastMessageSenderId,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Chats_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "DoctorPatients",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FileNumber = table.Column<int>(type: "int", nullable: false),
                    PatientName = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    PatientPhone = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    SearchName = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    FamilyHistory = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    ProfileNotes = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    FirstSessionAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    LastSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    LastSessionType = table.Column<string>(type: "varchar(12)", unicode: false, maxLength: 12, nullable: true),
                    LastSessionAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    LastSessionBranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    SessionCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    ExamCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    ConsultationCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    ConsultationsSinceExam = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    Archived = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    ArchivedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    SelfBookingBlocked = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    SelfBookingBlockedReason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    LinkedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    LinkedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DoctorPatients", x => x.Id);
                    table.CheckConstraint("CK_DoctorPatients_LastSessionType", "([LastSessionType] IS NULL OR ([LastSessionType]='consultation' OR [LastSessionType]='examination'))");
                    table.ForeignKey(
                        name: "FK_DoctorPatients_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_DoctorPatients_LastSessionBranchId",
                        column: x => x.LastSessionBranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_DoctorPatients_LinkedBy",
                        column: x => x.LinkedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_DoctorPatients_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "PatientMedicalProfileItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    LinkId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Kind = table.Column<string>(type: "varchar(17)", unicode: false, maxLength: 17, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PatientMedicalProfileItems", x => x.Id);
                    table.CheckConstraint("CK_PatientMedicalProfileItems_Kind", "([Kind]='surgery' OR [Kind]='currentMedication' OR [Kind]='chronicDisease' OR [Kind]='allergy')");
                    table.ForeignKey(
                        name: "FK_PatientMedicalProfileItems_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_PatientMedicalProfileItems_LinkId",
                        column: x => x.LinkId,
                        principalTable: "DoctorPatients",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Sessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LinkId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AppointmentId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Type = table.Column<string>(type: "varchar(12)", unicode: false, maxLength: 12, nullable: false),
                    FeePiasters = table.Column<int>(type: "int", nullable: false),
                    PatientFeePiasters = table.Column<int>(type: "int", nullable: false),
                    ListPricePiasters = table.Column<int>(type: "int", nullable: true),
                    PaymentMethod = table.Column<string>(type: "varchar(8)", unicode: false, maxLength: 8, nullable: true),
                    DayKey = table.Column<DateOnly>(type: "date", nullable: false),
                    MonthKey = table.Column<string>(type: "char(7)", unicode: false, fixedLength: true, maxLength: 7, nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedByRole = table.Column<string>(type: "varchar(9)", unicode: false, maxLength: 9, nullable: false),
                    AwaitingDoctor = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    ChiefComplaint = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    Findings = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    BpSys = table.Column<short>(type: "smallint", nullable: true),
                    BpDia = table.Column<short>(type: "smallint", nullable: true),
                    Pulse = table.Column<short>(type: "smallint", nullable: true),
                    TempC = table.Column<decimal>(type: "decimal(3,1)", nullable: true),
                    WeightKg = table.Column<decimal>(type: "decimal(5,2)", nullable: true),
                    HeightCm = table.Column<decimal>(type: "decimal(4,1)", nullable: true),
                    Glucose = table.Column<short>(type: "smallint", nullable: true),
                    Diagnosis = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    PatientNotes = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    FollowUpDate = table.Column<DateOnly>(type: "date", nullable: true),
                    PatientSeenAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    Deleted = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    DeletedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    DeletedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    DeleteReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Sessions", x => x.Id);
                    table.CheckConstraint("CK_Sessions_Amounts", "([FeePiasters]>=(0) AND ([PatientFeePiasters]>=(0) AND [PatientFeePiasters]<=(10000000)))");
                    table.CheckConstraint("CK_Sessions_CreatedByRole", "([CreatedByRole]='assistant' OR [CreatedByRole]='doctor')");
                    table.CheckConstraint("CK_Sessions_Deleted", "([Deleted]=(0) OR [DeletedAt] IS NOT NULL AND [DeleteReason] IS NOT NULL)");
                    table.CheckConstraint("CK_Sessions_MonthKey", "([MonthKey] like '[12][0-9][0-9][0-9]-[01][0-9]')");
                    table.CheckConstraint("CK_Sessions_PaymentMethod", "([PaymentMethod] IS NULL OR ([PaymentMethod]='wallet' OR [PaymentMethod]='instapay' OR [PaymentMethod]='card' OR [PaymentMethod]='cash'))");
                    table.CheckConstraint("CK_Sessions_Type", "([Type]='consultation' OR [Type]='examination')");
                    table.ForeignKey(
                        name: "FK_Sessions_AppointmentId",
                        column: x => x.AppointmentId,
                        principalTable: "Appointments",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Sessions_BranchId",
                        column: x => x.BranchId,
                        principalTable: "Branches",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Sessions_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Sessions_DeletedBy",
                        column: x => x.DeletedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Sessions_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_Sessions_LinkId",
                        column: x => x.LinkId,
                        principalTable: "DoctorPatients",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Sessions_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "MedicalRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Category = table.Column<string>(type: "varchar(12)", unicode: false, maxLength: 12, nullable: false),
                    OtherType = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: true),
                    OtherTypeText = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    Title = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    DocumentDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Notes = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    Source = table.Column<string>(type: "varchar(6)", unicode: false, maxLength: 6, nullable: false),
                    SourceChatMessageId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedByRole = table.Column<string>(type: "varchar(9)", unicode: false, maxLength: 9, nullable: false),
                    PatientSeenAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    Deleted = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    DeletedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    DeletedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MedicalRecords", x => x.Id);
                    table.CheckConstraint("CK_MedicalRecords_Category", "([Category]='other' OR [Category]='radiology' OR [Category]='lab' OR [Category]='prescription')");
                    table.CheckConstraint("CK_MedicalRecords_OtherType", "([Category]='other' AND ([OtherType] IS NULL OR ([OtherType]='custom' OR [OtherType]='consent' OR [OtherType]='endoscopy' OR [OtherType]='eegEmg' OR [OtherType]='ecg' OR [OtherType]='sickLeave' OR [OtherType]='referral' OR [OtherType]='report')) OR [Category]<>'other' AND [OtherType] IS NULL)");
                    table.CheckConstraint("CK_MedicalRecords_Role", "([CreatedByRole]='assistant' OR [CreatedByRole]='doctor')");
                    table.CheckConstraint("CK_MedicalRecords_Source", "([Source]='chat' OR [Source]='upload' OR [Source]='scan')");
                    table.ForeignKey(
                        name: "FK_MedicalRecords_CreatedBy",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_MedicalRecords_DeletedBy",
                        column: x => x.DeletedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_MedicalRecords_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_MedicalRecords_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_MedicalRecords_SessionId",
                        column: x => x.SessionId,
                        principalTable: "Sessions",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_MedicalRecords_SourceChatMessageId",
                        column: x => x.SourceChatMessageId,
                        principalTable: "ChatMessages",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Prescriptions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    DoctorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Kind = table.Column<string>(type: "varchar(14)", unicode: false, maxLength: 14, nullable: false),
                    Diagnosis = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    Advice = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    Status = table.Column<string>(type: "varchar(14)", unicode: false, maxLength: 14, nullable: false, defaultValue: "draft"),
                    PreparedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    PreparedByRole = table.Column<string>(type: "varchar(9)", unicode: false, maxLength: 9, nullable: true),
                    PdfPath = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    SentAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CancelledAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CancelReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ReplacesRxId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    QrShortCode = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    PatientSeenAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Prescriptions", x => x.Id);
                    table.CheckConstraint("CK_Prescriptions_Cancel", "([Status]<>'cancelled' OR [CancelledAt] IS NOT NULL AND [CancelReason] IS NOT NULL)");
                    table.CheckConstraint("CK_Prescriptions_Kind", "([Kind]='investigations' OR [Kind]='medication')");
                    table.CheckConstraint("CK_Prescriptions_QrLen", "(len([QrShortCode])>=(10))");
                    table.CheckConstraint("CK_Prescriptions_Sent", "(NOT ([Status]='cancelled' OR [Status]='sent') OR [PdfPath] IS NOT NULL AND [SentAt] IS NOT NULL)");
                    table.CheckConstraint("CK_Prescriptions_Status", "([Status]='cancelled' OR [Status]='sent' OR [Status]='readyForReview' OR [Status]='draft')");
                    table.ForeignKey(
                        name: "FK_Prescriptions_DoctorId",
                        column: x => x.DoctorId,
                        principalTable: "Doctors",
                        principalColumn: "UserId");
                    table.ForeignKey(
                        name: "FK_Prescriptions_PatientId",
                        column: x => x.PatientId,
                        principalTable: "Patients",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Prescriptions_PreparedBy",
                        column: x => x.PreparedBy,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Prescriptions_ReplacesRxId",
                        column: x => x.ReplacesRxId,
                        principalTable: "Prescriptions",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Prescriptions_SessionId",
                        column: x => x.SessionId,
                        principalTable: "Sessions",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "SessionPrivateNotes",
                columns: table => new
                {
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Text = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SessionPrivateNotes", x => x.SessionId);
                    table.ForeignKey(
                        name: "FK_SessionPrivateNotes_SessionId",
                        column: x => x.SessionId,
                        principalTable: "Sessions",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "MedicalRecordAttachments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    RecordId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Path = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: false),
                    FileName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    MimeType = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    PageCount = table.Column<int>(type: "int", nullable: true),
                    ThumbPath = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    SortOrder = table.Column<int>(type: "int", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MedicalRecordAttachments", x => x.Id);
                    table.CheckConstraint("CK_MedicalRecordAttachments_Size", "([SizeBytes]>(0))");
                    table.ForeignKey(
                        name: "FK_MedicalRecordAttachments_RecordId",
                        column: x => x.RecordId,
                        principalTable: "MedicalRecords",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "PrescriptionInvestigationItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    PrescriptionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    Category = table.Column<string>(type: "varchar(9)", unicode: false, maxLength: 9, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    LoincCode = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: true),
                    Notes = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PrescriptionInvestigationItems", x => x.Id);
                    table.CheckConstraint("CK_PrescriptionInvestigationItems_Category", "([Category]='radiology' OR [Category]='lab')");
                    table.ForeignKey(
                        name: "FK_PrescriptionInvestigationItems_PrescriptionId",
                        column: x => x.PrescriptionId,
                        principalTable: "Prescriptions",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "PrescriptionMedicationItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())"),
                    PrescriptionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    DrugName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ActiveIngredient = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    CatalogId = table.Column<string>(type: "varchar(50)", unicode: false, maxLength: 50, nullable: true),
                    Form = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    Strength = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    Dose = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Frequency = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Timing = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Duration = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Instructions = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PrescriptionMedicationItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PrescriptionMedicationItems_PrescriptionId",
                        column: x => x.PrescriptionId,
                        principalTable: "Prescriptions",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_AppointmentHistory_Appointment",
                table: "AppointmentHistory",
                columns: new[] { "AppointmentId", "At" });

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_Branch_Date_Status",
                table: "Appointments",
                columns: new[] { "BranchId", "LocalDate", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_Doctor_Date_Status",
                table: "Appointments",
                columns: new[] { "DoctorId", "LocalDate", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_Due_Reminders",
                table: "Appointments",
                column: "StartUtc",
                filter: "([Status]='confirmed')");

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_GuestPhone",
                table: "Appointments",
                column: "GuestPhone",
                filter: "([GuestPhone] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_Patient_Start",
                table: "Appointments",
                columns: new[] { "PatientId", "StartUtc" },
                descending: new[] { false, true },
                filter: "([PatientId] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_Pending",
                table: "Appointments",
                column: "CreatedAt",
                filter: "([Status]='pending')");

            migrationBuilder.CreateIndex(
                name: "UQ_Appointments_QueueNumber",
                table: "Appointments",
                columns: new[] { "BranchId", "LocalDate", "PeriodStartLocal", "QueueNumber" },
                unique: true,
                filter: "([QueueNumber] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "UQ_Appointments_TimedSlot",
                table: "Appointments",
                columns: new[] { "BranchId", "StartUtc" },
                unique: true,
                filter: "([Mode]='timed' AND [Overbooked]=(0) AND ([Status] IN ('pending', 'confirmed', 'checkedIn', 'withDoctor')))");

            migrationBuilder.CreateIndex(
                name: "IX_Assistants_DoctorId",
                table: "Assistants",
                columns: new[] { "DoctorId", "Status" });

            migrationBuilder.CreateIndex(
                name: "UQ_Assistants_Phone",
                table: "Assistants",
                column: "Phone",
                unique: true,
                filter: "([Status] IN ('active', 'disabled'))");

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogs_Actor_At",
                table: "AuditLogs",
                columns: new[] { "ActorUserId", "At" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogs_At",
                table: "AuditLogs",
                column: "At",
                descending: new bool[0]);

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogs_Doctor_At",
                table: "AuditLogs",
                columns: new[] { "DoctorId", "At" },
                descending: new[] { false, true },
                filter: "([DoctorId] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogs_Target",
                table: "AuditLogs",
                columns: new[] { "TargetType", "TargetId" });

            migrationBuilder.CreateIndex(
                name: "IX_BranchClosures_Doctor_Branch_From",
                table: "BranchClosures",
                columns: new[] { "DoctorId", "BranchId", "FromLocal" });

            migrationBuilder.CreateIndex(
                name: "IX_BranchDateOverridePeriods_OverrideId",
                table: "BranchDateOverridePeriods",
                column: "OverrideId");

            migrationBuilder.CreateIndex(
                name: "UQ_BranchDateOverrides_Branch_Date",
                table: "BranchDateOverrides",
                columns: new[] { "BranchId", "Date" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Branches_DoctorId",
                table: "Branches",
                columns: new[] { "DoctorId", "Status" });

            migrationBuilder.CreateIndex(
                name: "UQ_Branches_OneDefault",
                table: "Branches",
                column: "DoctorId",
                unique: true,
                filter: "([IsDefault]=(1))");

            migrationBuilder.CreateIndex(
                name: "IX_BranchPeriods_Branch_Weekday",
                table: "BranchPeriods",
                columns: new[] { "BranchId", "Weekday" });

            migrationBuilder.CreateIndex(
                name: "IX_BranchPhones_BranchId",
                table: "BranchPhones",
                column: "BranchId");

            migrationBuilder.CreateIndex(
                name: "IX_CatalogCustomItems_UpdatedAt",
                table: "CatalogCustomItems",
                column: "UpdatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_CatalogReports_Status",
                table: "CatalogReports",
                columns: new[] { "Status", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "UQ_CatalogVersions_VersionNumber",
                table: "CatalogVersions",
                column: "VersionNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_Chat_CreatedAt",
                table: "ChatMessages",
                columns: new[] { "ChatId", "CreatedAt" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "IX_ChatReadStates_User_Unread",
                table: "ChatReadStates",
                column: "UserId",
                filter: "([UnreadCount]>(0))");

            migrationBuilder.CreateIndex(
                name: "IX_Chats_Doctor_LastMessage",
                table: "Chats",
                columns: new[] { "DoctorId", "LastMessageAt" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "IX_Chats_Patient_LastMessage",
                table: "Chats",
                columns: new[] { "PatientId", "LastMessageAt" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "UQ_Chats_LinkId",
                table: "Chats",
                column: "LinkId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DeletionRequests_Status",
                table: "DeletionRequests",
                columns: new[] { "Status", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_DoctorAdminNotes_DoctorId",
                table: "DoctorAdminNotes",
                columns: new[] { "DoctorId", "CreatedAt" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "UQ_DoctorItemHistory",
                table: "DoctorItemHistory",
                columns: new[] { "DoctorId", "Kind", "Name", "Form", "Strength" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DoctorPatients_Doctor_LastSession",
                table: "DoctorPatients",
                columns: new[] { "DoctorId", "Archived", "LastSessionAt" },
                descending: new[] { false, false, true });

            migrationBuilder.CreateIndex(
                name: "IX_DoctorPatients_Doctor_Phone",
                table: "DoctorPatients",
                columns: new[] { "DoctorId", "PatientPhone" });

            migrationBuilder.CreateIndex(
                name: "IX_DoctorPatients_Doctor_SearchName",
                table: "DoctorPatients",
                columns: new[] { "DoctorId", "SearchName" });

            migrationBuilder.CreateIndex(
                name: "IX_DoctorPatients_PatientId",
                table: "DoctorPatients",
                column: "PatientId");

            migrationBuilder.CreateIndex(
                name: "UQ_DoctorPatients_Doctor_File",
                table: "DoctorPatients",
                columns: new[] { "DoctorId", "FileNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UQ_DoctorPatients_Doctor_Patient",
                table: "DoctorPatients",
                columns: new[] { "DoctorId", "PatientId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Doctors_SpecialtyId",
                table: "Doctors",
                column: "SpecialtyId");

            migrationBuilder.CreateIndex(
                name: "IX_Doctors_Status",
                table: "Doctors",
                columns: new[] { "Status", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_InvoiceAdjustments_InvoiceId",
                table: "InvoiceAdjustments",
                column: "InvoiceId");

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_Doctor_Month",
                table: "Invoices",
                columns: new[] { "DoctorId", "MonthKey" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_Status_DueDate",
                table: "Invoices",
                columns: new[] { "Status", "DueDate" });

            migrationBuilder.CreateIndex(
                name: "UQ_Invoices_Doctor_Month",
                table: "Invoices",
                columns: new[] { "DoctorId", "MonthKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_InvoiceStatusHistory_InvoiceId",
                table: "InvoiceStatusHistory",
                columns: new[] { "InvoiceId", "ChangedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_MedicalRecordAttachments_RecordId",
                table: "MedicalRecordAttachments",
                column: "RecordId");

            migrationBuilder.CreateIndex(
                name: "IX_MedicalRecords_Doctor_Patient_Category",
                table: "MedicalRecords",
                columns: new[] { "DoctorId", "PatientId", "Category", "Deleted", "DocumentDate" },
                descending: new[] { false, false, false, false, true });

            migrationBuilder.CreateIndex(
                name: "IX_MedicalRecords_Patient_Category",
                table: "MedicalRecords",
                columns: new[] { "PatientId", "Category", "Deleted", "DocumentDate" },
                descending: new[] { false, false, false, true });

            migrationBuilder.CreateIndex(
                name: "IX_MedicalRecords_SessionId",
                table: "MedicalRecords",
                column: "SessionId",
                filter: "([SessionId] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_Recipient",
                table: "Notifications",
                columns: new[] { "RecipientUserId", "CreatedAt" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_Recipient_Unread",
                table: "Notifications",
                column: "RecipientUserId",
                filter: "([IsRead]=(0))");

            migrationBuilder.CreateIndex(
                name: "IX_PatientMedicalProfileItems_Link_Kind",
                table: "PatientMedicalProfileItems",
                columns: new[] { "LinkId", "Kind" });

            migrationBuilder.CreateIndex(
                name: "UQ_Patients_Phone",
                table: "Patients",
                column: "Phone",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UQ_Patients_UserId",
                table: "Patients",
                column: "UserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Payments_InvoiceId",
                table: "Payments",
                column: "InvoiceId");

            migrationBuilder.CreateIndex(
                name: "IX_Payments_Status_SubmittedAt",
                table: "Payments",
                columns: new[] { "Status", "SubmittedAt" });

            migrationBuilder.CreateIndex(
                name: "UQ_PaymentScreenshots_Payment_Order",
                table: "PaymentScreenshots",
                columns: new[] { "PaymentId", "SortOrder" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PrescriptionInvestigationItems_Rx",
                table: "PrescriptionInvestigationItems",
                columns: new[] { "PrescriptionId", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_PrescriptionMedicationItems_Rx",
                table: "PrescriptionMedicationItems",
                columns: new[] { "PrescriptionId", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_Prescriptions_Doctor_Patient",
                table: "Prescriptions",
                columns: new[] { "DoctorId", "PatientId", "CreatedAt" },
                descending: new[] { false, false, true });

            migrationBuilder.CreateIndex(
                name: "IX_Prescriptions_Doctor_Review",
                table: "Prescriptions",
                columns: new[] { "DoctorId", "Status" },
                filter: "([Status]='readyForReview')");

            migrationBuilder.CreateIndex(
                name: "IX_Prescriptions_Patient_Status",
                table: "Prescriptions",
                columns: new[] { "PatientId", "Status", "CreatedAt" },
                descending: new[] { false, false, true });

            migrationBuilder.CreateIndex(
                name: "IX_Prescriptions_SessionId",
                table: "Prescriptions",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "UQ_Prescriptions_QrShortCode",
                table: "Prescriptions",
                column: "QrShortCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PriceHistory_Doctor",
                table: "PriceHistory",
                columns: new[] { "DoctorId", "ChangedAt" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "UQ_PublicHolidays_Date",
                table: "PublicHolidays",
                column: "Date",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_User_Active",
                table: "RefreshTokens",
                column: "UserId",
                filter: "([RevokedAt] IS NULL)");

            migrationBuilder.CreateIndex(
                name: "UQ_RefreshTokens_TokenHash",
                table: "RefreshTokens",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Sessions_Doctor_Day",
                table: "Sessions",
                columns: new[] { "DoctorId", "DayKey", "CreatedAt" },
                descending: new[] { false, false, true });

            migrationBuilder.CreateIndex(
                name: "IX_Sessions_Doctor_Month",
                table: "Sessions",
                columns: new[] { "DoctorId", "MonthKey", "Deleted" })
                .Annotation("SqlServer:Include", new[] { "Type", "FeePiasters", "BranchId" });

            migrationBuilder.CreateIndex(
                name: "IX_Sessions_Doctor_Patient",
                table: "Sessions",
                columns: new[] { "DoctorId", "PatientId", "Deleted", "CreatedAt" },
                descending: new[] { false, false, false, true });

            migrationBuilder.CreateIndex(
                name: "IX_Sessions_Patient",
                table: "Sessions",
                columns: new[] { "PatientId", "Deleted", "CreatedAt" },
                descending: new[] { false, false, true });

            migrationBuilder.CreateIndex(
                name: "UQ_Sessions_AppointmentId",
                table: "Sessions",
                column: "AppointmentId",
                unique: true,
                filter: "([AppointmentId] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "IX_SettingsHistory_Field_ChangedAt",
                table: "SettingsHistory",
                columns: new[] { "Field", "ChangedAt" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "UQ_Specialties_NameAr",
                table: "Specialties",
                column: "NameAr",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UQ_Specialties_NameEn",
                table: "Specialties",
                column: "NameEn",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UQ_SpecialtyProfileItems",
                table: "SpecialtyProfileItems",
                columns: new[] { "SpecialtyId", "ItemType", "Value" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UQ_UserDevices_User_Device",
                table: "UserDevices",
                columns: new[] { "UserId", "DeviceId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_Phone",
                table: "Users",
                column: "Phone",
                filter: "([Phone] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "UQ_Users_Email",
                table: "Users",
                column: "Email",
                unique: true,
                filter: "([Email] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "UQ_Users_PatientPhone",
                table: "Users",
                column: "Phone",
                unique: true,
                filter: "([Role]='patient' AND [Phone] IS NOT NULL)");

            migrationBuilder.CreateIndex(
                name: "UQ_UserTokens_TokenHash",
                table: "UserTokens",
                column: "TokenHash",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_AppointmentHistory_AppointmentId",
                table: "AppointmentHistory",
                column: "AppointmentId",
                principalTable: "Appointments",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_BranchId",
                table: "Appointments",
                column: "BranchId",
                principalTable: "Branches",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_DoctorId",
                table: "Appointments",
                column: "DoctorId",
                principalTable: "Doctors",
                principalColumn: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_PatientId",
                table: "Appointments",
                column: "PatientId",
                principalTable: "Patients",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_SessionId",
                table: "Appointments",
                column: "SessionId",
                principalTable: "Sessions",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_AssistantBranches_AssistantId",
                table: "AssistantBranches",
                column: "AssistantId",
                principalTable: "Assistants",
                principalColumn: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_AssistantBranches_BranchId",
                table: "AssistantBranches",
                column: "BranchId",
                principalTable: "Branches",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Assistants_DoctorId",
                table: "Assistants",
                column: "DoctorId",
                principalTable: "Doctors",
                principalColumn: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_AuditLogs_DoctorId",
                table: "AuditLogs",
                column: "DoctorId",
                principalTable: "Doctors",
                principalColumn: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_AuditLogs_PatientId",
                table: "AuditLogs",
                column: "PatientId",
                principalTable: "Patients",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_BranchClosures_BranchId",
                table: "BranchClosures",
                column: "BranchId",
                principalTable: "Branches",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_BranchClosures_DoctorId",
                table: "BranchClosures",
                column: "DoctorId",
                principalTable: "Doctors",
                principalColumn: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_BranchDateOverridePeriods_OverrideId",
                table: "BranchDateOverridePeriods",
                column: "OverrideId",
                principalTable: "BranchDateOverrides",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_BranchDateOverrides_BranchId",
                table: "BranchDateOverrides",
                column: "BranchId",
                principalTable: "Branches",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_BranchDayStates_BranchId",
                table: "BranchDayStates",
                column: "BranchId",
                principalTable: "Branches",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Branches_DoctorId",
                table: "Branches",
                column: "DoctorId",
                principalTable: "Doctors",
                principalColumn: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_ChatMessages_ChatId",
                table: "ChatMessages",
                column: "ChatId",
                principalTable: "Chats",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_ChatReadStates_ChatId",
                table: "ChatReadStates",
                column: "ChatId",
                principalTable: "Chats",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Chats_LinkId",
                table: "Chats",
                column: "LinkId",
                principalTable: "DoctorPatients",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_DoctorPatients_LastSessionId",
                table: "DoctorPatients",
                column: "LastSessionId",
                principalTable: "Sessions",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Sessions_AppointmentId",
                table: "Sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_DoctorPatients_LinkedBy",
                table: "DoctorPatients");

            migrationBuilder.DropForeignKey(
                name: "FK_Doctors_ApprovedBy",
                table: "Doctors");

            migrationBuilder.DropForeignKey(
                name: "FK_Doctors_UserId",
                table: "Doctors");

            migrationBuilder.DropForeignKey(
                name: "FK_Patients_UserId",
                table: "Patients");

            migrationBuilder.DropForeignKey(
                name: "FK_Sessions_CreatedBy",
                table: "Sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_Sessions_DeletedBy",
                table: "Sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_DoctorPatients_LastSessionBranchId",
                table: "DoctorPatients");

            migrationBuilder.DropForeignKey(
                name: "FK_Doctors_DefaultBranchId",
                table: "Doctors");

            migrationBuilder.DropForeignKey(
                name: "FK_Sessions_BranchId",
                table: "Sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_DoctorPatients_DoctorId",
                table: "DoctorPatients");

            migrationBuilder.DropForeignKey(
                name: "FK_Patients_CreatedByDoctorId",
                table: "Patients");

            migrationBuilder.DropForeignKey(
                name: "FK_Sessions_DoctorId",
                table: "Sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_DoctorPatients_PatientId",
                table: "DoctorPatients");

            migrationBuilder.DropForeignKey(
                name: "FK_Sessions_PatientId",
                table: "Sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_DoctorPatients_LastSessionId",
                table: "DoctorPatients");

            migrationBuilder.DropTable(
                name: "AppointmentHistory");

            migrationBuilder.DropTable(
                name: "AppSettings");

            migrationBuilder.DropTable(
                name: "AssistantBranches");

            migrationBuilder.DropTable(
                name: "AuditLogs");

            migrationBuilder.DropTable(
                name: "BranchClosures");

            migrationBuilder.DropTable(
                name: "BranchDateOverridePeriods");

            migrationBuilder.DropTable(
                name: "BranchDayStates");

            migrationBuilder.DropTable(
                name: "BranchPeriods");

            migrationBuilder.DropTable(
                name: "BranchPhones");

            migrationBuilder.DropTable(
                name: "BranchPhotos");

            migrationBuilder.DropTable(
                name: "CatalogCustomItems");

            migrationBuilder.DropTable(
                name: "CatalogReports");

            migrationBuilder.DropTable(
                name: "ChatReadStates");

            migrationBuilder.DropTable(
                name: "DailyStats");

            migrationBuilder.DropTable(
                name: "DeletionRequests");

            migrationBuilder.DropTable(
                name: "DoctorAdminNotes");

            migrationBuilder.DropTable(
                name: "DoctorDailyMetrics");

            migrationBuilder.DropTable(
                name: "DoctorExtraSpecialties");

            migrationBuilder.DropTable(
                name: "DoctorItemHistory");

            migrationBuilder.DropTable(
                name: "InvoiceAdjustments");

            migrationBuilder.DropTable(
                name: "InvoiceBranchBreakdown");

            migrationBuilder.DropTable(
                name: "InvoiceStatusHistory");

            migrationBuilder.DropTable(
                name: "MedicalRecordAttachments");

            migrationBuilder.DropTable(
                name: "MonthlyStats");

            migrationBuilder.DropTable(
                name: "Notifications");

            migrationBuilder.DropTable(
                name: "PatientMedicalProfileItems");

            migrationBuilder.DropTable(
                name: "PaymentScreenshots");

            migrationBuilder.DropTable(
                name: "PrescriptionInvestigationItems");

            migrationBuilder.DropTable(
                name: "PrescriptionMedicationItems");

            migrationBuilder.DropTable(
                name: "PrescriptionTemplates");

            migrationBuilder.DropTable(
                name: "PriceHistory");

            migrationBuilder.DropTable(
                name: "PublicHolidays");

            migrationBuilder.DropTable(
                name: "RefreshTokens");

            migrationBuilder.DropTable(
                name: "SessionPrivateNotes");

            migrationBuilder.DropTable(
                name: "SettingsHistory");

            migrationBuilder.DropTable(
                name: "SpecialtyProfileItems");

            migrationBuilder.DropTable(
                name: "UserDevices");

            migrationBuilder.DropTable(
                name: "UserTokens");

            migrationBuilder.DropTable(
                name: "CatalogVersions");

            migrationBuilder.DropTable(
                name: "Assistants");

            migrationBuilder.DropTable(
                name: "BranchDateOverrides");

            migrationBuilder.DropTable(
                name: "MedicalRecords");

            migrationBuilder.DropTable(
                name: "Payments");

            migrationBuilder.DropTable(
                name: "Prescriptions");

            migrationBuilder.DropTable(
                name: "ChatMessages");

            migrationBuilder.DropTable(
                name: "Invoices");

            migrationBuilder.DropTable(
                name: "Chats");

            migrationBuilder.DropTable(
                name: "Appointments");

            migrationBuilder.DropTable(
                name: "Users");

            migrationBuilder.DropTable(
                name: "Branches");

            migrationBuilder.DropTable(
                name: "Doctors");

            migrationBuilder.DropTable(
                name: "Specialties");

            migrationBuilder.DropTable(
                name: "Patients");

            migrationBuilder.DropTable(
                name: "Sessions");

            migrationBuilder.DropTable(
                name: "DoctorPatients");
        }
    }
}
