# el3yada API (ASP.NET Core)

The Web API and the SQL Server database for the el3yada app. The full product spec is [`../spec.md`](../spec.md) and the work plan is [`../PHASES.md`](../PHASES.md).

| Project | What it holds |
|---|---|
| `src/El3yada.Api` | ASP.NET Core Web API (.NET 10): controllers, `Program.cs`, settings |
| `src/El3yada.Data` | EF Core: `AppDbContext`, one entity class per table (`Entities/`), migrations |
| `tests/El3yada.Data.Tests` | xUnit tests that build a fresh database from the migrations and check it |
| `tests/El3yada.Api.Tests` | API tests: the real API hosted with `WebApplicationFactory` on a throwaway database with demo data |

### Inside `src/El3yada.Api`

| Folder | What it holds |
|---|---|
| `Features/<Area>/` | One folder per area: controller, service, DTOs, validators. For example `Features/PatientPortal` (P1–P14) and `Features/Admin` (AD11, AD12). |
| `Infrastructure/Auth` | JWT bearer setup, `JwtTokenFactory` (the Phase 1 login uses it), policies, `ICurrentUser`, `SessionRevoker`. |
| `Infrastructure/Errors` | `ApiException` and `ErrorCodes`. Every error is ProblemDetails with a `code` field. |
| `Infrastructure/Auditing` | `IAuditLogger`, the single way to write `AuditLogs`. |
| `Infrastructure/Notifications` | `INotificationWriter` stores `Notifications` rows. Phase 5 adds push delivery behind it. |
| `Infrastructure/Files` | `IFileStorage` (local folder now, object storage later). Files are never public URLs. |
| `Infrastructure/Ids` | `NewId.Next()`: **set `Id` on every new row yourself.** The model doesn't generate GUID keys, so an unset key is `Guid.Empty`. |
| `Development/` | Demo data and `POST /api/dev/token`, mapped only in Development. |

### Rules for endpoints

- **Deny by default.** The fallback policy requires an active account; public endpoints say `[AllowAnonymous]`. Use `[Authorize(Policy = Policies.Patient)]` and so on.
- **Status from the database.** `ActiveAccountHandler` reads `Users.Status` and `SecurityStamp` on every request, so a disabled account or a password change takes effect at once. Call `SessionRevoker.RevokeAllAsync` to sign someone out everywhere.
- **Validation:** add an `AbstractValidator<TRequest>` next to the request type. The global `FluentValidationFilter` runs it and answers 400 with `code = VALIDATION_FAILED` and the failing fields.
- **Errors:** `throw ApiException.Conflict(ErrorCodes.X)`; add the code to `ErrorCodes` and to the app's ARB messages.
- **Times:** inject `TimeProvider`, never `DateTime.UtcNow`, so tests can control time. Cairo days come from `CairoTime`. JSON writes every `DateTime` as UTC with a `Z`.

## Before the first run

1. **.NET 10 SDK** (`dotnet --version`).
2. **SQL Server LocalDB**, which comes with Visual Studio or the SQL Server Express installer. Check with `sqllocaldb info`.
3. From this folder (`backend/`):

```bash
dotnet tool restore            # installs dotnet-ef 10.0.11 from dotnet-tools.json
dotnet ef database update --project src/El3yada.Data --startup-project src/El3yada.Api
```

This creates the `el3yada_dev` database with all 55 tables, the platform settings and the starting specialties.

## Run

```bash
dotnet run --project src/El3yada.Api --launch-profile https
```

- API: `https://localhost:7001`, the same address as the Flutter app's `config/dev.json`.
- Health check: `GET https://localhost:7001/api/health` returns the database name and the applied and pending migrations.
- OpenAPI document (Development only): `https://localhost:7001/openapi/v1.json`.

The development connection string is in `src/El3yada.Api/appsettings.Development.json`. In production, set the `ConnectionStrings__Default` environment variable. Never commit production secrets.

**Production settings** (environment variables): `ConnectionStrings__Default`, `Jwt__SigningKey` (at least 32 characters; the API refuses to start without it) and `FileStorage__RootPath`. The development signing key in `appsettings.Development.json` is not a secret and must never be used elsewhere.

### Demo data and tokens (Development only)

Until the Phase 1 login exists, use `src/El3yada.Api/El3yada.Api.http`:

1. `POST /api/dev/seed` creates an admin, two doctors who share one patient, an assistant, and visits, prescriptions and files in every state (sent, cancelled, draft, deleted). It runs once; later calls return the same ids.
2. `POST /api/dev/token` with `{ "identifier": "01000000002", "role": "patient" }` (or `admin@el3yada.dev`, `doctor@el3yada.dev`, `01000000001`) returns an access token.

Both endpoints exist only when `ASPNETCORE_ENVIRONMENT=Development`.

## Test

```bash
dotnet test
```

The tests create a throwaway LocalDB database, run every migration, check it, and drop it. To use another SQL Server (for example a container in CI), set `EL3YADA_TEST_SQL` to a connection string without a database name.

## Changing the database

The EF Core model and its migrations are the source of truth. `database/schema.sql` is the original design (version 1) and is kept for reading only.

1. Change or add the entity class in `src/El3yada.Data/Entities/` and its configuration in `AppDbContext.cs`.
2. Add the migration with a short name that says what changed:

   ```bash
   dotnet ef migrations add AddSessionTags --project src/El3yada.Data --startup-project src/El3yada.Api
   ```

3. Read the generated migration before you commit it, then apply it: `dotnet ef database update …` (same options).
4. Run `dotnet test`. `Model_and_migrations_are_in_sync` fails if an entity changed without a migration.
5. Update spec.md section 8 in the same pull request, and tell the team. Others run `dotnet ef database update` after they pull.

Never edit a migration that is already on `main`. Add a new one instead.

### Rules to keep when you add tables or columns

The naming, money (piasters), time (UTC and Cairo dates) and enum conventions at the top of [`../database/schema.sql`](../database/schema.sql) still apply. Some model rules live outside `AppDbContext.cs`:

| File | What it does |
|---|---|
| `AppDbContext.Rules.cs` | Applies the lists below, the audit log IDENTITY key and one INCLUDE index. Stops EF from adding an index for every foreign key, because indexes are chosen per query. |
| `CheckConstraints.cs` | Every CHECK constraint (enums, ranges, permission dependencies). Add new ones here. |
| `ZeroDefaults.cs` | Columns with `DEFAULT 0` or `DEFAULT false`. |

**Defaults:** a column with a database default also gets the same value as a C# initializer on the entity, for example `public bool SelfBooking { get; set; } = true;`. The app then always sends the value, so `false` and `0` are saved as set and never replaced by the database default.
