# Kultitracker — MongoDB schema (collections & fields)

MongoDB uses **collections** (not SQL tables). Use database name **`kultitracker`** with the collections below for **login/register**, **habits**, **daily check-ins**, **streaks/stats**, **companion**, **social arena**, and **Habit Teacher bot**.

Initialize: run `mongodb/init_indexes.mongosh.js` against **your** MongoDB (local or Atlas). If you use **Atlas** and do not see `kultitracker`, read **`mongodb/ATLAS.md`** — you must run the script with your `mongodb+srv://` URI, not only localhost.

---

## 1. `users`

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | Primary key |
| `email` | string | Unique, lowercase normalized |
| `passwordHash` | string | bcrypt/argon2 (never store plain text) |
| `displayName` | string | Matches register `name` / greeting |
| `bestStreakRecorded` | int | Cache of best global streak (same as `HabitStore`) |
| `createdAt` | date | |
| `updatedAt` | date | |
| `lastLoginAt` | date | optional |
| `settings` | object | optional: `{ "theme": "dark" }` |
| `companion` | object | optional: equipped/unlocked skins (see below) |

**`companion` (optional)**

| Subfield | Type | Notes |
|----------|------|--------|
| `equippedSkinId` | string \| null | e.g. `"default"`, `"crown"` |
| `unlockedSkinIds` | string[] | IDs unlocked by XP/check-ins |

**Indexes**

- Unique: `{ email: 1 }`

---

## 2. `habits`

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | Replaces client string id when syncing |
| `userId` | ObjectId | ref → `users._id` |
| `title` | string | |
| `category` | string | `"focus"` \| `"move"` \| `"mind"` \| `"learn"` |
| `clientId` | string | optional; original app id for merge/sync |
| `isArchived` | bool | default `false` |
| `sortOrder` | int | optional UI order |
| `createdAt` | date | |
| `updatedAt` | date | |

**Indexes**

- `{ userId: 1, isArchived: 1 }`
- `{ userId: 1, createdAt: -1 }`

---

## 3. `habit_completions` (one row per habit × calendar day)

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | |
| `userId` | ObjectId | |
| `habitId` | ObjectId | ref → `habits._id` |
| `day` | string | `"yyyy-MM-dd"` in **user’s timezone** (or fixed UTC+stored `timeZone`) |
| `checkedAt` | date | when the check-in was saved (server UTC) |

**Indexes**

- **Unique** compound (prevents duplicate check-in same day): `{ userId: 1, habitId: 1, day: 1 }`
- Calendar / stats: `{ userId: 1, day: 1 }`
- Per habit history: `{ habitId: 1, day: -1 }`

**Source of truth for “what happened each day”** — one document per habit per day. The backend also maintains **`user_stats_cache`**, **`daily_rollups`**, and **`calendar_orbit_days`** (updated when you toggle habits, bootstrap, or delete a habit) so **Stats**, **Calendar**, and **Calendar Orbit** have fast, queryable rows in Atlas.

---

## 4. `user_stats_cache` (Stats panel / leaderboard cache)

One document per user, **recomputed** from `habit_completions` + `habits` by `flutter_backend/services/statsCalendarSync.js`.

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | |
| `userId` | ObjectId | unique |
| `currentStreak` | int | consecutive UTC days with ≥1 completion ending today |
| `bestStreakRecorded` | int | max consecutive days in history (and current) |
| `totalCompletions` | int | count of completion documents |
| `activeHabitsCount` | int | count of habits |
| `totalPoints` | int | `totalCompletions * 25 + currentStreak * 15` (matches app formula) |
| `level` | int | `1 + floor(totalPoints / 500)` |
| `pulseDetails` | object | **Insight Lab / “Your pulse”** snapshot (recomputed with habits + completions; uses **UTC** calendar days on the server, which can differ from the device near midnight) |
| `createdAt` / `updatedAt` | date | Mongoose timestamps |

**`pulseDetails` (nested)**

| Subfield | Type | Notes |
|----------|------|--------|
| `focusScore` | number | 0–100, same formula as `HabitStore.focusScore()` |
| `ringProgress` | number | `focusScore / 100` (pulse ring fill) |
| `estimatedFocusMinutesToday` | int | `doneToday * 25` |
| `trendLabel` | string | e.g. `+12% vs prior week` |
| `momentumLast7` | number[] | 7 values 0–1, daily completion intensity (oldest → newest) |
| `avgDailyCompletionLast7` | number | average of `momentumLast7` |
| `categoryFractions` | object | `focus` / `move` / `mind` / `learn` (0–1) |
| `insightNudgeBody` | string | “Next win” copy |
| `tileStreakDays` | int | streak under the ring |
| `tileActiveHabits` | int | active habit count |
| `tileDeepWorkValue` | number | display number for Deep work tile |
| `tileDeepWorkUnit` | string | `"m"` or `"h"` |

**API:** `GET /api/me/stats-cache` (Bearer JWT) returns `pulseDetails` with the fields above.

**Indexes**

- Unique: `{ userId: 1 }`
- Leaderboard: `{ totalPoints: -1 }`

---

## 5. `daily_rollups` (Calendar / heatmap per day)

One document per **user × calendar day** that had at least one check-in. Removed when that day has zero completions.

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | |
| `userId` | ObjectId | |
| `day` | string | `yyyy-MM-dd` |
| `habitsCheckedInCount` | int | completions that day (habits done) |
| `activeHabitsCount` | int | total habits at update time |
| `dailyCompletionRatio` | double | `habitsCheckedInCount / activeHabitsCount` (0–1) |
| `createdAt` / `updatedAt` | date | |

**API:** `GET /api/me/calendar-days?from=yyyy-MM-dd&to=yyyy-MM-dd` (Bearer JWT).

**Indexes**

- Unique: `{ userId: 1, day: 1 }`
- `{ userId: 1, day: -1 }`

---

## 6. `calendar_orbit_days` (Calendar Orbit sheet per day)

One document per **user × calendar day** that had at least one check-in. Stores the same kind of data the app uses for orbit dots and the “Selected day” list (`Done · {habit title}`). Removed when that day has zero completions.

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | |
| `userId` | ObjectId | |
| `day` | string | `yyyy-MM-dd` |
| `habitsCompletedCount` | int | distinct habits completed that day |
| `lines` | string[] | e.g. `["Done · Reading", "Done · Yoga"]`, sorted |
| `createdAt` / `updatedAt` | date | |

**API:** `GET /api/me/calendar-orbit?year=YYYY&month=M` (Bearer JWT, `month` 1–12).

**Indexes**

- Unique: `{ userId: 1, day: 1 }`
- `{ userId: 1, day: -1 }`

---

## 7. `habit_teacher_sessions` (Habit Teacher bot)

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | |
| `userId` | ObjectId | |
| `messages` | array | `{ role: "user"\|"assistant", text: string, at: date }[]` |
| `updatedAt` | date | |

**Indexes**

- `{ userId: 1, updatedAt: -1 }`

---

## 8. `squads` (Social — groups)

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | |
| `name` | string | |
| `ownerUserId` | ObjectId | |
| `memberIds` | ObjectId[] | includes owner |
| `createdAt` | date | |

**Indexes**

- `{ memberIds: 1 }`

---

## 9. `squad_battles` (Social — timed challenges)

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | |
| `squadId` | ObjectId | ref → `squads._id` |
| `title` | string | e.g. “Morning Movers” |
| `startsAt` | date | |
| `endsAt` | date | |
| `scoresByUserId` | object | map string userId → int points during window |

**Indexes**

- `{ squadId: 1, endsAt: -1 }`

---

## 10. `refresh_tokens` (optional, if you use JWT refresh)

| Field | Type | Notes |
|--------|------|--------|
| `_id` | ObjectId | |
| `userId` | ObjectId | |
| `tokenHash` | string | hash of refresh token |
| `expiresAt` | date | |
| `createdAt` | date | |

**Indexes**

- `{ userId: 1 }`
- TTL optional on `expiresAt` if stored as Date

---

## Relationships (summary)

```
users 1 ── * habits
users 1 ── * habit_completions
habits 1 ── * habit_completions
users 1 ── * habit_teacher_sessions (or 1 active session per user)
users * ── * squads (via memberIds)
squads 1 ── * squad_battles
```

---

## Example documents

**`users`**

```json
{
  "_id": { "$oid": "..." },
  "email": "alex@example.com",
  "passwordHash": "$2b$12$...",
  "displayName": "Alex",
  "bestStreakRecorded": 12,
  "createdAt": { "$date": "2026-04-01T10:00:00.000Z" },
  "updatedAt": { "$date": "2026-04-04T08:00:00.000Z" },
  "companion": {
    "equippedSkinId": "default",
    "unlockedSkinIds": ["default", "crown"]
  }
}
```

**`habits`**

```json
{
  "_id": { "$oid": "..." },
  "userId": { "$oid": "..." },
  "title": "Morning reading",
  "category": "learn",
  "clientId": "1712345678901",
  "isArchived": false,
  "sortOrder": 0,
  "createdAt": { "$date": "2026-04-02T07:00:00.000Z" },
  "updatedAt": { "$date": "2026-04-02T07:00:00.000Z" }
}
```

**`habit_completions`**

```json
{
  "_id": { "$oid": "..." },
  "userId": { "$oid": "..." },
  "habitId": { "$oid": "..." },
  "day": "2026-04-04",
  "checkedAt": { "$date": "2026-04-04T15:30:00.000Z" }
}
```

---

## Next step in your stack

Your `AuthService` already calls `http://localhost:5000/register` and `/login`. Implement those routes in Node/Express (or similar) with **Mongoose** or the native driver, using the collections above. The Flutter app can then replace `SharedPreferences` sync with API calls per user.
