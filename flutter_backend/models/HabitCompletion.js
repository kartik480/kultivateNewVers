const mongoose = require("mongoose");

const HabitCompletionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    habitId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Habit",
      required: true,
      index: true,
    },
    day: { type: String, required: true },
    checkedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

HabitCompletionSchema.index(
  { userId: 1, habitId: 1, day: 1 },
  { unique: true }
);

module.exports = mongoose.model(
  "HabitCompletion",
  HabitCompletionSchema,
  "habit_completions"
);
