# el3yada API: Phase 2 clinic contract (branches, visit prices, profile, assistants, activity log)

This is what the Flutter app builds against for D22, D24–D29, D37, AS12, AS17 (read-only parts) and AS19. D29's Working hours, Special dates and Booking settings tabs (and AS17's editable ones) use `updateBranchSchedule`: see [api-phase-6-schedule.md](api-phase-6-schedule.md). Conventions, errors, tokens and paging are as in [api-phase-1.md](api-phase-1.md). Who may call a clinic endpoint, and the order of the access checks, are in [api-phase-2.md](api-phase-2.md#clinic-endpoints-who-may-call-them). The code is the source of truth. When this page and the code differ, fix this page.

- [Who may call what](#who-may-call-what)
- [Branches (D28, D29, AS17)](#branches-d28-d29-as17)
- [Visit prices (D37, AS19)](#visit-prices-d37-as19)
- [Doctor profile (D22)](#doctor-profile-d22)
- [Notification preferences (D24, AS12)](#notification-preferences-d24-as12)
- [Assistants (D25, D26)](#assistants-d25-d26)
- [Activity log (D27)](#activity-log-d27)
- [Notifications written](#notifications-written)
- [Audit actions](#audit-actions)
- [Error codes](#error-codes)
- [Decisions where the spec is silent](#decisions-where-the-spec-is-silent)
- [Not built yet](#not-built-yet)

## Who may call what

"Doctor only" endpoints answer an assistant with 403 `PERMISSION_DENIED`, `"permission": "doctorOnly"`, whatever their permissions (BR-AS5). None of these endpoints is blocked while the doctor is suspended (BR-G5): profile, settings, branches, prices and assistants all keep working, for the doctor and for assistants with the permission (BR-G8).

| Endpoint | Doctor | Assistant | Branch check (BR-AS13) |
|---|---|---|---|
| `GET /api/branches`, `GET /api/branches/{branchId}` | ✔ | ✔ any permission | none: every branch is readable |
| `POST /api/branches/createBranch`, `updateBranch`, `setBranchStatus`, `setDefaultBranch` | ✔ | ✘ doctor only | |
| `PUT /api/staff/branches/{branchId}/schedule` (`updateBranchSchedule`, [api-phase-6-schedule.md](api-phase-6-schedule.md)) | ✔ | `scheduleManage` | their branches |
| `GET /api/prices` | ✔ | `pricesManage` | none: every branch is listed |
| `POST /api/prices/updatePrices` | ✔ | `pricesManage` | their branches (doctor-level prices: any) |
| `GET /api/doctor/profile`, `POST /api/doctor/updateProfile` | ✔ | ✘ doctor only | |
| `GET /api/assistants`, `GET /api/assistants/{assistantId}`, `createAssistant`, `updateAssistant`, `resetAssistantPassword`, `setAssistantStatus` | ✔ | ✘ doctor only | |
| `GET /api/clinic/activity` | ✔ | ✘ doctor only | |
| `GET /api/me/notificationPrefs`, `POST /api/me/updateNotificationPrefs` | ✔ | ✔ (their own) | not a clinic endpoint: any signed-in role |

Every clinic endpoint can also answer the checks of [api-phase-2.md](api-phase-2.md#clinic-endpoints-who-may-call-them): 401, 403 `FORBIDDEN` (patient, admin), `DOCTOR_PENDING_APPROVAL`, `DOCTOR_REJECTED`, `ACCOUNT_DISABLED`, `CLINIC_NOT_ACTIVE`, `PERMISSION_DENIED`, `PASSWORD_CHANGE_REQUIRED`. The tables below list only each endpoint's own errors.

- **Branch check:** a branch the assistant isn't assigned to answers 403 `BRANCH_NOT_ALLOWED`. It runs before the branch is looked up, so an assistant of some branches gets `BRANCH_NOT_ALLOWED` for any other branch ID too.
- **Another doctor's record:** a branch or assistant ID of another doctor (or one that doesn't exist) answers 404 `NOT_FOUND`.
- **Validation** (400) runs before the access checks, so a request is checked for its shape first.
- An account with `mustChangePassword` (a new or reset assistant) gets 403 `PASSWORD_CHANGE_REQUIRED` everywhere here until A9.

## Branches (D28, D29, AS17)

Times are Cairo local times, `"HH:mm"`. Weekdays are ISO: **1 = Monday … 6 = Saturday, 7 = Sunday** (the app starts the week on Saturday). Dates are Cairo dates, `YYYY-MM-DD`. A branch's `status` is `active`, `temporarilyClosed` or `archived`. There is no delete: a branch with history is archived (BR-BR9).

### `GET /api/branches` (D28)

Every branch of the doctor: the default first, then oldest first, archived ones last.

```json
{
  "items": [
    {
      "id": "…", "nameAr": "فرع المعادي", "nameEn": null,
      "governorate": "القاهرة", "city": "المعادي", "area": null,
      "status": "active", "closedMessage": null, "reopenDate": null,
      "isDefault": true, "assigned": true,
      "todayPeriods": [
        { "weekday": 7, "startLocal": "10:00", "endLocal": "14:00", "endsNextDay": false, "label": "صباحي", "capacity": 20 },
        { "weekday": 7, "startLocal": "18:00", "endLocal": "01:00", "endsNextDay": true, "label": "مسائي", "capacity": null }
      ],
      "upcomingBookings": 0
    }
  ],
  "count": 2, "limit": 5, "canAdd": true,
  "today": "2026-11-15", "todayWeekday": 7
}
```

- `todayPeriods`: the weekly periods of today's Cairo weekday, earliest first, whatever the branch's status. A period that ends after midnight is listed on the day it starts.
- `upcomingBookings`: bookings from today on that are `pending`, `confirmed`, `checkedIn` or `withDoctor`. Always 0 until bookings come in Phase 6.
- `count` / `limit`: the branches that are **not archived**, and `maxBranchesPerDoctor` ("2 of 5"). `canAdd` is `count < limit`; at the limit, disable "Add branch".
- `assigned`: the caller works there (always `true` for the doctor). It matches `clinic/me`.

### Branch details (D29)

`GET /api/branches/{branchId}` returns this view, and so does every branch write. The groups have the same names as the `updateBranch` groups, so a tab can send back what it shows.

```json
{
  "id": "…", "isDefault": false, "status": "temporarilyClosed",
  "closedMessage": "مغلق للتجديدات", "reopenDate": "2026-11-25", "assigned": true,
  "info": { "nameAr": "فرع الدقي", "nameEn": "Dokki", "description": "عيادة الأطفال بالدور الثاني" },
  "address": {
    "governorate": "الجيزة", "city": "الدقي", "area": "ميدان المساحة",
    "details": "12 شارع التحرير، الدور التاني، شقة 4", "landmark": "بجوار البنك الأهلي",
    "mapUrl": "https://maps.app.goo.gl/AbCd1234XyZ"
  },
  "contact": {
    "phones": [
      { "number": "+20233351234", "label": "landline", "isWhatsapp": false },
      { "number": "+201012345678", "label": "mobile", "isWhatsapp": true }
    ],
    "email": "dokki@clinic.example"
  },
  "workingHours": {
    "bookingMode": "queue", "defaultCapacity": 30,
    "periods": [
      { "weekday": 6, "startLocal": "10:00", "endLocal": "14:00", "endsNextDay": false, "label": "صباحي", "capacity": 25 },
      { "weekday": 6, "startLocal": "20:00", "endLocal": "01:00", "endsNextDay": true, "label": "مسائي", "capacity": null }
    ]
  },
  "clinicInfo": {
    "prices": {
      "examinationPricePiasters": 40000, "consultationPricePiasters": null, "usesDoctorPrices": false,
      "effectiveExaminationPricePiasters": 40000, "effectiveConsultationPricePiasters": 15000
    },
    "paymentMethods": ["cash", "instapay"],
    "amenities": ["elevator"]
  },
  "createdAt": "2026-11-15T10:04:00.000Z", "updatedAt": "2026-11-15T10:04:00.000Z"
}
```

- `workingHours.periods`: by weekday (1–7), then start time. `bookingMode` (`queue` or `timed`) and `defaultCapacity` are read-only here; they change with the booking settings in `updateBranchSchedule`. Show each period's capacity in queue mode, with `defaultCapacity` as the placeholder for `null`.
- `clinicInfo.prices`: see [visit prices](#visit-prices-d37-as19). They are changed with `updatePrices`, not `updateBranch`.
- `paymentMethods`: from `cash`, `card`, `instapay`, `wallet`. `amenities` [S]: from `elevator`, `parking`, `wheelchair`, `kidsArea`. Both come in this order.
- Booking settings, special dates and closures are not in this view: `GET /api/staff/branches/{branchId}/schedule` has them ([api-phase-6-schedule.md](api-phase-6-schedule.md)).
- 404 `NOT_FOUND` for another doctor's branch. An assistant reads every branch of their doctor (AS17 shows Info, Address and Contact read-only).

### Branch groups (createBranch, updateBranch)

The fields and limits are the ones the first branch has at sign-up ([A4](api-phase-1.md#post-apidoctorscompletedoctorregistration-anonymous-rate-limited)). Texts are trimmed; an empty optional text is stored as `null`. Field paths in errors are `info.nameAr`, `contact.phones[0].number` and so on.

| Field | Rule | Error code |
|---|---|---|
| `info` | required on create | `REQUIRED` |
| `info.nameAr` | 2–60 characters | `REQUIRED`, `INVALID_VALUE` |
| `info.nameEn` | optional, ≤ 60 | `TOO_LONG` |
| `info.description` | optional, ≤ 500 | `TOO_LONG` |
| `address` | required on create | `REQUIRED` |
| `address.governorate`, `address.city` | required; ≤ 50, 60 | `REQUIRED`, `TOO_LONG` |
| `address.details` | «العنوان بالتفصيل»: street, building, floor and apartment as one text (new lines allowed); required, ≤ 300 | `REQUIRED`, `TOO_LONG` |
| `address.area`, `address.landmark` | optional; ≤ 60, 150 | `TOO_LONG` |
| `address.mapUrl` | optional «لينك جوجل ماب», ≤ 500: the same rule as sign-up's [`branch.mapUrl`](api-phase-1.md#post-apidoctorscompletedoctorregistration-anonymous-rate-limited) (an `https` or `http` Google Maps link, checked by form only) | `TOO_LONG`, `INVALID_MAP_LINK` («ده مش لينك جوجل ماب») |
| `contact` | required on create | `REQUIRED` |
| `contact.phones` | 1–5 | `PHONE_REQUIRED` («أضف رقم تليفون واحد على الأقل»), `INVALID_VALUE` |
| `contact.phones[i]` | not null | `REQUIRED` |
| `contact.phones[i].number` | Egyptian mobile, landline or hotline; stored in E.164 (hotlines as typed) | `REQUIRED`, `INVALID_PHONE` |
| `contact.phones[i].label` | `reception` (default), `mobile`, `landline` | `INVALID_VALUE` |
| `contact.phones[i].isWhatsapp` | optional, default `false` | |
| `contact.email` | optional email, stored in lower case | `INVALID_EMAIL` |
| `clinicInfo` | optional | |
| `clinicInfo.paymentMethods` | from the list above, each once | `INVALID_VALUE` |
| `clinicInfo.amenities` | from the list above, each once | `INVALID_VALUE` |

A group that is sent **replaces that group whole**: a field left out of it is cleared (for example `info` without `nameEn` clears the English name), and `contact` replaces every phone. `clinicInfo` without `paymentMethods` stores no payment method.

### `POST /api/branches/createBranch` (doctor only)

```json
{
  "info": { "nameAr": "فرع الدقي", "nameEn": "Dokki", "description": null },
  "address": { "governorate": "الجيزة", "city": "الدقي", "details": "12 شارع التحرير", "mapUrl": "https://maps.app.goo.gl/AbCd1234XyZ" },
  "contact": { "phones": [ { "number": "02 3335 1234", "label": "landline", "isWhatsapp": false } ], "email": null },
  "clinicInfo": { "paymentMethods": ["cash", "card"], "amenities": [] }
}
```

**201** with the [branch details](#branch-details-d29). The new branch is `active` and not the default; it needs no admin approval (BR-BR1). Without `clinicInfo`, the payment methods are `["cash"]`. Working hours are set next with `updateBranchSchedule`, and prices with `updatePrices`.

| Errors | |
|---|---|
| 400 | the [group rules](#branch-groups-createbranch-updatebranch) |
| 409 `BRANCH_LIMIT_REACHED` | the doctor already has `maxBranchesPerDoctor` branches that are not archived |

### `POST /api/branches/updateBranch` (doctor only)

`{ "branchId": "…", "info"?: {…}, "address"?: {…}, "contact"?: {…}, "clinicInfo"?: {…} }`: one D29 tab or several. **200** with the branch details. Archived branches can be edited too.

| Errors | |
|---|---|
| 400 | `branchId`: `REQUIRED`; `body`: `REQUIRED` (no group sent); the group rules |
| 404 `NOT_FOUND` | not one of the doctor's branches |

### Working hours (retired `updateBranchHours`)

`POST /api/branches/updateBranchHours` is gone (it applied new hours without looking at bookings, BR-AP12). The D29 Working hours tab and AS17 send the week with `PUT /api/staff/branches/{branchId}/schedule` ([api-phase-6-schedule.md](api-phase-6-schedule.md#working-hours-rules)), which checks the same rules (spec 11: order, length from 15 minutes to 16 hours, overlaps across midnight and the week, at most 10 periods a day) and lists the bookings a change strands before applying it. Its errors are on `weekly[i]`, `weekly[i].end` and so on instead of `periods[i]` and `periods[i].endLocal`; the codes are the same.

### `POST /api/branches/setBranchStatus` (doctor only)

```json
{ "branchId": "…", "status": "temporarilyClosed", "closedMessage": "مغلق للتجديدات", "reopenDate": "2026-11-25" }
```

- `status`: `active`, `temporarilyClosed` or `archived`.
- `temporarilyClosed` needs `closedMessage` (≤ 300, shown to patients on the branch card, BR-BR10). `reopenDate` is optional, today or later. Sending `temporarilyClosed` again updates the message and date.
- `active` and `archived` clear the message and date. Sending the current status changes nothing.
- **200** with the branch details.

Refused (nothing changes):

| Code | When |
|---|---|
| 409 `CANNOT_ARCHIVE_DEFAULT_BRANCH` | archiving the default branch. Choose another default first (`setDefaultBranch`). |
| 409 `LAST_ACTIVE_BRANCH` | closing or archiving the doctor's only active branch (BR-BR1) |
| 409 `BRANCH_HAS_BOOKINGS` | closing or archiving while the branch has bookings from today on (BR-BR9). For a closure with `reopenDate`, only the bookings before that date count. |
| 409 `BRANCH_LIMIT_REACHED` | bringing an archived branch back would go over `maxBranchesPerDoctor` |
| 400 | `branchId`: `REQUIRED`; `status`: `REQUIRED`, `INVALID_VALUE`; `closedMessage`: `REQUIRED`, `TOO_LONG`; `reopenDate`: `OUT_OF_RANGE` (in the past), `INVALID_REQUEST` (not `YYYY-MM-DD`) |
| 404 `NOT_FOUND` | not one of the doctor's branches |

`BRANCH_HAS_BOOKINGS` lists the bookings, earliest first (at most 100; `totalCount` is the full number), so the app can show them with Move / Cancel (Phase 6):

```json
{
  "status": 409, "code": "BRANCH_HAS_BOOKINGS", "title": "Move or cancel this branch's bookings first.",
  "totalCount": 3,
  "bookings": [
    { "id": "…", "localDate": "2026-11-17", "periodStartLocal": "10:00", "startUtc": "2026-11-17T08:00:00.000Z",
      "status": "confirmed", "visitType": "examination", "patientId": null, "name": "ضيف", "isGuest": true },
    { "id": "…", "localDate": "2026-11-20", "periodStartLocal": "10:00", "startUtc": "2026-11-20T08:00:00.000Z",
      "status": "confirmed", "visitType": "consultation", "patientId": "…", "name": "منى حسن", "isGuest": false }
  ]
}
```

`name` is the patient's name in this clinic, or the guest's name. A booking counts when it is `pending`, `confirmed`, `checkedIn` or `withDoctor`.

### `POST /api/branches/setDefaultBranch` (doctor only)

`{ "branchId": "…" }` → **200** with the branch details (`isDefault: true`). The previous default stays as it is, and new sessions default to this branch (BR-BR3). Setting the current default again changes nothing.

| Errors | |
|---|---|
| 400 | `branchId`: `REQUIRED` |
| 404 `NOT_FOUND` | not one of the doctor's branches |
| 409 `BRANCH_NOT_ACTIVE` | the branch is temporarily closed or archived |

The default branch can be temporarily closed (while another branch is active), but never archived.

## Visit prices (D37, AS19)

Section 6.15. These are the clinic's prices for its patients, not the platform fees (`clinic/me` `fees`). Money is integer piasters (100 = 1 EGP); the app takes EGP with up to 2 decimals (0–100,000 EGP).

- **Doctor prices:** `examinationPricePiasters` and `consultationPricePiasters`, each `null` when not set.
- **Branch prices:** each branch's own, each `null` = use the doctor's price for that visit type (BR-PR2). `usesDoctorPrices` is `true` when the branch has neither; D37's "Use the doctor's prices" switch sends both as `null`.
- **Effective prices** (`effective…`): the branch's price, else the doctor's, else `null`. `null` means patients see «يُرجى الاستفسار من العيادة» and a session needs the amount typed (BR-PR6).
- New prices apply to sessions saved afterwards (BR-PR4). Show «تُطبق الأسعار الجديدة على الزيارات القادمة فقط».

### `GET /api/prices` (`pricesManage`)

Query: `page`, `pageSize` (1–100, default 25) for the history. Every branch is listed, for assistants too (`assigned` says which they may change).

```json
{
  "doctor": { "examinationPricePiasters": 30000, "consultationPricePiasters": 15000 },
  "branches": [
    {
      "branchId": "…", "nameAr": "فرع المعادي", "nameEn": null, "status": "active", "isDefault": true, "assigned": true,
      "prices": {
        "examinationPricePiasters": null, "consultationPricePiasters": null, "usesDoctorPrices": true,
        "effectiveExaminationPricePiasters": 30000, "effectiveConsultationPricePiasters": 15000
      }
    }
  ],
  "history": {
    "items": [
      {
        "id": "…", "changedAt": "2026-11-15T10:04:00.000Z",
        "changedBy": { "userId": "…", "name": "منى سمير", "role": "assistant" },
        "branch": { "id": "…", "nameAr": "فرع الدقي", "nameEn": "Dokki" },
        "before": { "examinationPricePiasters": null, "consultationPricePiasters": null },
        "after": { "examinationPricePiasters": 40000, "consultationPricePiasters": null }
      },
      {
        "id": "…", "changedAt": "2026-11-14T09:00:00.000Z",
        "changedBy": { "userId": "…", "name": "أحمد علي", "role": "doctor" },
        "branch": null,
        "before": { "examinationPricePiasters": 25000, "consultationPricePiasters": 15000 },
        "after": { "examinationPricePiasters": 30000, "consultationPricePiasters": 15000 }
      }
    ],
    "page": 1, "pageSize": 25, "totalCount": 2, "totalPages": 1
  }
}
```

History: newest first, the doctor's and every branch's. `branch: null` is the doctor's prices. Errors: 400 `page` / `pageSize` `OUT_OF_RANGE`.

### `POST /api/prices/updatePrices` (`pricesManage`)

```json
{ "branchId": null, "examinationPricePiasters": 30000, "consultationPricePiasters": 15000 }
```

- `branchId` `null` (or absent): the doctor's prices. A branch ID: that branch's prices.
- **Both prices are replaced.** An absent or `null` price is "not set" (doctor) or "use the doctor's" (branch).
- **200** with the same body as `GET /api/prices` (history page 1).
- A change writes a PriceHistory row and a `pricesUpdated` audit row (BR-PR5). Sending the current prices writes neither.
- An assistant may change doctor-level prices, and a branch's prices only for their own branches.

| Errors | |
|---|---|
| 400 | `examinationPricePiasters`, `consultationPricePiasters`: `OUT_OF_RANGE` (0–10,000,000) |
| 403 `BRANCH_NOT_ALLOWED` | an assistant, and not one of their branches |
| 404 `NOT_FOUND` | not one of the doctor's branches |

## Doctor profile (D22)

Personal and professional info. The prescription header and print settings come in Phase 3; clinic and branch details are in Branches. Password: `POST /api/auth/changePassword`.

### `GET /api/doctor/profile` (doctor only)

```json
{
  "doctorId": "…",
  "fullName": "أحمد علي", "fullNameEn": "Ahmed Ali",
  "title": "استشاري", "titleEn": "Consultant",
  "degreesAr": "دكتوراه الباطنة", "degreesEn": null,
  "specialty": { "id": "…", "nameAr": "باطنة", "nameEn": "Internal Medicine" }, "specialtyId": "…",
  "extraSpecialties": [ { "id": "…", "nameAr": "قلب", "nameEn": "Cardiology" } ], "extraSpecialtyIds": ["…"],
  "email": "ahmed@example.com", "emailVerified": true, "phone": "+201012345678",
  "licenseNumber": "45678", "status": "active",
  "updatedAt": "2026-11-15T10:04:00.000Z"
}
```

`email`, `emailVerified`, `phone`, `licenseNumber` and `status` are read-only here. Specialty names come from `GET /api/specialties`.

### `POST /api/doctor/updateProfile` (doctor only)

Send every field (the D22 form). Optional texts are cleared with `null` or `""`.

```json
{
  "fullName": "أحمد علي", "fullNameEn": "Ahmed Ali", "title": "استشاري", "titleEn": "Consultant",
  "degreesAr": "دكتوراه الباطنة", "degreesEn": null,
  "specialtyId": "…", "extraSpecialtyIds": ["…"]
}
```

**200** with the profile. The name also becomes the account's `displayName` (`auth/me`), and `clinic/me` shows the new name and specialty on the next read.

- **Specialty change** (primary or extras): it applies at once, with no review. It writes a `doctorSpecialtyChanged` audit row and notifies every active admin (D22).
- A specialty the admin has since turned off can be kept, but not newly chosen.

| Field | Rule | Error code |
|---|---|---|
| `fullName` | 2–60 letters and spaces, at least 2 words | `REQUIRED`, `INVALID_NAME` |
| `title` | ≤ 40 | `REQUIRED`, `TOO_LONG` |
| `fullNameEn`, `titleEn`, `degreesAr`, `degreesEn` | optional; ≤ 60, 40, 300, 300 | `TOO_LONG` |
| `specialtyId` | an active specialty (or the current one) | `REQUIRED`, `INVALID_SPECIALTY` |
| `extraSpecialtyIds` [S] | up to 2, no repeats, not the primary; active (or already held) | `INVALID_VALUE`, `INVALID_SPECIALTY` |

## Notification preferences (D24, AS12)

The signed-in user's own preferences, any role (an assistant changes their own, never the doctor's). Push delivery uses them from Phase 5. Language and appearance stay in `POST /api/auth/updatePreferences`.

| Method and route | Request | Success |
|---|---|---|
| `GET /api/me/notificationPrefs` | | 200 `{ "chat": true, "reminders": true, "showPreview": false, "bookings": false }` |
| `POST /api/me/updateNotificationPrefs` | Only the fields to change: `{ "showPreview": true }`. `null` or absent keeps the value. | 200, the same shape |

- `chat`: new chat messages (default on).
- `reminders`: billing and appointment reminders (default on).
- `showPreview`: the message text in chat pushes, «إظهار نص الرسالة في الإشعارات» (default off, spec 10.1).
- `bookings`: the doctor's booking alerts (default off, spec 10.1). Show it to doctors only.

## Assistants (D25, D26)

Doctor only, also while suspended. An assistant belongs to one doctor (BR-AS3). Their permissions and branches are read from the database on each of their requests (BR-AS4), so every change here applies on their next request, without signing in again.

### Assistant object

Returned by every assistant endpoint.

```json
{
  "userId": "…", "fullName": "سارة محمود", "phone": "+201012345678",
  "preset": "reception", "status": "active",
  "allBranches": false,
  "branches": [ { "id": "…", "nameAr": "فرع المعادي", "nameEn": null, "status": "active" } ],
  "branchIds": ["…"],
  "permissions": {
    "patientsManage": true, "patientsResetPassword": true, "sessionsCreate": true, "sessionsDelete": false,
    "clinicalView": false, "clinicalEditProfile": false, "filesManage": true, "prescriptionsPrint": true,
    "prescriptionsDraft": false, "chat": false, "billingView": false, "billingPay": false,
    "appointmentsView": true, "appointmentsManage": true, "scheduleManage": false, "revenueView": false,
    "pricesManage": false
  },
  "mustChangePassword": true,
  "lastActiveAt": null, "createdAt": "2026-11-15T10:04:00.000Z", "updatedAt": "2026-11-15T10:04:00.000Z", "removedAt": null
}
```

- `preset`: `reception`, `clinical`, `officeManager` or `custom` (D25 shows it). The server works it out from the permissions: the preset whose permissions match exactly, else `custom`.
- `status`: `active`, `disabled` or `removed`.
- `branches` and `branchIds` are empty when `allBranches` is `true`.
- `permissions`: every key of spec 6.10, the same map as `clinic/me`. Presets and dependencies are listed in [api-phase-2.md](api-phase-2.md#clinic-endpoints-who-may-call-them).
- `mustChangePassword`: they haven't replaced the temporary password yet.
- `lastActiveAt`: their last clinic request, to within 5 minutes; `null` if never.

### `GET /api/assistants` and `GET /api/assistants/{assistantId}`

The list: oldest first. Removed assistants are left out unless `?includeRemoved=true` (then they come last).

```json
{ "items": [ { "userId": "…", "fullName": "سارة محمود", "…": "…" } ], "count": 2, "limit": 5, "canAdd": true }
```

`count` is the **active and disabled** assistants, which is what `limit` (`maxAssistantsPerDoctor`) counts; removed ones don't. At the limit (`canAdd: false`), disable "Add assistant" and show «وصلت للحد الأقصى لعدد المساعدين».

`GET /api/assistants/{assistantId}`: one assistant (D26 edit), removed ones too. 404 for another doctor's assistant.

### `POST /api/assistants/createAssistant`

```json
{
  "fullName": "سارة محمود", "phone": "01012345678",
  "allBranches": false, "branchIds": ["…"],
  "permissions": { "patientsManage": true, "sessionsCreate": true, "appointmentsManage": true }
}
```

- `permissions`: a map of keys to `true` / `false`; a missing key is off. D26's preset picker fills the checkboxes in the app; send the resulting map.
- Dependencies are switched on by the server (`appointmentsManage` → `appointmentsView`), and the preset is worked out from the result.
- `allBranches: true`, or one or more of the doctor's non-archived `branchIds`.

**201** with `Cache-Control: no-store`:

```json
{ "assistant": { "userId": "…", "mustChangePassword": true, "…": "…" }, "temporaryPassword": "a7Kq9mPz" }
```

The 8-character temporary password is shown **once** (BR-AS2), with WhatsApp / SMS / Copy; it is never stored in clear. The assistant signs in with their mobile and goes to A9 to set their own password.

- The number can already be a **patient** account: A3 then offers "log in as" when the passwords match.
- It can't be an assistant of any doctor, this one or another (BR-AS3).

| Field | Rule | Error code |
|---|---|---|
| `fullName` | 2–60 letters and spaces, at least 2 words | `REQUIRED`, `INVALID_NAME` |
| `phone` | Egyptian mobile, stored in E.164 | `REQUIRED`, `INVALID_MOBILE` |
| `branchIds` | required unless `allBranches` is `true`; each once, at most 50; the doctor's, not archived | `REQUIRED`, `INVALID_VALUE`, `INVALID_BRANCH` |
| `permissions` | required (may be all off); known keys only | `REQUIRED`, `INVALID_VALUE` |

Other errors: 409 `ASSISTANT_LIMIT_REACHED` («وصلت للحد الأقصى لعدد المساعدين»), 409 `ASSISTANT_PHONE_TAKEN`.

### `POST /api/assistants/updateAssistant`

Only the parts sent change:

```json
{ "assistantId": "…", "fullName": "سارة محمود علي", "phone": "01012345679", "branchIds": ["…", "…"], "permissions": { "…": true } }
```

- `fullName`: also their `displayName`.
- `phone`: they sign in with the new number from now on.
- Branches: send `allBranches: true`, or `branchIds` (with or without `allBranches: false`).
- `permissions`: the whole map, as in create. A change writes an `assistantPermissionsChanged` audit row (D27 "permission changed"). It applies on the assistant's next request; their app re-reads `clinic/me` after a `PERMISSION_DENIED`.
- **200** with the assistant object.

| Errors | |
|---|---|
| 400 | `assistantId`: `REQUIRED`; `fullName`: `INVALID_NAME`; `phone`: `INVALID_MOBILE`; `branchIds`: `REQUIRED` (with `allBranches: false`), `INVALID_VALUE`, `INVALID_BRANCH`; `permissions`: `INVALID_VALUE` |
| 404 `NOT_FOUND` | not one of the doctor's assistants |
| 409 `ASSISTANT_PHONE_TAKEN` | the new number is another assistant's |
| 409 `ASSISTANT_REMOVED` | the assistant was removed |

### `POST /api/assistants/resetAssistantPassword`

`{ "assistantId": "…" }` → **200**, `Cache-Control: no-store`: `{ "assistant": {…}, "temporaryPassword": "…" }`.

The answer to an assistant's A8 request (BR-AS11): a new 8-character temporary password, shown once, and `mustChangePassword`. Any lockout is cleared. The assistant is signed out on every device: their current access token answers 401 `SESSION_REVOKED` and their refresh token stops working. A disabled assistant's password can be reset too.

Errors: 400 `assistantId`: `REQUIRED`; 404; 409 `ASSISTANT_REMOVED`.

### `POST /api/assistants/setAssistantStatus`

`{ "assistantId": "…", "status": "disabled" }` → **200** with the assistant object. `status`: `active` (enable), `disabled` or `removed` (BR-AS8). Sending the current status changes nothing.

- **Disable** and **remove** revoke every refresh token and remove the assistant's push devices at once. Their next request with a still-valid access token answers **403 `ACCOUNT_DISABLED`**, so their app clears the session and shows A10 (AC-19). Signing in again answers the same (disabled) or 401 `INVALID_CREDENTIALS` (removed).
- **Enable:** they sign in again.
- **Remove** is soft and final. Their history stays in the activity log, they are left out of the list (unless `includeRemoved=true`), and they no longer count toward the limit. Their number is free: add them again as a new assistant if needed. A removed assistant can't be enabled, edited or reset.

Errors: 400 `assistantId`: `REQUIRED`, `status`: `REQUIRED` / `INVALID_VALUE`; 404; 409 `ASSISTANT_REMOVED`.

## Activity log (D27)

### `GET /api/clinic/activity` (doctor only)

Everything done in the clinic by the doctor and the assistants (BR-AS10), newest first, paged. Rows that admins wrote about the doctor (sign-up review, license views) are not shown; they are in the admin audit (AD15).

Query, all optional:

| Parameter | Meaning |
|---|---|
| `actorUserId` | the doctor or one assistant (from `people`) |
| `action` | one action (from `actions`) |
| `patientId` | one patient |
| `from`, `to` | Cairo dates `YYYY-MM-DD`, both included |
| `page`, `pageSize` | 1–100, default 25 |

```json
{
  "items": [
    {
      "id": 812, "at": "2026-11-15T10:04:00.000Z",
      "actor": { "userId": "…", "name": "سارة محمود", "role": "assistant" },
      "action": "patientCreated", "targetType": "patient", "targetId": "…",
      "patient": { "id": "…", "name": "منى حسن", "fileNumber": 17 },
      "details": { "fileNumber": 17 }
    },
    {
      "id": 811, "at": "2026-11-15T09:58:00.000Z",
      "actor": { "userId": "…", "name": "أحمد علي", "role": "doctor" },
      "action": "branchScheduleUpdated", "targetType": "branch", "targetId": "…",
      "patient": null,
      "details": { "periods": 3, "overrides": 0, "closures": 1, "mode": "queue", "kept": 0, "moved": 1, "cancelled": 0 }
    }
  ],
  "page": 1, "pageSize": 25, "totalCount": 2, "totalPages": 1,
  "people": [
    { "userId": "…", "name": "أحمد علي", "role": "doctor", "status": null },
    { "userId": "…", "name": "سارة محمود", "role": "assistant", "status": "active" },
    { "userId": "…", "name": "منى سمير", "role": "assistant", "status": "removed" }
  ],
  "actions": ["branchScheduleUpdated", "patientCreated", "pricesUpdated"]
}
```

- `actor.role`: `doctor`, `assistant` or `system` (for example an assistant's A8 request, `passwordResetRequested`). A system row has no `userId` or `name`.
- `actor.name` is the person's current name.
- `patient`: the patient the action was about, with their name and file number in this clinic (`name` and `fileNumber` are `null` if they are no longer linked). `null` when there is none.
- `details`: action-specific IDs and values (below and in [api-phase-2-patients.md](api-phase-2-patients.md)), never medical text.
- `people`: the doctor, then every assistant the clinic ever had, removed ones last, for the person filter.
- `actions`: every action in this clinic's log, for the action filter. The app maps each action to an ARB label and shows the raw name for any it doesn't know yet.
- Tap opens the related item from `targetType` and `targetId` (or `patient.id`).

Errors: 400 `from`, `to`: `INVALID_VALUE` (not `YYYY-MM-DD`, or `to` before `from`); `action`: `TOO_LONG`; `page`, `pageSize`: `OUT_OF_RANGE`; `INVALID_REQUEST` when `actorUserId` or `patientId` isn't a GUID.

## Notifications written

| `type` | Recipient | Title (AR / EN) | Body | `route` | `data` |
|---|---|---|---|---|---|
| `doctorSpecialtyChanged` | every active admin | تغيير تخصص طبيب / A doctor changed their specialty | `د. {name}: {old specialties} ← {new specialties}` (primary first, then extras) | `/admin/doctors/{doctorId}` | `{ doctorId }` |

## Audit actions

Every write below adds one row in the clinic's log (`doctorId` = the clinic, the actor = the doctor or assistant), in the same transaction as the change.

| Action | Target | Details |
|---|---|---|
| `branchCreated` | `branch` | `nameAr` |
| `branchUpdated` | `branch` | `groups`: the groups sent (`info`, `address`, `contact`, `clinicInfo`) |
| `branchScheduleUpdated` | `branch` | `updateBranchSchedule` ([api-phase-6-schedule.md](api-phase-6-schedule.md)): `periods`, `overrides`, `closures` (how many), `mode`, and the affected bookings `kept`, `moved`, `cancelled` |
| `branchHoursUpdated` | `branch` | `periods`: how many. Written by the retired `updateBranchHours`; old rows still show in D27 |
| `branchStatusChanged` | `branch` | `before`, `after`, `reopenDate` |
| `defaultBranchChanged` | `branch` (the new default) | `before`, `after` (branch IDs) |
| `pricesUpdated` | `doctor` (doctor prices) or `branch` | `branchId`, `before`, `after` (`{ examinationPricePiasters, consultationPricePiasters }`) |
| `doctorProfileUpdated` | `doctor` | `fields`: the fields that changed |
| `doctorSpecialtyChanged` | `doctor` | `before`, `after`: `{ specialtyId, extraSpecialtyIds }` |
| `assistantCreated` | `assistant` | `preset`, `allBranches`, `branchIds`, `permissions` (keys on) |
| `assistantUpdated` | `assistant` | `fields`: `fullName`, `phone`, `branches` |
| `assistantPermissionsChanged` | `assistant` | `added`, `removed` (keys), `presetBefore`, `presetAfter` |
| `assistantPasswordReset` | `assistant` | |
| `assistantDisabled`, `assistantEnabled`, `assistantRemoved` | `assistant` | |

The `assistant` target ID is the assistant's user ID. Notification preferences are personal settings and are not audited.

## Error codes

New in this part of Phase 2. The other codes are in [api-phase-1.md](api-phase-1.md#error-codes) and [api-phase-2.md](api-phase-2.md#clinic-endpoints-who-may-call-them).

| Code | HTTP | Meaning |
|---|---|---|
| `BRANCH_LIMIT_REACHED` | 409 | The clinic has `maxBranchesPerDoctor` branches that are not archived |
| `CANNOT_ARCHIVE_DEFAULT_BRANCH` | 409 | Choose another default branch first |
| `LAST_ACTIVE_BRANCH` | 409 | The clinic needs at least one active branch |
| `BRANCH_HAS_BOOKINGS` | 409 | Move or cancel the listed bookings first (`bookings`, `totalCount`) |
| `BRANCH_NOT_ACTIVE` | 409 | Only an active branch can be the default |
| `ASSISTANT_LIMIT_REACHED` | 409 | «وصلت للحد الأقصى لعدد المساعدين» |
| `ASSISTANT_PHONE_TAKEN` | 409 | This number is already an assistant (of this or another clinic) |
| `ASSISTANT_REMOVED` | 409 | The assistant was removed; add them again as a new assistant |
| `INVALID_BRANCH` | field | Not one of the clinic's branches, or archived |
| `PERIOD_END_BEFORE_START` | field | The period ends before it starts; mark it as ending the next day |
| `PERIOD_LENGTH_OUT_OF_RANGE` | field | A period lasts 15 minutes to 16 hours |
| `PERIODS_OVERLAP` | field | «الفترات متداخلة» |

Also used here: `BRANCH_NOT_ALLOWED`, `PERMISSION_DENIED` (api-phase-2), and `REQUIRED`, `TOO_LONG`, `OUT_OF_RANGE`, `INVALID_VALUE`, `INVALID_NAME`, `INVALID_MOBILE`, `INVALID_PHONE`, `PHONE_REQUIRED`, `INVALID_MAP_LINK`, `INVALID_EMAIL`, `INVALID_SPECIALTY`, `NOT_FOUND` (api-phase-1).

## Decisions where the spec is silent

- **Branch limit:** archived branches don't count toward `maxBranchesPerDoctor`, since a branch can't be deleted. Bringing one back checks the limit.
- **Last active branch:** closing or archiving the only active branch is refused (BR-BR1). A doctor with one branch uses closures (D29 Special dates) for a holiday.
- **Default branch:** it can be temporarily closed while another branch is active, but never archived. Only an active branch can become the default.
- **Bookings that block a closure (BR-BR9):** pending, confirmed, checked-in and with-the-doctor bookings from today (Cairo) on. With a reopening date, only those before it.
- **Hours:** overlaps are checked across midnight and from Sunday into Monday. At most 10 periods a day.
- **Branch prices fall back per visit type:** a branch with only an examination price uses the doctor's consultation price.
- **Assistant limit:** active and disabled assistants count; removed ones don't.
- **Removed assistants are final:** they can't be enabled again, and their number is free for a new assistant (UQ_Assistants_Phone covers active and disabled only). A new account keeps the old one's history apart.
- **Disable and remove** revoke refresh tokens but keep the security stamp, so the next request says `ACCOUNT_DISABLED` (A10) rather than `SESSION_REVOKED` (which would send the assistant to A3 without a reason). A reset password does change the stamp.
- **Permissions** are sent as a map (the same shape as answers and `clinic/me`), not as a preset name.
- **Assistant branches** must be non-archived branches of the doctor.
- **Notification preferences** are open to every signed-in role, since patients and admins have the same columns (spec 9.4: a patient writes "their own preferences").
- **Activity log** leaves out admin rows about the doctor, and lists `people` and `actions` for the filters in the same answer.
- **Profile:** a specialty the admin turned off can be kept but not chosen again.

## Not built yet

- Branch photos [S] (BranchPhotos, up to 5).
- The admin's side of `setAssistantStatus` (AD5, with the admin doctor screens).
