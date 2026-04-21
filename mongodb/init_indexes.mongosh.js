/**
 * Kultitracker — MongoDB database + indexes (mongosh)
 *
 * Database name: kultitracker
 *
 * Local (MongoDB Community):
 *   mongosh "mongodb://127.0.0.1:27017" --file mongodb/init_indexes.mongosh.js
 *
 * MongoDB Atlas (use YOUR connection string from Atlas → Connect → Drivers / Shell):
 *   mongosh "mongodb+srv://USER:PASSWORD@CLUSTER.mongodb.net/?appName=kultitracker" --file mongodb/init_indexes.mongosh.js
 *   (URL-encode special characters in PASSWORD, e.g. @ → %40)
 *   This script always uses DB name "kultitracker" via getSiblingDB — you do not need it in the URI path.
 *
 * Or in mongosh after connecting: load("path/to/init_indexes.mongosh.js")
 */

const dbName = 'kultitracker';
const db = db.getSiblingDB(dbName);

// Create empty collections so `kultitracker` shows up in Compass before any app writes.
const collectionNames = [
  'users',
  'habits',
  'habit_completions',
  'user_stats_cache',
  'daily_rollups',
  'calendar_orbit_days',
  'habit_teacher_sessions',
  'squads',
  'squad_battles',
  'refresh_tokens',
];

const existing = new Set(db.getCollectionNames());
for (const name of collectionNames) {
  if (!existing.has(name)) {
    db.createCollection(name);
  }
}

// --- users ---
db.users.createIndex({ email: 1 }, { unique: true, name: 'users_email_unique' });

// --- habits ---
// Document shape (Mongoose Habit): userId, title, category, notes (string), frequency (daily|weekdays|weekly),
// isArchived (bool), createdAt, updatedAt
db.habits.createIndex({ userId: 1, isArchived: 1 }, { name: 'habits_user_archived' });
db.habits.createIndex({ userId: 1, createdAt: -1 }, { name: 'habits_user_created' });
db.habits.createIndex({ userId: 1, category: 1 }, { name: 'habits_user_category' });

// --- habit_completions (daily check-ins) ---
db.habit_completions.createIndex(
  { userId: 1, habitId: 1, day: 1 },
  { unique: true, name: 'completions_user_habit_day_unique' }
);
db.habit_completions.createIndex({ userId: 1, day: 1 }, { name: 'completions_user_day' });
db.habit_completions.createIndex({ habitId: 1, day: -1 }, { name: 'completions_habit_day' });

// --- stats cache (per user aggregates) ---
db.user_stats_cache.createIndex({ userId: 1 }, { unique: true, name: 'stats_cache_user_unique' });
db.user_stats_cache.createIndex({ totalPoints: -1 }, { name: 'stats_cache_leaderboard_points' });

// --- calendar / heatmap (per user per day) ---
db.daily_rollups.createIndex(
  { userId: 1, day: 1 },
  { unique: true, name: 'rollups_user_day_unique' }
);
db.daily_rollups.createIndex({ userId: 1, day: -1 }, { name: 'rollups_user_day_desc' });

// --- calendar orbit (per user per day: habit lines for UI) ---
db.calendar_orbit_days.createIndex(
  { userId: 1, day: 1 },
  { unique: true, name: 'orbit_user_day_unique' }
);
db.calendar_orbit_days.createIndex({ userId: 1, day: -1 }, { name: 'orbit_user_day_desc' });

// --- habit teacher bot ---
db.habit_teacher_sessions.createIndex({ userId: 1, updatedAt: -1 }, { name: 'teacher_user_updated' });

// --- social ---
db.squads.createIndex({ memberIds: 1 }, { name: 'squads_members' });
db.squad_battles.createIndex({ squadId: 1, endsAt: -1 }, { name: 'battles_squad_ends' });

// --- refresh tokens (optional TTL) ---
db.refresh_tokens.createIndex({ userId: 1 }, { name: 'refresh_user' });
// db.refresh_tokens.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'refresh_ttl' });

print(`Database "${dbName}" ready: collections + indexes applied.`);
