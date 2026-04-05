const mongoose = require("mongoose");

/// Per-calendar-day summary for heatmaps / calendar UI (one row per user per day).
const DailyRollupSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    day: { type: String, required: true },
    habitsCheckedInCount: { type: Number, default: 0 },
    activeHabitsCount: { type: Number, default: 0 },
    dailyCompletionRatio: { type: Number, default: 0 },
  },
  { timestamps: true }
);

DailyRollupSchema.index({ userId: 1, day: 1 }, { unique: true });

module.exports = mongoose.model(
  "DailyRollup",
  DailyRollupSchema,
  "daily_rollups"
);
