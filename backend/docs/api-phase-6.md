# API contract: Phase 6 (appointments and the live board)

The app builds against this file. Names follow spec section 9.1. Dates are Cairo dates (`yyyy-MM-dd`), times of day are Cairo wall-clock (`HH:mm:ss`), instants are UTC ISO 8601. Errors are `application/problem+json` with a `code` (spec 6.12.6, plus `ALREADY_HANDLED`, `INVALID_TRANSITION`, `OVERBOOKING_WARNING`, `GUEST_NEEDS_ACCOUNT`, `BUSY`). Every endpoint answers 401 without a token and 403 for the wrong role.

| Area | Routes | Caller |
|---|---|---|
| Patient (P15–P17) | `/api/patient/…` | patient, only with doctors they are linked to |
| Staff (D29–D34, AS13–AS17) | `/api/staff/…` | doctor, or assistant with `appointmentsView` (reads) / `appointmentsManage` (changes) in that branch; `scheduleManage` for the schedule |

## How the queue works (BR-AP3, product owner 17 Nov)

Queue mode (`bookingMode: "queue"`, the default):

1. **A booking only takes a place on the period's list.** `createAppointment` and `rescheduleAppointment` check the capacity (`PERIOD_FULL`; staff get `OVERBOOKING_WARNING` and may pass `overbook: true`) and return `queueNumber: null`. Booked patients have no number before they arrive.
2. **The number is given at check-in, in order of arrival.** `checkInAppointment` gives the period's next number. It runs in one transaction that first locks the period's `BranchDayStates` row (`UPDLOCK, HOLDLOCK`, the row is created if missing), so two check-ins at the same moment never get the same number; the unique index `UQ_Appointments_QueueNumber` is the second guard.
3. **Walk-ins** (`addWalkIn`) are checked in on creation and take the next number the same way, in the current period (or the next one today, or the last one).
4. **Numbers are never reused.** The next number is one more than the highest the period has given; a patient who left without being seen keeps theirs. **Undoing a no-show** (`undoNoShow`, same day) checks the patient in again with a **new** number.
5. **Priority** (`movePriority`, with a reason) keeps the number and only changes the order: priority patients go first.

Example (AC-21): A books Saturday evening at 9:00, B at 11:00. B is checked in at 18:05 and gets 1, A at 18:20 gets 2, a walk-in at 18:25 gets 3.

Timed mode (`"timed"`) is unchanged: the booked time sets the order and there are no numbers.

## Patient (P15–P17)

| Method and route | Name | Notes |
|---|---|---|
| `GET /api/patient/doctors/{doctorId}/booking-options` | `getBookingOptions` | P15 steps 1–3: branches (with `mode`), visit-type rule, prices, `upcomingAppointmentId` |
| `GET /api/patient/availability?branchId&visitType&from&to` | `getPatientAvailability` | Server-side only (BR-AP1). Queue: `periods[]` with `capacity, booked, remaining, unavailable` and no time estimate (the turn and its estimate come at check-in, BR-AP3); timed: `slots[]` |
| `GET /api/patient/appointments?tab=upcoming\|past\|cancelled` | `getMyAppointments` | `Appointment[]` (P16, P1) |
| `GET /api/patient/appointments/{id}` | `getMyAppointment` | `Appointment` with `history` (P17) |
| `POST /api/patient/appointments` | `createMyAppointment` | `{ branchId, visitType, date, time, reason }`; queue: `time` = the period start |
| `POST /api/patient/appointments/{id}/reschedule` | `rescheduleMyAppointment` | `{ branchId, date, time }` |
| `POST /api/patient/appointments/{id}/cancel` | `cancelMyAppointment` | `{ reason }` |

## Staff

| Method and route | Name |
|---|---|
| `GET /api/staff/branches`, `GET`/`PUT /api/staff/branches/{id}/schedule` | `getStaffBranches`, `getBranchSchedule`, `updateBranchSchedule` |
| `GET /api/staff/availability` | `getStaffAvailability` |
| `GET /api/staff/appointments` (search), `GET /api/staff/appointments/{id}` | `searchAppointments`, `getAppointment` |
| `POST /api/staff/appointments` | `createAppointment` — `{ branchId, patientId \| guest: { name, phone }, visitType, date, time, reason, staffNotes, overbook, confirmWarnings }` |
| `POST /api/staff/appointments/{id}/reschedule \| cancel \| confirm \| reject` | `rescheduleAppointment`, `cancelAppointment`, `confirmAppointment`, `rejectAppointment` |
| `POST /api/staff/appointments/{id}/check-in` | `checkInAppointment` — today only; gives the queue number (above) |
| `POST /api/staff/appointments/{id}/no-show \| undo-no-show \| left-without-seen` | `markNoShow`, `undoNoShow`, `markLeftWithoutSeen` (`{ reason }`) |
| `POST /api/staff/appointments/{id}/call-in \| send-back` | `callIn`, `sendBackToWaiting` |
| `POST /api/staff/appointments/{id}/priority` | `movePriority` — `{ reason }` (required) |
| `POST /api/staff/appointments/{id}/convert-guest` | `convertGuest` — `{ patientId }` |
| `PUT /api/staff/patients/{patientId}/self-booking` | `setSelfBooking` — `{ enabled, reason }` |
| `GET /api/staff/board?branchId&date` | `getBoard` — `BoardSnapshot` |
| `GET /api/staff/board/{appointmentId}/summary` | `getBoardPatientSummary` — the side panel, never mirrored |
| `POST /api/staff/board/walk-in` | `addWalkIn` — `{ branchId, patientId \| guest, visitType, staffNotes }` |
| `POST /api/staff/board/call-next?branchId` | `callNext` [S] — calls in the first waiting card; 204 when nobody waits |
| `POST /api/staff/board/cancel-rest-of-day`, `POST /api/staff/board/delay` | `cancelRestOfDay` → `{ cancelled }`, `sendDelayNotice` [S] → `{ notified }` |

Two people acting on one card: the first wins; the second gets 409 `ALREADY_HANDLED` with `details: { status, action, by, at }` (BR-LB4). Check-in reads the booking again after locking the period, so a second check-in of the same card always gets this answer.

## `Appointment`

`id, doctorId, doctor, branchId, branch, patientId, displayName, phone (staff only), isGuest, visitType, mode, date, time, startUtc, endUtc, queueNumber, status, source, bookedByRole, bookedByName (staff only), reason, staffNotes (staff only), overbooked, rescheduleCount, checkedInAt, calledAt, sessionId, cancelReason, cancelledByRole, isPriority, flaggedNoSession, createdAt, canChange, nowServing, estimatedTime, history, branchPhones, ahead, estimatedWaitMinutes`.

Queue mode:

- `queueNumber` is `null` until check-in (`pending`, `confirmed`, and a `noShow` that never arrived). From check-in on it is the patient's turn.
- `nowServing`: on the booking's day, the number last called in to the doctor in that period, or `null`.
- `ahead`, `estimatedWaitMinutes`, `estimatedTime`: only while `checkedIn`, else `null`. `ahead` counts the checked-in patients of the same period who go in first: priority patients, then lower numbers; patients with the doctor are not counted. `estimatedWaitMinutes` = `ahead` × the branch's average visit time (spec 6.12.2, `avgVisitMinutes`, default 10). `estimatedTime` = now (or the period start, if later) + that wait, Cairo time.

## `BoardSnapshot` (D34; SignalR `boardChanged`, Firestore `liveBoards/{branchId}_{date}`)

`{ doctorId, branchId, date, mode, nowServing, delayMinutes, counts: { expected, waiting, withDoctor, done, missed }, entries: [BoardEntry], nextNumbers: [int], updatedAt }`

`BoardEntry`: `appointmentId, queueNumber, timeLocal, stage, displayName, visitType, source, isNewPatient, lastVisitDate, lastVisitType, flags: { priority, walkIn, late, guest, consultationNotAllowed, hasNotes, pending }, checkedInAt, calledAt, order, status, patientId, sessionId, createdAt`. No phone numbers, no medical data (AC-25).

`entries` come in board order and `order` is the card's place on the whole board (0, 1, 2 …), so a Firestore listener sorts by it:

- columns in the order `expected`, `waiting`, `withDoctor`, `done`, `missed`;
- **Expected**, queue mode: by booking time (`createdAt`), with `queueNumber: null` (the card shows «محجوز»); timed mode: by time;
- **Waiting**: priority first, then each period's line by `queueNumber` (the order of arrival); timed mode by time, or by arrival when the branch has `waitingOrderByArrival`;
- **With the doctor**: by when they went in.

`nextNumbers`: the first five numbers of the Waiting column, in its order (D36). `nowServing`: the last number called in today (from the period rows that have one), else the number with the doctor. SignalR `queueChanged` (group `queue:{branchId}`, anyone signed in, no names) carries `{ branchId, date, nowServing, delayMinutes, nextNumbers }`; Firestore `liveQueues/{branchId}_{date}` the same.

## Notifications (spec 10.1, BR-AP16)

| Type | When | Text (AR) |
|---|---|---|
| `bookingConfirmed` | booked with auto-confirm, by staff, or confirmed | «تم تأكيد حجزك» — «السبت 22 نوفمبر، الفترة المسائية من 6 مساءً — الدور بأسبقية الحضور» (queue) / «… الساعة 6:15 مساءً» (timed) |
| `bookingReminder` | 24 h before, and on the day 2 h before the period (queue) or the time (timed). A reminder whose time has passed when the booking is made, or moved, is skipped: a booking made 1 hour before gets none. | Queue, on the day: «اليوم موعدك في فرع المعادي، الفترة المسائية من 6 مساءً. الدور بأسبقية الحضور: سجّل حضورك في الاستقبال عند وصولك.» Timed: «تذكير: موعدك اليوم الساعة 6:15 مساءً — فرع المعادي». The day before: «تذكير: موعدك غداً …» |
| `checkedIn` | queue mode, at check-in, walk-in and undone no-show; patients with an account (a guest is told at the desk) | «تم تسجيل حضورك» — «دورك رقم 7، وقبلك 3 مرضى. الانتظار المتوقع حوالي 30 دقيقة» («دورك رقم 7، وأنت التالي» with nobody ahead). `data: { appointmentId, queueNumber, ahead, waitMinutes }` |
| `nextInLine` [S] | queue mode, when someone goes in (`callIn`, `callNext`): the next checked-in patient of that period (priority first, then by number), once per booking | «دورك التالي» — «دورك رقم 8: استعد للدخول للطبيب» |

Each has `route: /patient/appointments/{id}`. `turnComing` («باقي 3 أدوار على دورك») exists as a type but is not sent: the spec gives no trigger for it.

The period is named by its start: «الفترة الصباحية» before 15:00, «الفترة المسائية» from 15:00 (as the search filter, 6.12.8).

## Database

Migration `QueueNumberAtCheckIn` (no new column):

- `CK_Appointments_Queue` lets a `confirmed` or `noShow` queue booking have no number; `checkedIn`, `withDoctor` and `completed` queue bookings must have one.
- Data: queue bookings still `pending` or `confirmed` lose the number they got at booking (and their board order goes back to 0, unless staff moved them up). They get a number when checked in.
- Down gives a number back, after the period's highest, in booking order, to every queue booking the old rule needs one for.

The dev command `add-booking` follows the same rule: a confirmed place on the 10:00 period's list, without a number.
