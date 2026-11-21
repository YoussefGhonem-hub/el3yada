# el3yada API: free trial

Product owner's change (Youssef, 17 Nov). Spec 6.16 has the rules (BR-T1 to BR-T6).

There is **no approval step**: a doctor who completes sign-up is `active` at once, with a free trial of `trialDays` days (14 by default). The admin does nothing. Sessions saved during the trial carry no platform fee.

When the trial ends, the doctor and their assistants can still sign in, but every clinic screen is closed. They see **A15** («انتهت الفترة التجريبية»): a message asking them to contact us, the support contacts, and Sign out. The admin then either activates the service, after which normal per-session fees apply, or extends the trial.

The API checks everything with its own clock on every request. The app never decides on its own clock whether the trial has ended. It uses only the `ended` flag that the API sends.

## The trial object

`trial` appears in the session, in `GET /api/clinic/me` and in the admin's registration views. It is `null` when there is no trial: the doctor's service is active, either because they were approved before this change or because the admin activated it.

```json
"trial": { "endsAt": "2026-12-01T10:04:00.000Z", "ended": false, "daysLeft": 14 }
```

| Field | Meaning |
|---|---|
| `endsAt` | UTC (`Doctors.TrialEndsAt`). Set at sign-up to the sign-up time plus `trialDays` days. |
| `ended` | `true` once `endsAt` is past. |
| `daysLeft` | Whole days left, rounded up; `0` once ended. For a trial ending in 30 hours, `daysLeft` is `2`. |

## Sign-up (`completeDoctorRegistration`)

The request is unchanged (api-phase-1.md). The **201** session now has `doctorStatus: "active"` and a running `trial`, so the app opens the doctor's home, not A6.

- The doctor gets a `doctorWelcome` notification with the trial's length.
- Every admin gets `doctorRegistrationReceived` («طبيب جديد»), for information only.
- `Doctors.ApprovedAt` is the sign-up time, and `ApprovedBy` is `null`.

A6, A7, `resubmitDoctorRegistration` and `reviewDoctorRegistration` stay for doctors who signed up before this change and are still `pendingApproval` or `rejected`. Approving one of them starts their trial.

## Session (auth/me, every sign-in, refresh)

The session object (api-phase-1.md) gains `trial`.

- For a doctor, it is the doctor's own trial.
- For an assistant, it is their doctor's trial.
- For other roles, it is always `null`.

Signing in is never refused because the trial has ended.

**A1 routing:** an active (or suspended) doctor or an assistant whose `trial.ended` is `true` goes to **A15** instead of the shell. A pending or rejected doctor still goes to A6 or A7. Those doctors are not approved yet, so they have no trial anyway.

## Clinic endpoints

When the clinic's trial has ended, **every** clinic endpoint (api-phase-2.md) answers **403 `TRIAL_ENDED`**. The one exception is `GET /api/clinic/me`. This covers the doctor and every assistant, for reads and writes.

`ClinicAttribute` runs its checks in this order:
1. role;
2. doctor or assistant status (`DOCTOR_PENDING_APPROVAL`, `DOCTOR_REJECTED`, `ACCOUNT_DISABLED`, `CLINIC_NOT_ACTIVE`);
3. **`TRIAL_ENDED`**;
4. doctor only;
5. permission;
6. suspension.

On `TRIAL_ENDED`, the app reloads the account (`GET /api/auth/me`), and the router opens A15. The trial can end while someone is using the app; their next request gets this answer.

`GET /api/clinic/me` gains `trial`. **While the trial is running, `fees.examinationFeePiasters` and `fees.consultationFeePiasters` are `0`,** because that is what a session saved now will be charged. In the D8 info endpoint, every type's `platformFeePiasters` is also `0`. With `trial` running, the app shows the fee as «مجاناً (فترة تجريبية)» rather than «0 ج.م».

**`createSession`:** while the trial is running, the fee snapshot (`Sessions.FeePiasters`) is `0` (BR-T3). The session still counts in `DailyStats` and `MonthlyStats`, with a 0 amount. So D1 to D3 show the visits, with 0 fees, and the month's invoice (Phase 7) is `noCharge` when every session was in the trial.

## Admin

### Settings (AD13)

New setting **`trialDays`**: an integer from 1 to 90, default 14. It appears in `GET /api/admin/settings` and `updateSettings` and is logged in `SettingsHistory` like the others. A change affects only doctors who sign up after it; trials already running keep their end date (BR-T2).

### Sign-up requests (AD2, AD3)

- `GET /api/admin/doctorRegistrations`:
  - new query `trial`: `running` or `ended`, which lists only doctors whose trial is in that state;
  - each item gains `trial`.
  - To find a doctor who contacted support after their trial ended: `status=all&trial=ended`, plus `search`.
- `GET /api/admin/doctorRegistrations/{doctorId}` and the doctor's own `GET /api/doctors/myRegistration`: the registration view gains `trial`.
- `reviewDoctorRegistration` with `approve` is only for a doctor who signed up before this change and is still pending. It starts their trial: `endsAt` = now + `trialDays` days. The approval notification says how long the trial lasts.

### `POST /api/admin/activateDoctorService` (any admin)

`{ "doctorId": "…" }`. Ends the trial and turns the service on (BR-T5): `TrialEndsAt` becomes `null`, and per-session fees apply to every session saved from now on. It works whether the trial is running or has ended.

**200** returns `DoctorTrialView`:

```json
{ "doctorId": "…", "fullName": "أحمد سامي عبد الله", "status": "active", "trial": null }
```

- If the service is already active, nothing changes and the answer is 200.
- Writes a `doctorServiceActivated` audit row (`details`: `{ trialEndsAtBefore }`).
- Notifies the doctor and their active assistants: «تم تفعيل الخدمة».
- Their next request works. Their app reloads the account on resume, or after the next 403.

Errors:
- 400 `doctorId`: `REQUIRED`;
- 404 when the ID is not a doctor;
- 409 `DOCTOR_STATUS_NOT_CHANGEABLE` with `status`, when the doctor is not `active` or `suspended`.

### `POST /api/admin/extendDoctorTrial` (any admin)

`{ "doctorId": "…", "days": 7 }`. `days` is from 1 to 90. The new end date is the later of the current `endsAt` and now, plus `days`. So an ended trial restarts from today, and a running one gets longer.

- **200** returns `DoctorTrialView` with the new `trial`.
- Writes a `doctorTrialExtended` audit row (`details`: `{ before, after, days }`).
- Notifies the doctor and their active assistants: «تم مد الفترة التجريبية حتى …».

Errors:
- 400 `doctorId`: `REQUIRED`;
- 400 `days`: `REQUIRED`, `OUT_OF_RANGE`;
- 404;
- 409 `DOCTOR_STATUS_NOT_CHANGEABLE` with `status`, as above;
- 409 **`SERVICE_ALREADY_ACTIVE`**: the doctor has no trial, because the service is on.

## Error codes

| Code | HTTP | Where | Meaning |
|---|---|---|---|
| `TRIAL_ENDED` | 403 | every clinic endpoint except `clinic/me` | The clinic's free trial has ended. Reload the account; the app shows A15. |
| `SERVICE_ALREADY_ACTIVE` | 409 | `extendDoctorTrial` | The doctor's service is already active; there is no trial to extend. |

## Reminders before the end (`trialReminders`, BR-T6 [S])

A daily job in `BillingJobsHost` (10:00 Cairo, so the push arrives in the day) notifies the doctor and their active assistants. It counts days like `trial.daysLeft` and the banner:

| Type | When | To the doctor | To each active assistant |
|---|---|---|---|
| `trialEndingSoon` | 3 days left or fewer (`daysLeft` 2 or 3) | «باقي 3 أيام على نهاية الفترة التجريبية المجانية. تواصل معنا لتفعيل الخدمة ومواصلة استخدام العيادة.» | «باقي … على نهاية الفترة التجريبية لعيادة د. …. اطلب من الطبيب التواصل معنا لتفعيل الخدمة.» |
| `trialLastDay` | less than a day left | «تنتهي الفترة التجريبية المجانية خلال 24 ساعة. تواصل معنا …» | «تنتهي الفترة التجريبية لعيادة د. … خلال 24 ساعة. اطلب من الطبيب …» |

- Both languages are stored; the push goes in the recipient's language. They are not gated by the reminders switch: like a suspension, they are about the service itself.
- `route`: `/doctor/settings` or `/assistant/settings`, which have the support contact. After the end, the app sends doctors and assistants to A15 from any route. `data`: `{ doctorId, trialEndsAt, daysLeft }`.
- Idempotent without a new table: a recipient who already has a notification of that type since the window opened (3 days, or 1 day, before the trial's current end) is skipped, so a restart or a second run the same day sends nothing. An extended trial (BR-T5) moves the windows, so it gets its reminders again. Each doctor is handled under a lock on their row.
- Only doctors who are `active` or `suspended` with an active account; ended trials get nothing (A15 takes over).
