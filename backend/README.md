# el3yada API (ASP.NET Core)

The Web API and the SQL Server database for the el3yada app. The full product spec is [`../spec.md`](../spec.md) and the work plan is [`../PHASES.md`](../PHASES.md). The endpoint contract for the app is in [`docs/`](docs/). Phase 1 (sign-in and admin basics) is [`docs/api-phase-1.md`](docs/api-phase-1.md).

| Project | What it holds |
|---|---|
| `src/El3yada.Api` | ASP.NET Core Web API (.NET 10): controllers, `Program.cs`, settings (`Configuration/`), sign-in and tokens (`Auth/`), the audit log (`Audit/`), email (`Email/`), notification rows (`Notifications/`), doctor registration (`Doctors/`), AD13 settings fields (`Settings/`), the `seed-admin` and `add-booking` commands (`Commands/`), validation (`Validation/`), file storage (`Storage/`) |
| `src/El3yada.Data` | EF Core: `AppDbContext`, one entity class per table (`Entities/`), migrations |
| `tests/El3yada.Api.Tests` | xUnit. Unit tests for validation, settings checks and file storage, and integration tests in `Integration/` that run the real API on a throwaway migrated database |
| `tests/El3yada.Data.Tests` | xUnit tests that build a fresh database from the migrations and check it |

Packages added on top of ASP.NET Core and EF Core:

| Package | Used for |
|---|---|
| `Serilog.AspNetCore`, `Serilog.Enrichers.Environment` | Logs to the console and a daily file, one line per request |
| `FluentValidation`, `FluentValidation.DependencyInjectionExtensions` | Input validation (rules from spec section 11) |
| `SkiaSharp`, `SkiaSharp.NativeAssets.Linux.NoDependencies` | Image thumbnails (MIT licence; the second package makes it work on a Linux host) |
| `Microsoft.AspNetCore.Authentication.JwtBearer` | Access tokens (JWT, HMAC-SHA256) |
| `MailKit` | Email over SMTP, and `.eml` files in development (MIT licence) |
| `Microsoft.AspNetCore.Mvc.Testing` (tests only) | Runs the real API in memory |

Password hashing (`PasswordHasher<T>` from ASP.NET Core Identity) and rate limiting (`Microsoft.AspNetCore.RateLimiting`) come with ASP.NET Core.

## Before the first run

1. **.NET 10 SDK** (`dotnet --version`).
2. **SQL Server LocalDB**, which comes with Visual Studio or the SQL Server Express installer. Check with `sqllocaldb info`.
3. From this folder (`backend/`):

```bash
dotnet tool restore            # installs dotnet-ef 10.0.11 from dotnet-tools.json
dotnet ef database update --project src/El3yada.Data --startup-project src/El3yada.Api
dotnet user-secrets set Jwt:SigningKey "$(openssl rand -base64 48)" --project src/El3yada.Api
dotnet run --project src/El3yada.Api -- seed-admin you@example.com --name "First Last"
```

These commands:

- create the `el3yada_dev` database with all 55 tables, the platform settings and the starting specialties;
- give your machine its own JWT signing key;
- create your first super admin, printing a temporary password once.

The key is stored outside the repo (`%APPDATA%\Microsoft\UserSecrets\el3yada-api\secrets.json`, or `~/.microsoft/usersecrets/el3yada-api/` on macOS and Linux). In PowerShell 7, use `([Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48)))` in place of `"$(openssl rand -base64 48)"`. Any random value of 32 bytes or more works.

Without the key, the API stops at start-up with a message that shows this command. After pulling someone else's migration, run the `database update` line again.

## First super admin: `seed-admin`

```bash
dotnet run --project src/El3yada.Api -- seed-admin <email> [--name "First Last"] [--reset]
```

- It creates an active **super admin** with `mustChangePassword` and a 12-character temporary password, printed **once**. The first sign-in goes to A9 (set new password). There is no admin sign-up screen (spec section 5); later admins are added in AD14.
- It refuses an email that already exists and changes nothing (exit code 1).
- `--reset` is for recovery when no super admin can sign in. For an existing **admin** with that email, it prints a new temporary password, makes the account an active super admin, clears its lock and signs it out everywhere. It never touches a doctor, assistant or patient account.
- `--name` defaults to "Super Admin" and must be two words, letters only.
- In production, run it once on the server with the production environment variables set.
- It writes an `adminSeeded` audit row. The handler is `SeedAdminCommand.ExecuteAsync`, which `SeedAdminCommandTests` calls directly.

## A test booking: `add-booking` (Development only)

```bash
dotnet run --project src/El3yada.Api -- add-booking --branch <branchId> --patient <patientId> [--date YYYY-MM-DD]
```

- Bookings get their endpoints in Phase 6, but branches already count them (D28 "upcoming bookings") and refuse to close or be archived while they have some (`BRANCH_HAS_BOOKINGS`). This inserts one confirmed queue booking at 10:00 Cairo time on `--date` (default: tomorrow), for a patient of the branch's doctor, and prints its ID.
- It refuses to run unless the environment is Development. `dotnet run` takes Development from the launch profile; the database is the one in `ConnectionStrings:Default`, so set `ConnectionStrings__Default` when it must be another database (the app's contract test does).
- The handler is `AddBookingCommand.ExecuteAsync`, which `AddBookingCommandTests` calls directly.

## Run

```bash
dotnet run --project src/El3yada.Api --launch-profile https
```

- API: `https://localhost:7001`, the same address as the Flutter app's `config/dev.json`. Every route starts with `/api/`.
- Health check: `GET https://localhost:7001/api/health` returns the database name and the applied and pending migrations.
- OpenAPI document (Development only): `https://localhost:7001/openapi/v1.json`.
- Logs: the console, and `src/El3yada.Api/logs/el3yada-api-YYYYMMDD.log` (one JSON object per line, kept 31 days).
- Stored files: `src/El3yada.Api/App_Data/files/`.
- Emails (Development): every email the API sends is written as an `.eml` file to `src/El3yada.Api/App_Data/mail/`. Open it in any mail app, or copy the link from the text. Reset links look like `https://localhost:7001/reset-password?token=…`.

All of these folders are git-ignored.

## Settings and secrets

Settings are checked when the API starts. A missing secret or a value out of range stops it with a message that names the setting.

| Setting | Development | Production |
|---|---|---|
| `ConnectionStrings:Default` | LocalDB, in `appsettings.Development.json` | `ConnectionStrings__Default` |
| `Jwt:SigningKey` (32 bytes or more) | user-secrets (above) | `Jwt__SigningKey` |
| `Jwt:Issuer`, `Jwt:Audience` | `appsettings.json` | same, or `Jwt__Issuer`, `Jwt__Audience` |
| `Jwt:AccessTokenMinutes` (1–1440), `Jwt:RefreshTokenDays` (1–365) | 15 and 30, in `appsettings.json` | same, or `Jwt__AccessTokenMinutes`, `Jwt__RefreshTokenDays` |
| `Auth:MaxFailedLogins` (5), `Auth:LockoutMinutes` (15) | `appsettings.json` | same, or `Auth__MaxFailedLogins`, `Auth__LockoutMinutes` |
| `Auth:PasswordResetTokenMinutes` (60), `Auth:EmailVerificationTokenHours` (48), `Auth:VerificationEmailCooldownSeconds` (60), `Auth:AccountSelectionMinutes` (5) | `appsettings.json` | same, or `Auth__…` |
| `Auth:UserStateCacheSeconds` (30): how long the per-request account check is cached | `appsettings.json` | same, or `Auth__UserStateCacheSeconds` |
| `RateLimits` per IP: `LoginPerMinute` (10), `PasswordResetPer15Minutes` (5), `RegistrationPerHour` (10), `RefreshPerMinute` (60), `EmailTokenPer15Minutes` (20) | `appsettings.json` | same, or `RateLimits__…` |
| `RateLimits:PasswordResetPerIdentifierPerHour` (3): per email or mobile number | `appsettings.json` | same, or `RateLimits__PasswordResetPerIdentifierPerHour` |
| `Email:Delivery` | `Pickup` (`.eml` files), in `appsettings.Development.json` | `Smtp` (required) |
| `Email:PickupDirectory` | `App_Data/mail` | not used |
| `Email:FromAddress`, `Email:FromName` | `no-reply@el3yada.local`, `el3yada` | `Email__FromAddress` (required), `Email__FromName` |
| `Email:ResetPasswordUrl`, `Email:VerifyEmailUrl`: the emailed link; the API adds `?token=…` | `https://localhost:7001/reset-password`, `…/verify-email` | `Email__ResetPasswordUrl`, `Email__VerifyEmailUrl` (required): an App Link / Universal Link, or a custom scheme such as `el3yada://reset-password` |
| `Email:Smtp:Host`, `Email:Smtp:Port` (587), `Email:Smtp:Security` (`StartTls`; `SslOnConnect` for port 465; `None` for a local relay only) | not used | `Email__Smtp__Host` (required), `Email__Smtp__Port`, `Email__Smtp__Security` |
| `Email:Smtp:Username`, `Email:Smtp:Password` | not used | `Email__Smtp__Username`, `Email__Smtp__Password` (a secret) |
| `Storage:RootPath` | `App_Data/files`, in `appsettings.Development.json` | `Storage__RootPath`, an absolute path outside the deploy folder |
| `Storage:MaxUploadMb` (1–200) | 200, in `appsettings.json` | same, or `Storage__MaxUploadMb` |
| `Storage:ThumbnailMaxPx` (64–1024) | 320, in `appsettings.json` | same, or `Storage__ThumbnailMaxPx` |
| Log file | `logs/el3yada-api-.log` | `Serilog__WriteTo__File__Args__path`, an absolute path |

Production reads secrets from environment variables only. Never commit a secret, a production connection string or a key, not even in `appsettings.Development.json`. In production the API refuses to start without SMTP, a real sender address and real email links.

**Behind a reverse proxy** (IIS, nginx, a cloud load balancer), the per-IP rate limits see the proxy's address, so all users share one limit. Before going live, turn on forwarded headers for the known proxy (`ForwardedHeadersOptions` with `KnownProxies`), so the limits use the client's IP.

## Sign-in, tokens and the security stamp

The flow for the app is in [`docs/api-phase-1.md`](docs/api-phase-1.md). Inside the API:

- **Passwords:** `Users.PasswordHash` holds an ASP.NET Core Identity `PasswordHasher<User>` hash (PBKDF2, salted). Arabic-Indic digits become 0–9 before hashing.
- **Lockout:** wrong passwords count in `Users.AccessFailedCount`. At `Auth:MaxFailedLogins` the account is locked until `Users.LockoutEndAt`. The same count also runs in memory per identifier (`Auth/IdentifierThrottle.cs`), so an identifier with no account locks too, and a lock never shows that an account exists.
- **Access token:** a JWT that lasts `Jwt:AccessTokenMinutes`, with the claims `sub`, `role`, `adminRole`, `doctorId`, `sid` (the refresh-token family) and `sst` (a hash of `Users.SecurityStamp`).
- **Per-request check** (`Auth/AuthSetup.cs`): after the signature and lifetime, every request reads the account through `AccountStateCache`, a memory cache that lasts `Auth:UserStateCacheSeconds`. Then:
  - A token whose `sst` no longer matches is refused with 401 `SESSION_REVOKED`.
  - A token whose role or admin role changed gets 401 `TOKEN_OUTDATED`.
  - A disabled account gets 403 `ACCOUNT_DISABLED`.
  - An assistant whose doctor is pending, rejected or disabled gets 403 `CLINIC_NOT_ACTIVE` (BR-AS9).

  Every endpoint that changes a user's security stamp, status or role calls `AccountStateCache.Invalidate(userId)` after saving, so this API instance applies the change at once. Other instances apply it within the cache time. A doctor's status (pending, suspended …) for doctor endpoints is read from the database by each endpoint, from Phase 2 on (spec 9.4).
- **Signing out everywhere:** `SessionService.SignOutEverywhereAsync` sets a new security stamp and revokes every refresh token. Setting, changing and resetting a password use it, and so does disabling an admin.
- **Refresh tokens:** 256 random bits, given to the app once. `RefreshTokens.TokenHash` keeps only the SHA-256 hash.
  - One sign-in on one device is a family (`RefreshTokens.FamilyId`).
  - Each refresh revokes the token it receives, links it to its replacement (`ReplacedByTokenId`), and issues a new one valid for another `Jwt:RefreshTokenDays`.
  - A token that was already rotated and comes back revokes the whole family, writes a `refreshTokenReuseDetected` audit row and answers `REFRESH_TOKEN_REUSED`.
- **`mustChangePassword`:** `PasswordChangeGate`, a global filter, answers 403 `PASSWORD_CHANGE_REQUIRED` on every authenticated endpoint not marked `[AllowWhilePasswordChangeRequired]`.
- **Authorization:** every endpoint needs a signed-in user unless it is marked `[AllowAnonymous]` (the fallback policy). The `admin`, `superAdmin` and `doctor` policies read the role claims, which the per-request check has already matched against the database.
- **Rate limiting:** the built-in ASP.NET Core rate limiter, per IP and policy (`Common/RateLimiting.cs`). Put `[EnableRateLimiting(RateLimitPolicies.X)]` on every new anonymous endpoint.
- **Errors:** return them with `this.Problem(status, ErrorCodes.X, "English title")` or `ValidationProblems.Field(...)`. Every problem+json carries a `code`.

## Audit log and notifications

- **Audit:** inject `Auditor` and call `auditor.Add(action, targetType, targetId, details, doctorId: …)` before `SaveChangesAsync`. The row is saved in the same transaction as the change. The actor is the signed-in user, or `AuditActor.System`.
  - Never pass passwords, tokens or medical text. Detail names containing "password", "token" or "secret" are dropped anyway.
  - The actions are listed in `AuditActions`.
- **Notifications:** inject `NotificationWriter` and call `Add(recipientUserId, NotificationTexts.X(...), route, data)`. It writes the `Notifications` row in Arabic and English, saved with the change. Push delivery (FCM, SignalR) comes in Phase 5.

## Email

`IEmailSender` sends one message: `PickupEmailSender` (Development) writes an `.eml` file, and `SmtpEmailSender` (MailKit) sends through `Email:Smtp`.

- **Queue:** endpoints don't send directly. They put the message on `EmailQueue`, and a background worker sends it. So a request answers in the same time whether or not an email went out, and an SMTP outage doesn't slow the API.
- **Lost messages:** a message still queued when the API stops is lost; the user asks again.
- **Logs** name the email kind and the user ID, never the address.
- **Texts** are in `Email/EmailTemplates.cs`, in Arabic and English, with the recipient's language first.

## Logging

Serilog is set in the `Serilog` section of `appsettings.json`. Each request writes one line: method, path, status and time. Query strings, headers and bodies are never logged.

The app handles medical data (spec section 12), so:

- Never log request or response bodies, phone numbers, emails, passwords, tokens, or medical text (diagnosis, notes, file names). Log IDs instead.
- Never put a phone number or medical text in a URL path, because the API logs paths. It does not log query strings, but a proxy in front of it may, so prefer the body.
- Never turn on `EnableSensitiveDataLogging` in EF Core, and keep `Microsoft.EntityFrameworkCore` at `Warning`.
- EF's own "save failed" and "command failed" log events are switched off (`Program.cs`), because SQL Server's message for a unique index holds the duplicate value. Endpoints catch unique violations with `SqlErrors.IsUniqueViolation` and answer with a code; anything uncaught is still logged by the exception handler.

## Validation

Every endpoint input is a request record with a FluentValidation validator in this assembly. `ValidationFilter` runs it before the action, so the action has no validation code. A failure returns `400 application/problem+json`:

```json
{
  "title": "One or more validation errors occurred.",
  "status": 400,
  "code": "VALIDATION_FAILED",
  "errors": { "phone": ["Enter a valid Egyptian mobile number."] },
  "errorCodes": { "phone": ["INVALID_MOBILE"] },
  "traceId": "…"
}
```

- Field names are camelCase, as in the JSON body. A field gets one error: its first failing rule.
- Give each rule an error code from `ErrorCodes.cs`, with `.WithErrorCode(...)` or a shared rule. The app maps codes to ARB messages.
- Shared rules from spec section 11 live in `Validation/RuleBuilderExtensions.cs`: `Required()`, `MaxChars(n)`, `FullName()`, `Email()`, `StrongPassword()`, `OneOf(...)`, `EgyptianMobile()`.
  - Store `EgyptianMobile.Normalize(value)`, the E.164 form. It follows the same rules as the app's `validators.dart`, so change both together.
  - Branch and support phones (landlines too) use `EgyptianPhone.Normalize`.
- A body that isn't JSON gets the same shape with `code: "INVALID_REQUEST"`.
- `tests/El3yada.Api.Tests/ValidationFilterTests.cs` shows the whole pattern.

## File storage

`IFileStorage` (local disk: `LocalFileStorage`) saves, opens, deletes and makes thumbnails. Files are never public URLs: the download endpoints check access, then stream the file (the doctor license in Phase 1, the rest in Phase 3).

| File | Path under `Storage:RootPath` |
|---|---|
| Medical record attachment | `medical/{doctorId}/{patientId}/{recordId}/{attachmentId}.{ext}` |
| Its thumbnail | `medical/{doctorId}/{patientId}/{recordId}/{attachmentId}.thumb.jpg` |
| Prescription PDF | `prescriptions/{doctorId}/{patientId}/{rxId}.pdf` |
| Chat attachment and thumbnail | `chat/{chatId}/{msgId}/file.{ext}`, `chat/{chatId}/{msgId}/thumb.jpg` |
| Payment screenshot (images, 1–3) | `payments/{doctorId}/{invoiceId}/{paymentId}/{n}.{ext}` |
| Doctor license | `doctors/{doctorId}/license/{fileId}.{ext}` |
| Prescription logo and signature | `doctors/{doctorId}/branding/logo.png`, `doctors/{doctorId}/branding/signature.png` |

- This is the layout in spec section 8, except that `{fileName}` is replaced by an ID. Paths are built only from IDs (`StoragePath.MedicalAttachment(...)` and the other factory methods). The name the user gave the file goes in the `FileName` column, for display only.
- The value saved in the `Path` and `ThumbPath` columns is `StoragePath.Value`. Read it back with `StoragePath.Parse`, which refuses anything else (`..`, absolute paths, other folders, other extensions).
- Accepted types: JPEG, PNG, WebP and PDF (`.jpg`, `.png`, `.webp`, `.pdf`). The first bytes must match the type, so a renamed file is refused. Upload endpoints find the type from the bytes with `FileTypes.Detect`, because clients often send `application/octet-stream`.
- Size: pass the limit to `SaveAsync` (`AppSettings.MaxUploadMb` for medical files, 10 MB for payment screenshots and the doctor license). `Storage:MaxUploadMb` is the hard ceiling above it.
- Thumbnails: JPEG, longest edge `Storage:ThumbnailMaxPx`, turned upright from the EXIF orientation, metadata dropped.
- Refused files throw `FileStorageException` with `FILE_TOO_LARGE`, `FILE_TYPE_NOT_ALLOWED` or `FILE_CONTENT_INVALID`.

## Test

```bash
dotnet test
```

- **`El3yada.Api.Tests` unit tests** (`ApiFactory`) run the API in memory with a test signing key and a temp storage folder. They need no secrets and no database.
- **`El3yada.Api.Tests` integration tests** (`Integration/`) build one throwaway database from the migrations (`TestDatabase`) and run the API on it (`IntegrationFactory`). Emails go to a temp folder as `.eml` files, and rate limits are raised except in `RateLimitTests`. The test classes share the database and run one at a time (`[Collection(IntegrationCollection.Name)]`); each test makes its own accounts with `TestData`.
- **`El3yada.Data.Tests`** creates a throwaway database, runs every migration, checks it, and drops it.

The databases are LocalDB by default. To use another SQL Server (for example a container in CI), set `EL3YADA_TEST_SQL` to a connection string without a database name.

## Changing the database

The EF Core model and its migrations are the source of truth. `database/schema.sql` is the original design (version 1) and is kept for reading only.

1. Change or add the entity class in `src/El3yada.Data/Entities/` and its configuration in `AppDbContext.cs`.
2. Add the migration with a short name that says what changed:

   ```bash
   dotnet ef migrations add AddSessionTags --project src/El3yada.Data --startup-project src/El3yada.Api
   ```

3. Read the generated migration before you commit it, then apply it: `dotnet ef database update …` (same options).
4. Run `dotnet test`. `Model_and_migrations_are_in_sync` fails if an entity changed without a migration.
5. Update spec.md section 8 in the same commit, and tell the team. Others run `dotnet ef database update` after they pull.

Never edit a migration that is already on `main`. Add a new one instead.

| Migration | What it changes |
|---|---|
| `InitialCreate`, `SeedReferenceData` | Phase 0: every table, the settings row and the starting specialties |
| `AddRefreshTokenFamily` | Phase 1: `RefreshTokens.FamilyId` (UNIQUEIDENTIFIER NOT NULL) and index `IX_RefreshTokens_FamilyId`, for refresh-token rotation and reuse detection |

### Rules to keep when you add tables or columns

The naming, money (piasters), time (UTC and Cairo dates) and enum conventions at the top of [`../database/schema.sql`](../database/schema.sql) still apply. Some model rules live outside `AppDbContext.cs`:

| File | What it does |
|---|---|
| `AppDbContext.Rules.cs` | Applies the lists below, the audit log IDENTITY key and one INCLUDE index. Stops EF from adding an index for every foreign key, because indexes are chosen per query. |
| `CheckConstraints.cs` | Every CHECK constraint (enums, ranges, permission dependencies). Add new ones here. |
| `ZeroDefaults.cs` | Columns with `DEFAULT 0` or `DEFAULT false`. |

**Defaults:** a column with a database default also gets the same value as a C# initializer on the entity, for example `public bool SelfBooking { get; set; } = true;`. The app then always sends the value, so `false` and `0` are saved as set and never replaced by the database default. IDENTITY columns are the exception: the database assigns them, so EF never sends a value.
