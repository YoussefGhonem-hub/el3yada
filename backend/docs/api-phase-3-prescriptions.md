# el3yada API: Phase 3, prescriptions

This covers:
- spec 6.4 and 6.4.1 (BR-RX1 to BR-RX6);
- screens D13 to D15, D22 (the prescription header and print settings), D23, AS7 and AS8;
- acceptance check AC-15.

The clinic rules of api-phase-2.md apply to every endpoint: the guard order, `TRIAL_ENDED` once the free trial is merged, `DOCTOR_SUSPENDED`, 404 for another doctor's records, and the activity log (D27).

**The app builds the PDF** with the Flutter `pdf` package, following the 6.4.1 layout. It uploads that PDF when it sends the prescription, so the patient, every reprint and the paper all show the same document (BR-RX4, BR-RX5).

## Who may do what

| Endpoint | Doctor | Assistant | Blocked while suspended |
|---|---|---|---|
| `createPrescriptionDraft`, `updatePrescriptionDraft`, `deletePrescriptionDraft` | ✔ | `prescriptionsDraft` (needs `clinicalView`) | yes |
| `submitDraftForReview` [S] | ✘ (`permission: "assistantOnly"`) | `prescriptionsDraft` | yes |
| `sendPrescription` | ✔ | ✘ doctor only | yes |
| `cancelPrescription` | ✔ | ✘ doctor only | no |
| Reads (session, patient, one, PDF) | ✔ | `clinicalView`: every status. `prescriptionsPrint` only: **sent** ones (AS8). Neither: 403 `PERMISSION_DENIED` (`prescriptionsPrint`). | no |
| `itemHistory` | ✔ | `prescriptionsDraft` | no |
| `deleteHistoryItem`, templates, print settings, logo and signature | ✔ | ✘ doctor only | no |

Patients and admins get 403 `FORBIDDEN` on all of these. The patient's own views come with Phase 4.

## Statuses (BR-RX2)

`draft` → `readyForReview` [S] → `sent` → `cancelled`.

- Drafts and `readyForReview` documents can be edited, deleted and sent.
- `sent` and `cancelled` documents are read-only. Editing one answers 409 `PRESCRIPTION_NOT_EDITABLE`, with `status`.
- To change a sent document, cancel it and **issue a new copy**.

## The prescription view

```json
{
  "prescriptionId": "…", "patientId": "…", "sessionId": "…",
  "kind": "medication", "status": "draft",
  "diagnosis": "التهاب الحلق", "advice": "راحة تامة", "followUpDate": "2026-12-01",
  "items": [ { "drugName": "Panadol", "activeIngredient": "paracetamol", "catalogId": "drug:123", "form": "tablet",
               "strength": "500 mg", "dose": "قرص", "frequency": "3 مرات يومياً", "timing": "afterFood",
               "duration": "5 أيام", "instructions": "بعد الأكل" } ],
  "preparedBy": { "userId": "…", "role": "assistant", "name": "منى السيد" },
  "sentAt": null, "cancelledAt": null, "cancelReason": null,
  "replacesRxId": null, "replacedById": null,
  "qrShortCode": "aZ3kP0qLm9Xc", "qrUrl": "https://api.example/rx/aZ3kP0qLm9Xc",
  "hasPdf": false, "createdAt": "…", "updatedAt": "…"
}
```

- **`kind`**: `medication` («روشتة علاج») or `investigations` («روشتة تحاليل وأشعة»).
- **`items`** depend on the kind:
  - **Medication:** `drugName, activeIngredient, catalogId, form, strength, dose, frequency, timing, duration, instructions`.
  - **Investigations:** `category` (`lab` or `radiology`), `name`, `loincCode`, `notes`.
- **`followUpDate`**: zone 6 of the printed page (6.4.1). It prints as «موعد المتابعة» on a medication prescription and as «إحضار النتائج في» on an investigations request.
- **`qrShortCode`** is 12 random base62 characters, made when the draft is created. **`qrUrl`** is what the app prints as the QR code: `{AppLinks:PublicBaseUrl}/rx/{qrShortCode}`.
- **`preparedBy`** is the person who created the draft. The doctor sees "Prepared by …" (BR-AS10).
- **`replacedById`** points to the new copy made from a cancelled document. The patient app shows the cancelled one struck through, next to its replacement.
- The doctor's header for the PDF comes from other endpoints:
  - D22 profile: names, titles and degrees;
  - `GET /api/doctor/rxSettings`;
  - the logo and signature (below);
  - the branches (D28).

## Drafts

### `POST /api/prescriptions/createPrescriptionDraft`

`{ "sessionId": "…", "kind": "medication", "copyFromId": null }` → **201**, the view.

- **`sessionId`**: one of this doctor's sessions that isn't deleted (BR-RX1). Otherwise 400 `INVALID_SESSION`. The D6 "new prescription" flow picks one of today's sessions or creates one first.
- **Pre-filled** from the session: the diagnosis, plus the session's follow-up date for a medication prescription.
- **`copyFromId`** ("Issue new copy", D15) copies the diagnosis, advice, follow-up and items, and sets `replacesRxId`. It must name a `sent` or `cancelled` document of the same kind for the same patient. Otherwise 400 `INVALID_COPY_SOURCE`.
- The activity log gets `prescriptionDraftCreated`.

### `POST /api/prescriptions/updatePrescriptionDraft`

```json
{ "prescriptionId": "…", "diagnosis": "…", "advice": "…", "followUpDate": "2026-12-01", "items": [ … ] }
```

- **Everything is replaced.** A field left out is cleared.
- **Items** are stored in the order sent, which is how D13 and D14 reorder them (drag to reorder).
- **Text:** `diagnosis` and `advice` are trimmed, and their line breaks are kept.
- **Answers:**
  - **200**: the view. The activity log gets `prescriptionDraftUpdated`, with the item count only.
  - 404 for another doctor's document.
  - 409 `PRESCRIPTION_NOT_EDITABLE`.

**Field rules** (spec 6.4 and 11):

| Field | Rule | Error codes |
|---|---|---|
| `diagnosis`, `advice` | ≤ 1000 | `TOO_LONG` |
| `followUpDate` | a date between 2000 and 2100 | `INVALID_DATE` |
| `items` | medication: ≤ 30; investigations: ≤ 50 | `TOO_MANY` (field `items`) |
| `items[i].drugName` | required, ≤ 200 | `REQUIRED`, `TOO_LONG` |
| `items[i].activeIngredient` | ≤ 300 | `TOO_LONG` |
| `items[i].catalogId` | ≤ 50: the catalog row the doctor picked (BR-CAT7), or null for typed text (BR-CAT8) | `TOO_LONG` |
| `items[i].form` | ≤ 40. The app offers `tablet, capsule, syrup, injection, cream, drops, inhaler, suppository, sachet, other`, or free text. | `TOO_LONG` |
| `items[i].strength` | ≤ 40 | `TOO_LONG` |
| `items[i].dose`, `frequency`, `duration` | ≤ 60. The app formats the duration ("5 أيام", "أسبوعين", "مستمر"). | `TOO_LONG` |
| `items[i].timing` | `beforeFood`, `afterFood`, `withFood` or `unspecified` | `INVALID_VALUE` |
| `items[i].instructions` | ≤ 300 | `TOO_LONG` |
| `items[i].category` | `lab` or `radiology` (investigations) | `REQUIRED`, `INVALID_VALUE` |
| `items[i].name` | required, ≤ 200 (investigations) | `REQUIRED`, `TOO_LONG` |
| `items[i].loincCode` | ≤ 20 | `TOO_LONG` |
| `items[i].notes` | ≤ 300 | `TOO_LONG` |

A field that belongs to the other kind answers `INVALID_VALUE`, for example `category` on a medication item.

Error paths look like `items[2].drugName`.

### `POST /api/prescriptions/deletePrescriptionDraft`

`{ prescriptionId }` → **204**. It discards a draft or a `readyForReview` document. The patient never saw it, so nothing is kept. The activity log gets `prescriptionDraftDeleted`.

### `POST /api/prescriptions/submitDraftForReview` [S]

`{ prescriptionId }` → **200**, the view with status `readyForReview`. This is AS7 «إرسال للطبيب للمراجعة» (BR-AS12).

- It needs at least one item. Otherwise 409 `PRESCRIPTION_EMPTY`.
- Calling it again answers 200 and changes nothing.
- The doctor gets «مسودة روشتة جاهزة للمراجعة — المريض …», routed to `/prescriptions/{id}`.
- The doctor reviews the draft in D13 or D14 and sends it from D15.

## Sending

### `POST /api/prescriptions/sendPrescription` (doctor only)

`multipart/form-data`:

| Part | Content |
|---|---|
| `data` | `{ "prescriptionId": "…" }` |
| `pdf` | The PDF the app built, ≤ 10 MB |

This one call covers D15 "Send to patient" and "Send and print". The app prints the same PDF once the call has answered. "Printing a draft sends it" (BR-RX5) uses this endpoint too.

On success:
1. The PDF is stored at `prescriptions/{doctorId}/{patientId}/{rxId}.pdf`.
2. The status becomes `sent`, with `sentAt` set.
3. Every item is counted in the doctor's **item history** ("used before", BR-CAT4). The key is the kind, name, form and strength for a drug, and the kind and name for a test. Each key counts once per document.
4. The patient gets «روشتة علاج جديدة من د. …» or «روشتة تحاليل وأشعة جديدة من د. …», routed to `/prescriptions/{id}`, with no medical text.
5. The activity log gets `prescriptionSent`.

**200** returns the view.

Errors:

| Status | Code | When |
|---|---|---|
| 400 | `data.prescriptionId`: `REQUIRED` | |
| 400 | `pdf`: `REQUIRED`, `FILE_TYPE_NOT_ALLOWED`, `FILE_TOO_LARGE` | `FILE_TYPE_NOT_ALLOWED`: not a PDF by its bytes |
| 404 | | |
| 409 | `PRESCRIPTION_NOT_EDITABLE` | already sent or cancelled |
| 409 | `PRESCRIPTION_EMPTY` | no items (BR-RX3) |
| 413 | `REQUEST_TOO_LARGE` | |

### `POST /api/prescriptions/cancelPrescription` (doctor only)

`{ prescriptionId, reason }`.

- `reason` is 3–500 characters; otherwise `REASON_REQUIRED` or `TOO_LONG`. The patient sees it in the app.
- Only a `sent` document can be cancelled. Otherwise 409 `PRESCRIPTION_NOT_SENT`, with `status`.
- **200**: the view.
- The patient gets «تم إلغاء روشتة». The reason is not in the push text.
- A cancelled document can't be printed (BR-RX5). The app hides Print, but the stored PDF stays for the record.

## Reads

- `GET /api/sessions/{sessionId}/prescriptions`: D9 and D15 "Print all". The session's documents, oldest first, as an array of views.
- `GET /api/patients/{patientId}/prescriptions?kind=&page=&pageSize=`: the D6 Prescriptions tab. Newest first, as a paged list of views.
- `GET /api/prescriptions/{id}`: the view, or 404, also when the caller may not see that status.
- `GET /api/prescriptions/{id}/pdf[?download=true]`: the stored PDF.
  - It exists for sent and cancelled documents. Assistants with only `prescriptionsPrint` get sent ones.
  - Returned inline, or as an attachment named `prescription-YYYY-MM-DD.pdf` or `request-…`.
  - Headers: `Cache-Control: private, no-store`.
  - The PDF is what **Reprint** prints (BR-RX5), so every copy is identical.

## Item history and templates

### `GET /api/prescriptions/itemHistory`

The doctor's 1000 most used items, by `useCount` and then `lastUsedAt`. The editors put these first on the device (BR-CAT4 group 1).

```json
[ { "itemId": "…", "kind": "drug", "name": "Panadol", "catalogId": "drug:123", "form": "tablet", "strength": "500 mg",
    "useCount": 5, "lastUsedAt": "…" } ]
```

- **`kind`**: `drug`, `lab` or `radiology`.
- **`catalogId`**: the catalog ID for a drug, or the LOINC code for a test.

### `POST /api/prescriptions/deleteHistoryItem` [S] (D23)

`{ itemId }` → **204**, or 404.

### Templates [S] (BR-RX6, D23)

Doctor only.

| Endpoint | Request | Answer |
|---|---|---|
| `GET /api/prescriptionTemplates?kind=` | | Sorted by name |
| `POST /api/prescriptionTemplates/createTemplate` | `{ name ≤ 100, kind, items (1+, same rules), advice? }` | **201** |
| `POST /api/prescriptionTemplates/updateTemplate` | `{ templateId, name, items, advice? }`. Everything replaced; the kind can't change. | **200** |
| `POST /api/prescriptionTemplates/deleteTemplate` | `{ templateId }` | **204** |

The template view is `{ templateId, kind, name, items, advice, createdAt, updatedAt }`. Using a template is done in the app: it fills the draft's items, which are then saved with `updatePrescriptionDraft`.

## D22: prescription header and print settings

The names, titles and degrees come from the D22 profile (`/api/doctor/profile`). The rest:

### `GET /api/doctor/rxSettings`

```json
{ "language": "ar", "accentColor": "#0F4C45", "paperSize": "A5", "customWidthMm": null, "customHeightMm": null,
  "preprinted": false, "marginTopMm": null, "marginBottomMm": null, "footerText": null,
  "hasLogo": true, "hasSignature": false, "updatedAt": "…" }
```

### `POST /api/doctor/updateRxSettings`

Every field is replaced.

| Field | Rule | Error codes |
|---|---|---|
| `language` | `ar` or `en`: the prescription language, independent of the app's | `REQUIRED`, `INVALID_VALUE` |
| `accentColor` | `#RRGGBB`, stored in upper case. Default: the brand pine `#0F4C45`. | `REQUIRED`, `INVALID_VALUE` |
| `paperSize` | `A5` (default), `A4` or `custom` [S] | `REQUIRED`, `INVALID_VALUE` |
| `customWidthMm`, `customHeightMm` | Required with `custom`: 90–300 × 120–420 mm, one decimal. Cleared for A5 and A4. | `REQUIRED`, `OUT_OF_RANGE` |
| `preprinted` | true or false (pre-printed paper mode) | `REQUIRED` |
| `marginTopMm`, `marginBottomMm` | 0–100 mm, one decimal; used in pre-printed mode | `OUT_OF_RANGE` |
| `footerText` | ≤ 300 | `TOO_LONG` |

**200** returns the settings. When something changed, the activity log gets `rxSettingsUpdated`, with the field names.

### Logo and signature

| Endpoint | Request | Answer |
|---|---|---|
| `POST /api/doctor/uploadRxImage` | `multipart/form-data` with `kind` (`logo` or `signature`) and `file` (JPEG, PNG or WebP, ≤ 2 MB) | **200**: the settings |
| `GET /api/doctor/rxImage/{logo\|signature}` | | The PNG, or 404 when there is none |
| `POST /api/doctor/deleteRxImage` | `{ kind }` | **200**: the settings. Deletes the file. |

- **Storage:** the image is stored as a **PNG that keeps transparency**, upright, at most **1000 px** on the long edge, with no metadata, at `doctors/{doctorId}/branding/{logo|signature}.png`. That keeps it sharp on a 30 mm header at 300 dpi and small on disk.
- **Errors:** `kind` `INVALID_VALUE`; `file`: `REQUIRED`, `FILE_TOO_LARGE`, `FILE_TYPE_NOT_ALLOWED`, `FILE_CONTENT_INVALID`.
- **Activity log:** `rxBrandingUpdated`.

## The QR link (`rxLink`, 6.4.1)

These are anonymous and not under `/api`.

- **`GET /rx/{shortCode}`** answers **302**:
  - to `AppLinks:PlayStoreUrl` on Android;
  - to `AppLinks:AppStoreUrl` on iPhone and iPad;
  - to `AppLinks:WebUrl` otherwise.

  It never reads the database, so every code gets the same answer and a code reveals nothing. It sends `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
- **`GET /.well-known/assetlinks.json`**: Android App Links, built from `AppLinks:Android` (package names with their SHA-256 signing fingerprints).
- **`GET /.well-known/apple-app-site-association`**: iOS Universal Links for `/rx/*`, built from `AppLinks:IosAppIds`.

On a phone with the app, the link opens the app directly. The **patient-side resolve endpoint** comes with Phase 4 (P7): the app sends the short code after sign-in and gets the prescription.

**`AppLinks` settings** (`appsettings.json`, checked at start-up):
- `PublicBaseUrl`: must not be localhost in production;
- `PlayStoreUrl`, `AppStoreUrl`, `WebUrl`;
- `Android[]`: `{ PackageName, Sha256CertFingerprints[] }`;
- `IosAppIds[]`: `"TEAMID.bundle.id"`.

## Error codes

| Code | HTTP | Meaning |
|---|---|---|
| `PRESCRIPTION_NOT_EDITABLE` | 409 | Sent or cancelled. The answer has `status`. |
| `PRESCRIPTION_NOT_SENT` | 409 | Only a sent document can be cancelled. The answer has `status`. |
| `PRESCRIPTION_EMPTY` | 409 | No items (BR-RX3). |
| `INVALID_COPY_SOURCE` | 400 | `copyFromId` is not a sent or cancelled document of this kind for this patient. |
| `INVALID_SESSION` | 400 | Not one of this doctor's sessions. |

## Storage and data

- **PDF:** `prescriptions/{doctorId}/{patientId}/{rxId}.pdf`.
- **Branding:** `doctors/{doctorId}/branding/{logo|signature}.png`.
- **Migration `PrescriptionsAndCatalogs`:**
  - `Prescriptions.FollowUpDate`;
  - the default clinic colour `#0F4C45`;
  - the General specialty profile row (see api-phase-3-catalogs.md).
