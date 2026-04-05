const mongoose = require("mongoose");

/// Per-day rows for the Calendar Orbit sheet (dots + “Selected day” list).
const CalendarOrbitDaySchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    day: { type: String, required: true },
    /// Distinct habits completed that day (matches HabitStore.countCompletedOn).
    habitsCompletedCount: { type: Number, default: 0 },
    /// Same strings as HabitStore.dayLabels (e.g. "Done · Reading").
    lines: { type: [String], default: [] },
  },
  { timestamps: true }
);

CalendarOrbitDaySchema.index({ userId: 1, day: 1 }, { unique: true });

module.exports = mongoose.model(
  "CalendarOrbitDay",
  CalendarOrbitDaySchema,
  "calendar_orbit_days"
);
