# el3yada: Delivery phases

The team (Youssef, Amr and Mohamed Gomaa) works through these phases together, in order. Each phase lists what to build in the **API** (ASP.NET Core + SQL Server) and in the **app** (one Flutter codebase), the tables it uses, and the checks that close it.

- Screen IDs (A, D, AS, P, AD) and rule IDs (BR-…) point to [spec.md](spec.md). Acceptance checks (AC-…) are in spec section 14.
- **[M]** must have, **[S]** should have, **[C]** could have. A phase can close with open [S] and [C] items. Note them in the phase's checklist.
- Every table already exists in [database/schema.sql](database/schema.sql). "Tables" below means the tables the phase reads and writes, not tables to create.
- Tick a box only when the item works on **Android and Windows**, in **Arabic and English**, and in **light and dark**, and a screen also has **its motion** (spec section 12, "Motion and visual polish").

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

**Status (21 Nov 2026, Youssef).** Every phase is now written in code, and the checks pass: `dotnet test` 773 (764 API, 9 data), `flutter test` 611 passed, 190 skipped (screenshots), `flutter analyze` clean. What still needs people, accounts or devices is listed per phase below. Changes since the Phase 4–8 merges:
- **Flutter 3.50.1 is required** (pdfrx 3 needs Dart 3.14). Run `flutter upgrade`. Material now comes from `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`. Localization delegates come from `lib/l10n/app_localization_delegates.dart`, because the generated list still uses the old ones, and Arabic lost its Material texts. CI is pinned to 3.50.1.
- **Android builds again:** `compileSdk` 37 and core library desugaring, both needed by `flutter_local_notifications`.
- **Request paths are under `/api`:** write `/patient/home`, not `/api/patient/home`. The Phase 4–6 repositories asked for `/api/api/...` and worked only against the offline fakes. `test/core/api_paths_test.dart` guards this.
- **Queue numbers at check-in** (BR-AP3, BR-AP16, the AC-21 queue order): booking only takes a place on the period's list.
  - Check-in gives the next number in arrival order under a period lock, and notifies «دورك رقم 7، وقبلك 3 مرضى» with the wait. «دورك التالي» [S] goes to the next patient.
  - The board orders Expected by booking time and Waiting by number; P15–P17 show the arrival-order texts.
  - Migration `QueueNumberAtCheckIn`: **run `dotnet ef database update`.** Contract: [api-phase-6.md](backend/docs/api-phase-6.md).
- **One schedule editor:** D29 now has the Working hours, Special dates and Booking settings tabs with the conflicts sheet (keep, move or cancel; BR-AP12).
  - AS17 is the same screen, with the other tabs read-only.
  - `updateBranchHours` and the separate Schedule page are gone, so hours can't change without the bookings check. Contract: [api-phase-6-schedule.md](backend/docs/api-phase-6-schedule.md).
- **Added:**
  - **Patient app:** P3 Book, Chat and records; P4 branch filter; P8 date filter; P14 change password, terms and support.
  - **Doctor's screens:** D6 Appointments tab with Book and Chat; D4 unread badge, files count and CSV export (doctor only); D32 "New patient" through D5.
  - **Schedule and branches:** branch photos (D29, shown in P3); public holidays (AD13, suggested closures).
  - **Free trial:** reminders 3 days before and on the last day.
  - **Admin:** AD6 add doctor; AD2 filters and pending badge; AD16 broadcast; PDF licenses in the app (AD3).
  - **Catalog:** "Report a missing or wrong item" in D13/D14; D0 shows the free space needed.
  - **Live board:** drag and drop, the doctor's extras (BR-LB6), D36 waiting-room screen.
  - **App shell:** Windows tray; native splash (light and dark).
- **Still open, needs accounts or decisions:**
  - Firebase (`flutterfire configure`, the service-account key): until then no push reaches a phone, and the board uses SignalR plus the 15-second refresh.
  - Crashlytics or Sentry; the hosting, database and backups; store accounts.
  - Real-device QA, the A5 printer check, the load test on real infrastructure, the catalog's medical review.

---

## How we work

These rules keep three people's code consistent. Change them only by agreement.

**Code and branches**
- Everyone works on the **`dev`** branch directly, with no pull requests. Pull before you start (`git pull --rebase`), commit small, and push often so the others see your work.
- Before every push: `flutter analyze` is clean, `flutter test` passes, and the API tests pass, all run locally. CI runs the same checks, but only when started by hand (Actions tab → CI → Run workflow), to save GitHub Actions minutes. Run it before merging `dev` into `main`. If it goes red, fixing it comes before anything else.
- `main` gets `dev` when a phase is done and CI is green.
- One Flutter codebase for every platform. **Each screen is built once** and adapts to phone (< 600 px), tablet (600–1024) and desktop (> 1024), as in spec section 4. Don't make separate phone and desktop copies of a screen.
- App structure follows [app/README.md](app/README.md): each feature has `domain/`, `data/`, `application/` and `presentation/`. No hard-coded text (ARB files, both languages) and no hard-coded colours (theme tokens).

**Design and motion**
- Every screen ships with its motion: entrance, staggered lists, crossfading states, pressed feedback, and at most one signature moment (spec section 12). Durations and curves come from `core/theme/motion.dart`, never inline numbers.
- Build screens from the shared animated widgets made in Phase 0 (pressable, skeleton list, empty state, success animation) instead of re-creating them per screen.
- Use the design skills in `.claude/skills/` when designing or reviewing a screen: `ui-ux-pro-max` (stack `flutter`, `--rtl`) and `frontend-design`. Before you push a screen, run the pre-delivery checklist in `ui-ux-pro-max/references/pro-rules.md`.
- Check every new screen on a real phone with reduced motion on and off.

**API**
- One ASP.NET Core solution in `backend/` in this repo (created in Phase 0).
- Endpoint names follow spec section 9.1 (`createSession`, `createAppointment` …), so the spec, the API and the app use the same words.
- Every write validates its input (FluentValidation, rules from spec section 11) and checks role, status and assistant permissions from the database (spec 9.4).
- Error responses use the codes in the spec (`CONSULTATION_REQUIRES_EXAM`, `DOCTOR_SUSPENDED`, the booking codes in 6.12.6). The app maps each code to an ARB message.
- Every sensitive action writes a row in `AuditLogs`.

**Database**
- The EF Core model and migrations in `backend/src/El3yada.Data` are the source of truth. Change a table by changing the entity and adding a migration (`dotnet ef migrations add <Name>`), with the matching update to spec section 8. Announce it to the team before you push it. Steps in [backend/README.md](backend/README.md#changing-the-database).
- Never edit a migration that is already pushed to `dev`. After pulling, run `dotnet ef database update`.
- Conventions (names, piasters, UTC, Cairo dates, enums as strings) are at the top of `database/schema.sql`, which is kept as the original design.

---

## Phase 0: Setup and checks

**Goal:** everyone can run the API, the database and the app locally, and the risky platform pieces are proven before features depend on them.

**Already done**
- [x] Flutter app skeleton: sign-in screen with dev accounts, per-role navigation (phone, tablet and desktop layouts), Arabic/English with RTL, light/dark themes from colour tokens, tests. See [app/README.md](app/README.md).
- [x] Database design: [database/schema.sql](database/schema.sql) (55 tables) and [database/seed.sql](database/seed.sql) (settings and specialties).
- [x] Backend solution in [backend/](backend/README.md): ASP.NET Core Web API (.NET 10), EF Core model for all 55 tables, migrations `InitialCreate` and `SeedReferenceData`, `GET /api/health`, OpenAPI document, and data tests. The migrated database was compared with `schema.sql` object by object (tables, columns, defaults, keys, foreign keys, checks, indexes) and matches.

**Database**
- [ ] Each person runs `dotnet tool restore` and `dotnet ef database update` to create `el3yada_dev` locally ([backend/README.md](backend/README.md)), then sets the dev JWT key with `dotnet user-secrets` (one command in the README).
  - Youssef: done 15 Nov. Both migrations applied, and `GET /api/health` returns `{"status":"ok","database":"el3yada_dev","appliedMigrations":2,"pendingMigrations":[]}`. Amr and Mohamed Gomaa: not yet.
- [ ] Shared `dev` and `prod` SQL Server databases on the host, in a region close to Egypt. Daily backups.
  - Not started: the team first has to choose and pay for a host. The API is ready for it: set `ConnectionStrings__Default`, `Jwt__SigningKey`, `Storage__RootPath` and the log path there.

**API**
- [x] Serilog and FluentValidation.
  - **Serilog:** console plus daily JSON log files, kept 31 days. The request log has no query strings, headers or bodies.
  - **FluentValidation:** a global filter returns a 400 `application/problem+json` with `errors` and `errorCodes` per field. `.EgyptianMobile()` is the first shared rule, matching the app's validator.
  - Unknown routes and server errors also return problem+json.
- [x] `dev` and `prod` settings live outside the repo, checked when the API starts (`Jwt`, `Storage`, connection string).
  - **Dev:** the JWT key comes from `dotnet user-secrets`.
  - **Prod:** environment variables only; the list is in [backend/README.md](backend/README.md).
  - **Tokens:** access tokens last 15 minutes and refresh tokens 30 days. The spec gave no values, so change them here if needed.
- [x] File storage service behind the API: save, read, delete and image thumbnails (SkiaSharp), using the spec section 8 paths, which are now built from IDs only.
  - **Files:** only JPEG, PNG, WebP and PDF are accepted, and the file's first bytes must match its type. Size limits are enforced, and path traversal is rejected.
  - **Endpoints:** none yet, because files need sign-in. Upload and download endpoints come in Phase 3.
- [ ] CI: build and test the API and the app.
  - Written in [.github/workflows/ci.yml](.github/workflows/ci.yml): the API runs against a SQL Server container, and the app runs `flutter analyze`, `flutter test` and a check that generated code is up to date.
  - It runs only when started by hand, to save Actions minutes. Youssef runs it once after Phase 2.
  - The first automatic run (15 Nov) never started: GitHub reported a billing problem on the account, so no minutes were used. Fix billing before the first manual run.

API checks (15 Nov): `dotnet build` gives 0 warnings. `dotnet test` passes 74 of 74 (69 API tests and 5 data tests), five runs in a row.

Notes for later phases:
- **Phase 3 uploads:** the server's default request body limit (about 28.6 MB) is below the 50 MB upload setting, so the upload endpoints need `[RequestSizeLimit]`.
- **Photo GPS data:** thumbnails drop it, but original photos keep it; consider stripping it in Phase 3.
- **Duplicate phone numbers:** SQL Server's duplicate-key error message contains the duplicate value, such as a phone number, and that message gets logged. Check phone uniqueness in code (Phases 1–2) before saving.
- **Pasted numbers:** the mobile-number check doesn't strip the invisible direction marks that pasted Arabic numbers can carry. Fix it in the API and the app together.

**App**
- [x] Android flavors `dev` and `prod`, wired to `config/dev.json` and `config/prod.json`. `dev` installs next to `prod` as "el3yada dev" (`com.el3yada.app.dev`). The app refuses to start when the flavor and the config file disagree (`Env.checkFlavor`). Checked: `flutter build apk --flavor dev` gives that ID and name. Launch configurations in `.vscode/launch.json`.
- [ ] iOS and macOS flavor schemes (`dev`, `prod`). They need Xcode, so whoever has a Mac does this.
- [x] Alexandria (Arabic + Latin, SIL OFL) bundled in 4 weights and set as `AppTheme.fontFamily`. Light and dark colour tokens rebuilt from the chosen design (pine `#0F4C45`, mint ground `#E6F2EC`, mint `#7CE0C3`, coral for "new"), and the ع = 3 logo mark drawn in code on the splash and login screens. Checked with widget tests and rendered screenshots in Arabic, light and dark. Not run on Windows yet (see the Windows check below).
- [x] `freezed` + `json_serializable` for API models. `AuthSession` is the first one. Generated files are committed, and CI fails if they are out of date.

**App: design and motion foundation** (spec section 12, "Motion and visual polish")
- [x] Add `flutter_animate`, `animations`, `lottie`, `skeletonizer` and `flutter_svg`. `flutter_animate` and `flutter_svg` are added but not used yet: `Animate` starts a timer even with no delay, which breaks widget tests that don't pump time, and `flutter_svg` needs per-theme colour mapping. The shared widgets use Flutter's own animations instead (see the Conventions section in `app/README.md`).
- [x] Motion tokens in `core/theme/motion.dart`: `fast` / `normal` / `slow` durations, enter and exit curves, a spring curve, and one reduced-motion switch (`Motion.of(context)`) that every animated widget reads.
- [x] Page transitions: shared axis forward and back (mirrored in Arabic), set in the theme so every `GoRoute` gets it; fade-through between tabs (each role is one `StatefulShellRoute`, so each tab keeps its state); `ContainerTransform` for list → detail. Note: the global transition removes the iOS edge swipe to go back; turning it back on is one line in `AppTheme`.
- [x] Custom floating bottom bar for phones (`FloatingNavBar`): pill shape, sliding mint indicator, outline-to-filled icons, badge pop-in (`navBadgeProvider`), haptic, RTL mirroring, hidden while the keyboard is open. The same indicator on the tablet rail (`AppNavRail`) and the desktop side menu (`AppSideMenu`). At 360 dp, "اللوحة المباشرة" was too long for the bar, so the phone bar uses `navLiveShort` ("المباشر" / "Live"). **Team: confirm this wording.**
- [x] Shared animated widgets in `core/widgets/`: `Pressable`, `StaggeredEntrance`, `SkeletonLoading`, `EmptyState` (queue-ticket illustration drawn in code), `SuccessCheck` (Lottie, 1.1 s, made for the project), `StateSwitcher` / `AsyncStateSwitcher`, `ShakeOnError`, `SubmitButton` (label → spinner after 300 ms → check).
- [x] Animated logo: the ع draws itself and the plus pops in (`AppLogoMark(animate: true)`), drawn in code rather than SVG or Lottie. Used on the splash. It carries a Hero tag for the splash → login move, which Phase 1 wires up (A3).
- *Checked (15 Nov):* `flutter analyze` clean, 89 tests pass, phone, tablet and desktop screenshots checked in Arabic, light and dark. Still open: 60 fps in profile mode and the haptics on a real phone (the Phase 9 motion review).

**Checks (do these before Phase 1 features depend on them)**
- [ ] **Windows release build:** HTTPS login, token refresh, file upload and a SignalR connection all work (spec section 13).
  - *Result (15 Nov):* not run. Youssef's machine is missing the Visual Studio "Desktop development with C++" workload (`flutter doctor`), so Windows can't build there yet. The login, refresh, upload and SignalR endpoints arrive in Phases 1, 3 and 5, so repeat this check as each one lands. Windows builds also need **Developer Mode** on (Settings → For developers), because plugins are linked with symlinks; `flutter pub get` warns when it's off.
- [ ] **Firestore on Windows:** custom-token sign-in and live updates in a release build. If it falls short, Windows uses the 15-second API refresh (spec 9.6).
  - *Result (15 Nov):* not run. It needs the Firebase project (`flutterfire configure`), which doesn't exist yet.
- [ ] **Scanner prototype** on Android and iOS (cunning_document_scanner or equivalent).
  - *Result (15 Nov):* not run. It needs a real Android or iOS device.
- [ ] **Arabic PDF prototype:** an A5 prescription with Arabic and English text renders, prints and shares correctly.
  - *Result (15 Nov):* renders correctly. `app/test/prototypes/arabic_pdf_test.dart` writes `build/prototypes/rx_a5_prototype.pdf` (A5, Arabic and English, QR code), and it was checked by eye. Two findings for Phase 3:
    - The PDF library needs every Arabic presentation-form glyph, and Alexandria lacks the isolated ي («استشاري» printed as «استشار»). Arabic text in PDFs therefore uses Noto Sans Arabic (bundled, OFL), and Latin text uses Alexandria. `font_coverage_test.dart` guards this.
    - A space between an Arabic word and the number after it can disappear («كل12»). Put numbers in their own span when building the PDF.
  - Still open: printing on a real printer and sharing from a phone. Both need the `printing` plugin (Phase 3).
- [ ] **Local catalog search:** drift + SQLite FTS5 with Arabic search works on Android, iOS and Windows.
  - *Result (15 Nov):* works on Windows. `app/test/prototypes/catalog_fts5_test.dart` confirms FTS5 and the spec A.6 normalization: hamza forms, ة/ه, ى/ي, diacritics, Arabic-Indic digits, "250/5" kept as one number, and every word as a prefix that must match. `sqlite3` 3.x bundles SQLite with FTS5 through build hooks, so `sqlite3_flutter_libs` isn't needed. Still open: run the same test on an Android and an iOS device.

**Done when:** all three of us run the app against our local API and database, and every check above has a result written down.

---

## Phase 1: Sign-in and admin basics

**Goal:** every role can sign in, doctors can register and be approved, and the admin can manage settings and admins.

The app builds against [backend/docs/api-phase-1.md](backend/docs/api-phase-1.md) (routes, session fields, error codes, refresh rules).

**API** (163 tests: 77 unit, 79 integration on a migrated database, 7 data. Smoke-tested on LocalDB.)
- [x] `login` (email or Egyptian mobile; patient + assistant on the same number asks "log in as"), access + refresh tokens, `refresh`, `logout` (removes the device's push token), rate limiting.
  - Doctors and admins sign in by email only; a mobile number matches patients and assistants. Refresh tokens are grouped per device (`RefreshTokens.FamilyId`): reusing one revokes the family, so the app must never run two refreshes at once. Lockout after 5 wrong passwords for 15 minutes. Behind a reverse proxy the per-IP limits need forwarded headers (backend/README.md).
- [x] Password rules: `mustChangePassword`, set new password (A9), password change signs out other devices (`SecurityStamp`). The server answers 403 `PASSWORD_CHANGE_REQUIRED` everywhere until the password is set.
- [x] Forgot password (A8): email reset link for doctors and admins (`UserTokens`); phone request for patients and assistants notifies their doctor (`requestPatientPasswordReset`). Same answer whether or not the account exists. The email also shows the code, which the app accepts. Emails go through an in-memory queue (lost on restart); production refuses to start without SMTP settings.
- [x] `completeDoctorRegistration` (A4, with the first branch), license upload, `pendingApproval` status. Also `myRegistration` and `resubmitDoctorRegistration` (A7), and email verification (A5). Visit prices entered at sign-up become the doctor's prices; working hours come after approval (Phase 2).
- [x] `reviewDoctorRegistration` (approve / reject with reason), `createAdmin`, `setAdminRole`, disable admin. `createAdmin` returns a temporary password shown once (spec AD14 updated); the last super admin can't be demoted or disabled.
- [x] `updateSettings` with range checks and `SettingsHistory`. Public settings endpoint (version, maintenance, support, terms). Partial updates; the Terms and Privacy "version" is a fingerprint of the text.
- [x] One-time command to create the first super admin (`dotnet run -- seed-admin <email>`; `--reset` prints a new temporary password).
- [x] Audit log foundation: one helper that every endpoint uses to write `AuditLogs`. Successful logins aren't audited (to keep the table small); lockouts and token reuse are.
- Fixed on the way: Doctor → Branch was one-to-one in the model (now one-to-many, needed for Phase 2), and every `AuditLogs` insert would have failed (IDENTITY key).
- Not in Phase 1: the API doesn't enforce maintenance mode or the minimum version (the app does); notification list and push (Phase 5); the `DOCTOR_*` status gate on doctor endpoints (Phase 2).

**App** (status 15 Nov: built and covered by widget tests and Arabic light/dark screenshots; not yet run on an Android device or a Windows build, so nothing below is ticked yet)
- [ ] A1 Splash routing by session, role and status; A2 language choice on first launch.
  - *Built:* start-up reads public settings (cached for offline), checks the minimum version (A11) and maintenance (A13), refreshes the saved session from `/auth/me`, then routes in the order in `appRedirect` (router.dart). A2 previews the language as you pick.
- [ ] A3 Login against the real API (replace `FakeAuthRepository` in prod builds), A4 registration (4 steps), A5 verify email [S].
  - *Built:* A3 with "log in as" (bottom sheet on phones, dialog on desktop). `config/dev.json` now uses the local API; `config/dev-offline.json` keeps the offline accounts (pending, rejected, disabled, two-account and first-login cases). A4: 4 steps with the license from the camera, photos or a file (`image_picker`, `file_selector`), searchable specialty and governorate pickers, server errors sent back to the right step. A5: paste the code from the email, "I've verified", Resend with a 60-second countdown. Step 3's map pin became an optional Google Maps link in Phase 2 (see D28/D29 below). Not done: changing the email from A5 (no endpoint while pending), opening the app from the email link.
- [ ] Splash and login signature animation: the logo draws in and moves into the login header, the form slides up, Sign in morphs into progress and then a check, and wrong credentials shake the form once. Registration steps (A4) slide between steps with the progress bar animating.
  - *Built for splash and login:* the splash and login share one page, so the logo rises in place (no Hero needed). A4 steps slide between each other (mirrored in Arabic) under an animated progress bar.
- [ ] A6 pending, A7 rejected (edit and resubmit), A8 forgot password, A9 set new password, A10 disabled, A11 force update, A12 terms, A13 maintenance, A14 patient on desktop.
  - *Built:* A8 (by mobile, or by email with the code from the email), A9 (live checklist, Terms checkbox for patients), A10 (disabled account, or inactive clinic for assistants), A11 (needs the store links as `UPDATE_URL_*` defines once published), A12, A13 (admins can still sign in), A14. A6 shows the submitted data (two columns on desktop) with Refresh; A7 shows the reason and "Edit and resubmit" re-opens A4 filled in, keeping the license unless replaced.
- [ ] Token refresh on 401 in the API client (TODO in `AuthInterceptor`).
  - *Built:* refresh shortly before expiry and on 401, one refresh at a time, one retry; a refused refresh signs out; 403 `ACCOUNT_DISABLED` / `CLINIC_NOT_ACTIVE` open A10. Unit-tested.
- [ ] AD2 sign-up requests, AD3 sign-up review, AD13 settings, AD14 admin users, AD15 audit log, AD18 admin profile.
  - *Built:* AD2 + AD3 as master-detail on desktop (cards and a full review page on phones), the license viewer (images inline; PDFs open in the system viewer on Windows and macOS), approve, and reject with a required reason. AD13 covers every setting in `SettingFields.cs` in tabs, sends only what changed, guards unsaved edits, and shows the history per setting. AD14 shows the temporary password once with a copy button; plain admins don't see AD14 in the menu (`NavDestinationSpec.visibleTo`). AD15 has filters for action, role, target and Cairo date range; each row reads as a sentence, with its details. AD18 has the profile, language and theme, change password and log out; the top bar has a profile button for admins.
  - Not done: AD2 filters by specialty, governorate and date (the API has them); a badge with the pending count; opening PDF licenses on phones (needs a FileProvider or the Phase 3 `printing` package).

**Dev accounts:** run `dotnet run --project src/El3yada.Api -- seed-admin admin@el3yada.dev` once; it prints a temporary password that must be changed at first sign-in. Patients and assistants arrive in Phase 2 (created by doctors); until then use `config/dev-offline.json` to see their screens.

**Screenshots:** `EL3YADA_SCREENSHOTS=1 flutter test test/screenshots` (in `app/`) writes every Phase 1 screen to `app/build/screenshots/`.

**Tables:** Users, UserDevices, RefreshTokens, UserTokens, Doctors, DoctorExtraSpecialties, Branches, BranchPhones, Specialties, AppSettings, SettingsHistory, AuditLogs.

**Done when:** a doctor registers, the admin approves them, and they reach the doctor home. A rejected doctor sees the reason and can resubmit. A patient on Windows is refused with A14. Every A screen works in both languages and both themes.

---

## Phase 2: Patients, sessions, branches and assistants

**Goal:** a doctor and their assistants can run a clinic day without appointments: add patients, record examinations and consultations, and see today's and this month's platform fees.

The app builds against [backend/docs/api-phase-2.md](backend/docs/api-phase-2.md) (who may call what, `GET /api/clinic/me`), [api-phase-2-patients.md](backend/docs/api-phase-2-patients.md) and [api-phase-2-clinic.md](backend/docs/api-phase-2-clinic.md).

**API** (576 tests: 8 data and 568 API, run against a migrated LocalDB database. They cover the acceptance checks in "Done when".)
- [x] `createPatient` (link an existing number with BR-P3, file number, temporary password shown once), `updatePatientPhone`, `resetPatientPassword`, archive [S].
  - Also `lookupPhone` for D5. Linking needs the phone alone. A clinic that linked an existing patient sees only the name, phone, gender and date of birth (`ownsDetails`); the optional details stay with the clinic that created the account. A doctor's password reset also lifts the 15-minute login block on the number.
- [x] Medical profile read and update (allergies, chronic diseases, medications, surgeries, family history, notes).
  - Removed items are soft-deleted (BR-P8, migration `SoftDeleteMedicalProfileItems`: run `dotnet ef database update` after pulling).
- [x] `createSession` in one transaction: consultation rule (BR-S2, BR-S3), fee snapshot, visit price, amount charged, branch, link counters, `DailyStats` and `MonthlyStats`, patient notification. Error codes `CONSULTATION_REQUIRES_EXAM`, `DOCTOR_SUSPENDED`, `NOT_LINKED`.
  - The link row is locked, so two saves at once can't both pass (AC-2). Archived branches refuse sessions (`BRANCH_ARCHIVED`); a temporarily closed branch still takes them. Fee totals (D1–D3) are SQL sums of the sessions.
- [x] Session clinical fields update (doctor only), private notes, `deleteSession` (BR-S7, soft, recalculates the link).
  - The amount charged can change on the same Cairo day, by the doctor or whoever recorded the session. The admin audit log lists that change without the amounts (BR-REV1).
- [x] `createBranch`, `updateBranch`, `setBranchStatus` (info, address, contact, weekly working hours), `updatePrices` with `PriceHistory`.
  - Weekly hours are `updateBranchHours` (spec 9.1's `updateBranchSchedule`; Phase 6 adds date overrides, booking settings and the BR-AP12 dry run). Also `setDefaultBranch`. The default branch and the last active branch can't be archived; future bookings block closing (BR-BR9). Not done: branch photos [S].
  - Address (product owner's change, 16 Nov): street, building, floor and apartment became one «العنوان بالتفصيل» text (`details`; `addressDetails` in the sign-up branch), and latitude and longitude became an optional Google Maps link (`mapUrl`, `INVALID_MAP_LINK` when it isn't one). Migration `BranchAddressDetailsAndMapUrl` copies existing branches over: **run `dotnet ef database update` after pulling.**
- [x] `createAssistant`, `updateAssistant` (presets, permission dependencies), `resetAssistantPassword`, `setAssistantStatus`, `getClinicActivity`.
  - Removing an assistant is final and frees the number. Disabling or removing one refuses their next request with `ACCOUNT_DISABLED` (A10). Also the doctor profile (D22: a specialty change notifies the admins) and notification preferences (`/api/me/notificationPrefs`).
- [x] Assistant permission checks in **every** endpoint, read from the database on each request.
  - One guard, `[Clinic(permission) { DoctorOnly, BlockedWhileSuspended }]` in `Clinic/ClinicAttribute.cs`, runs before body validation. Branch scope (BR-AS13) is checked on each request too (`BRANCH_NOT_ALLOWED`).
- [x] `getPatientsRegister` (D4) with search (Arabic letter variants), filters, sorting and paging.
  - Booking and no-show filters come with appointments (Phase 6).
- [x] **API authorization tests** for every role and every assistant permission. Phase 2 does not close without them.
  - Two matrices (`PatientsAuthorizationTests` and the clinic one) check, for every endpoint: no token, patient, admin, assistant with and without the permission, another doctor's record, a suspended doctor, and another branch.
- [x] **Free trial** (product owner's change, 17 Nov; spec 6.16, contract [api-free-trial.md](backend/docs/api-free-trial.md)):
  - No approval step: sign-up makes the doctor `active` with a trial of `trialDays` days (14 by default, set in AD13). Sessions in the trial carry no platform fee.
  - When the trial ends, signing in still works, but every clinic endpoint except `clinic/me` answers `TRIAL_ENDED`.
  - The admin can `activateDoctorService` or `extendDoctorTrial`. AD2 filters by trial state.
  - Migration `DoctorFreeTrial`: **run `dotnet ef database update` after pulling.** Doctors approved before it have no trial.
  - Not done: push reminders before the end (Phase 5).

**App** (status 16 Nov: built and covered by widget tests and Arabic light/dark screenshots at phone and desktop sizes; not yet run on an Android device or a Windows build, so nothing below is ticked yet)
- [ ] Current-branch picker in the top bar (BR-BR3).
  - *Built:* shown when the doctor or assistant works in more than one branch, and remembered per user. The shell also reads `GET /api/clinic/me` (again on resume and after a refusal), hides an assistant's menu items without the permission (also by address), and shows «عيادة د. …» to assistants and the suspension banner with Pay now (BR-G5, BR-G8).
- [ ] D4 patients register (cards on phone, table on desktop, master-detail on desktop), D5 add patient, D6 patient profile, D7 edit patient and medical profile.
  - *Built:* all four, with the temporary password dialog (WhatsApp, SMS, Copy) and the BR-P3 link dialog. Not done: D6's Files, Prescriptions and Appointments tabs and its Book, Chat, Scan and Upload actions (Phases 3, 5, 6); D4's files, booking and unread columns; export [S].
- [ ] D8 new session (type cards, consultation rule message, fee confirmation, amount charged), D9 session details.
  - *Built:* both. After saving, prescription, lab request and attach files show as «قريباً» (Phase 3).
- [ ] D1 dashboard (fee cards and suspension banner only; analytics come in Phase 7), D2 today's sessions, D3 monthly summary.
  - *Built:* all three. Until the live board arrives (Phase 6), the doctor's home (`/doctor/live`) shows today's sessions in the current branch, with quick actions.
- [ ] D22 profile (personal and professional info; the prescription header comes in Phase 3), D24 settings, D37 visit prices.
  - *Built:* all three. Doctors get a profile button in the top bar. On phones, language, theme and sign-out live in settings.
- [ ] D28 branches, D29 branch editor (Info, Address and map, Contact, Working hours tabs).
  - *Built:* both, plus a Clinic info tab (prices, payment methods, amenities). The Address tab has the detailed address and the Google Maps link: a pasted share text keeps just the link, and "Open in Google Maps" checks it (sign-up step 3 has the same two fields). Special dates and booking settings come in Phase 6.
- [ ] D25 assistants, D26 add / edit assistant, D27 activity log.
  - *Built:* all three. D26 applies the permission dependencies and turns the preset into Custom. D27 rows read as sentences and open their branch, assistant, patient or visit.
- [ ] Assistant screens AS1 (home without the live board), AS2–AS5, AS12, AS19, with every item the assistant can't use hidden.
  - *Built:* all of them, from the same screens as the doctor's. Not done: AS17 (branch schedule) comes with appointments (Phase 6).
- [ ] Free trial (spec 6.16): A15 when it ended, the last-3-days banner, «مجاناً» in D8, AD3 activate / extend, AD2 filter, `trialDays` in AD13.
  - *Built:* all of them, with widget tests. Offline accounts `trial@el3yada.dev` (2 days left) and `trial-ended@el3yada.dev` (A15).

**Dev accounts:** `config/dev-offline.json` has a full offline clinic: `doctor@el3yada.dev` (two branches, 15 patients, today's sessions), `suspended@el3yada.dev` (the banner), `+201000000001` (reception assistant, one branch) and `+201000000005` (office manager). Against the local API, register a doctor, approve them as the admin, then add assistants from D26.

**Screenshots:** `EL3YADA_SCREENSHOTS=1 flutter test test/screenshots` now writes every Phase 2 screen too (314 images).

**Contract test:** `flutter test test/contract` (off by default; how to run it is at the top of `api_contract_test.dart`) now also runs one clinic day through the app's real Phase 2 repositories against a running API: sign-up and approval, branches, prices, patients, sessions, fees, a reception assistant, and the activity log. After it, a second clinic links that patient (BR-P3), a booking put in by the Development-only `add-booking` command shows on the branch card and stops closing and archiving (`BRANCH_HAS_BOOKINGS`), the admin suspends and reactivates the doctor (`setDoctorStatus`, below in Phase 7), and the app's own client (the Riverpod providers, the auth interceptor and `clinicContextProvider`) refreshes a stale token, reloads the clinic after `PERMISSION_DENIED` and `DOCTOR_SUSPENDED`, and signs out to A10 on `ACCOUNT_DISABLED`. It passed twice on one database on 16 Nov with no mismatches.

**Tables:** Patients, DoctorPatients, PatientMedicalProfileItems, Sessions, SessionPrivateNotes, DailyStats, MonthlyStats, Branches, BranchPhones, BranchPeriods, PriceHistory, Assistants, AssistantBranches, AuditLogs, Notifications (rows only; delivery comes in Phase 5).

**Done when:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-10, AC-11, AC-19 and the branch parts of AC-20 pass.

---

## Phase 3: Files, prescriptions and catalogs

**Goal:** doctors scan and upload medical files, write prescriptions and lab/radiology requests with specialty-based search, and print or send them.

**API** (617 tests: 8 data and 609 API, run against a migrated LocalDB database. Contracts: [api-phase-3-files.md](backend/docs/api-phase-3-files.md), [api-phase-3-prescriptions.md](backend/docs/api-phase-3-prescriptions.md), [api-phase-3-catalogs.md](backend/docs/api-phase-3-catalogs.md).)
- [x] Authenticated upload and download for medical records (size limit `MaxUploadMb`, thumbnails, soft delete).
  - Two steps: `uploadFile` then `createRecord`, so every file gets its own progress and retry.
  - Every file is optimized for storage: images are cut to 2560 px, saved as JPEG quality 80 and stripped of GPS data, and other files are gzip-compressed when that helps.
  - Migration `MedicalFileStorage`: **run `dotnet ef database update` after pulling.**
- [x] Prescription drafts (create, edit, reorder items), `submitDraftForReview` [S], `sendPrescription` (needs the uploaded PDF), `cancelPrescription`, "issue new copy".
  - The app builds the PDF (6.4.1) and uploads it with `sendPrescription`.
  - Reads by permission: `clinicalView` sees every status; `prescriptionsPrint` sees sent documents only (AS8).
  - Migration `PrescriptionsAndCatalogs` adds `Prescriptions.FollowUpDate`.
- [x] `rxLink` (`GET /rx/{shortCode}`) for the QR code: App Links / Universal Links and store redirect; never shows content without sign-in.
  - It never reads the database, so every code gets the same redirect. The files come from the `AppLinks` settings; production sets the real fingerprints and app IDs.
  - Not done: the patient-side resolve endpoint (P7, Phase 4).
- [x] Doctor item history ("used before") and templates [S].
- [x] Prescription header and print settings in the doctor profile (logo, signature, names, colour, paper, margins).
  - The logo and signature are stored as PNGs of at most 1000 px. The default clinic colour is the brand pine `#0F4C45`.
- [x] `publishCatalog`, catalog version download, `CatalogCustomItems` sync, `reportCatalogItem` [S], specialty profiles.
  - Downloads support ranges, so D0 can resume.
  - The General profile is an inactive "General" specialty row.
  - `dotnet run -- seed-specialty-profiles <csv>` loads the builder's `specialty-profiles.csv`.
  - The expected `schema_version` is 1 (`CatalogSchema.ExpectedVersion`), the version the builder writes.
  - The dev database has the 20 default profiles (402 items) from the builder's file.
- [x] Catalog builder (spec 9.5 and Appendix A): `tools/catalog-builder`, with shared search code in `packages/catalog_core`. Details and decisions: [tools/catalog-builder/README.md](tools/catalog-builder/README.md).
  - Catalog v1 (drug dataset June 2026, LOINC 2.83): 24,715 medicines, 43,459 lab tests, 6,941 radiology procedures. 6.9 MB to download (19.4 MB unpacked).
  - Every AC-18 search check passes, including «بنادول», plus all 316 priority aliases in English and Arabic.
  - The source files and the built file stay out of git (LOINC licence, A.7). Put LOINC under `tools/catalog-builder/sources/loinc/<release>/`.
  - **Before publishing v1:** a doctor or pharmacist reviews the groups, the class mapping, the profiles and the Arabic names (README, "What needs a doctor's review"); the EDA spot check (A.3.8); and open questions 32 and 33 in the spec.

**App** (492 tests pass; the screenshot tests are skipped unless turned on.)
- [x] D10 scan (mobile only), D11 upload (drag and drop on desktop), D12 file viewer (black background, zoom, PDF), and the D6 Files tab.
  - Files are made smaller on the device before upload too (images at most 2560 px, JPEG 80, no EXIF; scans as one PDF of JPEG 75 pages), and each file shows how much it saved.
  - Not yet tried on a real device: the document scanner and camera permission, real drag and drop, "Open with", the share sheet and save dialog, and drawing real PDFs.
  - iOS: add `ar.lproj/InfoPlist.strings` and `en.lproj/InfoPlist.strings` to the Runner target in Xcode.
- [x] D13 medication editor and D14 investigations editor with catalog search sections (BR-CAT4–CAT8), D15 preview and send (PDF, print, print all, share), the D6 Prescriptions tab and the D9 card.
  - The app builds the A5 PDF (6.4.1): 4 medicines fit on one page, and a longer prescription continues on page 2 with the header repeated.
  - A duration shows in the prescription's language, whatever the app's language.
  - Print all turns the stored PDFs into one print job (pages drawn at 300 dpi), so every copy is exactly what was sent.
  - Not yet tried on real hardware: printing on A5 and A4 paper (AC-15), the system print and share dialogs, picking the logo and signature.
  - Not done: "Report a missing or wrong item" [S] in the editors (the API has `reportCatalogItem`).
- [x] D22 prescription header and print settings with live preview and test print. D23 templates and favourites [S].
- [x] D0 preparing the catalog (download with progress, works in the background).
  - The download resumes after a failure or a restart (HTTP Range), is checked (sha256 and schema version), and is swapped in only when complete.
  - D0 opens at the first download, and for a new version of 15 MB or more. Doctors, admins and assistants with `prescriptionsDraft` download it; patients never do.
  - Search runs in a background isolate over the local file: under 25 ms per search on the real catalog (Windows desktop).
  - Custom items sync every minute while the app is open; the specialty profile refreshes at sign-in and every 6 hours.
  - Not yet tried on a phone: FTS5 on Android, iOS and macOS (the `sqlite3` package's built-in SQLite includes it), search speed, the file picker.
  - The API doesn't give the unpacked size, so D0 can't warn about free space.
- [x] AS6 files (the Files tab for an assistant with `filesManage`; deleting stays doctor-only).
- [x] AS7 draft editor [S], AS8 sent prescription (print and share only).
- [x] AD19 specialty profiles, AD20 catalogs.
  - AD20 checks the file's sha256 against the builder's manifest before uploading, and asks before publishing a version with more than 5% fewer rows.
- [x] "Data sources and licences" screen (`/legal/sources`, from Settings → About): the LOINC notice, the RadLex attribution and the drug dataset credit (BR-CAT14, A.7).

**Tables:** MedicalRecords, MedicalRecordAttachments, Prescriptions, PrescriptionMedicationItems, PrescriptionInvestigationItems, PrescriptionTemplates, DoctorItemHistory, Doctors (Rx* columns), CatalogVersions, CatalogCustomItems, CatalogReports, Specialties, SpecialtyProfileItems.

**Done when:** AC-14, AC-15 and AC-18 pass. An A5 prescription prints correctly on a real printer, on plain and pre-printed paper.

*Status (17 Nov):* AC-18 passes against the API with the real catalog v1, and AC-14 is covered by widget tests. Still open: AC-15 on a real printer, the device checks above, and the medical review before catalog v1 is published.

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

**How the queue works** (product owner, 17 Nov; spec D14, BR-AP3, BR-AP16). This is the default mode, and most clinics use it.
1. **Booking puts the patient on a list, not in a line.** The patient books a day's period from the app (P15), or reception books it for a phone call (D32). That gives them a place on the period's list: a waiting list with a capacity, and no number. Not everyone who books comes.
2. **The turn is given at the clinic.** When the patient arrives, reception checks them in and they get the next number. So they see the doctor in order of arrival. Walk-ins join the same line the same way.
3. **Notifications:**
   - a reminder 24 hours before
   - a reminder on the day, 2 hours before the period starts, saying the turn goes by order of arrival
   - at check-in, «تم تسجيل حضورك — دورك رقم 7، وقبلك 3 مرضى»
   - **[S]** «دورك التالي» when the patient before them goes in

Timed mode (exact times) keeps its order by time.

**API**
- [ ] Schedule: `updateBranchSchedule` with special dates, closures, booking settings and the conflicts dry run (BR-AP12).
- [ ] `getAvailability` (server-side only, BR-AP1) for queue and timed modes.
- [ ] `createAppointment` with every rule in 6.12.5 in one transaction, `rescheduleAppointment`, `cancelAppointment`, `confirmAppointment`, `rejectAppointment`. In queue mode a booking only takes a place on the period's list (capacity, `PERIOD_FULL`); it gets no queue number.
- [ ] `checkInAppointment`, `addWalkIn`, guest conversion, `markNoShow`, `undoNoShow`, `markLeftWithoutSeen`, `cancelRestOfDay`, `sendDelayNotice` [S], `callNext` [S], `setSelfBooking`.
  - Queue mode: check-in gives the period's next number in arrival order, inside a transaction that locks the period, so two receptionists checking in at once never get the same number (BR-AP3). Walk-ins take the next number too. Numbers aren't reused. A no-show undone the same day gets a new number at check-in.
  - Check-in notifies the patient: their number, how many are ahead, and an estimated wait from the average visit time (BR-AP16). A guest has no app and is told at the desk.
- [ ] Live board: `callIn`, `sendBackToWaiting`, `movePriority`, `getBoardPatientSummary`; first action wins (`RowVersion`, BR-LB4); `createSession` completes the booking (BR-AP10).
- [ ] Firestore mirror written by the API after every change, and `getRealtimeToken` (spec 9.6).
- [ ] `searchAppointments` (6.12.8).
- [ ] Jobs: `appointmentReminders` (24 hours before, and on the day 2 hours before the period or the time), `expirePendingAppointments`, `markNoShows`, `flagCheckedInNoSession`.
- [ ] **[S]** «دورك التالي» to the next checked-in patient when someone goes in to the doctor (`callIn`, `callNext`).
- [ ] Load test: availability, concurrent booking of the same slot, concurrent check-ins in one period (no repeated number), and the board with many devices.

**App**
- [ ] D29 Working hours, Special dates and Booking settings tabs with the conflicts sheet. AS17 branch schedule.
- [ ] D30 appointments calendar, D31 appointment details, D32 book appointment (existing patient, new patient, quick guest, walk-in), D33 search.
- [ ] D34 live board (columns on desktop and tablet, tabs on phone, drag and drop on desktop, side panel, doctor extras), offline banner (BR-LB5). D36 waiting-room screen [C].
  - Queue mode: Expected cards show «محجوز» and are ordered by booking time. A card gets its number when it moves to Waiting (check-in), and Waiting is ordered by number, which is the order of arrival.
- [ ] AS1 with the live board, AS13–AS16.
- [ ] P15 book appointment, P16 my appointments, P17 appointment details (reschedule, cancel, live "now serving" [S]).
  - Queue mode: P15 shows the period and «الدور بأسبقية الحضور في العيادة», with no number. P1, P16 and P17 show «سجّل حضورك في الاستقبال عند وصولك» until check-in. From check-in they show the number, how many are ahead and the estimated wait.

**Tables:** Appointments, AppointmentHistory, Branches (booking columns), BranchPeriods, BranchDateOverrides, BranchDateOverridePeriods, BranchClosures, BranchDayStates, PublicHolidays [C], DoctorPatients (self-booking block), Sessions.

**Status (branch `phase-6/appointments-live-board`):** API complete except the load test on real infrastructure (the API tests already race 12 requests for one slot and 10 for a 3-place period with no double booking). Screens built: D29/AS17 schedule (as a Schedule page until Phase 2's D29 tabs exist), D30, D31, D32 (existing patient via a small lookup endpoint, or quick guest), D33, D34/AS1/AS16 live board with side panel and offline banner, P15–P17. Waiting on others: Phase 2 `createSession` must call `BoardActionsService.CompleteWithSessionAsync` (BR-AP10) and the board's Finish button opens D8; "create patient now" in D32 uses D5. Still to do: Firestore listener in the app (needs Firebase; SignalR + 15-second refresh work now), drag and drop [S], doctor extras on the board (BR-LB6), D36 [C], public holidays [C].

**Done when:** AC-21 (including the queue-order check: A books before B, B arrives first and goes in first), AC-22, AC-25 and AC-26 pass. The load test shows no double booking and no repeated queue number.

---

## Phase 7: Billing and analytics

**Goal:** the platform bills doctors monthly, the admin reviews payments, unpaid doctors are suspended and reactivated automatically, and doctors see their full analytics and revenue.

**API**
- [x] `monthlyClose` (1st of the month, 00:05 Cairo): totals from `Sessions` with SQL aggregates, one invoice per doctor and month, idempotent.
- [x] `dailyBillingCheck` (00:10): reminders, `overdue`, suspension (BR-G1). `statsReconcile` [S].
- [x] `submitPayment` (screenshots), `reviewPayment` (approve / reject, reactivation check BR-G3).
- [x] `adjustInvoice`, `waiveInvoice`, `markInvoicePaid`, `extendInvoiceDueDate`, `setDoctorStatus`, `getDoctorActivity` (masked patient names).
  - *Done early (Phase 2), API only:* `setDoctorStatus` suspends and reactivates by hand with a reason (BR-G4), notifies the doctor and assistants and writes the audit row (`backend/docs/api-phase-1.md`); the app has it in `AdminRepository`. Not done: the AD5 screen, "disable" (it must cancel future bookings, so it waits for Phase 6), and the automatic suspension and reactivation (`dailyBillingCheck`, BR-G1, BR-G3).
- [x] Suspension limits applied everywhere (BR-G5, BR-G8): read-only plus payment for the doctor and assistants, patients keep read access.
- [x] `buildDailyMetrics` (02:30), `getDashboard`, `getRevenueReport`. Money fields are removed for callers without revenue access (BR-REV1).

**App**
- [x] D18 billing hub, D19 invoice details, D20 submit payment (InstaPay box with copy buttons). AS10.
- [x] D1 full analytics (filters, compare, KPI tiles, charts C1–C12, insights), D35 revenue, D4 money and clinical columns, AS18.
- [x] AD1 admin dashboard, AD4 doctors list, AD5 doctor details (all tabs, actions), AD7 payments to review, AD8 payment review, AD9 invoices, AD10 invoice details.

**Status (20 Nov 2026):** the API and the app are written and their tests pass: `dotnet test` 710 of 710 (new: `BillingTests`, `AnalyticsTests`, covering AC-6, 7, 8, 9, 12, 23, 24 and a month close run twice) and `flutter test` 544 passed, 190 skipped (new: `billing_analytics_test.dart`). Contract: `backend/docs/api-phase-7.md`. Notes:
- The jobs run in `BillingJobsHost` (`Jobs:Enabled`, off in tests); each job runs once per Cairo day per process and is idempotent. A billing suspension carries the reason `billing:{yyyy-MM}`, so a manual suspension (BR-G4) is never lifted by a payment.
- The dashboard computes from `Sessions` and `Appointments` live; `DoctorDailyMetrics` is built nightly but not yet read by it.
- The app needs Flutter 3.50 or newer (pdfrx needs Dart 3.13).
- Not verified: devices and Windows runs, a load test, a run against a real SQL Server outside the tests, a contract test for Phase 7.
- Merging Phases 1–3 with 4–6 left committed conflict markers; they are resolved, and some Phase 2/4/5 widget tests were updated to the merged app (start-up gate, floating bottom bar, live board as home).

**Tables:** Invoices, InvoiceBranchBreakdown, InvoiceAdjustments, InvoiceStatusHistory, Payments, PaymentScreenshots, DailyStats, MonthlyStats, DoctorDailyMetrics, Doctors (status), DoctorAdminNotes, Sessions.

**Done when:** AC-6, AC-7, AC-8, AC-9, AC-12, AC-23 and AC-24 pass, including a full month close run twice with no change the second time.

---

## Phase 8: Hardening and release

**Goal:** the app is ready for the stores and for real clinics.

**Status (21 Nov 2026).** Done in code, committed on `dev` and not pushed:
- Security sweep (`SecuritySweepTests`): every route needs a sign-in unless it is public on purpose; an admin gets 403 on clinic, patient and money routes; a patient gets 403 on staff and admin routes. All pass. Rate limits already existed (login, reset, sign-up, refresh).
- Monitoring: a failed billing job writes one log line starting `ALERT billing-job` and turns `GET /api/health/jobs` to 503 until the next success (`JobHealthTests`). Crashlytics or Sentry is still open: it needs an account and a choice.
- Performance: lists are 25 per page (records were 30); payment screenshots are compressed before upload; the dashboard answers in about 0.02 to 0.3 s on the demo data (441 sessions). Not measured on 4G or on a large clinic.
- Reduced motion and large text: `phase7_accessibility_test.dart` opens the Phase 7 screens at 360 dp, text 1.3x, in Arabic and English, light and dark. It found and fixed four phone overflows.
- Icons for Android, iOS, Windows and macOS come from `brand/el3yada-icon.png`. No native splash yet; the app draws its own (A1).
- Open and needing you: real-device QA, the 60 fps check, golden baselines, backups and restore, the legal review, name and trademark checks, store listings and accounts, the signed Windows installer.
- Known: the API test project uses `Microsoft.AspNetCore.SignalR.Client` 10.0.11, whose dependency has a high-severity advisory (test-only; bump when a patched version is out).

- [ ] Full QA on Android, iOS and Windows (macOS if in scope), in all four combinations: Arabic/English × light/dark. Golden tests for the main screens. AC-16 and AC-17 pass.
- [ ] Motion review on a mid-range Android phone in profile mode: 60 fps on the live board, the bottom bar and the screen transitions. Every screen still works with reduced motion on, and no animation blocks a tap.
- [ ] Performance: dashboard under 2 seconds on 4G, lists paginated at 25, image compression on upload.
- [ ] Monitoring: Crashlytics or Sentry in the app, API logs with alerts on billing-job errors.
- [ ] Backups and point-in-time restore tested on a copy of `prod`.
- [ ] Security review: rate limits, file access, authorization tests green, admin blocked from medical content.
- [x] Account deletion for every role (spec 6.17, backend/docs/api-account-deletion.md; branch `feat/account-deletion`, 21 Nov): delete from P14, D24, AS12 and AD18 with the current password, no admin approval. The account is disabled at once, signing in during the 30-day grace period (`accountDeletionGraceDays`, AD13) opens only A16 (restore, sign out, a doctor's invoices), and the daily `accountErasure` job erases the identity while medical and billing records stay. Doctors: refused with unpaid invoices, a final invoice closed early, erasure waits for payment, carried fees after a paid final invoice. AD12 lists every deletion with Cancel and restore; AD5 and AD11 start one. Store listings can point to it (privacy forms).
- [ ] Legal review of the Terms and Privacy Policy against Law 151 of 2020.
- [ ] Name and store checks: search the stores for the existing app «el3eyada» and check the Egyptian trademark register before submitting. Confirm the bundle ID `com.el3yada.app`; it cannot change after the first upload.
- [ ] Store listings: name «el3yada | العيادة», Arabic keywords (عيادة, عياده, دكتور, كشف, حجز, روشتة), screenshots in Arabic and English, privacy forms, account-deletion flow.
- [ ] Windows signed installer (MSIX), auto-update check against `minAppVersion` [S]. macOS DMG if in scope.
- [ ] App icons and splash (light and dark).
