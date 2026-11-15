# el3yada API (ASP.NET Core)

The Web API and the SQL Server database for the el3yada app. The full product spec is [`../spec.md`](../spec.md) and the work plan is [`../PHASES.md`](../PHASES.md).

| Project | What it holds |
|---|---|
| `src/El3yada.Api` | ASP.NET Core Web API (.NET 10): controllers, `Program.cs`, settings |
| `src/El3yada.Data` | EF Core: `AppDbContext`, one entity class per table (`Entities/`), migrations |
| `tests/El3yada.Data.Tests` | xUnit tests that build a fresh database from the migrations and check it |

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
