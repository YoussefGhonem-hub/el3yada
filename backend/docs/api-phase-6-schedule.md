# el3yada API: branch schedule contract (D29 schedule tabs, AS17)

`updateBranchSchedule` (spec 9.1) is the one way to change a branch's working hours, special dates, closures and booking settings. The app's D29 Working hours, Special dates and Booking settings tabs, and AS17 for an assistant with `scheduleManage`, build against this page. Conventions, errors and tokens are as in [api-phase-1.md](api-phase-1.md); the branch's other D29 tabs are in [api-phase-2-clinic.md](api-phase-2-clinic.md). The code (`Features/Appointments/ScheduleService.cs`) is the source of truth. When this page and the code differ, fix this page.

- [Who may call](#who-may-call)
- [GET the schedule](#get-apistaffbranchesbranchidschedule)
- [PUT the schedule](#put-apistaffbranchesbranchidschedule)
- [Working hours rules](#working-hours-rules)
- [Affected bookings (BR-AP12)](#affected-bookings-br-ap12)
- [Errors](#errors)
- [Audit and notifications](#audit-and-notifications)
- [Public holidays (AD13) [C]](#public-holidays-ad13-c)

## Who may call

| Endpoint | Doctor | Assistant |
|---|---|---|
| `GET /api/staff/branches/{branchId}/schedule` | ✔ | `appointmentsView`, in their branches |
| `PUT /api/staff/branches/{branchId}/schedule` | ✔ | `scheduleManage`, in their branches |

- Another branch (the assistant's other branches, another doctor's): 403 `PERMISSION_DENIED`. Patients and admins: 403.
- The clinic's free trial and status are checked as for every staff endpoint: 403 `TRIAL_ENDED`, `CLINIC_INACTIVE`. A suspended clinic can still change its schedule (BR-G5 doesn't block it), and moving its existing bookings is allowed (BR-AP17).
- `POST /api/branches/updateBranchHours` (Phase 2) is retired: it applied new hours without looking at bookings.

## `GET /api/staff/branches/{branchId}/schedule`

```json
{
  "branchId": "…",
  "weekly": [
    { "weekday": 6, "start": "10:00:00", "end": "14:00:00", "endsNextDay": false, "label": "صباحي", "capacity": 25 },
    { "weekday": 6, "start": "20:00:00", "end": "01:00:00", "endsNextDay": true, "label": "مسائي", "capacity": null }
  ],
  "dateOverrides": [
    { "date": "2026-11-28", "periods": [ { "start": "18:00:00", "end": "21:00:00", "endsNextDay": false, "label": null, "capacity": null } ] },
    { "date": "2026-12-05", "periods": [] }
  ],
  "closures": [
    { "id": "…", "fromLocal": "2026-12-10T00:00:00", "toLocal": "2026-12-13T00:00:00", "reason": "إجازة", "allBranches": true }
  ],
  "settings": {
    "mode": "queue", "slotMinutes": 15, "examSlots": 1, "consultationSlots": 1, "defaultCapacity": 30, "avgVisitMinutes": 10,
    "selfBooking": true, "autoConfirm": true, "windowDays": 30, "minNoticeMinutes": 60, "sameDay": true, "freeCancelMinutes": 120,
    "maxReschedules": 2, "maxUpcomingPerPatient": 1, "noShowLimitCount": 3, "noShowLimitDays": 90, "reminderMinutes": [1440, 120],
    "staffOverbooking": true, "waitingOrderByArrival": false
  },
  "holidays": [ { "date": "2026-12-25", "nameAr": "عيد الميلاد المجيد", "nameEn": "Christmas" } ]
}
```

- `weekly`: ISO weekdays (1 = Monday … 7 = Sunday). A period that ends after midnight has `endsNextDay` and belongs to the day it starts (BR-AP19).
- `dateOverrides`: special hours from today on. They replace that date's weekly hours; no periods means closed that day.
- `closures`: closures and blocked time that haven't ended, in Cairo local time (`toLocal` is exclusive). `allBranches` closures (a vacation) belong to the doctor and show on every branch's schedule.
- `settings`: spec 6.12.2.
- `holidays` [C]: the [public holidays](#public-holidays-ad13-c) of the coming year, earliest first. They are suggestions only; send a closure to close on one.

## `PUT /api/staff/branches/{branchId}/schedule`

The body is the whole schedule, in the shape `GET` returns, plus `dryRun` and `decisions`:

```json
{
  "weekly": [ … ], "dateOverrides": [ … ], "closures": [ … ], "settings": { … },
  "dryRun": true,
  "decisions": []
}
```

Everything is replaced: the weekly periods, the special dates from today on (past ones are kept), and the closures that haven't ended for this branch and the doctor's all-branch ones. A D29 tab that saves only its own part sends the others as they are saved.

1. Send it with `dryRun: true`. Nothing changes. **200** `{ "applied": false, "conflicts": [ … ] }` lists the [affected bookings](#affected-bookings-br-ap12).
2. If `conflicts` is empty, send it again with `dryRun: false`. Otherwise open the conflicts sheet, then send it with a decision for each listed booking. **200** `{ "applied": true, "conflicts": [ … ] }`.

The change and every decision are applied in one transaction: if one move fails, nothing changes.

## Working hours rules

The D29 rules (spec section 11, BR-BR2), the same as `WeeklyHours` in the app:

- A period ends after it starts, or has `endsNextDay: true` (20:00–01:00).
- It lasts 15 minutes to 16 hours.
- No two periods overlap. Overlaps are checked on the real week: Saturday 20:00–01:00 (next day) overlaps Sunday 00:30–03:00, and Sunday night runs into Monday morning. Periods that touch (14:00 and 14:00) are fine.
- At most 10 periods a day. `label` is optional (≤ 30, for example صباحي / مسائي; trimmed, empty is `null`). `capacity` is optional (1–200; `null` uses `defaultCapacity`).
- "Copy Saturday to all days" is done in the app: send the copied periods.
- A special date's periods follow the same rules, on that one day.

Order, length and overlaps are checked once every weekday is readable, so fix the field errors first.

## Affected bookings (BR-AP12)

A booking is affected when it is `pending` or `confirmed`, starts in the future, and the new schedule has no place for it: its period (queue mode) or slot (timed mode) is gone, the booking mode changes, or a closure covers it. A new all-branch closure also affects the doctor's other branches.

```json
{
  "appointmentId": "…", "displayName": "منى حسن", "date": "2026-11-28", "time": "20:30:00", "queueNumber": null,
  "status": "confirmed", "branchId": "…", "visitType": "examination",
  "suggestion": { "branchId": "…", "date": "2026-11-28", "time": "19:00:00" }
}
```

- `time`: the booked time (timed mode) or the period start (queue mode), Cairo.
- `suggestion`: the nearest free place under the **new** schedule in the booking's own branch: the same day first, then up to 14 days later, the period or slot closest to the booked time. Suggestions in one answer never take the same slot twice, and never fill a period past its capacity. `null` when there is none (or the booking is in another branch).

A decision for each listed booking:

| `action` | Fields | What happens |
|---|---|---|
| `keep` | | The booking stays where it is, as an exception. |
| `move` | `date`, `time`, optional `branchId` (default: the booking's branch) | A clinic reschedule (BR-AP6): the place is checked like a staff booking under the new schedule, the history says `rescheduled` with the reason `scheduleChange`, and the patient is notified of the new time. |
| `cancel` | | `cancelled` by the clinic with the reason `scheduleChange`; the patient is notified with a rebook link. |

```json
{
  "decisions": [
    { "appointmentId": "…", "action": "keep" },
    { "appointmentId": "…", "action": "move", "date": "2026-11-28", "time": "19:00" },
    { "appointmentId": "…", "action": "cancel" }
  ]
}
```

- "One action for all" is done in the app: send the same action for each (for `move`, each booking's `suggestion`).
- A booking that isn't listed (any more) can't be decided on: its decision is ignored.
- A booking made between the dry run and the save, and now affected, has no decision: the answer is 409 `SCHEDULE_CONFLICTS` with the bookings still to decide, and nothing changes.

## Errors

| Errors | |
|---|---|
| 400 | `weekly`, `dateOverrides`, `closures`: `REQUIRED`; `weekly`: `INVALID_VALUE` (more than 10 periods a day); `weekly[i]`: `PERIODS_OVERLAP` (on the later period); `weekly[i].weekday`, `weekly[i].capacity`: `OUT_OF_RANGE`; `weekly[i].end`: `PERIOD_END_BEFORE_START`, `PERIOD_LENGTH_OUT_OF_RANGE`; `weekly[i].label`: `TOO_LONG`; the same under `dateOverrides[i].periods[j]`; `closures[i]`: `INVALID_RANGE` (ends before it starts); `mode`: `INVALID_MODE`; the settings: `INVALID_RANGE`; `decisions[i].action`: `INVALID_ACTION`; `decisions[i].date`, `decisions[i].time`: `REQUIRED` for `move` |
| 403 `PERMISSION_DENIED` | not `scheduleManage`, or not one of the caller's branches |
| 404 `NOT_FOUND` | the branch doesn't exist |
| 409 `SCHEDULE_CONFLICTS` | affected bookings without a decision; `details.conflicts` lists them (the same shape as above) |
| 409 from a `move` | `SLOT_TAKEN`, `PERIOD_FULL`, `OVERBOOKING_WARNING` (staff overbooking needs the warning, so pick another place), `OUTSIDE_HOURS`, `BRANCH_CLOSED`, `TOO_SOON`: the new place can't take the booking; nothing changes |

## Audit and notifications

- One `branchScheduleUpdated` row in the clinic's log (D27), target `branch`, with `periods`, `overrides`, `closures` (how many), `mode`, and the affected bookings `kept`, `moved`, `cancelled`.
- A moved booking: `bookingRescheduled` to the patient («تم تغيير موعدك»), and an `appointment.rescheduled` audit row.
- A cancelled booking: `bookingCancelled` to the patient («تم إلغاء موعدك — احجز موعداً جديداً», route `/patient/appointments/book`).
- The live board of every branch and day touched is published again.

## Public holidays (AD13) [C]

BR-AP13: "Suggested Egyptian public holidays from a list the admin manages." The admin keeps the list in AD13; D29's Special dates tab shows the coming ones (`holidays` above) with "Close this day", which adds a whole-day closure for the branch (or every branch) and saves it like any closure, with the conflicts check. A holiday on the list closes nothing by itself, and patients see nothing until a branch closes.

| Endpoint | Who | |
|---|---|---|
| `GET /api/admin/publicHolidays` | admin | Every holiday from a month ago on, earliest first: `[{ id, date, nameAr, nameEn }]` |
| `POST /api/admin/createPublicHoliday` | admin | `{ date, nameAr, nameEn }` (names required, ≤ 100). **201** with the holiday. One holiday a date: 409 `PUBLIC_HOLIDAY_EXISTS` |
| `POST /api/admin/deletePublicHoliday` | admin | `{ id }`. **204**; 404 `NOT_FOUND`. Closures clinics already added stay |

Audit: `publicHolidayCreated`, `publicHolidayDeleted` (target `settings`, with `date` and `nameAr`). Clinic callers, patients: 403.
