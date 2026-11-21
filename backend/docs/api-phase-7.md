# API contract: Phase 7 (billing and analytics)

The app builds against this file. Names follow spec section 9.1. Money is in **piasters** (integers). Dates are Cairo dates (`yyyy-MM-dd`), months are `yyyy-MM`, times are UTC ISO 8601. Errors are `application/problem+json` with a `code` (see "Error codes"). Every endpoint answers 401 without a token and 403 for the wrong role.

Who may call what:

| Area | Routes | Caller |
|---|---|---|
| Clinic billing (D18–D20, AS10) | `/api/billing/…` | doctor, or assistant with `billingView` (`billingPay` to pay). **Allowed while suspended** (BR-G5). |
| Dashboard (D1, AS18) | `/api/dashboard` | doctor, or assistant with `appointmentsView`, `billingView` or `revenueView` |
| Revenue (D35) | `/api/revenue…` | doctor, or assistant with `revenueView` |
| Admin | `/api/admin/…` | any admin (an admin never gets clinic data or the clinic's revenue, BR-REV1, AC-12) |

## Clinic billing

### `GET /api/billing/invoices` (D18, the invoice card of D1)

```json
{
  "items": [InvoiceListItem],
  "attention": InvoiceListItem | null,      // oldest unpaid / rejected / overdue invoice: the one to pay
  "underReview": InvoiceListItem | null,    // an invoice with a payment waiting
  "outstandingPiasters": 15000,
  "suspension": { "monthKey": "2026-10" | null, "billing": true } | null   // set while the doctor is suspended (BR-G5)
}
```

`InvoiceListItem`: `id, monthKey, periodStart, periodEnd, examCount, consultationCount, examAmountPiasters, consultationAmountPiasters, adjustmentsPiasters, totalDuePiasters, dueDate, status, canPay, paidAt, isFinal`. `isFinal`: a month closed early by the doctor's account deletion ([api-account-deletion.md](api-account-deletion.md)).
`status`: `unpaid | pendingReview | paid | rejected | overdue | waived | noCharge`. `canPay` is true for `unpaid`, `rejected` and `overdue`.
The running month is not an invoice: D18 shows it from `GET /api/sessions/month` (Phase 2).

### `GET /api/billing/invoices/{id}` (D19)

`InvoiceDetail`: the list fields plus `paidMethod`, `branches` (`branchId, nameAr, nameEn, examCount, consultationCount, amountPiasters`), `adjustments` (`id, amountPiasters, reason, createdAt, carriedMonthKey`; `carriedMonthKey` marks fees carried from a final invoice of that month), `timeline` (`status, note, changedAt, changedByRole`), `payments` (`id, amountPiasters, transferDate, reference, senderName, note, status, submittedAt, reviewedAt, rejectionReason, screenshots`), and `doctor` (null here). 404 for another doctor's invoice.

### `GET /api/billing/paymentInfo` (D20)

`{ instapayAddress, instapayAccountName, instructionsAr, instructionsEn }`

### `POST /api/billing/invoices/{id}/submitPayment` (`submitPayment`, D20; `billingPay`)

`multipart/form-data`: `amountPiasters` (≥ 1), `transferDate` (not in the future, at most 120 days old), optional `reference` (≤ 100), `senderName` (≤ 60), `note` (≤ 500), and **1 to 3** `screenshots` (JPEG, PNG or WebP, ≤ 10 MB each; the first bytes must match). Answer 201 `{ paymentId, invoiceId, invoiceStatus: "pendingReview" }`. The invoice becomes `pendingReview` and the admins are notified.
Field errors (400): `screenshots` → `REQUIRED`, `TOO_MANY_SCREENSHOTS`, `FILE_TOO_LARGE`, `FILE_TYPE_NOT_ALLOWED`; `amountPiasters`, `transferDate`, `reference`, `senderName`, `note`.
409 `INVOICE_NOT_PAYABLE` (the invoice is paid, waived, under review or has no charge).

### `GET /api/billing/payments/{paymentId}/screenshots/{n}`

The image (`n` from 1). `Cache-Control: private, no-store`. 404 for another clinic's payment.

## Dashboard (D1, AS18)

### `GET /api/dashboard`

Query (BR-REV2, BR-REV3): `preset` (`today | yesterday | thisWeek | lastWeek | thisMonth | lastMonth | last3Months | last6Months | thisYear | lastYear | custom`, default `thisMonth`), `from` and `to` (required with `custom`, at most about 2 years), `branchId`, `type` (`examination | consultation`), `compare` (default true). Weeks start on Saturday. 403 `BRANCH_NOT_ALLOWED` for a branch the caller can't use.

Every part the caller may not see is `null` (never zero). `access` says what they may see: `{ revenue, patients, billing }` (`revenueView`, `appointmentsView`, `billingView`; all true for the doctor).

```json
{
  "period": { "from", "to", "previousFrom", "previousTo", "preset", "bucket": "day|week|month", "compare" },
  "access": { "revenue": true, "patients": true, "billing": true },
  "tiles": {                       // Tile = { value, previous|null, changePct|null }
    "revenue", "netIncome", "platformFees", "visits", "examinations", "consultations",
    "uniquePatients", "newPatients", "weeklyAveragePatients", "averageRevenuePerVisit",
    "noShowRate" /* percent */, "appShare" /* percent */, "averageWaitMinutes"
  },
  "revenueSeries":  [{ "date", "examinationPiasters", "consultationPiasters", "previousTotalPiasters" }],   // C1
  "visitsSeries":   [{ "date", "examinations", "consultations", "previousTotal" }],                          // C2
  "patientsPerWeek": { "weeks": [{ "weekStart", "patients" }], "average" },                                  // C3
  "months": [{ "monthKey", "visits", "lastYearVisits", "busiest", "quietest" }],                             // C4, last 12 months
  "heatmap": [[24 ints] × 7],                                                                                // C5, Saturday first
  "newVsReturning": [{ "monthKey", "new", "returning" }],                                                    // C6
  "typeSplit": { "examinations", "consultations", "examinationRevenuePiasters|null", "consultationRevenuePiasters|null" },  // C7
  "branches": [{ "branchId", "nameAr", "nameEn", "visits", "revenuePiasters|null" }] | null,                 // C8 (2+ branches)
  "funnel": { "booked", "arrived", "seen", "noShows", "cancellations", "weeks": [{ "weekStart", "noShows", "cancellations" }] },  // C9
  "sources": [{ "monthKey", "app", "staff", "walkIn" }],                                                     // C10
  "notSeen": [{ "months": 3, "patients", "filter": "notSeen3m" }, … 6, 12],                                  // C11
  "waitingTimes": [{ "date", "minutes" }],                                                                   // C12
  "insights": [{ "code", "textAr", "textEn", "screen": "revenue|patients|dashboard", "filter": "notSeen6m"|null }],
  "invoice": { "id", "monthKey", "totalDuePiasters", "dueDate", "status", "daysLeft" } | null                // D1 invoice card (billingView)
}
```

Today is live (read from the sessions). Without `revenueView` there is no money anywhere in the answer. `notSeen[].filter` is the D4 `lastVisit` filter that lists the same patients (AC-24).

## Revenue (D35)

Query: `year`, or `from` and `to`; `branchId`; `type`.

- `GET /api/revenue` → `{ from, to, months: [{ monthKey, row, changePct, invoiceId|null, invoiceStatus|null }], totals: row, bestMonth, worstMonth, byBranch: [{ branchId, nameAr, nameEn, row }], byType: [{ type, row }], byPaymentMethod: [{ method|null, row }] }`.
- `GET /api/revenue/month?month=2026-10` → `{ monthKey, days: [{ day, row }], totals: row }`.
- `GET /api/revenue/day?day=2026-10-12` → `{ day, sessions: [{ id, at, patientId, patientName, branchId, branchNameAr, branchNameEn, type, listPricePiasters, amountChargedPiasters, discountPiasters, paymentMethod, recordedBy, recordedByRole }], totals: row }`.

`row`: `examinations, examinationRevenuePiasters, consultations, consultationRevenuePiasters, revenuePiasters, platformFeesPiasters, netPiasters, uniquePatients, newPatients, freeVisits, discountedVisits, discountPiasters`. `invoiceId` is filled only with `billingView`. The totals match the dashboard for the same filters (AC-23).

## Patients register (D4), added columns

`GET /api/patients/register` rows now carry `nextBooking` (`{ appointmentId, date, visitType, status, branchId }` or null) and `noShowCount`; new filters `hasUpcomingBooking=true` and `hasNoShows=true`. The profile (D6) has the same two fields. `createSession` takes an optional `appointmentId` (BR-AP10): it completes that checked-in booking in the same transaction (404 when it isn't this patient's or this branch's booking, 409 when it is already completed).

## Admin

### Payments (AD7, AD8)

- `GET /api/admin/payments?status=pendingReview|approved|rejected|all&doctorId&page&pageSize` → page of `{ paymentId, invoiceId, doctorId, doctorName, doctorNameEn, monthKey, invoiceTotalPiasters, amountPiasters, mismatch, submittedAt, status }`. The default is the queue, oldest first.
- `GET /api/admin/payments/{id}` → `{ payment: PaymentLine, doctor: { id, name, nameEn, status }, invoice: { id, monthKey, examCount, consultationCount, totalDuePiasters, dueDate, status }, mismatch, earlierAttempts: [PaymentLine] }`.
- `GET /api/admin/payments/{id}/screenshots/{n}` → image.
- `POST /api/admin/reviewPayment` `{ paymentId, action: "approve"|"reject", reason }` → `{ invoiceId, status, totalDuePiasters, dueDate }`. A rejection needs `reason` (3–500; the presets «المبلغ غير مطابق», «الإيصال غير واضح», «لم يصل التحويل» or free text). Rejecting after the due date makes the invoice `overdue` and suspends the doctor at once (BR-G2). Approving reactivates a doctor suspended for billing when none of their invoices is overdue (BR-G3). 409 `PAYMENT_ALREADY_REVIEWED`.

### Invoices (AD9, AD10)

- `GET /api/admin/invoices?month&status&doctorId&page&pageSize` → `{ page: PagedResult<{ id, doctorId, doctorName, doctorNameEn, monthKey, examCount, consultationCount, totalDuePiasters, dueDate, status }>, totals: { count, examCount, consultationCount, totalDuePiasters } }` (the totals cover the whole filtered set).
- `GET /api/admin/invoices/{id}` → `InvoiceDetail` with `doctor` filled.
- `POST /api/admin/adjustInvoice` `{ invoiceId, amountPiasters (signed, not 0), reason }`; `POST /api/admin/waiveInvoice` `{ invoiceId, reason }`; `POST /api/admin/markInvoicePaid` `{ invoiceId, method: "instapay"|"cash"|"bankTransfer"|"other", note }`; `POST /api/admin/extendInvoiceDueDate` `{ invoiceId, newDueDate, reason }`. Each needs a 3–500 character reason, answers `{ invoiceId, status, totalDuePiasters, dueDate }`, writes an audit row and tells the doctor. 409 `INVOICE_STATUS_INVALID` (only `unpaid`, `overdue` and `rejected` invoices can be changed), 422 `ADJUSTMENT_INVALID` (the total must stay above zero), 400 `DUE_DATE_INVALID` (a later date, within a year). An overdue invoice whose new due date has not passed goes back to `unpaid`. Waiving, marking paid and extending also reactivate a doctor suspended only for billing.

### Doctors (AD4, AD5)

- `GET /api/admin/doctors?search&status&specialtyId&governorate&sort=name|newest|sessions|outstanding&page&pageSize` → page of `{ doctorId, fullName, fullNameEn, email, phone, clinicName, clinicNameEn, governorate, specialtyAr, specialtyEn, status, trialEndsAt, createdAt, sessionsThisMonth, outstandingPiasters }`.
- `GET /api/admin/doctors/{id}` (profile), `POST /api/admin/doctors/updateDoctorProfile` `{ doctorId, fullName?, fullNameEn?, title?, titleEn?, licenseNumber?, specialtyId? }`.
- `GET /api/admin/doctors/{id}/activity?month&page&pageSize` (`getDoctorActivity`) → `{ months: [{ monthKey, examinations, consultations, platformFeesPiasters }], month, sessions: page of { id, day, at, type, feePiasters, patientMasked, deleted } }`. Patient names are masked («م*** ح***»); no clinical content and no clinic revenue.
- `GET /api/admin/doctors/{id}/audit?page&pageSize` → `{ deletedSessions: page of { id, day, type, deletedAt, reason, patientMasked }, statusChanges: page of { at, action, actorRole, details } }`.
- `GET /api/admin/doctors/{id}/branches`, `/appointments` (counts per month: `bookings, noShows, cancellations, checkedInNoSession, noShowRate`), `/assistants` (disable and enable through `/api/admin/accounts/{id}/status`), `/notes`; `POST /api/admin/doctors/addDoctorNote` `{ doctorId, text }`; `POST /api/admin/doctors/sendPasswordReset` `{ doctorId }`.
- Invoices and payments tabs use `GET /api/admin/invoices?doctorId=` and `GET /api/admin/payments?doctorId=&status=all`.
- `POST /api/admin/setDoctorStatus` now also takes `status: "disabled"` (with a reason): the doctor and their assistants can't sign in, and every pending or confirmed booking from today on is cancelled by the system and its patient told. A disabled doctor can only be reactivated (`status: "active"`).

### Dashboard (AD1)

`GET /api/admin/dashboard` → `{ doctors: { active, pendingApproval, suspended, disabled, rejected, inTrial }, totalPatients, sessionsToday: { examinations, consultations }, sessionsThisMonth, bookingsToday, noShowRateLast30Days|null (0–1), expectedFeesThisMonthPiasters, lastMonth: { monthKey, invoicedPiasters, collectedPiasters }, outstandingPiasters, overdueDoctors, paymentsToReview, signupsToReview, sessionsPerDay: [30 × { day, examinations, consultations }], invoicedVsCollected: [12 × { monthKey, invoicedPiasters, collectedPiasters }], latestPayments, latestSignups, invoicesDueSoon }`. No clinic revenue.

## Scheduled jobs (spec 9.3, Africa/Cairo)

| Job | When | What |
|---|---|---|
| `monthlyClose` | from 00:05 (the previous month, once a day; a closed month changes nothing) | One invoice per doctor with sessions in the month, from the fee snapshots; `noCharge` when the total is 0; due date = last day of the month + `gracePeriodDays`; notifies the doctor. Fees of sessions saved after an earlier final invoice are added as adjustment lines, also for a doctor with no session this month (api-account-deletion.md, BR-DEL10). |
| `dailyBillingCheck` | 00:10 | Reminders 2 days before and on the due date (once each); `unpaid` / `rejected` invoices past their due date become `overdue` and the doctor is suspended with the reason `billing:{monthKey}`; doctors suspended for billing with nothing overdue are reactivated. `pendingReview` never suspends (BR-G2). |
| `buildDailyMetrics` | 02:30 | Yesterday's `DoctorDailyMetrics` rows per doctor and branch, and any earlier day whose sessions changed in the last two days. |
| `statsReconcile` | 03:00 | Recalculates yesterday's `DailyStats` and the month's `MonthlyStats` from the sessions, corrects drift and writes one audit row per correction. |
| `accountErasure` | 03:30 | Erases the accounts whose deletion grace period has passed; a doctor who still owes an invoice waits (`waitingPayment`). See [api-account-deletion.md](api-account-deletion.md). |

Set `Jobs:Enabled=false` to turn the hosted scheduler off (tests call the jobs directly). `Jobs:BillingIntervalMinutes` (default 5) is how often it checks the clock.

## Error codes (new)

`INVOICE_NOT_PAYABLE`, `INVOICE_STATUS_INVALID`, `PAYMENT_ALREADY_REVIEWED`, `ADJUSTMENT_INVALID`, `DUE_DATE_INVALID`, `TOO_MANY_SCREENSHOTS`. Reused: `DOCTOR_SUSPENDED`, `PERMISSION_DENIED`, `BRANCH_NOT_ALLOWED`, `TRIAL_ENDED`, `REASON_REQUIRED`, `FILE_TOO_LARGE`, `FILE_TYPE_NOT_ALLOWED`, `OUT_OF_RANGE`, `REQUIRED`.
