# el3yada API: account deletion

Product owner's decisions (Youssef, 21 Nov). Spec 6.17 has the rules (BR-DEL1 to BR-DEL12) and answers open question 16. The code is in `Features/AccountDeletion/`, plus the billing changes in `Billing/BillingService.cs`. When this page and the code differ, fix this page.

Every role can delete its own account: patient (P14), doctor (D24), assistant (AS12) and admin (AD18). There is **no admin approval**. Instead there is a **grace period**:

1. The user confirms with their **current password**.
2. The account is **disabled at once** (`Users.Status = pendingDeletion`). Every device is signed out: the security stamp changes, refresh tokens are revoked, and push devices are removed.
3. For `accountDeletionGraceDays` days (AD13, 30 by default, 7 to 90), the right password opens only the **restore screen (A16)**: «حسابك هيتحذف نهائياً يوم …», with **Restore account** and **Sign out**.
4. After the grace period, the daily job `accountErasure` **erases the identity** and keeps the medical and billing records. A doctor's erasure **waits until every invoice is paid**.

An admin can also start a deletion for a support case (AD5, AD11, AD14) and can cancel any deletion in progress (AD12). The grace period and the rules are the same.

- [Sign-in during the grace period](#sign-in-during-the-grace-period)
- [Endpoints](#endpoints)
- [What each role's deletion does](#what-each-roles-deletion-does)
- [Doctors: invoices](#doctors-invoices)
- [Erasure: what goes and what stays](#erasure-what-goes-and-what-stays)
- [What others see](#what-others-see)
- [Admin: AD12](#admin-ad12)
- [Notifications, audit and error codes](#notifications-audit-and-error-codes)

## Sign-in during the grace period

**Design:** this is a normal session with a `pendingDeletion` state, not a separate restore token. It fits the session design of [api-phase-1.md](api-phase-1.md), as `mustChangePassword` (A9) and `trial.ended` (A15) do: the same tokens, refresh and logout, and the app routes on a session field.

- **Login and selectAccount:** with the right password, the answer is the usual `200 signedIn` session. `accountStatus` is `"pendingDeletion"` and `pendingDeletion` is set. An account in its grace period is never refused for its status or its clinic's status: it always gets to A16, so it can restore.
- **"Log in as" (A3):** each choice in `chooseAccount` has `pendingDeletion: true|false`. A number can be both a patient and an assistant. Only the account that signed in is affected, by the restore screen and by the deletion.
- **Refresh** works as usual and keeps the state. **Logout** works as usual.
- **Allowed endpoints:** that session may call only `GET /api/auth/me`, `POST /api/auth/updatePreferences`, `POST /api/auth/setNewPassword` (an A9 password comes first), `GET /api/me/accountDeletion` and `POST /api/me/restoreAccount`. A doctor may also call `GET /api/clinic/me` and every `/api/billing/...` endpoint (D18 to D20), to pay what holds the erasure back. Assistants with `billingView` can't, because the clinic is closed.
- **Every other endpoint** answers **403 `ACCOUNT_PENDING_DELETION`**. On that code, the app reloads the session (`GET /api/auth/me`), and the router opens A16. The SignalR hub isn't gated, but A16 doesn't connect to it, and the account has no push devices left.

```json
"accountStatus": "pendingDeletion",
"pendingDeletion": {
  "requestId": "6f1c…", "status": "scheduled",
  "requestedAt": "2026-11-21T10:04:00.000Z", "scheduledFor": "2026-12-21T10:04:00.000Z",
  "reason": "مش محتاج التطبيق", "requestedByAdmin": false,
  "unpaidInvoices": 1, "outstandingPiasters": 4500, "waitsForPayment": true
}
```

| Field | Meaning |
|---|---|
| `status` | `scheduled`, or `waitingPayment` once a doctor's grace period has passed with an invoice unpaid. |
| `scheduledFor` | UTC. The erasure date: `requestedAt` plus the grace days in force when the deletion started. A16 shows its Cairo date. |
| `reason` | The user's reason, or the admin's when `requestedByAdmin`. |
| `unpaidInvoices`, `outstandingPiasters` | Doctors only (0 for other roles): invoices still `unpaid`, `rejected`, `overdue` or `pendingReview`, and their total. |
| `waitsForPayment` | `unpaidInvoices > 0`: the erasure waits for them, even after `scheduledFor`. |

`pendingDeletion` is `null` in every other session. A1 routes `pendingDeletion != null` to **A16** before any role check, right after A9.

## Endpoints

Routes are under `/api`.

| Method and route (name) | Who | Request | Success | Errors |
|---|---|---|---|---|
| `GET /me/accountDeletion` (`getAccountDeletion`) | any signed-in role, also in the grace period | | 200 [state](#the-state) | 401 |
| `POST /me/requestAccountDeletion` (`requestAccountDeletion`) | any signed-in role | `{ currentPassword, reason? }` (reason ≤ 500) | 200 [started](#started) | 400 `currentPassword`: `REQUIRED` / `CURRENT_PASSWORD_INCORRECT`, `reason`: `TOO_LONG`; 409 `ACCOUNT_DELETION_SCHEDULED`, `LAST_SUPER_ADMIN`, `UNPAID_INVOICES` (with `details.invoices`); 429 (login rate limit) |
| `POST /me/restoreAccount` (`restoreAccount`) | the grace-period session | | 200 session (no tokens; the same tokens keep working) | 409 `ACCOUNT_NOT_PENDING_DELETION` |
| `GET /admin/accountDeletions` (`getAccountDeletions`) | any admin | `?role=all\|patient\|doctor\|assistant\|admin&status=all\|open\|scheduled\|waitingPayment\|restored\|completed&userId=&page=&pageSize=` | 200 page of [items](#admin-ad12), newest first | 400 `INVALID_VALUE` |
| `POST /admin/accountDeletions/schedule` (`adminScheduleAccountDeletion`) | any admin; for an admin account, a super admin (or the admin themself) | `{ userId, reason }` (reason required) | 200 item | 400; 403 `FORBIDDEN`; 404; 409 as `requestAccountDeletion` |
| `POST /admin/accountDeletions/{id}/cancel` (`adminCancelAccountDeletion`) | any admin; for an admin account, a super admin | `{ reason }` (required) | 200 item (`status: restored`) | 400; 403; 404; 409 `ACCOUNT_NOT_PENDING_DELETION` |

The old patient-only endpoints are gone: `GET/POST /patient/deletion-request`, `GET /admin/deletion-requests` and `POST /admin/deletion-requests/{id}/review`. `getPatientAccount` no longer has `deletionRequest`.

### The state

```json
{
  "role": "doctor", "graceDays": 30, "scheduledForIfNow": "2026-12-21T10:04:00.000Z",
  "pending": null,
  "unpaidInvoices": [],
  "finalInvoice": { "amountPiasters": 4500, "invoices": [
    { "monthKey": "2026-11", "periodStart": "2026-11-01", "periodEnd": "2026-11-21", "dueDate": "2026-11-28", "amountPiasters": 4500, "isFinal": true } ] },
  "refusal": null
}
```

- `pending` is the deletion in progress (the session's `pendingDeletion`), or `null`.
- `unpaidInvoices` (doctors) are the invoices that refuse the deletion now, or hold the erasure back: `[{ id, monthKey, totalDuePiasters, status, dueDate }]`. On A16 they are the invoices to pay.
- `finalInvoice` (doctors, only while nothing refuses the deletion) is what deleting would bill now. See [Doctors: invoices](#doctors-invoices). It is `null` when there is nothing to bill.
- `refusal` is why the deletion can't start now: `ACCOUNT_DELETION_SCHEDULED`, `UNPAID_INVOICES` or `LAST_SUPER_ADMIN`. It is `null` when it can start.

### Started

```json
{ "requestId": "6f1c…", "status": "scheduled", "requestedAt": "…", "scheduledFor": "…", "cancelledBookings": 2,
  "finalInvoice": { "amountPiasters": 4500, "invoices": [ … ] } }
```

The device that asked is signed out too: its tokens stop working at the next request. The app clears the session, says «حسابك هيتحذف نهائياً يوم …», and goes to A3.

## What each role's deletion does

When the deletion starts, the account is disabled and signed out everywhere (all roles). Then, by role:

| Role | Effects |
|---|---|
| **Patient** | Future bookings (`pending` and `confirmed`, from today) are cancelled: `CancelReason = accountDeleted` (BR-AP18, spec case 24). The clinic staff get the usual «إلغاء حجز» activity. Chats are closed. Linked doctors see `accountStatus: "pendingDeletion"` on D6 (the banner «حساب المريض مجدول للحذف»). They can still read and write clinical data and record sessions. They can't reset the patient's password or change the number (409 `ACCOUNT_DELETION_SCHEDULED`). |
| **Doctor** | The final invoice is issued, or the deletion is refused (see below). The clinic stops. The assistants are signed out, and their next request and sign-in get 403 `CLINIC_NOT_ACTIVE` (A10). Every future booking is cancelled, and the patient is told «تم إلغاء موعدك لأن العيادة أوقفت الخدمة». Chats are closed. Patients see `doctorStatus: "disabled"`, so there are no new bookings, but they keep reading their visits, files and prescriptions. Admins get AD17 «طبيب طلب حذف حسابه». |
| **Assistant** | No longer one of the clinic's active assistants. They get no clinic notifications, and D25 shows `accountStatus: "pendingDeletion"`. The doctor gets «المساعد … طلب حذف حسابه». |
| **Admin** | Nothing else. The last active super admin can never be deleted (409 `LAST_SUPER_ADMIN`, the same rule as AD14's demote and disable). AD14 can't switch an admin who is being deleted back on (409 `ACCOUNT_DELETION_SCHEDULED`); AD12 cancels the deletion. |

AD11's `setAccountLoginStatus` refuses an account being deleted (409 `ACCOUNT_DELETION_SCHEDULED`) or erased (409 `ACCOUNT_DELETED`).

**Restore** (the user on A16, or an admin's cancel) undoes what can be undone:

- The account is active again, and the same session works everywhere.
- A doctor's clinic opens again, and so its assistants can sign in. Assistants were never disabled, only kept out by `CLINIC_NOT_ACTIVE`, so the ones active before are active again. One the doctor disabled stays disabled.
- Chats open again. The doctor is bookable again.
- Cancelled bookings stay cancelled, and A16 says so.
- A doctor's unpaid final invoice is removed (see below).

## Doctors: invoices

**Refusal (BR-DEL7).** While any invoice is `unpaid`, `rejected`, `overdue` or `pendingReview`, the deletion is refused with **409 `UNPAID_INVOICES`**:

```json
{ "status": 409, "code": "UNPAID_INVOICES",
  "details": { "invoices": [ { "id": "…", "monthKey": "2026-10", "totalDuePiasters": 18000, "status": "overdue", "dueDate": "2026-11-07" } ] } }
```

The app shows «لازم تسدد الفواتير المستحقة الأول», with a link to D18.

**Final invoice (BR-DEL8).** Starting the deletion bills, at once and in the same transaction:

1. Every past month with sessions and no invoice yet. For example, a deletion on the 1st before month close. It closes as `monthlyClose` would: the full month, the usual due date.
2. The **final invoice** of the current month, closed early: `PeriodStart` is the 1st, and `PeriodEnd` is today in Cairo. `isFinal` is `true`, and the due date is today plus `gracePeriodDays`. It also carries any fees left from an earlier final invoice (below).

Nothing is issued when there is nothing to bill. `getAccountDeletion.finalInvoice` shows the amount before the doctor confirms («هيتعمل فاتورة نهائية بمبلغ … ولازم تتدفع قبل الحذف النهائي»). The started answer repeats it. `DeletionRequests.FinalInvoiceId` points at the final invoice.

The invoice views (D18, D19, AD10) have `isFinal`. Payment works as usual (D19, D20), also from the grace-period session.

**Erasure waits for payment (BR-DEL9).** When the grace period ends with any invoice unpaid, the job sets the deletion to `waitingPayment`, writes an audit row once, and keeps checking every day. It erases the account at its first run after the last invoice is paid (approved, marked paid or waived). Admins see these deletions as "waiting for payment".

**Restore with a final invoice (BR-DEL10):**

- **Nothing paid for it yet** (`unpaid` or `overdue`, no payment submitted): the invoice is removed, with its branch lines, timeline, carried lines and its notification. An audit row `finalInvoiceRemoved` holds its month and totals. The month is then invoiced at month close as usual, sessions after the restore included. A billing suspension caused only by it is lifted.
- **Paid, or a payment submitted** (`paid`, `pendingReview`, `rejected`): it stays. `UQ_Invoices_Doctor_Month` allows no second invoice for that month. So `monthlyClose` adds the fees of that month's sessions saved after it to the doctor's **next invoice**, as an adjustment line with `carriedMonthKey` set. A doctor with no sessions in the next month still gets that invoice. The carried amount is the month's session fees now, minus what the final invoice and earlier carried lines for that month billed. So a line is carried once, and running the job again adds nothing. Carried lines have `createdBy: null` (the system). D19 and AD10 show them with their own text, from `carriedMonthKey`.
- **The same month, deleted again** after a paid final invoice: the fees since then can't go in that month's invoice. They are billed at once in a final invoice under the next month's key, dated today. This is rare.

Billing records (invoices, payments, screenshots, adjustments) are never erased.

## Erasure: what goes and what stays

`accountErasure` runs every day at 03:30 Cairo time in `BillingJobsHost` (`GET /api/health/jobs` reports it). It takes every deletion whose `scheduledFor` has passed. Each one runs in its own transaction, with the row locked and checked again. Then the deletion is `completed`, and an `accountErased` audit row is written as the system. Stored files are deleted after the commit. It is idempotent: a completed deletion is skipped, and a second server or a restore at the same moment changes nothing.

| | Erased (replaced) | Kept |
|---|---|---|
| **Every role (Users)** | Name → «مريض محذوف», «طبيب محذوف», «مساعد محذوف» or «مسؤول محذوف». Phone → null. Email → `deleted-<id>@deleted.invalid` (users need a phone or an email). Email verification, password hash, security stamp (new), lockout, last login, language and theme (defaults), notification preferences (defaults). Rows deleted: refresh tokens, push devices, email tokens, their notifications, unread counts. Their chat messages keep their text, but the sender name is replaced. | Role, admin role, created date, Terms acceptance date. `Status = deleted`. |
| **Patient** | Name, phone (a placeholder `~` + 15 hex digits: `Patients.Phone` is required and unique), national ID, address, emergency contact name and phone. On every clinic link (DoctorPatients): name, phone and search name. | Gender, date of birth (and its "estimated" flag), and blood type: the clinical record needs them for doses, age-dependent ranges and transfusion safety. Sessions, private notes, medical profile items, medical files, prescriptions and their PDFs, chats, family history and profile notes on the links, file numbers. `Patients.Status = deleted`. |
| **Doctor** | Arabic and English names, degrees, licence number (`deleted`) and licence scan, prescription logo, signature and footer. For each branch: address details (`—`), landmark, map link, email, description, closed message; phones and photos deleted. **Their assistants are erased too.** | Title, specialty, prices, prescription settings, branch names and governorate/city/area (so past visits still read «… — فرع المعادي»), every patient's records, invoices, payments, screenshots, adjustments, admin notes. `Doctors.Status = disabled`, `StatusReason = accountDeleted`; branches `archived`. |
| **Assistant** | Name, phone (placeholder). `Assistants.Status = removed`. | Permissions and branches as history, the clinic activity log. |
| **Admin** | The Users fields above. | |

**The number and the email are free afterwards.** The index on each column:

- `UQ_Users_PatientPhone` (patients): the phone is null.
- `UQ_Users_Email`: per-user placeholder.
- `UQ_Patients_Phone` (no filter): placeholder.
- `UQ_Assistants_Phone`: filtered on active or disabled, and the assistant is removed, with a placeholder phone.
- Doctors have no phone column. `DoctorPatients.PatientPhone` has no unique index (`IX_DoctorPatients_Doctor_Phone`), and gets the placeholder too.

A new patient with the same number is a new account. The old clinic file stays under «مريض محذوف», without a number. `lookupPhone` says `new`, and the register's search by number finds only the new patient.

Views never show a placeholder phone: D6, the register and D25 send `""`. On an erased patient, `updatePatient`, `updatePatientPhone` and `resetPatientPassword` answer 409 `ACCOUNT_DELETED`.

**Not erased, by design:**

- Audit rows (append-only). A few hold a number in their details, such as AD11's searches.
- Other people's notifications that mention the name.
- The text of chat messages.
- Payment sender names (billing records).
- Admin notes about a doctor.

## What others see

- **A deleted patient**, to their doctors: the name «مريض محذوف». The records are still there. D6's `accountStatus` is `pendingDeletion` during the grace period (banner) and `deleted` after.
- **A deleted doctor**, to their patients: «طبيب محذوف», `doctorStatus: "disabled"`. Visits, files and prescriptions stay readable.
- **Chats:** history stays readable. While either account is being deleted, or once it is erased, the chat is closed for both sides. `canSend` is `false`, `unavailableReason` is `CHAT_CLOSED`, and sending answers 403 `CHAT_CLOSED`. Restoring opens it again.
- **The app** shows its own label for the four «… محذوف» names, in the user's language (`deletedPatient`, `deletedDoctor`, …).

## Admin: AD12

`getAccountDeletions` items:

```json
{ "id": "…", "userId": "…", "role": "doctor", "displayName": "أحمد علي", "phone": "+201012345678", "email": "ahmed@example.com",
  "status": "waitingPayment", "reason": "قفلت العيادة", "requestedAt": "…", "requestedByAdmin": false, "requestedByName": "أحمد علي",
  "scheduledFor": "…", "restoredAt": null, "restoredByName": null, "restoreReason": null, "completedAt": null,
  "patientId": null, "doctorId": "…", "assistantId": null, "unpaidInvoices": 1, "outstandingPiasters": 4500 }
```

- After erasure, `displayName` is the placeholder name, and `phone` and `email` are `null`.
- **Cancel and restore** needs a reason, which is audited.
- **Start deletion** comes from AD5 (doctors), AD11 (patients and assistants) and AD14 (admins). `?userId=` gives that account's deletions, for the account screens. AD11's search results carry `deletion: { id, status, scheduledFor }` for an account being deleted.

## Notifications, audit and error codes

**Notifications** (both languages, `Infrastructure/Notifications`):

| Type | To | Text |
|---|---|---|
| `deletionRequest` | every active admin (AD17) | «طبيب طلب حذف حسابه» / "A doctor asked to delete their account". Route `/admin/account-deletions`. |
| `assistantDeletionRequest` | the doctor | «طلب حذف حساب»: «المساعد … طلب حذف حسابه». Route `/doctor/assistants`. |
| `bookingCancelled` | each patient of a deleting doctor with a booking ahead | «تم إلغاء موعدك»: «تم إلغاء موعدك لأن العيادة أوقفت الخدمة» |
| `staffBookingActivity` | the clinic staff, for a deleting patient's booking | «إلغاء حجز», as when a patient cancels |
| `invoiceCreated` | the doctor | As usual, for the final invoice |

**Audit actions:**

- On the user: `accountDeletionRequested` (by the user), `accountDeletionScheduledByAdmin`, `accountRestored` (by the user), `accountDeletionCancelled` (by an admin, with the reason), `accountDeletionWaitingPayment` (system), `accountErased` (system).
- On the invoice: `finalInvoiceIssued`, `finalInvoiceRemoved`, `invoiceFeesCarried` (system), plus the usual `invoiceCreated`.
- A doctor's or an assistant's rows carry `doctorId`, so they show in the clinic activity log (D27).

**Error codes:**

| Code | Status | When |
|---|---|---|
| `ACCOUNT_PENDING_DELETION` | 403 | Any endpoint not listed above, from a grace-period session |
| `ACCOUNT_DELETION_SCHEDULED` | 409 | A deletion is already in progress; or AD11, AD14 or D7 actions on an account being deleted |
| `ACCOUNT_NOT_PENDING_DELETION` | 409 | Restore or cancel with nothing in progress |
| `UNPAID_INVOICES` | 409 | A doctor who owes an invoice, with `details.invoices` |
| `LAST_SUPER_ADMIN` | 409 | The last active super admin |
| `ACCOUNT_DELETED` | 409 | An action on an erased account |
| `CHAT_CLOSED` | 403 | Sending in a closed chat (and the chat's `unavailableReason`) |
| `CURRENT_PASSWORD_INCORRECT` | 400 (field `currentPassword`) | The wrong password |
