# el3yada API: Phase 3, catalogs

This covers:
- spec 6.9 (BR-CAT1 to BR-CAT14), 9.5 (the build pipeline and the local database) and Appendix A;
- screens D0, AD19 and AD20;
- acceptance check AC-18.

**How the catalog reaches devices:**
1. The catalog builder (`tools/catalog-builder`) produces `catalog-v{n}.sqlite.gz` and its manifest `catalog-v{n}.json`.
2. An admin publishes them in AD20.
3. Doctor and admin apps, and assistants with `prescriptionsDraft`, download the file in the background, check its sha256 and swap it in when it is complete (BR-CAT11, BR-CAT12).

Search runs on the device, against that file plus the custom items and the doctor's profile from this API. Patient devices never download it.

## Who may read the catalog

`GET /api/catalog/current`, `/api/catalog/file/{n}` and `/api/catalog/customItems` are open to:
- admins;
- doctors whose clinic is open (`active` or `suspended`);
- assistants with `prescriptionsDraft`.

Everyone else is refused:
- patients: 403 `FORBIDDEN`;
- other assistants: 403 `PERMISSION_DENIED` (`prescriptionsDraft`);
- a pending, rejected or disabled clinic: 403 `CLINIC_NOT_ACTIVE`.

`GET /api/catalog/myProfile` is a clinic endpoint for the doctor and `prescriptionsDraft` assistants, and follows the clinic guard order. `reportCatalogItem` is for the doctor only. Everything under `/api/admin/` is for any admin.

## Versions

The version view:

```json
{ "version": 3, "schemaVersion": 1, "sha256": "…64 hex…", "sizeBytes": 6123456, "uncompressedSizeBytes": 19400000,
  "counts": { "drugs": 25070, "labs": 6100, "radiology": 1200 },
  "drugSourceDate": "2026-06-30", "loincRelease": "2.83", "publishedAt": "…",
  "downloadPath": "/api/catalog/file/3" }
```

- `sizeBytes` is the download (the `.gz`). `uncompressedSizeBytes` is the space the database takes on the device once unpacked, so D0 can check the free space first; it is `null` only when the stored file can't be read. `CatalogVersions` has no column for it (no migration): `publishCatalog` measures it while checking the file (the builder's manifest has the same number as `uncompressed_size_bytes`) and writes it in the `catalogPublished` audit row, and later answers read it from the stored file's gzip trailer (ISIZE), once per version and API instance.

- **`GET /api/settings/public`** (anonymous) has `catalog` with this view, or `null` before the first publish. The app compares `catalog.version` with its local copy at launch (spec 9.5).
- **`GET /api/catalog/current`** returns the same view. Before the first publish it answers 404 `CATALOG_NOT_PUBLISHED`; the editors then accept free text and the doctor's history only (D0).
- **`GET /api/catalog/file/{n}`** downloads the `.sqlite.gz` (`application/gzip`):
  - **HTTP range requests** (`Accept-Ranges: bytes`, 206) let D0 resume an interrupted download.
  - Headers: `ETag` = the sha256, `Cache-Control: private, max-age=31536000, immutable`.
  - 404 for an unknown version.
  - Check the sha256 after downloading, then swap the file in atomically.
- **The server's version number is the one that counts.** The file's own `meta.catalog_version` is the builder's label and can differ.

### `POST /api/admin/publishCatalog` (AD20)

`multipart/form-data`:

| Part | Content |
|---|---|
| `file` | `catalog-v{n}.sqlite.gz`, ≤ 150 MB |
| `manifest` | The builder's JSON, sent as a file or a text field. Only `sha256` is required. |
| `confirmDrop` | Optional `true` |

Checks, in order:

| # | Check | Answer when it fails |
|---|---|---|
| 1 | The file's sha256 equals `manifest.sha256` | 400 `file`: `CATALOG_SHA_MISMATCH` |
| 2 | It gunzips to a SQLite database with a `meta` table and the tables `drugs`, `lab_tests` and `radiology`. `meta` may be key/value rows or one row with a column per key. | 400 `file`: `CATALOG_FILE_INVALID` |
| 3 | `meta.schema_version` equals `CatalogSchema.ExpectedVersion`, which is **1** for this release. It changes together with the app's reader and `packages/catalog_core`. | 400 `file`: `CATALOG_SCHEMA_UNSUPPORTED`, with `expected` and `actual` |
| 4 | No table has more than 5% fewer rows than the current version, unless `confirmDrop=true` | 409 `CATALOG_COUNT_DROP`, with `drops: [{ table, previous, current }]`, where table is `drugs`, `labs` or `radiology` |

On success:
- the version number is the previous one plus 1;
- the file is stored at `catalogs/v{n}.sqlite.gz`;
- a `CatalogVersions` row is written, with the counts, `drug_source_date` and `loinc_release` taken from `meta`;
- `AppSettings.CurrentCatalogVersionId` points at it;
- the admin audit log gets `catalogPublished` (with `sizeBytes` and `uncompressedSizeBytes`).

**201** returns the version view.

Other errors: 400 `file` or `manifest` `REQUIRED`, `manifest` `INVALID_REQUEST`, and 413 `REQUEST_TOO_LARGE`.

### `GET /api/admin/catalogVersions`

Every version, newest first: `[{ version: <view>, current: true|false, publishedBy: { userId, displayName } }]`.

## Custom items (BR-CAT9)

Items the admin adds for every doctor at once, without a new catalog version.

The custom item view:

```json
{ "customItemId": "…", "type": "drug", "nameEn": "Newcillin 500", "nameAr": "نيوسيلين", "activeIngredient": "amoxicillin",
  "drugGroupId": "antibiotics", "route": "oral", "loincCode": null, "aliases": ["newcil"], "active": true,
  "createdAt": "…", "updatedAt": "…" }
```

### Admin (AD20)

- **`GET /api/admin/catalog/customItems?type=&active=&search=&page=&pageSize=`**: the newest change first.
- **`POST /api/admin/catalog/createCustomItem`**: `{ type, nameEn, nameAr?, activeIngredient?, drugGroupId?, route?, loincCode?, aliases? }` → **201**.
- **`POST /api/admin/catalog/updateCustomItem`**: `{ customItemId, nameEn, nameAr?, activeIngredient?, drugGroupId?, route?, loincCode?, aliases?, active }` → **200**.
  - Every field is replaced, and the type can't change.
  - Items are **never deleted**: `active: false` disables one, so devices learn of it at the next sync.
- Both write a `catalogCustomItemSaved` audit row.

| Field | Rule | Error codes |
|---|---|---|
| `type` | `drug`, `lab` or `radiology` | `REQUIRED`, `INVALID_VALUE` |
| `nameEn` | required, ≤ 200 | `REQUIRED`, `TOO_LONG` |
| `nameAr` | ≤ 200 | `TOO_LONG` |
| `activeIngredient` ≤ 300, `drugGroupId` ≤ 100, `route` ≤ 50 | medicines only | `TOO_LONG`, or `INVALID_VALUE` for a test |
| `loincCode` | ≤ 20; lab and radiology only | `TOO_LONG`, or `INVALID_VALUE` for a medicine |
| `aliases` | ≤ 10, each ≤ 100. Duplicates are dropped, ignoring case. | `INVALID_VALUE` |

### Device sync

**`GET /api/catalog/customItems?since=<nextSince>`**:

```json
{ "items": [ …custom item views, oldest change first… ], "nextSince": "2026-11-17T10:00:00.123Z", "hasMore": false }
```

- The list holds items changed **after** `since`, or every item when `since` is left out. Inactive items are included, so devices remove them.
- Pages hold at most 1000 items. While `hasMore`, ask again with `since = nextSince`.
- Apps sync at launch and about once a minute while an editor is open. That way an admin's new item shows up in searches within a minute (AC-18).
- The answer has `Cache-Control: no-store`.

## Doctor reports [S] (BR-CAT8, AD20)

- **`POST /api/catalog/reportCatalogItem`** (doctor only): `{ type, text, itemRef? }` → **201**, the report view.
  - `type`: `missing`, `wrong` or `other`.
  - `text`: required, ≤ 500.
  - `itemRef`: optional, ≤ 100. It is the app's reference to the item, for example `drug:123`, `loinc:2093-3` or `search:ketofan`.
  - Every active admin gets «بلاغ عن عنصر في الكتالوج», routed to `/admin/catalogs`.
- **`GET /api/admin/catalog/reports?status=open|done|all&page=&pageSize=`**: open reports first, oldest first.
  The report view: `{ reportId, type, text, itemRef, status, doctorId, doctorName, createdAt, handledBy, handledAt }`.
- **`POST /api/admin/catalog/handleReport`**: `{ reportId }` → **200**, marks it `done` and writes `catalogReportHandled`. Asking again changes nothing.

## Specialty profiles (BR-CAT2, BR-CAT3, AD19)

A profile lists what a doctor of that specialty sees first. Items have a `type` and a `value`. Values are printable ASCII (ids and codes), ≤ 100 characters, and at most 300 per type.

| Type | Value |
|---|---|
| `drugGroup` | A clean group id from the catalog's `drug_groups` (BR-CAT5) |
| `route` [S] | A preferred route, for example `drops` or `suppository` for Pediatrics |
| `labCode` | A LOINC code of a recommended lab test |
| `radiologyRegion`, `radiologyModality` | The Playbook's body region and modality names |
| `radiologyCode` | A LOINC code of a recommended procedure |

**The General profile** (BR-CAT3) is a `Specialties` row with `nameEn` "General" and `nameAr` «عام».
- It is created by migration `PrescriptionsAndCatalogs`.
- It is **inactive**, so sign-up never lists it.
- Every specialty with `includeGeneral` (on by default) gets its items too.

### Admin (AD19)

- **`GET /api/admin/specialties`**: every specialty, General first:
  `[{ specialtyId, nameAr, nameEn, active, sortOrder, isGeneral, includeGeneral, doctorCount, itemCounts: { drugGroup: 5, … } }]`.
  `doctorCount` counts the doctors with it as their primary or an extra specialty.
- **`GET /api/admin/specialties/{id}/profile`**:
  `{ specialtyId, nameAr, nameEn, isGeneral, includeGeneral, drugGroups[], routes[], labCodes[], radiologyRegions[], radiologyModalities[], radiologyCodes[], updatedAt }`.
  Values are sorted.
- **`PUT /api/admin/specialties/{id}/profile`**:
  - Body: `{ includeGeneral, drugGroups?, routes?, labCodes?, radiologyRegions?, radiologyModalities?, radiologyCodes? }`.
  - Every list is replaced; a missing list empties that type. Duplicates are dropped.
  - `includeGeneral` is required, and ignored for General.
  - Errors: `includeGeneral` `REQUIRED`; a list `TOO_MANY` or `INVALID_VALUE`.
  - **200**: the profile.
- **`POST /api/admin/specialties/{id}/copyProfile`**:
  - Body: `{ fromSpecialtyId }`. It is "Copy from another specialty": the source's lists, and its `includeGeneral`, replace this one's.
  - Copying from General turns `includeGeneral` on.
  - Copying from itself, or from a specialty that doesn't exist, answers 400 `INVALID_VALUE`.
  - **200**: the profile.
- Both write a `specialtyProfileUpdated` audit row.

### Doctor: `GET /api/catalog/myProfile`

```json
{ "specialtyIds": ["…primary…", "…extra…"], "includesGeneral": true,
  "drugGroups": ["analgesics", "statins"], "routes": [], "labCodes": ["2093-3"],
  "radiologyRegions": ["Heart"], "radiologyModalities": ["US"], "radiologyCodes": [] }
```

It merges:
- the primary and extra specialties' items;
- the General items, when any of those specialties includes General.

The device ranks search with it (BR-CAT4):
1. "Used before": `GET /api/prescriptions/itemHistory`.
2. "Your specialty": items whose group, code, region or modality is in this profile.
3. «من تخصصات أخرى»: everything else, hidden by the «تخصصي فقط» chip.

### Seeding the defaults

```
dotnet run --project src/El3yada.Api -- seed-specialty-profiles tools/catalog-builder/mappings/specialty-profiles.csv
```

- The CSV header is `specialty_name_en,item_type,value`. `General` names the General profile.
- Every specialty in the file gets exactly the file's items; the others are left alone. Running it twice changes nothing.
- Unknown specialty names, item types or values stop it before anything is saved (exit code 1). A wrong argument count gives exit code 2.

## Error codes

| Code | HTTP | Meaning |
|---|---|---|
| `CATALOG_SHA_MISMATCH` | 400 | The file doesn't match the manifest. |
| `CATALOG_FILE_INVALID` | 400 | Not a gzip-compressed SQLite catalog with `meta`, `drugs`, `lab_tests` and `radiology`. |
| `CATALOG_SCHEMA_UNSUPPORTED` | 400 | `schema_version` is not the one this API serves. The answer has `expected` and `actual`. |
| `CATALOG_COUNT_DROP` | 409 | A table lost more than 5% of its rows. Send `confirmDrop=true` to publish anyway. The answer has `drops`. |
| `CATALOG_NOT_PUBLISHED` | 404 | No version has been published yet. |

## Storage

The files live at `catalogs/v{n}.sqlite.gz` and are kept for every version, so an app can still finish downloading the previous one.
