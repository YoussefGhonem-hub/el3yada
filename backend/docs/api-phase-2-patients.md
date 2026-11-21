# el3yada API: Phase 2 contract, patients and sessions

This is what the Flutter app builds against for patients, the medical profile, sessions and the platform-fee screens: **D1** (fee cards), **D2–D9**, **AS1–AS5**. Conventions, errors, tokens and paging are as in [api-phase-1.md](api-phase-1.md). Who may call a clinic endpoint, the order of the checks, Cairo dates and search text are in [api-phase-2.md](api-phase-2.md). The code is the source of truth (`Controllers/PatientsController.cs`, `SessionsController.cs`, `SessionReportsController.cs`). When this page and the code differ, fix this page.

- [Endpoints at a glance](#endpoints-at-a-glance)
- [Fields hidden by permission](#fields-hidden-by-permission)
- [Patients](#patients): [lookupPhone](#get-apipatientslookupphone), [createPatient](#post-apipatientscreatepatient), [patient view](#patient-view), [updatePatient](#post-apipatientsupdatepatient), [updatePatientPhone](#post-apipatientsupdatepatientphone), [resetPatientPassword](#post-apipatientsresetpatientpassword), [setArchived](#post-apipatientssetarchived)
- [Medical profile](#medical-profile)
- [Patients register (D4)](#get-apipatientsregister-d4)
- [Sessions](#sessions): [newSessionInfo](#get-apisessionsnewsessioninfo), [createSession](#post-apisessionscreatesession), [session view](#session-view), [lists](#session-lists), [private note](#private-note-doctor-only), [updateClinical](#post-apisessionsupdateclinical), [updateAmountCharged](#post-apisessionsupdateamountcharged), [deleteSession](#post-apisessionsdeletesession)
- [Fees](#fees): [day](#get-apisessionsday-d2-as1), [feeSummary](#get-apisessionsfeesummary-d1), [month](#get-apisessionsmonth-d3)
- [Screens → endpoints](#screens--endpoints)
- [Notifications](#notifications), [Audit actions](#audit-actions), [Error codes](#error-codes)
- [Decisions where the spec is silent](#decisions-where-the-spec-is-silent), [Not yet](#not-yet)

## Endpoints at a glance

`patientId` is `Patients.Id`. The server finds the caller's doctor's link to that patient; a patient who isn't linked to the caller's doctor answers **404 `NOT_FOUND`** (except `createSession`: 404 `NOT_LINKED`). A session of another doctor, or a deleted one, is 404 `NOT_FOUND`.

"Any" means any doctor or assistant of the clinic, whatever their permissions. "A or B" means either permission opens it; `PERMISSION_DENIED` then names A. **Blocked** means 403 `DOCTOR_SUSPENDED` while the doctor is suspended (BR-G5); everything else still works then.

| Method and route | Who | Blocked |
|---|---|---|
| `GET /api/patients/lookupPhone?phone=` | `patientsManage` | |
| `POST /api/patients/createPatient` | `patientsManage` | **yes** |
| `GET /api/patients/{patientId}` | any | |
| `POST /api/patients/updatePatient` | `patientsManage` | |
| `POST /api/patients/updatePatientPhone` | `patientsManage` | |
| `POST /api/patients/resetPatientPassword` | `patientsResetPassword` | |
| `POST /api/patients/setArchived` [S] | `patientsManage` | |
| `GET /api/patients/{patientId}/medicalProfile` | `clinicalView` | |
| `POST /api/patients/updateMedicalProfile` | `clinicalEditProfile` | |
| `GET /api/patients/register` | any | |
| `GET /api/patients/{patientId}/sessions` | `sessionsCreate` or `clinicalView` | |
| `GET /api/sessions/newSessionInfo?patientId=&branchId=` | `sessionsCreate` | |
| `POST /api/sessions/createSession` | `sessionsCreate` | **yes** |
| `GET /api/sessions/{sessionId}` | `sessionsCreate`, `clinicalView` or `billingView` | |
| `GET /api/sessions/{sessionId}/privateNote` | **doctor only** | |
| `POST /api/sessions/setPrivateNote` | **doctor only** | |
| `POST /api/sessions/updateClinical` | **doctor only** | |
| `POST /api/sessions/updateAmountCharged` | the doctor, or the assistant who recorded the session (`sessionsCreate`) | |
| `POST /api/sessions/deleteSession` | `sessionsDelete` | |
| `GET /api/sessions/day?day=` | `sessionsCreate` or `billingView` | |
| `GET /api/sessions/feeSummary` | `billingView` | |
| `GET /api/sessions/month?month=` | `billingView` | |

Every route answers 401 without a token, and 403 `FORBIDDEN` to a patient or an admin (AC-11, AC-12). An assistant calling a doctor-only route gets 403 `PERMISSION_DENIED` with `"permission": "doctorOnly"`. Those three answers, `PERMISSION_DENIED` and `DOCTOR_SUSPENDED` are in [api-phase-2.md](api-phase-2.md) and aren't repeated in each table below.

A body that fails validation gets its 400 before the clinic checks run (the validation filter runs first). A caller who may not use the endpoint can therefore see a 400 for a malformed body; a well-formed body gets the 403.

**Branches** (BR-AS13): an assistant works in their branches only for new sessions, deleting sessions and today's list (`day`). The patient list, the patient file (profile, sessions tab, session details) and the fee totals are clinic-wide. A branch the assistant isn't assigned to answers 403 `BRANCH_NOT_ALLOWED`; a branch of another doctor 404 `NOT_FOUND`.

## Fields hidden by permission

A hidden field is **present with the value `null`**, never `0`, `false` or an empty list. So `null` always means "not for you", and the app hides the column or card (spec 7.6, AS18). The doctor sees everything.

| Field | In | Shown to |
|---|---|---|
| `totalPaidPiasters` | patient view, register rows | `revenueView` |
| `hasAllergies` | patient view, register rows | `clinicalView` |
| `chronicDiseases` | register rows | `clinicalView` |
| `clinical` (the whole block) | session view | `clinicalView` |
| `chiefComplaint`, `diagnosis` | session list rows | `clinicalView` |
| `amountChargedPiasters`, `listPricePiasters`, `paymentMethod` | session view; the amount and method in list rows | `revenueView`, or the person who recorded that session |
| `amountChargedTotalPiasters` | `day` | `revenueView` |
| `hasPrivateNote` | session view | the doctor |

The medical profile endpoints need `clinicalView` as a whole. Private notes never appear in any answer except their own doctor-only endpoint. Visit prices (`visitPricePiasters` in `newSessionInfo`) are shown to everyone who records sessions: they are the default amount (BR-PR3, AS5).

## Patients

### `GET /api/patients/lookupPhone`

D5 and D32 pre-check, before the add-patient form or the link dialog. Query: `phone` (any accepted mobile form; the API doesn't log query strings). `Cache-Control: no-store`.

```json
{ "status": "linkedToYou", "patientId": "…", "fileNumber": 12, "fullName": "منى حسن", "archived": false }
{ "status": "existsElsewhere", "patientId": null, "fileNumber": null, "fullName": null, "archived": null }
{ "status": "new", "patientId": null, "fileNumber": null, "fullName": null, "archived": null }
```

| `status` | Meaning | App |
|---|---|---|
| `new` | No patient account on this number (an assistant account on it doesn't count, BR-AS3) | The full D5 form |
| `linkedToYou` | Already this doctor's patient | Open D6 for `patientId` (D32: suggest that patient) |
| `existsElsewhere` | Another clinic's patient. Nothing else is revealed (BR-P3). | The BR-P3 dialog, then `createPatient` with the phone |

Errors: 400 `phone`: `REQUIRED`, `INVALID_MOBILE`.

### `POST /api/patients/createPatient`

D5, AS3, D32. One transaction: a number with a patient account is **linked** (BR-P3); otherwise a new account is made (BR-P4). Either way the link gets the doctor's next file number (BR-P6), and concurrent adds never clash.

```json
{
  "fullName": "منى حسن", "phone": "010 1234 5678", "gender": "female",
  "dateOfBirth": "1990-05-01", "ageYears": null,
  "nationalId": "29005010123456", "address": "المعادي", "bloodType": "A+",
  "emergencyContactName": "حسن علي", "emergencyContactPhone": "02 2358 1234"
}
```

| Field | Rule (spec section 11) | Error code |
|---|---|---|
| `phone` | required, Egyptian mobile | `REQUIRED`, `INVALID_MOBILE` |
| `fullName` | 2–60 letters and spaces, at least 2 words. Required for a new account. | `REQUIRED`, `INVALID_NAME` |
| `gender` | `male` or `female`. Required for a new account. | `REQUIRED`, `INVALID_VALUE` |
| `dateOfBirth` | `YYYY-MM-DD`, not after today (Cairo), at most 120 years ago. A new account needs this **or** `ageYears`. | `REQUIRED`, `INVALID_DATE_OF_BIRTH` |
| `ageYears` | 0–120, instead of `dateOfBirth` (never both). Stored as today minus that many years, with `dateOfBirthEstimated: true`. | `INVALID_VALUE` (both sent), `OUT_OF_RANGE` |
| `nationalId` | optional, 14 digits (Arabic-Indic digits and spaces accepted) | `INVALID_NATIONAL_ID` |
| `address` | optional, ≤ 300 | `TOO_LONG` |
| `bloodType` | optional: `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-` | `INVALID_VALUE` |
| `emergencyContactName` | optional, ≤ 60 | `TOO_LONG` |
| `emergencyContactPhone` | optional, mobile or landline; answered in E.164 | `INVALID_PHONE` |

**Linking an existing number needs the phone alone.** The other fields are then ignored: the account keeps its own identity (BR-P3). The `REQUIRED` errors for `fullName`, `gender` and `dateOfBirth` come only when the number is new. The D5 form always sends them anyway.

**201**, `Cache-Control: no-store`:

```json
{
  "linked": false,
  "temporaryPassword": "MHCQt9VN",
  "patient": { …patient view… }
}
```

- `linked: false`: a new account. `temporaryPassword` (8 characters) is shown **once** with WhatsApp / SMS / Copy (BR-P4); the patient must change it at first sign-in (A9). Then open D6.
- `linked: true`: the number already had an account, now linked to this doctor. `temporaryPassword` is `null`. Show "This patient already has an account and has been added to your list" (BR-P3), then D6. The new doctor sees the identity and only the records their own clinic creates (AC-10).

Errors: 400 as above; **409 `PATIENT_ALREADY_LINKED`**, already this doctor's patient. The answer names the patient so the app can open D6:

```json
{ "status": 409, "code": "PATIENT_ALREADY_LINKED", "patientId": "…", "fileNumber": 1, "title": "This number is already one of your patients." }
```

### Patient view

`GET /api/patients/{patientId}` (D6 header and file summary; any clinic caller) returns it, and so do `createPatient`, `updatePatient`, `updatePatientPhone` and `setArchived`.

```json
{
  "patientId": "…", "fileNumber": 1,
  "fullName": "منى حسن", "phone": "+201012345678", "gender": "female",
  "dateOfBirth": "1990-05-01", "dateOfBirthEstimated": false, "ageYears": 36,
  "nationalId": null, "address": null, "bloodType": null,
  "emergencyContactName": null, "emergencyContactPhone": null,
  "ownsDetails": true,
  "accountStatus": "active",
  "archived": false, "archivedAt": null,
  "linkedAt": "2026-11-15T20:37:09.593Z",
  "visits": {
    "firstVisitAt": "2026-11-03T08:12:00.000Z",
    "lastVisit": {
      "sessionId": "…", "at": "2026-11-15T09:30:00.000Z", "day": "2026-11-15", "daysAgo": 0,
      "type": "consultation", "branchId": "…", "branchNameAr": "فرع المعادي", "branchNameEn": null
    },
    "total": 3, "examinations": 1, "consultations": 2, "consultationsSinceExam": 2
  },
  "totalPaidPiasters": 60000,
  "hasAllergies": false,
  "files": { "prescription": 0, "lab": 0, "radiology": 0, "other": 0, "total": 0 },
  "prescriptionCount": 0,
  "nextBooking": null,
  "noShowCount": 0
}
```

- `ownsDetails`: this clinic created the account, so it sees and edits the optional details (`nationalId`, `address`, `bloodType`, `emergencyContact*`). In a clinic that linked an existing patient they are `null` and `ownsDetails` is `false`: hide those fields in D6 and D7 (BR-P3).
- `ageYears` is computed from `dateOfBirth` on today's Cairo date. Show "≈" when `dateOfBirthEstimated`.
- `accountStatus`: the patient account: `active`, `disabled` (by the admin, AD11) or `deleted` (Phase 4).
- `visits` counts this doctor's non-deleted sessions only (BR-P3). `lastVisit` is `null` before the first session. `lastVisit.day` is its Cairo date and `daysAgo` the Cairo days since (0 = today), for "x days ago".
- `totalPaidPiasters`: the sum of the amounts charged on this doctor's non-deleted sessions (`revenueView`, else `null`).
- `hasAllergies`: `clinicalView`, else `null`. Show the red allergy flag when `true`.
- `files` (per D6 sub-tab) and `prescriptionCount` (sent prescriptions) count this clinic's records only. They are 0 until Phase 3.
- `nextBooking` is `null` and `noShowCount` 0 until Phase 6.

Errors: 404.

### `POST /api/patients/updatePatient`

D7 identity fields, except the phone. Every field is replaced: an optional field left out is cleared, so send the whole form.

```json
{ "patientId": "…", "fullName": "أميرة سعيد", "gender": "female", "dateOfBirth": "1991-02-03",
  "nationalId": null, "address": "مدينة نصر", "bloodType": null, "emergencyContactName": null, "emergencyContactPhone": null }
```

Rules as in `createPatient`, and `fullName`, `gender` and `dateOfBirth` or `ageYears` are always required. `patientId`: `REQUIRED`.

- The identity is one account shared by every clinic the patient is linked to, so a change to the name, gender or date of birth shows in every clinic (the name on every link and in their search).
- The optional details change only when `ownsDetails` is true; elsewhere they are ignored (BR-P3).
- An estimated date of birth is kept while the `ageYears` sent is still the age it gives, so re-saving the form doesn't move the date.

**200** patient view. Errors: 400, 404.

### `POST /api/patients/updatePatientPhone`

D7 phone change. The number is the patient's login and is unique among patient accounts (BR-P2). An assistant account on the same number is fine (BR-AS3).

```json
{ "patientId": "…", "phone": "01098765432" }
```

**200** patient view. The patient signs in with the new number from now on; existing sessions stay signed in. Errors: 400 `phone` (`REQUIRED`, `INVALID_MOBILE`), 404, **409 `PATIENT_PHONE_TAKEN`** (another patient account uses it).

### `POST /api/patients/resetPatientPassword`

BR-P5. `{ "patientId": "…" }` → **200**, `Cache-Control: no-store`:

```json
{ "patientId": "…", "temporaryPassword": "4KjYdAZh" }
```

Show it once with WhatsApp / SMS / Copy. The patient is signed out on every device (their next request gets 401 `SESSION_REVOKED`), must change the password at the next sign-in, and any lockout from wrong passwords is cleared. Errors: 400, 404.

### `POST /api/patients/setArchived`

BR-P7 [S]. `{ "patientId": "…", "archived": true }` → **200** patient view. Archived patients leave the default register; nothing is deleted. Recording a session for an archived patient unarchives them. Errors: 400 `archived: REQUIRED`, 404.

## Medical profile

Kept per doctor–patient link (spec 6.1): each clinic has its own. The patient sees it read-only (Phase 4).

### `GET /api/patients/{patientId}/medicalProfile`

`clinicalView`. D6 Overview, D7.

```json
{
  "patientId": "…",
  "hasAllergies": true,
  "allergies": [ { "id": "…", "text": "Penicillin" } ],
  "chronicDiseases": [ { "id": "…", "text": "سكر" } ],
  "currentMedications": [],
  "surgeries": [],
  "familyHistory": "الأب: سكر",
  "notes": null
}
```

Lists are in the order saved. **Allergies come first and are shown in red everywhere** (a red highlighted block in D6). Errors: 404.

### `POST /api/patients/updateMedicalProfile`

`clinicalEditProfile` (which needs `clinicalView`). **Replaces the whole profile**: a list or text left out is cleared.

```json
{
  "patientId": "…",
  "allergies": ["Penicillin"], "chronicDiseases": ["سكر", "ضغط"],
  "currentMedications": ["Metformin 500"], "surgeries": [],
  "familyHistory": "الأب: سكر", "notes": null
}
```

| Field | Rule | Error code |
|---|---|---|
| each list | ≤ 50 items | `OUT_OF_RANGE` (on the list, for example `allergies`) |
| each item | 1–200 characters, not blank | `REQUIRED`, `TOO_LONG` (on the item, `allergies[0]`) |
| `familyHistory`, `notes` | optional, ≤ 2000 | `TOO_LONG` |

Items are trimmed and single-spaced; repeats in one list (ignoring case) are dropped. Items that stay keep their `id`. **200** the profile, as `GET`. Errors: 400, 404.

## `GET /api/patients/register` (D4)

`getPatientsRegister`, D4 and AS2. Any clinic caller: the list is clinic-wide (BR-AS13). Paged (`page`, `pageSize` 1–100, default 25), answer as in Phase 1: `{ items, page, pageSize, totalCount, totalPages }`.

| Query | Meaning | Error |
|---|---|---|
| `search` | ≤ 60. Letters: every word must appear in the name, after [search normalization](api-phase-2.md#search-text) («احمد» finds «أحمد», «منه» finds «منة»). Digits (Arabic-Indic too, spaces ignored): part of the phone (`0101234`, `+20 101…`) or the whole file number. A mix ("منى 0101") applies each word. | `TOO_LONG` |
| `lastVisit` | `thisWeek` (since Saturday, Cairo), `thisMonth`, `notSeen3m`, `notSeen6m`, `notSeen12m` (last visit more than N months ago; never-visited patients excluded, AC-24), `never` | `INVALID_VALUE` |
| `branchId` | patients with at least one visit in that branch | 404 (not the doctor's) |
| `minVisits`, `maxVisits` | range on `visits.total` (≥ 0) | `OUT_OF_RANGE` |
| `newThisMonth=true` | linked to the doctor this Cairo month | |
| `archived=true` | archived patients only. Absent or `false`: active patients only (BR-P7). | |
| `hasUpcomingBooking=true` | a pending or confirmed booking from today on | |
| `hasNoShows=true` | at least one no-show | |
| `hasChronicDisease=true` | any chronic disease in the profile. **`clinicalView`** | 403 `PERMISSION_DENIED` `clinicalView` |
| `chronicDisease` | a chronic disease containing this text (≤ 200). **`clinicalView`** | 403 as above |
| `sort` | `lastVisit` (default), `fileNumber`, `name`, `phone`, `age`, `gender`, `firstVisit`, `visits`, `examinations`, `consultations`, `files`, `linkedAt`, `nextBooking`, `noShows`, `totalPaid` (**`revenueView`**), `allergies` (**`clinicalView`**), `unreadChat` (**`chat`**) | `INVALID_VALUE`; 403 for a sort the caller may not use |
| `direction` | `asc` or `desc`. Default `desc` for `lastVisit`, `firstVisit`, `visits`, `examinations`, `consultations`, `files`, `linkedAt`, `noShows`, `totalPaid`, `allergies`, `unreadChat`; `asc` for the rest. Ties go by file number. | `INVALID_VALUE` |

With `sort=lastVisit&direction=desc` (the default), never-visited patients come last. With `sort=nextBooking`, patients without a booking come last in both directions.

```json
{
  "items": [
    {
      "patientId": "…", "fileNumber": 1, "fullName": "منى حسن", "phone": "+201012345678", "gender": "female",
      "dateOfBirth": "1990-05-01", "dateOfBirthEstimated": false, "ageYears": 36,
      "visits": { "firstVisitAt": "…", "lastVisit": { …as in the patient view… },
                  "total": 3, "examinations": 1, "consultations": 2, "consultationsSinceExam": 2 },
      "totalPaidPiasters": 60000,
      "nextBooking": null, "noShowCount": 0,
      "filesCount": 0,
      "unreadChatCount": 2,
      "hasAllergies": true,
      "chronicDiseases": ["سكر"],
      "archived": false,
      "linkedAt": "2026-11-15T20:37:09.593Z"
    }
  ],
  "page": 1, "pageSize": 25, "totalCount": 1, "totalPages": 1
}
```

D4 columns: file number, name, phone, age, gender, first visit, last visit (date, type, branch, "x days ago" from `daysAgo`), visits (examinations / consultations), total paid, next booking, no-shows, files count, allergies flag, unread chat badge. `totalPaidPiasters` is `null` without `revenueView`; `hasAllergies` and `chronicDiseases` are `null` without `clinicalView`. `unreadChatCount` is the caller's own unread messages from that patient (the doctor and each assistant read separately); it is `null` without `chat`. `nextBooking` and `noShowCount` are described in api-phase-7.md.

### `GET /api/patients/register/export` (D4 [S] "Export CSV")

**Doctor only** (an assistant gets 403 `PERMISSION_DENIED`): it is the whole patient list with phone numbers. Takes the register's query (filters, `sort`, `direction`; `page` and `pageSize` are ignored) with the same errors, plus `lang`: `ar` (default) or `en` for the headers and values.

- **200** `text/csv; charset=utf-8`, `attachment; filename=patients-2026-11-21.csv`. UTF-8 with a BOM and CRLF rows, so Excel opens Arabic correctly.
- Columns: file number, name, mobile (`010 1234 5678`, spaced so a spreadsheet keeps the leading zero), gender, age, first visit, last visit (date, type, branch), visits, examinations, consultations, next booking, no-shows, files, then total paid in EGP (`350.00`, with `revenueView`), allergies (yes / no) and chronic diseases (with `clinicalView`), and the date added. Dates are Cairo days (`yyyy-MM-dd`).
- A cell that starts with `=`, `+`, `-`, `@`, tab or CR gets a leading apostrophe, so a name can never run as a spreadsheet formula.
- Writes a `patientsExported` audit row (D27) with the row count, the language and the filters used, never names or phones.
- 400 `EXPORT_TOO_LARGE` with `maxRows` (20000) when the filters match more patients than that.

### D6 Appointments tab

The tab lists one patient's bookings with `GET /api/staff/appointments?patientId={patientId}&sort=dateDesc` (`searchAppointments`, `appointmentsView`; an assistant sees their branches only). `patientId` and `sort=dateDesc` (newest first) are new; the other sorts are `date` (default, oldest first), `status` and `patient`.

## Sessions

`type` is `examination` (كشف) or `consultation` (استشارة). `at` is the server time of the save (UTC, BR-S9) and `day` its Cairo date. **Platform fee** (`platformFeePiasters`) is what the platform bills the doctor (spec 6.5), a snapshot taken at save time (BR-S5). **Amount charged** (`amountChargedPiasters`) is what the patient paid the clinic (BR-S10); **list price** (`listPricePiasters`) the clinic's visit price at that moment (6.15). They never affect each other.

### `GET /api/sessions/newSessionInfo`

`sessionsCreate`. D8 step 1 and AS5: everything the type cards, the BR-S4 message and the BR-S6 confirmation need. Query: `patientId`, `branchId` (both required; the current branch, BR-BR3).

```json
{
  "patientId": "…", "branchId": "…",
  "isFirstVisit": false,
  "lastSession": { "sessionId": "…", "at": "…", "day": "2026-11-03", "daysAgo": 12, "type": "examination",
                   "branchId": "…", "branchNameAr": "فرع المعادي", "branchNameEn": null },
  "consultationsSinceExam": 1,
  "maxConsecutiveConsultations": 2,
  "consultationAllowed": true,
  "consultationBlockedReason": null,
  "examination":  { "allowed": true, "platformFeePiasters": 3000, "visitPricePiasters": 30000, "priceSource": "doctor" },
  "consultation": { "allowed": true, "platformFeePiasters": 1500, "visitPricePiasters": 15000, "priceSource": "branch" }
}
```

- "Last session: Examination, 3 Nov" from `lastSession`; «استشارة 1 من 2 منذ آخر كشف» from `consultationsSinceExam` and `maxConsecutiveConsultations` (BR-S4).
- `consultationBlockedReason`: `firstVisit` (the patient has no examination with this doctor yet: offer only Examination, BR-S2) or `limitReached` (disable Consultation with the BR-S4 message «لا يمكن تسجيل أكثر من استشارتين متتاليتين. يجب تسجيل كشف أولاً.», whose number follows `maxConsecutiveConsultations`). An examination is always allowed.
- `platformFeePiasters` is the fee for the BR-S6 confirmation ("A fee of 30 EGP will be added").
- `visitPricePiasters` is the default amount charged: the branch's price for the type, else the doctor's (`priceSource` `branch` / `doctor`), else `null`: then the amount must be typed (BR-PR6, BR-S10).
- The answer can be out of date by the time of saving; `createSession` checks again.

Errors: 400 (`REQUIRED`), 403 `BRANCH_NOT_ALLOWED`, 404 (patient or branch), 409 `BRANCH_ARCHIVED`.

### `POST /api/sessions/createSession`

`sessionsCreate`, **blocked while suspended** (BR-S8). D8 and AS5 save, after the BR-S6 confirmation. One transaction (spec 9.1): it checks the consultation rule with the patient's link locked, so two devices saving at the same moment can't both get past it (BR-S4, AC-2). It also writes the fee snapshot, the list price and amount, the link counters, the day and month stats, the patient's notification and the audit row.

```json
{
  "patientId": "…", "branchId": "…", "type": "examination",
  "chiefComplaint": "صداع",
  "vitals": { "bpSys": 120, "bpDia": 80, "pulse": 75, "tempC": 37.2, "weightKg": 70.5, "heightCm": 170, "glucose": 95 },
  "findings": "…", "diagnosis": "صداع نصفي", "patientNotes": "راحة", "privateNote": "…", "followUpDate": "2026-11-22",
  "amountChargedPiasters": 25000, "paymentMethod": "cash"
}
```

| Field | Rule | Error code |
|---|---|---|
| `patientId`, `branchId` | required | `REQUIRED` |
| `type` | required: `examination`, `consultation` (BR-S1) | `REQUIRED`, `INVALID_VALUE` |
| `chiefComplaint` | optional, ≤ 1000 | `TOO_LONG` |
| `vitals` | optional object. Each value optional: `bpSys` 30–300 and `bpDia` 10–200 (send both or neither), `pulse` 20–300, `tempC` 25–45 (1 decimal), `weightKg` 0.2–400 (2 decimals), `heightCm` 20–250 (1 decimal), `glucose` 10–1500 mg/dL. Values are rounded to those decimals. The app warns about unusual values (spec 11: systolic 50–260, 34–43 °C …); the API accepts anything in these wider limits. | `OUT_OF_RANGE` (`vitals.bpSys` …), `INVALID_VALUE` (`vitals.bpDia`) |
| `findings`, `patientNotes` | optional, ≤ 10,000. **Doctor only** | `TOO_LONG` |
| `diagnosis` | optional, ≤ 1000. **Doctor only** | `TOO_LONG` |
| `privateNote` | optional, ≤ 10,000. **Doctor only.** Never visible to patients or assistants. | `TOO_LONG` |
| `followUpDate` | optional `YYYY-MM-DD`, from today (Cairo) to 2 years after. **Doctor only** | `OUT_OF_RANGE` |
| `amountChargedPiasters` | 0–10,000,000 (0–100,000 EGP). Optional: defaults to the visit price. Can be lowered or 0 (free); a higher value is accepted too. **Required when there is no visit price** for this type and branch. | `OUT_OF_RANGE`, `AMOUNT_REQUIRED` |
| `paymentMethod` | optional [S]: `cash`, `card`, `instapay`, `wallet` | `INVALID_VALUE` |

**Assistants** (AS5, BR-AS5) may send only `type`, `chiefComplaint`, `vitals`, `amountChargedPiasters` and `paymentMethod`. If `findings`, `diagnosis`, `patientNotes`, `privateNote` or `followUpDate` is filled (empty text counts as not sent), nothing is saved and the answer is:

```json
{ "status": 403, "code": "PERMISSION_DENIED", "permission": "doctorOnly", "fields": ["diagnosis"] }
```

An assistant's session gets `awaitingDoctor: true` (the «بانتظار الطبيب» badge, BR-AS7). It counts in the doctor's totals and invoice like any other (BR-AS6).

**201** the [session view](#session-view), as the caller may see it. Then D8 shows its after-save sheet.

The checks run in this order; the first that fails answers:

| Check | Answer |
|---|---|
| Field rules | 400 `VALIDATION_FAILED` |
| An assistant sent a doctor-only field | 403 `PERMISSION_DENIED`, `doctorOnly`, `fields` |
| The assistant doesn't work in `branchId` | 403 `BRANCH_NOT_ALLOWED` |
| The patient isn't linked to this doctor | **404 `NOT_LINKED`** |
| `branchId` isn't the doctor's | 404 `NOT_FOUND` |
| The branch is archived (a temporarily closed one is fine) | 409 `BRANCH_ARCHIVED` |
| The consultation rule (BR-S2, BR-S3) | **409 `CONSULTATION_REQUIRES_EXAM`** |
| No visit price and no amount | 400 `amountChargedPiasters: AMOUNT_REQUIRED` («أدخل المبلغ المحصّل») |

```json
{ "status": 409, "code": "CONSULTATION_REQUIRES_EXAM", "reason": "limitReached",
  "consultationsSinceExam": 2, "maxConsecutiveConsultations": 2, "title": "Record an examination first." }
```

`reason` is `firstVisit` or `limitReached`, as in `newSessionInfo`. On this answer, refresh `newSessionInfo` and show the BR-S4 message with these numbers.

### Session view

`GET /api/sessions/{sessionId}` (D9) returns it, and so do `createSession`, `updateClinical` and `updateAmountCharged`. Open to `sessionsCreate`, `clinicalView` or `billingView`. The doctor's view:

```json
{
  "sessionId": "…", "patientId": "…", "fileNumber": 1, "patientName": "منى حسن",
  "type": "examination", "at": "2026-11-15T20:37:10.149Z", "day": "2026-11-15",
  "branch": { "id": "…", "nameAr": "فرع المعادي", "nameEn": null },
  "platformFeePiasters": 3000,
  "amountChargedPiasters": 30000, "listPricePiasters": 30000, "paymentMethod": "cash",
  "recordedBy": { "userId": "…", "name": "أحمد علي", "role": "doctor" },
  "awaitingDoctor": false,
  "clinical": {
    "chiefComplaint": "صداع", "findings": "سليم",
    "vitals": { "bpSys": 120, "bpDia": 80, "pulse": 75, "tempC": 37.2, "weightKg": null, "heightCm": null, "glucose": null },
    "diagnosis": "صداع نصفي", "patientNotes": "راحة", "followUpDate": null
  },
  "hasPrivateNote": true,
  "can": { "editClinical": true, "editAmount": true, "delete": true, "deleteBlockedReason": null, "privateNote": true },
  "updatedAt": "2026-11-15T20:37:10.149Z"
}
```

A reception assistant's view of a session they recorded: `clinical: null`, `hasPrivateNote: null`, the amount shown because they recorded it:

```json
{
  "sessionId": "…", "type": "consultation", "…": "…",
  "platformFeePiasters": 1500, "amountChargedPiasters": 10000, "listPricePiasters": 15000, "paymentMethod": null,
  "recordedBy": { "userId": "…", "name": "سارة محمود", "role": "assistant" },
  "awaitingDoctor": true, "clinical": null, "hasPrivateNote": null,
  "can": { "editClinical": false, "editAmount": true, "delete": false, "deleteBlockedReason": null, "privateNote": false }
}
```

- `recordedBy.role`: `doctor` or `assistant`. Show "Recorded by <name>" to staff (BR-AS6).
- `type` and `at` never change (BR-S6): show them with a lock icon.
- `clinical`: `null` without `clinicalView` (an assistant then sees only time, type, fee, branch, recorded by, awaiting doctor). Inside it, any field can be `null`.
- `can` tells D9 which actions will work now, so it shows only those:
  - `editClinical`: the doctor (`updateClinical`).
  - `editAmount`: on the session's Cairo day, the doctor or whoever recorded it (`updateAmountCharged`).
  - `delete`: `sessionsDelete`, the session's branch, and BR-S7 allows it (`deleteSession`).
  - `deleteBlockedReason`: the BR-S7 reason, whatever the caller's permissions: `notLatest`, `notSameDay` or `null`.
  - `privateNote`: the doctor (the lock-icon field).

Errors: 403 `PERMISSION_DENIED` `sessionsCreate` (none of the three permissions), 404.

### Session lists

**`GET /api/patients/{patientId}/sessions`** (D6 Sessions tab, AS4): `sessionsCreate` or `clinicalView`. This doctor's non-deleted sessions of the patient, newest first, paged (`page`, `pageSize`). Clinic-wide, not limited to the assistant's branches. Errors: 404.

Rows (also used by [`day`](#get-apisessionsday-d2-as1)):

```json
{
  "sessionId": "…", "at": "2026-11-15T20:37:10.787Z", "day": "2026-11-15", "type": "consultation",
  "patientId": "…", "fileNumber": 1, "patientName": "منى حسن",
  "branch": { "id": "…", "nameAr": "فرع المعادي", "nameEn": null },
  "platformFeePiasters": 1500,
  "amountChargedPiasters": 20000, "paymentMethod": null,
  "recordedBy": { "userId": "…", "name": "أحمد علي", "role": "doctor" },
  "awaitingDoctor": false,
  "chiefComplaint": null, "diagnosis": null
}
```

`amountChargedPiasters` and `paymentMethod` need `revenueView` or having recorded that session; `chiefComplaint` and `diagnosis` need `clinicalView` (`null` otherwise). Type badges: كشف blue, استشارة green (D2).

### Private note (doctor only)

The doctor's private note on a session (spec 6.2), with a lock icon and "not visible to the patient". **Doctor only**: a patient or an admin gets 403 `FORBIDDEN` (AC-11), an assistant 403 `PERMISSION_DENIED` `doctorOnly` (BR-AS5). Allowed while suspended. `Cache-Control: no-store`.

| Method and route | Request | Success |
|---|---|---|
| `GET /api/sessions/{sessionId}/privateNote` | | 200 `{ "sessionId": "…", "text": "…", "updatedAt": "…" }`; `text` and `updatedAt` are `null` when there is none |
| `POST /api/sessions/setPrivateNote` | `{ "sessionId": "…", "text": "…" }`, `text` ≤ 10,000 (`TOO_LONG`). Empty or `null` removes the note. | 200, same shape |

Errors: 400, 404. The note can also be sent with `createSession` (`privateNote`).

### `POST /api/sessions/updateClinical`

**Doctor only**, allowed while suspended. D9 clinical fields. Every field is replaced: a field left out is cleared, so send the whole form.

```json
{
  "sessionId": "…",
  "chiefComplaint": "كحة", "findings": "صفير",
  "vitals": { "tempC": 38.2 },
  "diagnosis": "التهاب شعبي", "patientNotes": "مضاد حيوي", "followUpDate": "2026-11-29"
}
```

Field rules as in `createSession`, except `followUpDate`: from the session's day to 2 years after (`OUT_OF_RANGE`). `type` and the time can't be sent (BR-S6); they are ignored.

The doctor's save clears `awaitingDoctor` (BR-AS7) when at least one clinical field is filled after it. **200** session view. Errors: 400, 404.

### `POST /api/sessions/updateAmountCharged`

BR-S10: on the session's Cairo day only, by the doctor or by whoever recorded it. An assistant also needs `sessionsCreate`. Every change is logged with before and after.

```json
{ "sessionId": "…", "amountChargedPiasters": 15000, "paymentMethod": "card" }
```

`amountChargedPiasters` is required, 0–10,000,000 (`AMOUNT_REQUIRED`, `OUT_OF_RANGE`). `paymentMethod` is replaced: left out, it is cleared. The platform fee never changes.

**200** session view. Errors: 400, 403 `PERMISSION_DENIED` (`sessionsCreate`; or `doctorOnly` for an assistant who didn't record it), 404, **409 `AMOUNT_NOT_EDITABLE`** (an earlier day).

### `POST /api/sessions/deleteSession`

`sessionsDelete` (off in every preset), allowed while suspended. BR-S7: only the patient's **latest** non-deleted session with this doctor, recorded **today** (Cairo), with a **reason**.

```json
{ "sessionId": "…", "reason": "سجلت للمريض الخطأ" }
```

`reason`: 3–500 characters (`REASON_REQUIRED`, `TOO_LONG`). Show **Delete** only when the session view says `can.delete`, with a reason box and a confirmation.

**200** `{ "sessionId": "…", "deletedAt": "2026-11-15T21:02:00.000Z" }`. The deletion is soft:

- The session leaves every list, total and the invoice (BR-B1) and answers 404 from now on. Its fee comes off today's and this month's totals (AC-5).
- The patient's counters are rebuilt from the remaining sessions, including `consultationsSinceExam` (so a consultation may be allowed again).
- It appears in the admin audit log (AD15) with the reason (`sessionDeleted`).
- The patient's "new visit" notification stays; opening it finds nothing.

Errors: 400, 403 `BRANCH_NOT_ALLOWED` (an assistant, a session in a branch not theirs), 404, **409 `SESSION_NOT_DELETABLE`** with `reason`:

```json
{ "status": 409, "code": "SESSION_NOT_DELETABLE", "reason": "notLatest", "title": "This session can't be deleted." }
```

| `reason` | Message for the app |
|---|---|
| `notLatest` | "Only the patient's latest session can be deleted." |
| `notSameDay` | "A session can be deleted only on the day it was recorded." |

## Fees

Platform-fee totals (spec 6.5) are counts and sums of the **fee snapshots** of non-deleted sessions (BR-B1, BR-S5), so a fee change mid-month is counted right (AC-3) and they match the invoice. Days and months are Cairo dates, whatever the device's time zone (AC-4).

Totals object, used below:

```json
{ "examinationCount": 2, "consultationCount": 3, "examinationFeePiasters": 6000, "consultationFeePiasters": 4500, "totalPiasters": 10500 }
```

D1 card: «2 كشف + 3 استشارة = 105 ج.م» is `examinationCount` كشف + `consultationCount` استشارة = `totalPiasters` / 100 ج.م.

### `GET /api/sessions/day` (D2, AS1)

`sessionsCreate` or `billingView`. One Cairo day's sessions, newest first, **not paged** (a day is short), with totals for exactly the rows listed. D3's "tap a day" uses it too.

| Query | Meaning | Error |
|---|---|---|
| `day` | `YYYY-MM-DD`, default today (Cairo) | `INVALID_VALUE` |
| `branchId` | one branch | 403 `BRANCH_NOT_ALLOWED` (assistant), 404 |
| `type` | `examination` or `consultation` | `INVALID_VALUE` |
| `recordedBy` | a user ID: the doctor or one assistant | |

An assistant who works in some branches sees only those branches' sessions, and totals for them (BR-AS13).

```json
{
  "day": "2026-11-15",
  "items": [ { …session list row… } ],
  "totals": { "examinationCount": 1, "consultationCount": 2, "examinationFeePiasters": 3000, "consultationFeePiasters": 3000, "totalPiasters": 6000 },
  "amountChargedTotalPiasters": 60000
}
```

D2 row: time (`at`), patient (`patientName`, `fileNumber`), type badge, fee (`platformFeePiasters`), recorded by (`recordedBy.name`, `role`), «بانتظار الطبيب» when `awaitingDoctor`. Tap → D9. `amountChargedTotalPiasters` is `null` without `revenueView`.

### `GET /api/sessions/feeSummary` (D1)

`billingView`. The D1 fee cards, for the whole clinic (every branch). Tap today → D2, this month → D3.

```json
{
  "day": "2026-11-15", "month": "2026-11",
  "today":     { "examinationCount": 2, "consultationCount": 3, "examinationFeePiasters": 6000, "consultationFeePiasters": 4500, "totalPiasters": 10500 },
  "thisMonth": { "examinationCount": 40, "consultationCount": 31, "examinationFeePiasters": 120000, "consultationFeePiasters": 46500, "totalPiasters": 166500 }
}
```

### `GET /api/sessions/month` (D3)

`billingView`. Clinic-wide for assistants too: billing is per doctor (BR-BR7).

| Query | Meaning | Error |
|---|---|---|
| `month` | `YYYY-MM`, default this month (Cairo) | `INVALID_VALUE` |
| `branchId` | everything below for that branch only | 404 |

```json
{
  "month": "2026-11",
  "branchId": null,
  "totals": { "examinationCount": 3, "consultationCount": 1, "examinationFeePiasters": 9000, "consultationFeePiasters": 1500, "totalPiasters": 10500 },
  "branches": [
    { "branchId": "…", "nameAr": "فرع المعادي", "nameEn": null, "totals": { …, "totalPiasters": 6000 } },
    { "branchId": "…", "nameAr": "فرع مدينة نصر", "nameEn": null, "totals": { …, "totalPiasters": 4500 } }
  ],
  "days": [
    { "day": "2026-11-01", "totals": { "examinationCount": 0, "consultationCount": 0, "examinationFeePiasters": 0, "consultationFeePiasters": 0, "totalPiasters": 0 } },
    { "day": "2026-11-15", "totals": { …, "totalPiasters": 10500 } }
  ]
}
```

- `branches`: the branches with sessions that month, default branch first. Their totals add up to `totals` (BR-BR7, AC-20).
- `days`: one row per day, with zeros: the whole of a past month, up to today for this month, none for a future month. Tap a day → `day?day=…`.
- Past months: these numbers are live; the month's invoice (D19, Phase 7) is the billed figure.

## Screens → endpoints

| Screen | Calls |
|---|---|
| D1 fee cards | `feeSummary` (`billingView`); the suspension banner from `clinic/me` |
| D2 today's sessions, AS1 without the board | `day` |
| D3 monthly summary | `month`, then `day?day=` for a day |
| D4, AS2 register | `register`; Add patient → D5 |
| D5, AS3 add patient | `lookupPhone`, then `createPatient`; the password dialog when `temporaryPassword` isn't null |
| D6, AS4 patient profile | `GET /patients/{id}`; Overview: `medicalProfile` (`clinicalView`); Sessions tab: `/patients/{id}/sessions`; menu: `resetPatientPassword`, `setArchived` |
| D7 edit patient | `updatePatient`, `updatePatientPhone`, `updateMedicalProfile` |
| D8, AS5 new session | `newSessionInfo`, then `createSession` |
| D9 session details | `GET /sessions/{id}`, `updateClinical`, `updateAmountCharged`, `deleteSession`, `privateNote` / `setPrivateNote` |

## Notifications

Rows in `Notifications` (both languages); delivery comes in Phase 5. No clinical text, ever (spec 10.1).

| `type` | Recipient | Title (AR / EN) | Body | `route` | `data` |
|---|---|---|---|---|---|
| `sessionRecorded` | the patient | تم تسجيل زيارة جديدة / New visit recorded | `كشف لدى د. {doctor} — {branch}` / `Examination with Dr {doctor} — {branch}` (or استشارة / Consultation) | `/visits/{sessionId}` | `{ sessionId, doctorId }` |

## Audit actions

Every write adds an `AuditLogs` row with the clinic's `doctorId`, the actor (doctor or assistant) and the patient, for D27 (BR-AS10) and AD15. Target types: `patient`, `session`. Details never hold medical text, passwords or phone numbers.

| Action | Target | Details |
|---|---|---|
| `patientCreated` | patient | `fileNumber` |
| `patientLinked` | patient | `fileNumber` |
| `patientUpdated` | patient | `fields` (names) |
| `patientPhoneChanged` | patient | |
| `patientPasswordReset` | patient | |
| `patientArchived`, `patientUnarchived` | patient | |
| `patientMedicalProfileUpdated` | patient | `fields`: what changed, from `allergies`, `chronicDiseases`, `currentMedications`, `surgeries`, `familyHistory`, `notes`; `added`, `removed` (item counts). Saving the same profile again writes no row. |
| `sessionCreated` | session | `type`, `branchId`, `feePiasters`, `awaitingDoctor` |
| `sessionClinicalUpdated` | session | `fields` (names, `vitals.tempC` …) |
| `sessionPrivateNoteUpdated` | session | `cleared` |
| `sessionAmountChanged` | session | `before`, `after` (piasters), `paymentMethodBefore`, `paymentMethodAfter`. The admin audit log (AD15) lists this row with `details: null` (BR-REV1). |
| `sessionDeleted` | session | `reason`, `type`, `feePiasters`, `day`. AD5's per-doctor deletion count counts these. |

## Error codes

New in this part. The shared clinic codes (`PERMISSION_DENIED`, `BRANCH_NOT_ALLOWED`, `DOCTOR_SUSPENDED` …) are in [api-phase-2.md](api-phase-2.md), the rest in [api-phase-1.md](api-phase-1.md#error-codes).

| Code | HTTP | Where | Meaning |
|---|---|---|---|
| `INVALID_DATE_OF_BIRTH` | field | patients | «تاريخ الميلاد غير صحيح» (future, or more than 120 years ago) |
| `INVALID_NATIONAL_ID` | field | patients | «الرقم القومي يجب أن يكون 14 رقم» |
| `AMOUNT_REQUIRED` | field | `createSession`, `updateAmountCharged` | «أدخل المبلغ المحصّل» (no visit price for this type) |
| `REASON_REQUIRED` | field | `deleteSession` | A deletion needs a reason (from Phase 1) |
| `NOT_LINKED` | 404 | `createSession` | The patient isn't linked to this doctor |
| `PATIENT_ALREADY_LINKED` | 409 | `createPatient` | Already this doctor's patient; has `patientId` and `fileNumber` |
| `PATIENT_PHONE_TAKEN` | 409 | `updatePatientPhone` | Another patient account uses this number |
| `CONSULTATION_REQUIRES_EXAM` | 409 | `createSession` | BR-S2 / BR-S3; has `reason`, `consultationsSinceExam`, `maxConsecutiveConsultations` |
| `BRANCH_ARCHIVED` | 409 | `newSessionInfo`, `createSession` | The branch is archived |
| `AMOUNT_NOT_EDITABLE` | 409 | `updateAmountCharged` | Not the session's day (BR-S10) |
| `SESSION_NOT_DELETABLE` | 409 | `deleteSession` | BR-S7; has `reason`: `notLatest` or `notSameDay` |

## Decisions where the spec is silent

- **Shared identity.** Name, phone, gender and date of birth are one `Patients` row that every linked clinic sees and edits (BR-P3). The optional D5 details live on the same row but belong to the clinic that created the account (`Patients.CreatedByDoctorId`): only it sees and edits them (`ownsDetails`).
- **Linking** keeps the existing account's identity and ignores the typed fields. It needs the phone alone.
- **Age instead of a date of birth** is stored as today minus that many years, flagged as estimated.
- **The medical profile** is replaced per call. Items that stay keep their row. Removed items are soft-deleted (`DeletedAt`, BR-P8) and never shown again. The audit row counts what was added and removed, without the text.
- **The register's branch filter** means "has visited that branch"; `newThisMonth` means "linked this Cairo month"; `thisWeek` starts on Saturday; "not seen for N months" leaves out never-visited patients (they have their own filter).
- **Session details** need `sessionsCreate`, `clinicalView` or `billingView`, because D2 (`sessionsCreate` or `billingView`) and the Sessions tab open them.
- **Amounts** are visible to `revenueView` and to whoever recorded the session, in details and lists alike. An assistant edits only the amounts they recorded, and needs `sessionsCreate`.
- **The amount charged** may also be above the list price (extra services); the limit is 100,000 EGP.
- **«بانتظار الطبيب»** clears when the doctor saves the clinical form with at least one field filled.
- **A temporarily closed branch** still takes sessions (staff may see a patient anyway); only archived branches refuse.
- **An archived patient** who gets a new session is unarchived.
- **`deleteSession`** works while suspended (BR-G5 doesn't block it), and an assistant deletes only in their branches.
- **Private notes**: empty text removes the note. Its text is never in an audit row.
- **Day lists** aren't paged. Fee totals read SQL aggregates of the sessions, not the DailyStats / MonthlyStats counters (which `createSession` and `deleteSession` keep up to date for Phase 7).

## Not yet

| What | Phase |
|---|---|
| `nextBooking`, `noShowCount`, the `hasUpcomingBooking` and `hasNoShows` filters, `appointmentId` on `createSession` | 6 |
| Unread chat badge in D4, chat rows for new links | 5 |
| `files` and `prescriptionCount` above 0 | 3 |
| The patient's own view of sessions and the profile | 4 |
