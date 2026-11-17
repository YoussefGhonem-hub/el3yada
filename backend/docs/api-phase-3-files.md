# el3yada API: Phase 3, medical files

Spec 6.3 (BR-F1 to BR-F9), D10 to D12, AS6 and AC-14. The clinic rules of api-phase-2.md apply to every endpoint here: the guard order, `TRIAL_ENDED`, `DOCTOR_SUSPENDED`, 404 for another doctor's records, and the activity log.

| Endpoint | Doctor | Assistant | Blocked while suspended |
|---|---|---|---|
| `POST /api/records/uploadFile` | ✔ | `filesManage` | yes |
| `POST /api/records/createRecord` | ✔ | `filesManage` | yes |
| `GET /api/patients/{patientId}/records`, `GET /api/records/{recordId}`, file and thumbnail downloads | ✔ | `filesManage` | no (read-only) |
| `POST /api/records/updateRecord` | ✔ | `filesManage` | yes |
| `POST /api/records/deleteRecord` | ✔ | ✘ doctor only (6.10) | yes |

## How an upload works

A record is saved in two steps, so each file gets its own progress bar and its own retry (D11, AC-14):

1. **`uploadFile`**, once per file. The file is checked, optimized (below) and kept as a **pending upload** for 24 hours. The answer has an `uploadId`.
2. **`createRecord`** with the metadata and the `uploadIds`. The pending files become the record's attachments, in the order given.

Pending uploads that no record claims within 24 hours are deleted.

## Making files smaller (storage)

Every file is made as small as it can be without losing what a doctor needs to read. The server does this for every upload, whatever the app sends, so storage stays small even for an old app or an unusual file.

| What | What the server does |
|---|---|
| Photos and images (JPEG, PNG, WebP; HEIC is converted by the app first) | Turned upright (EXIF orientation). The longest edge is cut to **2560 px**: an A4 page at about 220 dpi, sharp enough for small print, while phone photos are often 4000+ px. Saved as **JPEG quality 80**, which strips all metadata (EXIF, GPS location). If that is not at least 10% smaller than the original, the original JPEG is kept and only its metadata segments are removed, losslessly. |
| PDFs | Kept as they are. The app builds scan PDFs small already: pages at most 2000 px on the long edge, JPEG quality 75. The app sends a first-page thumbnail with every PDF, because the server doesn't render PDFs. |
| Other files (DICOM, Word, ZIP, video, …), BR-F4 | Compressible types (DICOM, text, CSV, XML, JSON, BMP, TIFF, WAV, …) are stored **gzip-compressed** when that saves at least 10%. Downloads are decompressed on the fly, so users always get the original bytes. Already-compressed types (ZIP, Office files, MP4, MP3, …) are stored as they are. |
| Thumbnails | One JPEG thumbnail of at most 320 px (`Storage:ThumbnailMaxPx`) per image attachment, made by the server. For PDFs, the app's first-page thumbnail is checked and saved the same way. Lists load thumbnails only, never the files themselves. |

The size limit (`maxUploadMb`, default 50 MB, BR-F5) applies to the file as uploaded, before any optimization.

Every answer gives three sizes:
- `sizeBytes`: what users download;
- `storedSizeBytes`: what is on disk;
- `originalSizeBytes`: what was uploaded.

The app can show the saving: «تم تقليل الحجم من 4.2 ميجا إلى 610 ك.ب».

## `POST /api/records/uploadFile`

`multipart/form-data`:

| Part | Content |
|---|---|
| `file` | One file, any type (BR-F4). |
| `thumbnail` | Optional. A JPEG or PNG of the first page, for a PDF. At most 2 MB; resized to 320 px. Ignored for images, because the server makes those. |
| `pageCount` | Optional. The number of pages, for a PDF the app built from a scan. |

The type is read from the file's bytes for JPEG, PNG, WebP and PDF. Anything else keeps the part's Content-Type, or `application/octet-stream`, and the file name's extension. The file name is kept for display only; storage paths are built from IDs.

**201**, with `Cache-Control: no-store`:

```json
{
  "uploadId": "…", "fileName": "scan-1.jpg", "mimeType": "image/jpeg",
  "sizeBytes": 612034, "storedSizeBytes": 612034, "originalSizeBytes": 4380112,
  "pageCount": null, "hasThumbnail": true, "optimized": true, "expiresAt": "2026-11-18T09:00:00.000Z"
}
```

Errors:
- 400 `file`: `REQUIRED`;
- 400 `file`: `FILE_TOO_LARGE`, with `maxMb`;
- 400 `file`: `FILE_CONTENT_INVALID` (an image that can't be read);
- 400 `thumbnail`: `FILE_TYPE_NOT_ALLOWED`, `FILE_TOO_LARGE`;
- 400 `pageCount`: `OUT_OF_RANGE` (1–500);
- 413 `REQUEST_TOO_LARGE`.

## `POST /api/records/createRecord`

```json
{
  "patientId": "…", "category": "other", "otherType": "sickLeave", "otherTypeText": null,
  "title": null, "documentDate": "2026-11-17", "notes": null, "sessionId": null,
  "source": "scan", "uploadIds": ["…", "…"]
}
```

| Field | Rule | Error codes |
|---|---|---|
| `patientId` | one of this doctor's patients (linked) | `REQUIRED`; 404 |
| `category` | `radiology`, `lab`, `prescription` or `other` | `REQUIRED`, `INVALID_VALUE` |
| `otherType` [S] | only with `other`: `report`, `referral`, `sickLeave`, `ecg`, `eegEmg`, `endoscopy`, `consent` or `custom` | `INVALID_VALUE` |
| `otherTypeText` | required with `custom`, ≤ 60 | `REQUIRED`, `TOO_LONG` |
| `title` | ≤ 120. Empty means category plus date (BR-F3), stored in the doctor's language. | `TOO_LONG` |
| `documentDate` | `YYYY-MM-DD`, not after today (Cairo). Defaults to today. | `INVALID_DATE` |
| `notes` | ≤ 1000 | `TOO_LONG` |
| `sessionId` | optional; this patient's session with this doctor, not deleted | `INVALID_SESSION` |
| `source` | `scan` or `upload` (`chat` comes with Phase 5) | `REQUIRED`, `INVALID_VALUE` |
| `uploadIds` | 1–20, no repeats; uploads made in this clinic and not yet used or expired | `REQUIRED`, `TOO_MANY`, `UPLOAD_NOT_FOUND` (with `uploadId`) |

**201**: the record view.
- The patient gets a «ملف جديد» notification (BR-F9; push delivery comes with Phase 5).
- The clinic's activity log gets `medicalRecordCreated`.

**Record view:**

```json
{
  "recordId": "…", "patientId": "…", "category": "other", "otherType": "sickLeave", "otherTypeText": null,
  "title": "إجازة مرضية", "documentDate": "2026-11-17", "notes": null,
  "session": { "sessionId": "…", "type": "examination", "createdAt": "…" },
  "source": "scan", "createdAt": "…", "updatedAt": "…",
  "createdBy": { "userId": "…", "role": "assistant", "name": "سارة محمود" },
  "attachments": [
    { "attachmentId": "…", "fileName": "scan.pdf", "mimeType": "application/pdf", "sizeBytes": 812300,
      "storedSizeBytes": 812300, "pageCount": 3, "hasThumbnail": true, "previewable": true }
  ],
  "totalSizeBytes": 812300
}
```

- `previewable`: images and PDFs open inside the app (D12). Other types show "Open with" and "Download" (BR-F4).
- `createdBy` is shown to the doctor as "Recorded by …" (BR-AS10).

## `GET /api/patients/{patientId}/records`

The D6 Files tab and AS6. Query parameters:
- `category`: one of the four, or empty for all;
- `page`, `pageSize`: default 30, maximum 100.

Newest first, by document date and then by creation time. The answer is a paged list of record views plus `counts`, `{ "radiology": 2, "lab": 5, "prescription": 1, "other": 0 }`, for the category chips. Deleted records never appear.

## `GET /api/records/{recordId}`

The record view (D12). Error: 404.

## Downloads

- `GET /api/records/{recordId}/attachments/{attachmentId}`:
  - Streams the original bytes, decompressing them if they were stored gzip-compressed, with the attachment's `mimeType`.
  - Sent as `Content-Disposition: inline` (`attachment` with `?download=true`), with the original file name.
  - Headers: `Cache-Control: private, no-store` and `X-Content-Type-Options: nosniff`.
- `GET /api/records/{recordId}/attachments/{attachmentId}/thumbnail`: a JPEG. Error: 404 `NOT_FOUND` when there is none.

## `POST /api/records/updateRecord`

`{ recordId, category, otherType?, otherTypeText?, title?, documentDate, notes?, sessionId? }`. Every field is replaced, as in `updateClinical`: the app sends the whole form. The rules are the same as create.
- A field left out is cleared: `notes`, `sessionId` (unlinks the session), `otherType`.
- An empty `title` goes back to the default.
- Changing `category` away from `other` clears `otherType`.
- **200**: the record view.
- If anything changed, the activity log gets `medicalRecordUpdated` with the changed field names.

## `POST /api/records/deleteRecord` (doctor only)

`{ recordId }` → **204**.
- A soft delete (`Deleted`, `DeletedAt`, `DeletedBy`). The record disappears for everyone, including the patient.
- The files are kept for the audit trail.
- The activity log gets `medicalRecordDeleted`.
- Asking again: 404.

## Error codes

| Code | HTTP | Meaning |
|---|---|---|
| `FILE_TOO_LARGE` | 400 | Over `maxUploadMb`; the answer has `maxMb`. |
| `UPLOAD_NOT_FOUND` | 400 | The upload expired, was already used, or belongs to another clinic; the answer has `uploadId`. Upload it again. |
| `INVALID_SESSION` | 400 | The session is not this patient's, or it was deleted. |
| `TOO_MANY` | 400 | More than 20 files in one record. |
| `INVALID_DATE` | 400 | The document date is in the future. |

## Storage

- Pending uploads live at `uploads/{doctorId}/{uploadId}.{ext}` and move to `medical/{doctorId}/{patientId}/{recordId}/{attachmentId}.{ext}` when a record claims them.
- `{ext}` is `jpg`, `png`, `webp` or `pdf`, or `bin` for any other file and `gz` for a gzip-compressed one. The real type is in `MimeType`.
- Table `PendingUploads` and column `MedicalRecordAttachments.StoredSizeBytes` come from migration `MedicalFileStorage`.
