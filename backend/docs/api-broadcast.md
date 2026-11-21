# el3yada API: AD16 broadcast [C]

Spec AD16 and 10.1 ("Broadcast [C]", recipients: doctors, text: the admin's). Any admin (`admin` or `superAdmin`); doctors, assistants and patients get 403, and anonymous callers 401.

A broadcast is an ordinary notification (type `broadcast`) written for each recipient through the notification service, so delivery is the usual one: the in-app notification centre (D21), SignalR to running apps (Windows toasts), and FCM to Android and iOS devices **in each doctor's language** (`users.locale`). It has no table of its own: the history is read from its audit row.

## `POST /api/admin/sendBroadcast`

```json
{ "audience": "all", "doctorIds": null,
  "titleAr": "تحديث جديد", "bodyAr": "أضفنا الحجز من التطبيق.",
  "titleEn": "New update", "bodyEn": "Booking from the app is here." }
```

| Field | Rule | Error codes |
|---|---|---|
| `audience` | `all` or `selected` | `REQUIRED`, `INVALID_VALUE` |
| `doctorIds` | `selected`: 1–500 distinct doctor ids. `all`: left out. | `REQUIRED`, `INVALID_VALUE` (also when one id isn't a doctor) |
| `titleAr`, `titleEn` | ≤ 100 | `TOO_LONG`, `REQUIRED` |
| `bodyAr`, `bodyEn` | ≤ 500 | `TOO_LONG`, `REQUIRED` |

- A language is written whole (title **and** body) or left out; half a language answers `REQUIRED` on the missing half. At least one language is needed (`titleAr` `REQUIRED` when nothing is written).
- A language left out takes the other's text (spec 12: admin texts fall back to the other language), so every row has both.
- Texts are trimmed.

**Recipients:** doctors whose account is active and whose clinic is `active` or `suspended`. Pending, rejected and disabled doctors are left out, also when chosen. Assistants and patients never get a broadcast. When nobody is left: 409 `BROADCAST_NO_RECIPIENTS`.

**201** returns the broadcast view:

```json
{ "broadcastId": "…", "sentAt": "…", "sentBy": { "userId": "…", "displayName": "نور عادل" },
  "audience": "all", "recipients": 128,
  "titleAr": "…", "bodyAr": "…", "titleEn": "…", "bodyEn": "…" }
```

Each recipient's notification: `type: "broadcast"`, the four texts, `route: null`, `data: { broadcastId }`.

The audit log gets `broadcastSent`, target `broadcast` / the broadcast's id, with `{ audience, recipients, doctorIds, titleAr, bodyAr, titleEn, bodyEn }` (`doctorIds` only for `selected`). It is saved with the notifications in one transaction; delivery starts once they are committed.

## `GET /api/admin/broadcasts?page=&pageSize=`

The broadcasts sent, newest first: a page (`items`, `page`, `pageSize`, `totalCount`) of broadcast views, read from the `broadcastSent` audit rows.
