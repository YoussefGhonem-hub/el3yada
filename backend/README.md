# el3yada API (ASP.NET Core)

The Web API and the SQL Server database for the el3yada app. The full product spec is [`../spec.md`](../spec.md) and the work plan is [`../PHASES.md`](../PHASES.md).

| Project | What it holds |
|---|---|
| `src/El3yada.Api` | ASP.NET Core Web API (.NET 10): controllers, `Program.cs`, settings (`Configuration/`), validation (`Validation/`), file storage (`Storage/`) |
| `src/El3yada.Data` | EF Core: `AppDbContext`, one entity class per table (`Entities/`), migrations |
| `tests/El3yada.Api.Tests` | xUnit tests for validation, settings checks and file storage. They never open the database. |
| `tests/El3yada.Data.Tests` | xUnit tests that build a fresh database from the migrations and check it |

Packages added on top of ASP.NET Core and EF Core:

| Package | Used for |
|---|---|
| `Serilog.AspNetCore`, `Serilog.Enrichers.Environment` | Logs to the console and a daily file, one line per request |
| `FluentValidation`, `FluentValidation.DependencyInjectionExtensions` | Input validation (rules from spec section 11) |
| `SkiaSharp`, `SkiaSharp.NativeAssets.Linux.NoDependencies` | Image thumbnails (MIT licence; the second package makes it work on a Linux host) |
| `Microsoft.AspNetCore.Mvc.Testing` (tests only) | Runs the real API in memory |

## Before the first run

1. **.NET 10 SDK** (`dotnet --version`).
2. **SQL Server LocalDB**, which comes with Visual Studio or the SQL Server Express installer. Check with `sqllocaldb info`.
3. From this folder (`backend/`):

```bash
dotnet tool restore            # installs dotnet-ef 10.0.11 from dotnet-tools.json
dotnet ef database update --project src/El3yada.Data --startup-project src/El3yada.Api
dotnet user-secrets set Jwt:SigningKey "$(openssl rand -base64 48)" --project src/El3yada.Api
```

This creates the `el3yada_dev` database with all 55 tables, the platform settings and the starting specialties, and gives your machine its own JWT signing key. The key is stored outside the repo (`%APPDATA%\Microsoft\UserSecrets\el3yada-api\secrets.json`, or `~/.microsoft/usersecrets/el3yada-api/` on macOS and Linux). In PowerShell 7 use `([Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48)))` in place of `"$(openssl rand -base64 48)"`. Any random value of 32 bytes or more works.

Without the key, the API stops at start-up with a message that shows this command.

## Run

```bash
dotnet run --project src/El3yada.Api --launch-profile https
```

- API: `https://localhost:7001`, the same address as the Flutter app's `config/dev.json`.
- Health check: `GET https://localhost:7001/api/health` returns the database name and the applied and pending migrations.
- OpenAPI document (Development only): `https://localhost:7001/openapi/v1.json`.
- Logs: the console, and `src/El3yada.Api/logs/el3yada-api-YYYYMMDD.log` (one JSON object per line, kept 31 days).
- Stored files: `src/El3yada.Api/App_Data/files/`.

Both folders are git-ignored.

## Settings and secrets

Settings are checked when the API starts. A missing secret or a value out of range stops it with a message that names the setting.

| Setting | Development | Production |
|---|---|---|
| `ConnectionStrings:Default` | LocalDB, in `appsettings.Development.json` | `ConnectionStrings__Default` |
| `Jwt:SigningKey` (32 bytes or more) | user-secrets (above) | `Jwt__SigningKey` |
| `Jwt:Issuer`, `Jwt:Audience` | `appsettings.json` | same, or `Jwt__Issuer`, `Jwt__Audience` |
| `Jwt:AccessTokenMinutes` (1–1440), `Jwt:RefreshTokenDays` (1–365) | 15 and 30, in `appsettings.json` | same, or `Jwt__AccessTokenMinutes`, `Jwt__RefreshTokenDays` |
| `Storage:RootPath` | `App_Data/files`, in `appsettings.Development.json` | `Storage__RootPath`, an absolute path outside the deploy folder |
| `Storage:MaxUploadMb` (1–200) | 200, in `appsettings.json` | same, or `Storage__MaxUploadMb` |
| `Storage:ThumbnailMaxPx` (64–1024) | 320, in `appsettings.json` | same, or `Storage__ThumbnailMaxPx` |
| Log file | `logs/el3yada-api-.log` | `Serilog__WriteTo__File__Args__path`, an absolute path |

Production reads secrets from environment variables only. Never commit a secret, a production connection string or a key, not even in `appsettings.Development.json`.

## Logging

Serilog is set in the `Serilog` section of `appsettings.json`. Each request writes one line: method, path, status and time. Query strings, headers and bodies are never logged.

The app handles medical data (spec section 12), so:

- Never log request or response bodies, phone numbers, emails, passwords, tokens, or medical text (diagnosis, notes, file names). Log IDs instead.
- Never put a phone number or medical text in a URL path, because the API logs paths. It does not log query strings, but a proxy in front of it may, so prefer the body.
- Never turn on `EnableSensitiveDataLogging` in EF Core, and keep `Microsoft.EntityFrameworkCore` at `Warning`.

## Validation

Every endpoint input is a request record with a FluentValidation validator in this assembly. `ValidationFilter` runs it before the action, so the action has no validation code. A failure returns `400 application/problem+json`:

```json
{
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": { "phone": ["Enter a valid Egyptian mobile number."] },
  "errorCodes": { "phone": ["INVALID_MOBILE"] },
  "traceId": "…"
}
```

- Field names are camelCase, as in the JSON body. A field gets one error: its first failing rule.
- Give each rule an error code with `.WithErrorCode(...)` from `ErrorCodes.cs`. The app maps codes to ARB messages.
- Shared rules from spec section 11 live in `Validation/RuleBuilderExtensions.cs`, for example `RuleFor(x => x.Phone).NotEmpty().EgyptianMobile()`. Store `EgyptianMobile.Normalize(value)`, the E.164 form. It follows the same rules as the app's `validators.dart`, so change both together.
- `tests/El3yada.Api.Tests/ValidationFilterTests.cs` shows the whole pattern.

## File storage

`IFileStorage` (local disk: `LocalFileStorage`) saves, opens, deletes and makes thumbnails. Files are never public URLs: the download endpoints (Phase 3) check access, then stream the file.

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
- Accepted types: JPEG, PNG, WebP and PDF (`.jpg`, `.png`, `.webp`, `.pdf`). The first bytes must match the type, so a renamed file is refused.
- Size: pass the limit to `SaveAsync` (`AppSettings.MaxUploadMb` for medical files, 10 MB for payment screenshots). `Storage:MaxUploadMb` is the hard ceiling above it.
- Thumbnails: JPEG, longest edge `Storage:ThumbnailMaxPx`, turned upright from the EXIF orientation, metadata dropped.
- Refused files throw `FileStorageException` with `FILE_TOO_LARGE`, `FILE_TYPE_NOT_ALLOWED` or `FILE_CONTENT_INVALID`.

## Test

```bash
dotnet test
```

`El3yada.Api.Tests` runs the API in memory with a test signing key and a temp storage folder; it needs no secrets and no database. `El3yada.Data.Tests` creates a throwaway LocalDB database, runs every migration, checks it, and drops it. To use another SQL Server (for example a container in CI), set `EL3YADA_TEST_SQL` to a connection string without a database name.

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

### Rules to keep when you add tables or columns

The naming, money (piasters), time (UTC and Cairo dates) and enum conventions at the top of [`../database/schema.sql`](../database/schema.sql) still apply. Some model rules live outside `AppDbContext.cs`:

| File | What it does |
|---|---|
| `AppDbContext.Rules.cs` | Applies the lists below, the audit log IDENTITY key and one INCLUDE index. Stops EF from adding an index for every foreign key, because indexes are chosen per query. |
| `CheckConstraints.cs` | Every CHECK constraint (enums, ranges, permission dependencies). Add new ones here. |
| `ZeroDefaults.cs` | Columns with `DEFAULT 0` or `DEFAULT false`. |

**Defaults:** a column with a database default also gets the same value as a C# initializer on the entity, for example `public bool SelfBooking { get; set; } = true;`. The app then always sends the value, so `false` and `0` are saved as set and never replaced by the database default.
