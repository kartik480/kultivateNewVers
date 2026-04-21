const mongoose = require("mongoose");

/// Denormalized stats for leaderboard / app “Stats” panel (recomputed from habit_completions).
const UserStatsCacheSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    currentStreak: { type: Number, default: 0 },
    bestStreakRecorded: { type: Number, default: 0 },
    totalCompletions: { type: Number, default: 0 },
    activeHabitsCount: { type: Number, default: 0 },
    totalPoints: { type: Number, default: 0 },
    level: { type: Number, default: 1 },
    /// Mirrors the Flutter “Your pulse” / Insight Lab panel (Insight sheet).
    pulseDetails: {
      focusScore: { type: Number, default: 0 },
      ringProgress: { type: Number, default: 0 },
      estimatedFocusMinutesToday: { type: Number, default: 0 },
      trendLabel: { type: String, default: "" },
      momentumLast7: { type: [Number], default: [] },
      avgDailyCompletionLast7: { type: Number, default: 0 },
      categoryFractions: {
        focus: { type: Number, default: 0 },
        move: { type: Number, default: 0 },
        mind: { type: Number, default: 0 },
        learn: { type: Number, default: 0 },
        gym: { type: Number, default: 0 },
        nutrition: { type: Number, default: 0 },
        sleep: { type: Number, default: 0 },
        social: { type: Number, default: 0 },
        creative: { type: Number, default: 0 },
        other: { type: Number, default: 0 },
      },
      insightNudgeBody: { type: String, default: "" },
      /// Streak / habits / deep work tiles under the ring
      tileStreakDays: { type: Number, default: 0 },
      tileActiveHabits: { type: Number, default: 0 },
      tileDeepWorkValue: { type: Number, default: 0 },
      tileDeepWorkUnit: { type: String, default: "m" },
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model(
  "UserStatsCache",
  UserStatsCacheSchema,
  "user_stats_cache"
);
