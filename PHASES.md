# el3yada: Delivery phases

The team (Youssef, Amr and Mohamed Gomaa) works through these phases together, in order. Each phase lists what to build in the **API** (ASP.NET Core + SQL Server) and in the **app** (one Flutter codebase), the tables it uses, and the checks that close it.

- Screen IDs (A, D, AS, P, AD) and rule IDs (BR-…) point to [spec.md](spec.md). Acceptance checks (AC-…) are in spec section 14.
- **[M]** must have, **[S]** should have, **[C]** could have. A phase can close with open [S] and [C] items. Note them in the phase's checklist.
- Every table already exists in [database/schema.sql](database/schema.sql). "Tables" below means the tables the phase reads and writes, not tables to create.
- Tick a box only when the item works on **Android and Windows**, in **Arabic and English**, and in **light and dark**.

| Phase | Scope | Main screens |
|---|---|---|
| [0](#phase-0-setup-and-checks) | Setup and checks | – |
| [1](#phase-1-sign-in-and-admin-basics) | Sign-in and admin basics | A1–A14, AD2, AD3, AD13–AD15, AD18 |
| [2](#phase-2-patients-sessions-branches-and-assistants) | Patients, sessions, branches, assistants | D1–D9, D22, D24–D29, D37, AS1–AS5, AS12, AS19 |
| [3](#phase-3-files-prescriptions-and-catalogs) | Files, prescriptions, catalogs | D0, D10–D15, D23, AS6–AS8, AD19, AD20 |
| [4](#phase-4-patient-app) | Patient app | P1–P10, P14, AD11, AD12 |
| [5](#phase-5-chat-and-notifications) | Chat and notifications | D16, D17, D21, AS9, AS11, P11–P13, AD16, AD17 |
| [6](#phase-6-appointments-and-the-live-board) | Appointments and the live board | D29 (schedule tabs), D30–D34, D36, AS13–AS17, P15–P17 |
| [7](#phase-7-billing-and-analytics) | Billing and analytics | D1 (analytics), D18–D20, D35, AS10, AS18, AD1, AD4–AD10 |
| [8](#phase-8-hardening-and-release) | Hardening and release | All |

---

## How we work

These rules keep three people's code consistent. Change them only by agreement.

**Code and branches**
- `main` is always working. Work on a branch named after the screen or task, for example `feature/D8-new-session` or `api/createSession`. Merge through a pull request that another team member reviews.
- Before opening a pull request: `flutter analyze` is clean, `flutter test` passes, and the API tests pass.
- One Flutter codebase for every platform. **Each screen is built once** and adapts to phone (< 600 px), tablet (600–1024) and desktop (> 1024), as in spec section 4. Don't make separate phone and desktop copies of a screen.
- App structure follows [app/README.md](app/README.md): each feature has `domain/`, `data/`, `application/` and `presentation/`. No hard-coded text (ARB files, both languages) and no hard-coded colours (theme tokens).

**API**
- One ASP.NET Core solution in `backend/` in this repo (created in Phase 0).
- Endpoint names follow spec section 9.1 (`createSession`, `createAppointment` …), so the spec, the API and the app use the same words.
- Every write validates its input (FluentValidation, rules from spec section 11) and checks role, status and assistant permissions from the database (spec 9.4).
- Error responses use the codes in the spec (`CONSULTATION_REQUIRES_EXAM`, `DOCTOR_SUSPENDED`, the booking codes in 6.12.6). The app maps each code to an ARB message.
- Every sensitive action writes a row in `AuditLogs`.

**Database**
- The EF Core model and migrations in `backend/src/El3yada.Data` are the source of truth. Change a table by changing the entity and adding a migration (`dotnet ef migrations add <Name>`), with the matching update to spec section 8. Announce it to the team before you merge it. Steps in [backend/README.md](backend/README.md#changing-the-database).
- Never edit a migration that is already on `main`. After pulling, run `dotnet ef database update`.
- Conventions (names, piasters, UTC, Cairo dates, enums as strings) are at the top of `database/schema.sql`, which is kept as the original design.

---

## Phase 0: Setup and checks

**Goal:** everyone can run the API, the database and the app locally, and the risky platform pieces are proven before features depend on them.

**Already done**
- [x] Flutter app skeleton: sign-in screen with dev accounts, per-role navigation (phone, tablet and desktop layouts), Arabic/English with RTL, light/dark themes from colour tokens, tests. See [app/README.md](app/README.md).
- [x] Database design: [database/schema.sql](database/schema.sql) (55 tables) and [database/seed.sql](database/seed.sql) (settings and specialties).
- [x] Backend solution in [backend/](backend/README.md): ASP.NET Core Web API (.NET 10), EF Core model for all 55 tables, migrations `InitialCreate` and `SeedReferenceData`, `GET /api/health`, OpenAPI document, and data tests. The migrated database was compared with `schema.sql` object by object (tables, columns, defaults, keys, foreign keys, checks, indexes) and matches.

**Database**
- [ ] Each person runs `dotnet tool restore` and `dotnet ef database update` to create `el3yada_dev` locally ([backend/README.md](backend/README.md)).
- [ ] Shared `dev` and `prod` SQL Server databases on the host, in a region close to Egypt. Daily backups.

**API**
- [ ] Add Serilog and FluentValidation.
- [ ] `dev` and `prod` environments (connection strings, JWT keys, file storage path) outside the repo.
- [ ] File storage service behind the API: upload, download and thumbnail, using the paths in spec section 8. Files are never public URLs.
- [ ] CI: build and test the API and the app on every pull request.

**App**
- [ ] Flutter flavors for `dev` and `prod`, wired to `config/dev.json` and `config/prod.json`.
- [ ] Bundle the Arabic + Latin font (IBM Plex Sans Arabic or Cairo) and set `AppTheme.fontFamily`.
- [ ] Add `freezed` + `json_serializable` for API models.

**Checks (do these before Phase 1 features depend on them)**
- [ ] **Windows release build:** HTTPS login, token refresh, file upload and a SignalR connection all work (spec section 13).
- [ ] **Firestore on Windows:** custom-token sign-in and live updates in a release build. If it falls short, Windows uses the 15-second API refresh (spec 9.6).
- [ ] **Scanner prototype** on Android and iOS (cunning_document_scanner or equivalent).
- [ ] **Arabic PDF prototype:** an A5 prescription with Arabic and English text renders, prints and shares correctly.
- [ ] **Local catalog search:** drift + SQLite FTS5 with Arabic search works on Android, iOS and Windows.

**Done when:** all three of us run the app against our local API and database, and every check above has a result written down.

---

## Phase 1: Sign-in and admin basics

**Goal:** every role can sign in, doctors can register and be approved, and the admin can manage settings and admins.

**API**
- [ ] `login` (email or Egyptian mobile; patient + assistant on the same number asks "log in as"), access + refresh tokens, `refresh`, `logout` (removes the device's push token), rate limiting.
- [ ] Password rules: `mustChangePassword`, set new password (A9), password change signs out other devices (`SecurityStamp`).
- [ ] Forgot password (A8): email reset link for doctors and admins (`UserTokens`); phone request for patients and assistants notifies their doctor (`requestPatientPasswordReset`). Same answer whether or not the account exists.
- [ ] `completeDoctorRegistration` (A4, with the first branch), license upload, `pendingApproval` status.
- [ ] `reviewDoctorRegistration` (approve / reject with reason), `createAdmin`, `setAdminRole`, disable admin.
- [ ] `updateSettings` with range checks and `SettingsHistory`. Public settings endpoint (version, maintenance, support, terms).
- [ ] One-time command to create the first super admin (`dotnet run -- seed-admin <email>`).
- [ ] Audit log foundation: one helper that every endpoint uses to write `AuditLogs`.

**App**
- [ ] A1 Splash routing by session, role and status; A2 language choice on first launch.
- [ ] A3 Login against the real API (replace `FakeAuthRepository` in prod builds), A4 registration (4 steps), A5 verify email [S].
- [ ] A6 pending, A7 rejected (edit and resubmit), A8 forgot password, A9 set new password, A10 disabled, A11 force update, A12 terms, A13 maintenance, A14 patient on desktop.
- [ ] Token refresh on 401 in the API client (TODO in `AuthInterceptor`).
- [ ] AD2 sign-up requests, AD3 sign-up review, AD13 settings, AD14 admin users, AD15 audit log, AD18 admin profile.

**Tables:** Users, UserDevices, RefreshTokens, UserTokens, Doctors, DoctorExtraSpecialties, Branches, BranchPhones, Specialties, AppSettings, SettingsHistory, AuditLogs.

**Done when:** a doctor registers, the admin approves them, and they reach the doctor home. A rejected doctor sees the reason and can resubmit. A patient on Windows is refused with A14. Every A screen works in both languages and both themes.

---

## Phase 2: Patients, sessions, branches and assistants

**Goal:** a doctor and their assistants can run a clinic day without appointments: add patients, record examinations and consultations, and see today's and this month's platform fees.

**API**
- [ ] `createPatient` (link an existing number with BR-P3, file number, temporary password shown once), `updatePatientPhone`, `resetPatientPassword`, archive [S].
- [ ] Medical profile read and update (allergies, chronic diseases, medications, surgeries, family history, notes).
- [ ] `createSession` in one transaction: consultation rule (BR-S2, BR-S3), fee snapshot, visit price, amount charged, branch, link counters, `DailyStats` and `MonthlyStats`, patient notification. Error codes `CONSULTATION_REQUIRES_EXAM`, `DOCTOR_SUSPENDED`, `NOT_LINKED`.
- [ ] Session clinical fields update (doctor only), private notes, `deleteSession` (BR-S7, soft, recalculates the link).
- [ ] `createBranch`, `updateBranch`, `setBranchStatus` (info, address, contact, weekly working hours), `updatePrices` with `PriceHistory`.
- [ ] `createAssistant`, `updateAssistant` (presets, permission dependencies), `resetAssistantPassword`, `setAssistantStatus`, `getClinicActivity`.
- [ ] Assistant permission checks in **every** endpoint, read from the database on each request.
- [ ] `getPatientsRegister` (D4) with search (Arabic letter variants), filters, sorting and paging.
- [ ] **API authorization tests** for every role and every assistant permission. Phase 2 does not close without them.

**App**
- [ ] Current-branch picker in the top bar (BR-BR3).
- [ ] D4 patients register (cards on phone, table on desktop, master-detail on desktop), D5 add patient, D6 patient profile, D7 edit patient and medical profile.
- [ ] D8 new session (type cards, consultation rule message, fee confirmation, amount charged), D9 session details.
- [ ] D1 dashboard (fee cards and suspension banner only; analytics come in Phase 7), D2 today's sessions, D3 monthly summary.
- [ ] D22 profile (personal and professional info; the prescription header comes in Phase 3), D24 settings, D37 visit prices.
- [ ] D28 branches, D29 branch editor (Info, Address and map, Contact, Working hours tabs).
- [ ] D25 assistants, D26 add / edit assistant, D27 activity log.
- [ ] Assistant screens AS1 (home without the live board), AS2–AS5, AS12, AS19, with every item the assistant can't use hidden.

**Tables:** Patients, DoctorPatients, PatientMedicalProfileItems, Sessions, SessionPrivateNotes, DailyStats, MonthlyStats, Branches, BranchPhones, BranchPeriods, PriceHistory, Assistants, AssistantBranches, AuditLogs, Notifications (rows only; delivery comes in Phase 5).

**Done when:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-10, AC-11, AC-19 and the branch parts of AC-20 pass.

---

## Phase 3: Files, prescriptions and catalogs

**Goal:** doctors scan and upload medical files, write prescriptions and lab/radiology requests with specialty-based search, and print or send them.

**API**
- [ ] Authenticated upload and download for medical records (size limit `MaxUploadMb`, thumbnails, soft delete).
- [ ] Prescription drafts (create, edit, reorder items), `submitDraftForReview` [S], `sendPrescription` (needs the uploaded PDF), `cancelPrescription`, "issue new copy".
- [ ] `rxLink` (`GET /rx/{shortCode}`) for the QR code: App Links / Universal Links and store redirect; never shows content without sign-in.
- [ ] Doctor item history ("used before") and templates [S].
- [ ] Prescription header and print settings in the doctor profile (logo, signature, names, colour, paper, margins).
- [ ] `publishCatalog`, catalog version download, `CatalogCustomItems` sync, `reportCatalogItem` [S], specialty profiles.
- [ ] Catalog builder (spec 9.5 and Appendix A), including `class-to-group.csv` and `aliases.csv`. This is the biggest manual task, so start it early in the phase.

**App**
- [ ] D10 scan (mobile only), D11 upload (drag and drop on desktop), D12 file viewer (black background, zoom, PDF).
- [ ] D13 medication editor and D14 investigations editor with catalog search sections (BR-CAT4–CAT8), D15 preview and send (PDF, print, print all, share).
- [ ] D22 prescription header and print settings with live preview and test print. D23 templates and favourites [S].
- [ ] D0 preparing the catalog (download with progress, works in the background).
- [ ] AS6 files, AS7 draft editor [S], AS8 sent prescription (print and share only).
- [ ] AD19 specialty profiles, AD20 catalogs.

**Tables:** MedicalRecords, MedicalRecordAttachments, Prescriptions, PrescriptionMedicationItems, PrescriptionInvestigationItems, PrescriptionTemplates, DoctorItemHistory, Doctors (Rx* columns), CatalogVersions, CatalogCustomItems, CatalogReports, Specialties, SpecialtyProfileItems.

**Done when:** AC-14, AC-15 and AC-18 pass. An A5 prescription prints correctly on a real printer, on plain and pre-printed paper.

---

## Phase 4: Patient app

**Goal:** patients open the mobile app and see their whole medical file, grouped by doctor.

**API**
- [ ] Patient read endpoints: my doctors, doctor info with branches, visits (never private notes), prescriptions (`sent` and `cancelled` only), files, medical profile.
- [ ] Mark items as seen (`PatientSeenAt`) for the "New" badges.
- [ ] `requestAccountDeletion`, `reviewDeletionRequest`. Admin accounts support search [S].

**App** (mobile only; desktop keeps refusing patients with A14)
- [ ] P1 home (cards, doctor selector), P2 my doctors, P3 doctor info.
- [ ] P4 visits, P5 visit details, P6 prescriptions, P7 prescription details (plain-language doses, PDF).
- [ ] P8 medical files, P9 file viewer (no edit or delete), P10 medical profile (read-only).
- [ ] P14 account and settings, including the terms acceptance at first login (A9) and the deletion request.
- [ ] AD11 accounts support [S], AD12 deletion requests [S].

**Tables:** Patients, DoctorPatients, PatientMedicalProfileItems, Sessions, MedicalRecords, MedicalRecordAttachments, Prescriptions (+ items), Branches, BranchPhones, BranchPeriods, DeletionRequests.

**Status (branch `phase-4/patient-app`):** every item above is built, with API tests (visibility, AC-11, AC-12, deletion and support flows) and app tests (fake data, Arabic/English, light/dark, phone/tablet). Boxes stay unticked until checked on a real Android device and on Windows (A14). Not yet in the screens: P4 branch filter, P8 date-range filter, P3 Book and Chat buttons (Phases 5–6), P14 change password / terms text / support contact (Phase 1 public settings).

**Done when:** a patient linked to two doctors sees both files separately and together, never sees private notes or drafts, and gets the A14 refusal on Windows. AC-11 holds from the patient side.

---

## Phase 5: Chat and notifications

**Goal:** doctors (and assistants with `chat`) and patients chat, and every event in spec 10.1 reaches the right people as an in-app notification and a push.

**API**
- [ ] Chat endpoints: inbox, thread (paged), send text / image / file, read state, enable or disable a chat. Blocked while the doctor is suspended.
- [ ] SignalR hub: new messages, unread counts, and notifications for running Windows apps.
- [ ] Notification service, the single place that sends: stores `Notifications` in both languages, sends FCM to the recipient's devices by their language and preferences, removes invalid tokens, and pushes SignalR on Windows.
- [ ] Device registration (`UserDevices`), notification preferences, mark as read and mark all as read.
- [ ] Wire every event in spec 10.1 that earlier phases already produce (sessions, files, prescriptions, sign-ups, password requests).

**App**
- [ ] D16 chats inbox, D17 chat thread (attachments, "Save to patient file"), AS9.
- [ ] P11 chats (more than one doctor), P12 chat thread.
- [ ] D21, P13, AS11, AD17 notification centres. Tapping opens `data.route`.
- [ ] FCM on Android and iOS (ask for permission after login), Windows toasts with `flutter_local_notifications`, system tray [S].
- [ ] AD16 broadcast [C].

**Tables:** Chats, ChatMessages, ChatReadStates, Notifications, UserDevices, Users (Notify* columns), MedicalRecords (save from chat).

**Status (branch `phase-5/chat-notifications`):** chat API and screens (D16, D17, AS9, P11, P12), notification service with delivery (SignalR to running apps and Windows toasts; FCM to Android and iOS), notification centres, devices, and templates for every 10.1 event. Still to do: (1) `flutterfire configure`, the API's Firebase service-account key, and a `firebase_messaging` `PushTokenSource` in the app; (2) Phases 1–3 call `NotificationTemplates.*` from their endpoints (sessions, files, prescriptions, sign-ups, password requests); (3) system tray [S] and AD16 broadcast [C]. Boxes stay unticked until AC-13 is checked on a real Android phone and on Windows.

**Done when:** AC-13 passes. Push text arrives in the recipient's language, never contains diagnoses, and shows the message text only when the recipient turned previews on.

---

## Phase 6: Appointments and the live board

**Goal:** patients book from the app, staff book, check in and run the day from the live board, and every clinic device sees changes within about 2 seconds.

**API**
- [ ] Schedule: `updateBranchSchedule` with special dates, closures, booking settings and the conflicts dry run (BR-AP12).
- [ ] `getAvailability` (server-side only, BR-AP1) for queue and timed modes.
- [ ] `createAppointment` with every rule in 6.12.5 in one transaction, `rescheduleAppointment`, `cancelAppointment`, `confirmAppointment`, `rejectAppointment`.
- [ ] `checkInAppointment`, `addWalkIn`, guest conversion, `markNoShow`, `undoNoShow`, `markLeftWithoutSeen`, `cancelRestOfDay`, `sendDelayNotice` [S], `callNext` [S], `setSelfBooking`.
- [ ] Live board: `callIn`, `sendBackToWaiting`, `movePriority`, `getBoardPatientSummary`; first action wins (`RowVersion`, BR-LB4); `createSession` completes the booking (BR-AP10).
- [ ] Firestore mirror written by the API after every change, and `getRealtimeToken` (spec 9.6).
- [ ] `searchAppointments` (6.12.8).
- [ ] Jobs: `appointmentReminders`, `expirePendingAppointments`, `markNoShows`, `flagCheckedInNoSession`.
- [ ] Load test: availability, concurrent booking of the same slot, and the board with many devices.

**App**
- [ ] D29 Working hours, Special dates and Booking settings tabs with the conflicts sheet. AS17 branch schedule.
- [ ] D30 appointments calendar, D31 appointment details, D32 book appointment (existing patient, new patient, quick guest, walk-in), D33 search.
- [ ] D34 live board (columns on desktop and tablet, tabs on phone, drag and drop on desktop, side panel, doctor extras), offline banner (BR-LB5). D36 waiting-room screen [C].
- [ ] AS1 with the live board, AS13–AS16.
- [ ] P15 book appointment, P16 my appointments, P17 appointment details (reschedule, cancel, live "now serving" [S]).

**Tables:** Appointments, AppointmentHistory, Branches (booking columns), BranchPeriods, BranchDateOverrides, BranchDateOverridePeriods, BranchClosures, BranchDayStates, PublicHolidays [C], DoctorPatients (self-booking block), Sessions.

**Done when:** AC-21, AC-22, AC-25 and AC-26 pass, and the load test shows no double booking.

---

## Phase 7: Billing and analytics

**Goal:** the platform bills doctors monthly, the admin reviews payments, unpaid doctors are suspended and reactivated automatically, and doctors see their full analytics and revenue.

**API**
- [ ] `monthlyClose` (1st of the month, 00:05 Cairo): totals from `Sessions` with SQL aggregates, one invoice per doctor and month, idempotent.
- [ ] `dailyBillingCheck` (00:10): reminders, `overdue`, suspension (BR-G1). `statsReconcile` [S].
- [ ] `submitPayment` (screenshots), `reviewPayment` (approve / reject, reactivation check BR-G3).
- [ ] `adjustInvoice`, `waiveInvoice`, `markInvoicePaid`, `extendInvoiceDueDate`, `setDoctorStatus`, `getDoctorActivity` (masked patient names).
- [ ] Suspension limits applied everywhere (BR-G5, BR-G8): read-only plus payment for the doctor and assistants, patients keep read access.
- [ ] `buildDailyMetrics` (02:30), `getDashboard`, `getRevenueReport`. Money fields are removed for callers without revenue access (BR-REV1).

**App**
- [ ] D18 billing hub, D19 invoice details, D20 submit payment (InstaPay box with copy buttons). AS10.
- [ ] D1 full analytics (filters, compare, KPI tiles, charts C1–C12, insights), D35 revenue, D4 money and clinical columns, AS18.
- [ ] AD1 admin dashboard, AD4 doctors list, AD5 doctor details (all tabs, actions), AD6 add doctor [S], AD7 payments to review, AD8 payment review, AD9 invoices, AD10 invoice details.

**Tables:** Invoices, InvoiceBranchBreakdown, InvoiceAdjustments, InvoiceStatusHistory, Payments, PaymentScreenshots, DailyStats, MonthlyStats, DoctorDailyMetrics, Doctors (status), DoctorAdminNotes, Sessions.

**Done when:** AC-6, AC-7, AC-8, AC-9, AC-12, AC-23 and AC-24 pass, including a full month close run twice with no change the second time.

---

## Phase 8: Hardening and release

**Goal:** the app is ready for the stores and for real clinics.

- [ ] Full QA on Android, iOS and Windows (macOS if in scope), in all four combinations: Arabic/English × light/dark. Golden tests for the main screens. AC-16 and AC-17 pass.
- [ ] Performance: dashboard under 2 seconds on 4G, lists paginated at 25, image compression on upload.
- [ ] Monitoring: Crashlytics or Sentry in the app, API logs with alerts on billing-job errors.
- [ ] Backups and point-in-time restore tested on a copy of `prod`.
- [ ] Security review: rate limits, file access, authorization tests green, admin blocked from medical content.
- [ ] Legal review of the Terms and Privacy Policy against Law 151 of 2020.
- [ ] Name and store checks: search the stores for the existing app «el3eyada» and check the Egyptian trademark register before submitting. Confirm the bundle ID `com.el3yada.app`; it cannot change after the first upload.
- [ ] Store listings: name «el3yada | العيادة», Arabic keywords (عيادة, عياده, دكتور, كشف, حجز, روشتة), screenshots in Arabic and English, privacy forms, account-deletion flow.
- [ ] Windows signed installer (MSIX), auto-update check against `minAppVersion` [S]. macOS DMG if in scope.
- [ ] App icons and splash (light and dark).
