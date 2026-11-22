# el3yada API: Phase 1 contract (sign-in and admin basics)

This is what the Flutter app builds against for Phase 1 (A1–A14, AD2, AD3, AD13–AD15, AD18). Endpoint names follow [spec section 9.1](../../spec.md). The code is the source of truth. When this page and the code differ, fix this page.

- [Conventions](#conventions)
- [Errors](#errors)
- [Tokens: refresh on 401](#tokens-refresh-on-401)
- [Splash routing (A1)](#splash-routing-a1)
- [Same number, two accounts (A3)](#same-number-two-accounts-a3)
- Endpoints: [auth](#auth), [doctor registration](#doctor-registration-a4-a7), [public](#public), [admin](#admin)
- [Notifications written in Phase 1](#notifications-written-in-phase-1)
- [Audit actions](#audit-actions)
- [Error codes](#error-codes)

## Conventions

| Topic | Rule |
|---|---|
| Base URL | Development: `https://localhost:7001`. **Every route starts with `/api/`**: `API_BASE_URL` + `/api/auth/login`. |
| JSON | camelCase, UTF-8. Unknown fields in requests are ignored. Absent and `null` are the same for optional fields. |
| Times | UTC, ISO 8601 with milliseconds and `Z`: `2026-11-15T10:04:00.000Z`. Times sent with an offset are converted to UTC. |
| Money | Integer piasters (100 = 1 EGP). The admin types EGP with up to 2 decimals and the app converts it. |
| Phones | The API accepts `01XXXXXXXXX`, `+201XXXXXXXXX`, `00201XXXXXXXXX`, `201XXXXXXXXX`, with spaces, dashes, brackets and Arabic-Indic digits. It answers in E.164: `+201XXXXXXXXX`. Branch and support phones can also be landlines (`02 2358 1234` → `+20223581234`) or 5-digit hotlines (`19xxx`). |
| Emails | Trimmed and stored in lower case. |
| Passwords | At least 8 characters, a letter and a number, at most 128 characters. Arabic-Indic digits count as 0–9 everywhere, so `كلمة١٢٣٤٥٦٧٨` and `كلمة12345678` are the same password. |
| Auth header | `Authorization: Bearer <accessToken>`. Every endpoint needs it unless this page says **anonymous**. Unknown routes also answer 401 to anonymous callers. |
| Paging | `?page=1&pageSize=25` (page ≥ 1, pageSize 1–100). The answer is `{ "items": [...], "page": 1, "pageSize": 25, "totalCount": 73, "totalPages": 3 }`. |
| Files | Never public URLs. Downloads stream through the API after the access check (`Cache-Control: no-store`). |

## Errors

Every error is `application/problem+json` with a stable top-level `code`. The app maps the code to an ARB message; the English `title` is for logs only.

```json
{ "type": "…", "title": "Wrong identifier or password.", "status": 401, "code": "INVALID_CREDENTIALS", "traceId": "00-…" }
```

A validation error (400) has `code: "VALIDATION_FAILED"`, plus `errors` (English messages) and `errorCodes` (codes) per field. Field names are JSON paths: `branch.phones[0].number`. Each field gets one error, its first failing rule.

```json
{
  "status": 400, "code": "VALIDATION_FAILED",
  "errors": { "phone": ["Enter a valid Egyptian mobile number."], "branch.phones": ["Add at least one phone number."] },
  "errorCodes": { "phone": ["INVALID_MOBILE"], "branch.phones": ["PHONE_REQUIRED"] }
}
```

A body that isn't JSON, or has the wrong types, gets the same shape with `code: "INVALID_REQUEST"` (field `body` when the whole body is unreadable).

**Rate limits** (429 `TOO_MANY_ATTEMPTS`, with a `Retry-After` header in seconds): login and selectAccount 10 per minute per IP; forgot password 5 per 15 minutes per IP and 3 per hour per email or number; registration 10 per hour per IP; refresh and logout 60 per minute per IP; resetPassword and verifyEmail 20 per 15 minutes per IP. Five wrong passwords in a row lock the account for 15 minutes. Unknown identifiers lock the same way, so a lock never shows whether an account exists. All of these are settings (`RateLimits`, `Auth` in [README](../README.md)).

## Tokens: refresh on 401

| Token | Lifetime | Notes |
|---|---|---|
| `accessToken` | 15 minutes | JWT. The app treats it as opaque. Claims: `sub`, `role`, `adminRole`, `doctorId`, `sid` (session), `sst` (security stamp hash). |
| `refreshToken` | 30 days, **sliding**: each refresh gives a fresh 30 days | 43 random characters. Single use: every refresh returns a new one. |

The API checks the account in the database on every request, with a 30-second cache that this API instance clears on every change. So a password change, a disabled account or a role change takes effect on the next request.

**In `AuthInterceptor`:**

1. Send `Authorization: Bearer <accessToken>`.
2. On **401** from any endpoint except `login`, `selectAccount`, `refresh` and `logout` (codes `TOKEN_EXPIRED`, `TOKEN_OUTDATED`, `SESSION_REVOKED`, `UNAUTHENTICATED`), call `POST /api/auth/refresh` **once**, save the whole new session (both tokens), and retry the request once.
3. **Single flight:** if several requests get 401 together, run one refresh and make the others wait for it. Sending the same refresh token twice counts as theft: the API revokes the session and answers `REFRESH_TOKEN_REUSED`.
4. If refresh answers **401** (`REFRESH_TOKEN_INVALID`, `REFRESH_TOKEN_REUSED`), clear the saved session and go to A3.
5. If refresh (or any request) answers **403 `ACCOUNT_DISABLED`**, clear the session and show A10. For **403 `CLINIC_NOT_ACTIVE`**, show A10 with «حساب العيادة غير مفعّل، تواصل مع الطبيب».
6. **403 `PASSWORD_CHANGE_REQUIRED`** means: go to A9.
7. Other 403 codes (`FORBIDDEN`) are normal permission errors. Don't refresh for them.

You can also refresh shortly before `accessTokenExpiresAt` to avoid the 401 round trip.

## Splash routing (A1)

1. `GET /api/settings/public` (anonymous):
   - If `minAppVersion[platform]` is higher than the app's version, show **A11**.
   - If `maintenance.enabled`, show **A13** with `messageAr` or `messageEn`. The API doesn't block requests during maintenance; the app does.
2. No saved session: **A2** on first launch, then **A3**.
3. Saved session: call `GET /api/auth/me`, refreshing on 401 as above. A saved **patient** session on Windows or macOS is discarded (call `logout`), and the app shows **A14**.
4. Then route on the session fields, in this order:

| Field | Value | Screen |
|---|---|---|
| `mustChangePassword` | `true` | **A9** (with the terms checkbox when `mustAcceptTerms`) |
| `pendingDeletion` | not `null` | **A16**, the restore screen (any role; [api-account-deletion.md](api-account-deletion.md)) |
| `role` = `doctor`, `doctorStatus` | `pendingApproval` | **A6** (data from `GET /api/doctors/myRegistration`) |
| | `rejected` | **A7**, showing `doctorStatusReason` |
| | `suspended` | Doctor home with the suspension banner (Phase 7 rules) |
| | `active` | Doctor home |
| `role` = `assistant`, `doctorStatus` | `active` / `suspended` | Assistant home (banner when suspended). Any other clinic status never arrives: it is 403 `CLINIC_NOT_ACTIVE` (A10). |
| `role` = `patient` | | Patient home (mobile only) |
| `role` = `admin`, `adminRole` | `superAdmin` / `admin` | Admin home. AD14 only for `superAdmin`. |
| `emailVerified` | `false` | Optional A5 banner. It doesn't block anything in Phase 1. |

`accountStatus` is `active` in a session, or `pendingDeletion` during a deletion's grace period (A16): a disabled account gets 403 `ACCOUNT_DISABLED` instead (A10). A doctor whose account the admin disabled (`doctorStatus = disabled`) is also refused with `ACCOUNT_DISABLED`.

## Same number, two accounts (A3)

One mobile number can be a patient account and an assistant account at the same time. `login` checks the password against both:

- **Neither matches:** 401 `INVALID_CREDENTIALS`, the same answer as an unknown number.
- **One matches:** that account signs in (`result: "signedIn"`).
- **Both match:** `result: "chooseAccount"`. The app asks «الدخول كـ: مريض / مساعد طبيب», then sends the choice:

```http
POST /api/auth/login
{ "identifier": "01012345678", "password": "…" }

200 { "result": "chooseAccount",
      "selectionToken": "eyJ…", "selectionTokenExpiresAt": "2026-11-15T10:09:00.000Z",
      "accounts": [ { "role": "patient", "displayName": "منى حسن", "doctorName": null },
                    { "role": "assistant", "displayName": "منى حسن", "doctorName": "أحمد علي" } ] }

POST /api/auth/selectAccount
{ "selectionToken": "eyJ…", "role": "assistant", "device": { … } }

200 { "result": "signedIn", … }
```

The selection token lasts 5 minutes, works once, and stops working if either password changes (401 `SELECTION_TOKEN_INVALID`: sign in again). Nothing about the accounts is revealed before a password matches. On Windows or macOS the patient account is left out, so the assistant signs in directly.

## Auth

`device` is optional in every sign-in call. Send it so the session is tied to the device, the push token is registered, and the A14 check runs on the server:

```json
"device": { "deviceId": "stable per-install id, ≤ 100 ASCII", "platform": "android|ios|windows|macos", "appVersion": "1.0.0", "pushToken": "FCM token or null (Windows)" }
```

### Session object

Returned by `GET /api/auth/me` and `updatePreferences`. Every sign-in call returns it with `result` and the tokens added (`SignedInResponse`). It is a superset of the app's `AuthSession`.

```json
{
  "result": "signedIn",
  "userId": "8c1f…", "displayName": "د. أحمد علي", "role": "doctor", "adminRole": null,
  "doctorId": "8c1f…",
  "accountStatus": "active",
  "doctorStatus": "pendingApproval", "doctorStatusReason": null,
  "trial": null,
  "mustChangePassword": false, "mustAcceptTerms": false,
  "email": "ahmed@example.com", "emailVerified": false, "phone": "+201012345678",
  "locale": "ar", "themeMode": "system",
  "accessToken": "eyJ…", "accessTokenExpiresAt": "2026-11-15T10:19:00.000Z",
  "refreshToken": "q3V…", "refreshTokenExpiresAt": "2026-12-15T10:04:00.000Z"
}
```

`accountStatus` is `pendingDeletion` during an account's deletion grace period, and `pendingDeletion` then describes it (otherwise `null`): that session may only restore, sign out, read its own state and, for a doctor, pay invoices. See [api-account-deletion.md](api-account-deletion.md). `doctorId` is the doctor's own ID for a doctor and their doctor's ID for an assistant. `doctorStatusReason` is sent only to the doctor. `emailVerified` is `true` when the account has no email. `trial` is the clinic's free trial (`{ endsAt, ended, daysLeft }`, or `null` when there is none): see [api-free-trial.md](api-free-trial.md). `trial.ended` routes to A15.

| Method and route | Auth | Request | Success | Errors |
|---|---|---|---|---|
| `POST /api/auth/login` | anonymous | `{ identifier, password, device? }` | 200 session, or 200 `chooseAccount` | 400 (`identifier`: `REQUIRED`, `INVALID_IDENTIFIER`; `password`: `REQUIRED`, `TOO_LONG`; `device.*`), 401 `INVALID_CREDENTIALS`, 403 `ACCOUNT_DISABLED` / `CLINIC_NOT_ACTIVE` / `PATIENT_DESKTOP_NOT_SUPPORTED`, 429 |
| `POST /api/auth/selectAccount` | anonymous | `{ selectionToken, role: "patient"\|"assistant", device? }` | 200 session | 400, 401 `SELECTION_TOKEN_INVALID`, 403 as login, 429 |
| `POST /api/auth/refresh` | anonymous | `{ refreshToken }` | 200 session (new tokens) | 401 `REFRESH_TOKEN_INVALID` / `REFRESH_TOKEN_REUSED`, 403 `ACCOUNT_DISABLED` / `CLINIC_NOT_ACTIVE`, 429 |
| `POST /api/auth/logout` | anonymous | `{ refreshToken, deviceId?, pushToken? }` | 204, also for an unknown token | 400 |
| `GET /api/auth/me` | any role, also while `mustChangePassword` | | 200 session (no tokens) | 401, 403 |
| `POST /api/auth/updatePreferences` | any role | `{ locale?: "ar"\|"en", themeMode?: "system"\|"light"\|"dark" }` | 200 session | 400 `INVALID_VALUE` |
| `POST /api/auth/setNewPassword` (A9) | any role with `mustChangePassword` | `{ newPassword, acceptTerms?, device? }`. `acceptTerms: true` is required when `mustAcceptTerms`. | 200 session (new tokens) | 400 `newPassword`: `WEAK_PASSWORD` / `PASSWORD_SAME_AS_OLD`, `acceptTerms`: `TERMS_NOT_ACCEPTED`; 409 `PASSWORD_CHANGE_NOT_REQUIRED` |
| `POST /api/auth/changePassword` (D22, P14, AS12, AD18) | any role | `{ currentPassword, newPassword, device? }` | 200 session (new tokens) | 400 `currentPassword`: `CURRENT_PASSWORD_INCORRECT`, `newPassword`: `WEAK_PASSWORD` / `PASSWORD_SAME_AS_OLD`; 429 |
| `POST /api/auth/requestPasswordResetEmail` (A8, doctors and admins) | anonymous | `{ email }` | 202 `{ "status": "requested" }`, whether or not the email exists | 400 `INVALID_EMAIL`, 429 |
| `POST /api/auth/requestPatientPasswordReset` (A8, patients and assistants) | anonymous | `{ phone }` | 202 `{ "status": "requested" }`, whether or not the number exists | 400 `INVALID_MOBILE`, 429 |
| `POST /api/auth/resetPassword` | anonymous | `{ token, newPassword }` | 200 `{ "status": "passwordReset" }`. Then sign in. | 400 `EMAIL_TOKEN_INVALID` / `EMAIL_TOKEN_EXPIRED` / `EMAIL_TOKEN_USED`, `newPassword`: `WEAK_PASSWORD`; 429 |
| `POST /api/auth/verifyEmail` (A5) | anonymous | `{ token }` | 200 `{ "status": "emailVerified" }` | 400 `EMAIL_TOKEN_*`, 429 |
| `POST /api/auth/resendVerificationEmail` (A5) | any role with an email | | 202 `{ "status": "sent" }` | 409 `EMAIL_ALREADY_VERIFIED`, 429 `VERIFICATION_EMAIL_COOLDOWN` (60 s), 400 `INVALID_REQUEST` (no email) |

Notes:

- **A password change signs out every other device.** `setNewPassword`, `changePassword` and `resetPassword` set a new security stamp and revoke every refresh token. `setNewPassword` and `changePassword` return a fresh session for the device that made the change, so save it. `resetPassword` signs out everywhere.
- **Logout** revokes the session and deletes the `UserDevices` row of `deviceId`, or of the device the session was signed in from. It also deletes any row with `pushToken`. A push token belongs to one account: when another account signs in on the same device with the same token, the token moves to it.
- **Reset email:** the link is `Email:ResetPasswordUrl?token=…` (dev: `https://localhost:7001/reset-password?token=…`). The token is valid for 60 minutes and works once, and a newer email replaces the older link. The email also shows the token as a code, for desktop users whose link opens a browser: A8 can offer "paste the code", then call `resetPassword`. Only active doctor and admin accounts get the email.
- **Mobile reset:** the API writes notification rows for every doctor linked to the patient (active or suspended), plus each of their active assistants with `patientsResetPassword`. For an assistant's number, it writes one for their doctor. Push delivery comes in Phase 5.
- **Verification link:** `Email:VerifyEmailUrl?token=…`, valid 48 hours, sent at registration and when a resubmission changes the email. Following a reset link also counts as verifying the email.

## Doctor registration (A4–A7)

### `POST /api/doctors/completeDoctorRegistration` (anonymous, rate-limited)

`multipart/form-data` with two parts:

| Part | Content |
|---|---|
| `data` | A JSON string (below). |
| `license` | One file: JPEG, PNG, WebP or PDF, at most 10 MB. The type is read from the file's bytes, so the part's Content-Type doesn't matter. |

```json
{
  "fullName": "سامي عبد الله", "email": "sami@example.com", "phone": "010 1234 5678",
  "password": "Doctor123", "locale": "ar",
  "title": "استشاري", "specialtyId": "…", "extraSpecialtyIds": ["…"], "licenseNumber": "45678",
  "fullNameEn": null, "titleEn": null, "degreesAr": null, "degreesEn": null,
  "examinationPricePiasters": 30000, "consultationPricePiasters": 15000,
  "branch": {
    "nameAr": "فرع المعادي", "nameEn": null, "governorate": "القاهرة", "city": "المعادي", "area": null,
    "addressDetails": "12 شارع 9، عمارة النور، الدور التالت، شقة 5", "landmark": "بجوار المترو",
    "mapUrl": "https://maps.app.goo.gl/AbCd1234XyZ", "email": null,
    "phones": [ { "number": "02 2358 1234", "label": "landline", "isWhatsapp": false } ]
  },
  "acceptTerms": true,
  "device": { "deviceId": "…", "platform": "android", "appVersion": "1.0.0", "pushToken": null }
}
```

| Field | Rule (spec section 11) | Error code |
|---|---|---|
| `fullName` | 2–60 letters and spaces, at least 2 words | `REQUIRED`, `INVALID_NAME` |
| `email` | email, ≤ 254 | `REQUIRED`, `INVALID_EMAIL`; 409 `EMAIL_ALREADY_REGISTERED` |
| `phone` | Egyptian mobile | `REQUIRED`, `INVALID_MOBILE` |
| `password` | policy | `REQUIRED`, `WEAK_PASSWORD` |
| `locale` | `ar` (default) or `en` | `INVALID_VALUE` |
| `title` | ≤ 40 (أخصائي / استشاري / أستاذ …) | `REQUIRED`, `TOO_LONG` |
| `specialtyId` | an active specialty from `GET /api/specialties` | `REQUIRED`, `INVALID_SPECIALTY` |
| `extraSpecialtyIds` [S] | up to 2, no repeats, not the primary, active | `INVALID_VALUE`, `INVALID_SPECIALTY` |
| `licenseNumber` (syndicate number) | 3–20 letters, digits, `-` or `/`; Arabic digits become 0–9 | `REQUIRED`, `INVALID_LICENSE_NUMBER` |
| `fullNameEn`, `titleEn`, `degreesAr`, `degreesEn` | optional; ≤ 60, 40, 300, 300 | `TOO_LONG` |
| `examinationPricePiasters`, `consultationPricePiasters` | optional, 0–10,000,000 (100,000 EGP). Saved as the **doctor's** visit prices (6.15), which every branch without its own prices uses. | `OUT_OF_RANGE` |
| `branch` | required | `REQUIRED` |
| `branch.nameAr` | 2–60 | `REQUIRED`, `INVALID_VALUE` |
| `branch.governorate`, `branch.city` | required; ≤ 50, 60 | `REQUIRED`, `TOO_LONG` |
| `branch.addressDetails` | «العنوان بالتفصيل»: street, building, floor and apartment as one text (new lines allowed); required, ≤ 300, trimmed | `REQUIRED`, `TOO_LONG` |
| `branch.area`, `branch.landmark` | optional; ≤ 60, 150 | `TOO_LONG` |
| `branch.mapUrl` | optional «لينك جوجل ماب», ≤ 500. An `https` or `http` link to `maps.app.goo.gl/…`, `goo.gl/maps/…`, `maps.google.<tld>/…` or `(www.)google.<tld>/maps…` (`.com`, `.com.eg`, `.co.uk` …); only the form is checked, Google is never called. Text around the link is refused, so the app keeps just the link from a pasted share text. | `TOO_LONG`, `INVALID_MAP_LINK` |
| `branch.email` | optional email | `INVALID_EMAIL` |
| `branch.phones` | 1–5 | `PHONE_REQUIRED`, `INVALID_VALUE` |
| `branch.phones[i].number` | Egyptian mobile, landline or hotline | `REQUIRED`, `INVALID_PHONE` |
| `branch.phones[i].label` | `reception` (default), `mobile`, `landline` | `INVALID_VALUE` |
| `acceptTerms` | must be `true` | `TERMS_NOT_ACCEPTED` |
| `license` (file part) | required | `REQUIRED`, `FILE_TOO_LARGE`, `FILE_TYPE_NOT_ALLOWED`, `FILE_CONTENT_INVALID` |
| `data` (part) | required, valid JSON | `REQUIRED`, `INVALID_REQUEST` |

**201** returns a session with `doctorStatus: "active"` and a running free `trial`, so the app opens the doctor's home ([api-free-trial.md](api-free-trial.md)). Doctors who signed up before 17 Nov got `pendingApproval` and A6. The API also writes a `doctorRegistrationReceived` notification for every active admin and sends the verification email (A5). Other answers: 400, 409 `EMAIL_ALREADY_REGISTERED`, 413 `REQUEST_TOO_LARGE`, 415 `UNSUPPORTED_MEDIA_TYPE` (not multipart), 429.

Working hours and booking settings are not part of the Phase 1 registration. The doctor sets them after approval (D29, Phase 2). One branch is created and it is the default.

### Registration view

Returned by `myRegistration`, `resubmitDoctorRegistration`, the admin detail and `reviewDoctorRegistration`. It uses the same field names as `data` (no password), so A7 can pre-fill the form from it and send it back.

```json
{
  "doctorId": "…", "status": "rejected", "statusReason": "صورة الكارنيه غير واضحة",
  "submittedAt": "…", "approvedAt": null,
  "fullName": "…", "email": "…", "emailVerified": false, "phone": "+2010…", "locale": "ar",
  "title": "…", "specialty": { "id": "…", "nameAr": "…", "nameEn": "…" }, "specialtyId": "…",
  "extraSpecialties": [ { "id": "…", "nameAr": "…", "nameEn": "…" } ], "extraSpecialtyIds": ["…"],
  "licenseNumber": "45678", "licenseContentType": "image/jpeg",
  "fullNameEn": null, "titleEn": null, "degreesAr": null, "degreesEn": null,
  "examinationPricePiasters": 30000, "consultationPricePiasters": null,
  "branch": { "id": "…", "nameAr": "…", "governorate": "…", "city": "…", "addressDetails": "…", "mapUrl": null, "…": "…",
              "phones": [ { "number": "+20223581234", "label": "landline", "isWhatsapp": false } ] }
}
```

`submittedAt` is the latest submission time: the first one, or the last resubmission.

| Method and route | Auth | Request | Success | Errors |
|---|---|---|---|---|
| `GET /api/doctors/myRegistration` (A6, A7) | doctor, any status | | 200 registration view | 403 `FORBIDDEN` (not a doctor) |
| `GET /api/doctors/myRegistration/license` | doctor | | 200 file (`image/*` or `application/pdf`) | 404 `LICENSE_FILE_MISSING` |
| `POST /api/doctors/resubmitDoctorRegistration` (A7) | doctor with status `rejected` | multipart: `data` as above, without `password` and `acceptTerms`; `license` only when it changes | 200 registration view (`status: "pendingApproval"`, `statusReason: null`) | 409 `REGISTRATION_NOT_EDITABLE` (not rejected), 409 `EMAIL_ALREADY_REGISTERED`, 400 as above |

On resubmit the default branch and its phones are replaced, and a new license file replaces the old one (the old file is deleted). If the email changes, it becomes unverified and a new verification email is sent. Every active admin gets a `doctorRegistrationResubmitted` notification. While a registration is `pendingApproval` it is read-only (A6).

## Public

| Method and route | Auth | Success |
|---|---|---|
| `GET /api/settings/public` | anonymous | Below. `Cache-Control: no-cache`. |
| `GET /api/specialties` | anonymous | `[ { "id": "…", "nameAr": "باطنة", "nameEn": "Internal Medicine" } ]`, active ones in the admin's order |
| `GET /api/health` | anonymous | `{ "status": "ok", "database": "…", "appliedMigrations": 3, "pendingMigrations": [] }` |

```json
{
  "minAppVersion": { "android": "1.0.0", "ios": "1.0.0", "windows": "1.0.0", "macos": "0.0.0" },
  "maintenance": { "enabled": false, "messageAr": "…", "messageEn": "…" },
  "support": { "phone": "+20223581234", "whatsapp": "+201012345678", "email": "help@…" },
  "terms":   { "version": "6e340b9cffb3", "updatedAt": "2026-11-15T10:00:00.000Z", "ar": "…", "en": "…" },
  "privacy": { "version": "…", "updatedAt": null, "ar": null, "en": null }
}
```

Versions are `major.minor.patch`; compare them as numbers (`1.0.10` is higher than `1.0.9`). `terms.version` and `privacy.version` change whenever either language's text changes, so the app can cache the texts by version. `updatedAt` is the last AD13 change, or null if the text was never changed there. When a text is null in the user's language, show the other language (spec section 12).

## Admin

Every admin route needs `role = admin`. AD14 routes need `adminRole = superAdmin`; any other caller gets 403 `FORBIDDEN`. Every write adds an audit row.

### Sign-up requests (AD2, AD3), any admin

| Method and route | Request | Success | Errors |
|---|---|---|---|
| `GET /api/admin/doctorRegistrations` | Query: `status` (`pendingApproval` default, any doctor status, or `all`), `search` (name, email, mobile or syndicate number), `specialtyId`, `governorate`, `from`, `to` (submitted, UTC, `to` exclusive), `sort` (`oldest` default, `newest`), `page`, `pageSize` | 200 page of `{ doctorId, fullName, title, specialty {id,nameAr,nameEn}, governorate, city, status, submittedAt, createdAt, emailVerified }` | 400 |
| `GET /api/admin/doctorRegistrations/{doctorId}` | | 200 `{ "registration": <registration view>, "reviews": [ { decision: "approve"\|"reject", reason, reviewedBy, reviewedByName, at } ] }`, newest review first | 404 |
| `GET /api/admin/doctorRegistrations/{doctorId}/license` | | 200 file stream. Writes a `doctorLicenseViewed` audit row. | 404 `NOT_FOUND` / `LICENSE_FILE_MISSING` |
| `POST /api/admin/reviewDoctorRegistration` | `{ doctorId, decision: "approve"\|"reject", reason }`. `reason` (3–500) is required to reject. | 200 registration view (`active` or `rejected`). Notifies the doctor. | 400 `reason`: `REASON_REQUIRED`; 404; 409 `REGISTRATION_NOT_PENDING` (already reviewed, also when two admins answer at once) |

### Doctor status (AD5, BR-G4), any admin

The free trial's admin actions (`activateDoctorService`, `extendDoctorTrial`), the AD2 `trial` filter and the `trial` field of the registration view are in [api-free-trial.md](api-free-trial.md). Sign-up no longer waits for approval: the doctor is `active` at once, with a free trial (api-free-trial.md). AD2 and AD3 remain for the trial and for doctors who signed up before the change.

`setDoctorStatus` is listed in Phase 7 (AD5). Its API came early, in Phase 2, so a suspension can be tested end to end; the AD5 screen and the automatic suspension for unpaid invoices (BR-G1, BR-G3) are still Phase 7.

| Method and route | Request | Success | Errors |
|---|---|---|---|
| `POST /api/admin/setDoctorStatus` | `{ doctorId, status: "suspended"\|"active", reason }`. `active` reactivates. `reason` (3–500) is required both ways. | 200 `{ doctorId, fullName, status, statusReason, statusChangedAt }`. `statusReason` is the suspension reason, `null` once active. Asking for the status the doctor already has changes nothing. | 400 `reason`: `REASON_REQUIRED`, `TOO_LONG`; `status`: `INVALID_VALUE`; `doctorId`: `REQUIRED`. 404 (not a doctor). 409 `DOCTOR_STATUS_NOT_CHANGEABLE`, with `status`: the doctor is pending approval, rejected or disabled. |

- It moves a doctor only between `active` and `suspended`. Two admins at the same moment run one after the other.
- It applies at once: clinic endpoints read the doctor's status from the database on every request (spec 9.4). While suspended, the doctor and every assistant get 403 `DOCTOR_SUSPENDED` for the BR-G5 actions (adding or linking patients, new sessions; [api-phase-2.md](api-phase-2.md)), `clinic/me` shows `doctor.status: "suspended"`, and everything else works. Sign-in still works; the doctor's session has `doctorStatus: "suspended"` and `doctorStatusReason` (assistants get the status, never the reason).
- Notifies the doctor and their active assistants (`doctorSuspended` / `doctorReactivated`, below) and writes a `doctorSuspended` or `doctorReactivated` audit row with `doctorId`, so AD15 can filter by doctor. These rows don't show in the clinic's activity log (D27).
- There is no "disable" yet. A disabled doctor (`Doctors.Status = disabled`) already can't sign in (`ACCOUNT_DISABLED`) and their assistants get `CLINIC_NOT_ACTIVE`, but disabling must also cancel every future booking and tell the patients (spec 6.12.7, case 23), which needs the Phase 6 bookings, and the spec doesn't yet say how a disabled doctor comes back. It comes with AD5 in Phase 7.

### Add doctor (AD6), any admin

`POST /api/admin/createDoctor` creates a doctor account directly. Any admin may call it (`admin` or `superAdmin`); doctors, assistants and patients get 403.

`multipart/form-data`, like A4:

| Part | Content |
|---|---|
| `data` | The A4 form (see `completeDoctorRegistration`) **without** `password`, `acceptTerms` and `device`; a `password` sent anyway is ignored. Same field rules and error codes. `locale` (`ar` default, or `en`) is the language of the email and the notifications. |
| `license` | Required: the syndicate card or license, JPEG, PNG, WebP or PDF, ≤ 10 MB. |

On success:
- the user (`role = doctor`, `status = active`) has **no password** until the doctor chooses one, so nobody can sign in with it before that;
- the doctor is `active` with the service on and **no free trial** (`trialEndsAt` null, `approvedBy` = the admin): sessions carry the platform fees from the start;
- the first branch is the default branch, as in A4;
- the doctor gets the `doctorInvite` email (Arabic and English, the doctor's language first) with a link to `Email:ResetPasswordUrl?token=…` and the same token as a code. It is a `passwordReset` token (`UserTokens`), valid `Auth:DoctorInviteTokenHours` (72 by default), so the A8 screen and `POST /api/auth/resetPassword` set the password; that also marks the email verified. If the link expires, AD5 "Send password reset email" (`POST /api/admin/doctors/sendPasswordReset`) sends a new one;
- a `doctorWelcome` notification waits for the doctor (no trial length);
- the audit log gets `doctorCreated` with `{ specialtyId, branchId, serviceActive: true }` and `doctorId`.

**201** returns the registration view (`status: "active"`, `trial: null`).

Errors: the A4 field errors (400), 400 `license` `REQUIRED` / `FILE_TOO_LARGE` / `FILE_TYPE_NOT_ALLOWED`, 409 `EMAIL_ALREADY_REGISTERED` (nothing is created or sent), 413 `REQUEST_TOO_LARGE`, 415 `UNSUPPORTED_MEDIA_TYPE`.

### Admin users (AD14), super admin only

| Method and route | Request | Success | Errors |
|---|---|---|---|
| `GET /api/admin/admins` | | 200 `[ { userId, displayName, email, adminRole, status, mustChangePassword, createdAt, lastLoginAt } ]` | |
| `POST /api/admin/createAdmin` | `{ email, displayName, adminRole: "admin"\|"superAdmin" }` | 201 `{ "admin": {…}, "temporaryPassword": "a7Kq…" }`. The password is shown once. Sharing it is up to the super admin. The new admin must set their own password (A9). | 400 (`INVALID_EMAIL`, `INVALID_NAME`, `INVALID_VALUE`), 409 `EMAIL_ALREADY_REGISTERED` |
| `POST /api/admin/setAdminRole` | `{ userId, adminRole }` | 200 admin. The admin's current token gets 401 `TOKEN_OUTDATED`; a refresh brings the new role. | 404, 409 `CANNOT_CHANGE_OWN_ROLE` / `LAST_SUPER_ADMIN` |
| `POST /api/admin/setAdminStatus` | `{ userId, status: "disabled"\|"active" }` | 200 admin. Disabling signs them out everywhere at once. | 404, 409 `CANNOT_DISABLE_SELF` / `LAST_SUPER_ADMIN` |

There is always at least one active super admin. The check runs in the database under a lock, so two super admins demoting each other at the same moment leave one.

### Admin profile (AD18), any admin

| Method and route | Request | Success |
|---|---|---|
| `GET /api/admin/profile` | | 200 `{ "admin": {…}, "locale": "ar", "themeMode": "system" }` |
| `POST /api/admin/updateAdminProfile` | `{ displayName }` (full-name rule) | 200, same shape |

Password: `POST /api/auth/changePassword`. Language and appearance: `POST /api/auth/updatePreferences`. Logout: `POST /api/auth/logout`.

### Audit log (AD15), any admin

`GET /api/admin/auditLogs`. Query: `actorUserId`, `actorRole` (`system`, `admin`, `doctor`, `assistant`, `patient`), `action`, `targetType` (`user`, `doctor`, `settings`), `targetId`, `doctorId`, `from`, `to`, `page`, `pageSize`. Newest first.

```json
{ "items": [ { "id": 42, "at": "…", "actorUserId": "…", "actorRole": "admin", "actorName": "Nour Adel",
               "action": "doctorRegistrationRejected", "targetType": "doctor", "targetId": "…", "doctorId": "…",
               "details": { "reason": "…" } } ],
  "page": 1, "pageSize": 25, "totalCount": 1, "totalPages": 1 }
```

### Settings (AD13), any admin

| Method and route | Request | Success | Errors |
|---|---|---|---|
| `GET /api/admin/settings` | | 200 every field below, plus `updatedAt` and `updatedBy {id, displayName}` | |
| `POST /api/admin/updateSettings` | Only the fields to change: `{ "examFeePiasters": 4000, "supportEmail": null }`. `null` or `""` clears an optional text. | 200 all settings. One `SettingsHistory` row per field whose value changed (unchanged fields write none), and one `settingsUpdated` audit row. | 400: per field `OUT_OF_RANGE`, `INVALID_VALUE`, `TOO_LONG`, `INVALID_EMAIL`, `INVALID_PHONE`, `INVALID_VERSION`, `REQUIRED`, `UNKNOWN_SETTING`; `body: REQUIRED` for `{}`. Nothing is saved if any field fails. |
| `GET /api/admin/settingsHistory` | Query: `field` (a name below), `page`, `pageSize` | 200 page of `{ id, field, before, after, truncated, changedBy, changedByName, changedAt }`, newest first. Values longer than 300 characters are cut (`truncated: true`). | 400 `UNKNOWN_SETTING` |
| `GET /api/admin/settingsHistory/{id}` | | 200 one item with full values | 404 |

| Field | Type and range |
|---|---|
| `examFeePiasters`, `consultationFeePiasters` | integer 0–1,000,000 (0–10,000 EGP) |
| `gracePeriodDays` | integer 0–31 |
| `trialDays` | integer 1–90, default 14: the free trial given at approval ([api-free-trial.md](api-free-trial.md)) |
| `maxConsecutiveConsultations` | integer 1–5 |
| `maxUploadMb` | integer 1–200 |
| `maxAssistantsPerDoctor` | integer 0–50 |
| `maxBranchesPerDoctor` | integer 1–50 |
| `instapayAddress`, `instapayAccountName` | text ≤ 200, ≤ 100 |
| `instapayInstructionsAr`, `instapayInstructionsEn` | text ≤ 2000 |
| `supportPhone` | Egyptian mobile, landline or hotline |
| `supportWhatsapp` | mobile, Egyptian or international E.164 |
| `supportEmail` | email |
| `minVersionAndroid`, `minVersionIos`, `minVersionWindows`, `minVersionMacos` | `major.minor.patch`, required |
| `maintenanceEnabled` | `true` / `false` |
| `maintenanceMessageAr`, `maintenanceMessageEn` | text ≤ 500 |
| `termsAr`, `termsEn`, `privacyAr`, `privacyEn` | text ≤ 100,000 |

The settings marked "applies to new sessions/invoices only" in AD13 are a note for the screen; the API simply stores the new value.

## Notifications written in Phase 1

Rows in `Notifications` (both languages). The notification list, read state and push delivery come in Phase 5. `route` is a suggestion for the app's router; change it there and here together.

| `type` | Recipient | Title (AR / EN) | Body | `route` | `data` |
|---|---|---|---|---|---|
| `doctorRegistrationReceived` | every active admin | طلب تسجيل جديد / New sign-up request | `د. {name} — {specialty}` | `/admin/signups/{doctorId}` | `{ doctorId }` |
| `doctorRegistrationResubmitted` | every active admin | طلب تسجيل معدّل / Sign-up request resubmitted | same | same | `{ doctorId }` |
| `doctorRegistrationApproved` | the doctor | تم تفعيل حسابك / Your account is approved | | `/home` | `{ doctorId }` |
| `doctorRegistrationRejected` | the doctor | تم رفض طلبك / Your sign-up was not approved | `السبب: {reason}` | `/registration/rejected` | `{ doctorId }` |
| `patientPasswordResetRequested` | each linked doctor, and their assistants with `patientsResetPassword` | طلب إعادة تعيين كلمة المرور / Password reset request | `المريض {name} طلب إعادة تعيين كلمة المرور` | `/patients/{patientId}` | `{ patientId, linkId }` |
| `assistantPasswordResetRequested` | the assistant's doctor | same | `المساعد {name} طلب إعادة تعيين كلمة المرور` | `/assistants/{assistantId}` | `{ assistantId }` |
| `doctorSuspended` | the doctor, and each active assistant | تم إيقاف الخدمة / Your clinic is suspended (assistants: The clinic is suspended) | Doctor: `السبب: {reason}`. Assistants: `تم إيقاف خدمة عيادة د. {name}: …`, without the reason | `/home` | `{ doctorId }` |
| `doctorReactivated` | the doctor, and each active assistant | تم إعادة تفعيل الخدمة / Your clinic is active again | | `/home` | `{ doctorId }` |
| `doctorWelcome` | a doctor an admin added (AD6) | أهلاً بك في «العيادة» / Welcome to el3yada | `حسابك جاهز ويمكنك استخدام العيادة الآن.` (no trial length) | `/home` | `{ doctorId }` |

## Audit actions

`doctorRegistrationSubmitted`, `doctorRegistrationResubmitted`, `doctorRegistrationApproved`, `doctorRegistrationRejected` (details: `reason`), `doctorLicenseViewed`, `doctorSuspended` and `doctorReactivated` (`before`, `after`, `reason`), `doctorCreated` (AD6: `specialtyId`, `branchId`, `serviceActive`), `adminSeeded`, `adminCreated` (details: `adminRole`), `adminRoleChanged` (`before`, `after`), `adminDisabled`, `adminEnabled`, `adminProfileUpdated`, `settingsUpdated` (`fields`), `passwordSet`, `passwordChanged`, `passwordResetRequested` (`channel`: `email` or `doctor`), `passwordReset`, `accountLockedOut`, `refreshTokenReuseDetected`, `emailVerified`.

Audit rows never hold passwords, tokens or medical text. As a safety net, any detail whose name contains "password", "token" or "secret" is dropped.

## Error codes

Arabic texts in quotes are from the spec. The app owns the final wording in its ARB files.

| Code | HTTP | Meaning |
|---|---|---|
| `VALIDATION_FAILED` | 400 | See `errorCodes` per field |
| `INVALID_REQUEST` | 400 | The body is not JSON or has wrong types; also "this account has no email" for resend |
| `REQUIRED`, `TOO_LONG`, `OUT_OF_RANGE`, `INVALID_VALUE` | field | Generic field rules («قيمة غير صحيحة») |
| `INVALID_MOBILE` | field | «رقم الموبايل غير صحيح» |
| `INVALID_PHONE` | field | Not a valid phone number (landlines allowed) |
| `PHONE_REQUIRED` | field | «أضف رقم تليفون واحد على الأقل» |
| `INVALID_MAP_LINK` | field | A branch's `mapUrl` is not a Google Maps link («ده مش لينك جوجل ماب») |
| `INVALID_EMAIL` | field | «البريد الإلكتروني غير صحيح» |
| `INVALID_IDENTIFIER` | field | Neither an email nor an Egyptian mobile |
| `INVALID_NAME` | field | «اكتب الاسم ثنائي على الأقل» |
| `WEAK_PASSWORD` | field | «كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي على حرف ورقم» |
| `PASSWORD_SAME_AS_OLD` | field | The new password is the current one |
| `CURRENT_PASSWORD_INCORRECT` | field | The current password is wrong |
| `TERMS_NOT_ACCEPTED` | field | Accept the Terms and Privacy Policy |
| `INVALID_LICENSE_NUMBER` | field | «رقم النقابة مطلوب» |
| `INVALID_SPECIALTY` | field | Not an active specialty |
| `INVALID_VERSION` | field | Not `1.2.3` |
| `UNKNOWN_SETTING` | field | Not a settings field |
| `REASON_REQUIRED` | field | A rejection, a suspension or a reactivation needs a reason |
| `FILE_TOO_LARGE`, `FILE_TYPE_NOT_ALLOWED`, `FILE_CONTENT_INVALID` | field | License file problems |
| `INVALID_CREDENTIALS` | 401 | «رقم الهاتف/البريد أو كلمة المرور غير صحيحة» |
| `UNAUTHENTICATED` | 401 | No token, or a bad one: refresh, then A3 |
| `TOKEN_EXPIRED` | 401 | Refresh and retry |
| `TOKEN_OUTDATED` | 401 | The role changed: refresh and retry |
| `SESSION_REVOKED` | 401 | The password changed elsewhere: refresh fails, so go to A3 |
| `REFRESH_TOKEN_INVALID` | 401 | Sign in again (A3) |
| `REFRESH_TOKEN_REUSED` | 401 | The session was revoked for safety: sign in again |
| `SELECTION_TOKEN_INVALID` | 401 | "Log in as" expired or was used: sign in again |
| `ACCOUNT_DISABLED` | 403 | A10 "Your account has been disabled. Contact support." |
| `ACCOUNT_PENDING_DELETION` | 403 | The account is in its deletion grace period: reload the session and show A16 ([api-account-deletion.md](api-account-deletion.md)) |
| `CLINIC_NOT_ACTIVE` | 403 | A10 «حساب العيادة غير مفعّل، تواصل مع الطبيب» |
| `PATIENT_DESKTOP_NOT_SUPPORTED` | 403 | A14 «حساب المريض على تطبيق الموبايل فقط» |
| `PASSWORD_CHANGE_REQUIRED` | 403 | Go to A9 |
| `FORBIDDEN` | 403 | This role may not do this |
| `DOCTOR_PENDING_APPROVAL`, `DOCTOR_REJECTED`, `DOCTOR_SUSPENDED`, `DOCTOR_DISABLED` | 403 | Reserved for doctor endpoints from Phase 2 |
| `NOT_FOUND` | 404 | No such record or route |
| `LICENSE_FILE_MISSING` | 404 | The stored license file is gone |
| `METHOD_NOT_ALLOWED` | 405 | |
| `PASSWORD_CHANGE_NOT_REQUIRED` | 409 | Use `changePassword` |
| `EMAIL_ALREADY_REGISTERED` | 409 | An account with this email exists |
| `EMAIL_ALREADY_VERIFIED` | 409 | |
| `REGISTRATION_NOT_EDITABLE` | 409 | Only a rejected registration can be resubmitted |
| `REGISTRATION_NOT_PENDING` | 409 | Already reviewed |
| `DOCTOR_STATUS_NOT_CHANGEABLE` | 409 | `setDoctorStatus`: only an active doctor can be suspended, only a suspended one reactivated. The answer has `status`. |
| `SERVICE_ALREADY_ACTIVE` | 409 | `extendDoctorTrial`: the doctor has no trial ([api-free-trial.md](api-free-trial.md)) |
| `CANNOT_CHANGE_OWN_ROLE`, `CANNOT_DISABLE_SELF`, `LAST_SUPER_ADMIN` | 409 | AD14 guards |
| `REQUEST_TOO_LARGE` | 413 | The upload is too large |
| `UNSUPPORTED_MEDIA_TYPE` | 415 | Send `multipart/form-data` |
| `TOO_MANY_ATTEMPTS` | 429 | «محاولات كثيرة، حاول لاحقاً». See `Retry-After`. |
| `VERIFICATION_EMAIL_COOLDOWN` | 429 | Wait before resending (A5: 60 seconds) |
| `SERVER_ERROR` | 500 | Unexpected; details only in the server log |
