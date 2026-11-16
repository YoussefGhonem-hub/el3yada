# el3yada API: Phase 2 contract (patients, sessions, branches and assistants)

This is what the Flutter app builds against for Phase 2 (D1–D9, D22, D24–D29, D37, AS1–AS5, AS12, AS19). Conventions, errors, tokens and paging are as in [api-phase-1.md](api-phase-1.md). The code is the source of truth. When this page and the code differ, fix this page.

- [Clinic endpoints: who may call them](#clinic-endpoints-who-may-call-them)
- [`GET /api/clinic/me`](#get-apiclinicme)
- [Cairo dates](#cairo-dates)
- [Search text](#search-text)
- Patients, medical profile, sessions, fee summaries: [api-phase-2-patients.md](api-phase-2-patients.md)
- Branches, visit prices, doctor profile, assistants, activity log: [api-phase-2-clinic.md](api-phase-2-clinic.md)

## Clinic endpoints: who may call them

Every clinic endpoint accepts the **doctor**, and an **assistant of that doctor** when the assistant has the permission the endpoint needs (spec 9.1, 6.10). An assistant always works on their doctor's data; there is no `doctorId` parameter. The server reads the doctor's status and the assistant's permissions and branches from the database on every request (BR-AS4), so a change applies on the next request, without signing in again.

The checks run in this order. The first one that fails answers:

| Check | Answer |
|---|---|
| The caller is a patient or an admin (AC-11, AC-12) | 403 `FORBIDDEN` |
| The doctor is pending approval / rejected | 403 `DOCTOR_PENDING_APPROVAL` / `DOCTOR_REJECTED` |
| The assistant is disabled or removed, or their clinic is not active (BR-AS9) | 403 `ACCOUNT_DISABLED` / `CLINIC_NOT_ACTIVE` (the app opens A10) |
| A doctor-only endpoint called by an assistant (BR-AS5) | 403 `PERMISSION_DENIED`, `"permission": "doctorOnly"` |
| The assistant lacks the endpoint's permission | 403 `PERMISSION_DENIED`, `"permission": "<key>"` |
| The doctor is suspended and the action is blocked while suspended (BR-G5, BR-G8) | 403 `DOCTOR_SUSPENDED` |
| A branch the assistant is not assigned to (BR-AS13) | 403 `BRANCH_NOT_ALLOWED` |
| A record of another doctor (patient, session, branch, assistant) | 404 `NOT_FOUND` (never 403, so IDs don't leak) |

```json
{ "status": 403, "code": "PERMISSION_DENIED", "permission": "sessionsCreate", "title": "Your clinic permissions don't include this." }
```

The app hides what the caller can't do (spec 7.6), so these answers are a safety net. On `PERMISSION_DENIED` or `DOCTOR_SUSPENDED`, the app re-reads `GET /api/clinic/me` and redraws.

**Blocked while suspended** (BR-G5): adding or linking patients, creating sessions, uploading files, prescriptions, sending chat messages. Everything else (reading, editing a session's clinical fields, profile, settings, branches, prices, assistants) still works.

An admin suspends or reactivates a doctor by hand with `POST /api/admin/setDoctorStatus` (BR-G4, [api-phase-1.md](api-phase-1.md#doctor-status-ad5-br-g4-any-admin)); it applies on the next request. Billing suspends and reactivates automatically from Phase 7.

**Permission keys** (spec 6.10), the same in `clinic/me`, in assistant endpoints and in `PERMISSION_DENIED`: `patientsManage`, `patientsResetPassword`, `sessionsCreate`, `sessionsDelete`, `clinicalView`, `clinicalEditProfile`, `filesManage`, `prescriptionsPrint`, `prescriptionsDraft`, `chat`, `billingView`, `billingPay`, `appointmentsView`, `appointmentsManage`, `scheduleManage`, `revenueView`, `pricesManage`.

**Presets:** `reception`, `clinical`, `officeManager`, `custom`. **Dependencies:** `clinicalEditProfile` and `prescriptionsDraft` need `clinicalView`; `billingPay` needs `billingView`; `appointmentsManage` needs `appointmentsView`; `scheduleManage` needs `appointmentsManage`.

**Activity log** (D27, BR-AS10): every clinic write adds an audit row with the clinic's `doctorId`, the actor (doctor or assistant) and the patient when there is one.

## `GET /api/clinic/me`

Doctor or assistant, any permission, also while suspended. What the app needs to draw the clinic shell: menus by permission, the current-branch picker (BR-BR3), «عيادة د. …» for assistants (spec 7.6), the suspension banner, the fees on the D8 type cards. Read it after sign-in, on resume, and after a `PERMISSION_DENIED`.

```json
{
  "role": "assistant",
  "doctor": {
    "id": "…", "fullName": "أحمد علي", "fullNameEn": null, "title": "أخصائي", "titleEn": null,
    "specialtyId": "…", "specialtyNameAr": "باطنة", "specialtyNameEn": "Internal medicine", "status": "active"
  },
  "assistant": { "userId": "…", "fullName": "سارة محمود", "preset": "reception", "allBranches": false, "branchIds": ["…"] },
  "permissions": { "patientsManage": true, "patientsResetPassword": true, "sessionsCreate": true, "sessionsDelete": false, "…": "…" },
  "branches": [
    { "id": "…", "nameAr": "فرع المعادي", "nameEn": null, "isDefault": true, "status": "active", "governorate": "القاهرة", "city": "المعادي", "assigned": true },
    { "id": "…", "nameAr": "فرع مدينة نصر", "nameEn": null, "isDefault": false, "status": "active", "governorate": "القاهرة", "city": "مدينة نصر", "assigned": false }
  ],
  "defaultBranchId": "…",
  "fees": { "examinationFeePiasters": 3000, "consultationFeePiasters": 1500, "maxConsecutiveConsultations": 2 },
  "limits": { "maxAssistants": 5, "maxBranches": 5, "maxUploadMb": 50 }
}
```

- `assistant` is `null` for the doctor. A doctor's `permissions` are all `true`.
- `doctor.status`: `active` or `suspended` (the other statuses never get here).
- `branches`: every branch of the doctor, default first, then oldest first; `status` is `active`, `temporarilyClosed` or `archived`. `assigned` is whether the caller works there (always `true` for the doctor). The current-branch picker lists assigned branches that are not archived, and shows only when there is more than one.
- `fees` are the platform fees per session (BR-S5), not the clinic's visit prices (section 6.15).

## Cairo dates

Clinic days and months are Cairo dates (spec 6.5), whatever the device's time zone (AC-4). Dates the API takes or returns as `day` are `YYYY-MM-DD` Cairo dates; months are `YYYY-MM` Cairo months. Timestamps stay UTC.

## Search text

Patient search (D4) normalizes the typed text and the stored names the same way (spec A.6): lower case, Arabic-Indic digits → 0–9, no diacritics or tatweel, أ إ آ ٱ → ا, ة → ه, ى → ي, punctuation → spaces. So «أحمد» finds «احمد» and «منة» finds «منه». The app doesn't need to normalize before sending.
