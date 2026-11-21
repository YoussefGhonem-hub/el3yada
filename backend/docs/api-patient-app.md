# API contract: patient app filters (P4, P8)

The patient app's read endpoints live under `/api/patient` (`PatientPortalController`). Only the `patient` role reaches them: no token is 401, any other role is 403 (AC-11, AC-12). Every answer is limited to the caller's own file. This file covers the list filters that P4 (visits) and P8 (medical files) use. Dates are Cairo days (`yyyy-MM-dd`), and times are UTC ISO 8601.

## The list filters

`GET /api/patient/visits`, `GET /api/patient/prescriptions` and `GET /api/patient/records` take the same query, all optional:

| Query | Lists | Meaning |
|---|---|---|
| `doctorId` | all three | One doctor (the doctor selector, P1). |
| `branchId` | visits | Visits in this branch (P4). Another doctor's branch with `doctorId` set gives an empty page, not an error. |
| `kind` | prescriptions, records | Prescriptions: `medication` or `investigations`. Records: `prescription`, `lab`, `radiology` or `other`. |
| `from`, `to` | visits, records | Inclusive. Visits use the visit's Cairo day; records use the document date (P8). |
| `page`, `pageSize` | all three | 25 per page by default, 100 at most. |

Errors: 400 `VALIDATION_FAILED` with `kind`: `INVALID_KIND`, or `from`: `INVALID_RANGE` when `from` is after `to`.

## `GET /api/patient/records/counts` (P8 tabs)

Takes `doctorId`, `from` and `to`, like the list. The tab counts therefore follow the doctor and date range on screen. `kind` and `branchId` are ignored. The same 400 errors apply.

```json
{ "prescription": 0, "lab": 1, "radiology": 0, "other": 1 }
```

## `GET /api/patient/visits/branches` (`getMyVisitBranches`, P4 branch filter)

Lists the branches the caller has visits in, most visited first. Archived branches are included, so old visits can still be filtered. Deleted visits don't count. `doctorId` limits the list to one doctor.

```json
[
  {
    "branch": { "id": "…", "nameAr": "فرع المعادي", "nameEn": "Maadi branch" },
    "doctor": { "id": "…", "fullName": "د. أحمد سامي", "fullNameEn": "Dr. Ahmed Samy", "title": "استشاري", "titleEn": "Consultant" },
    "visits": 4
  }
]
```

The app shows the branch filter only when this list has two or more branches.
