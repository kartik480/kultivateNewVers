const mongoose = require("mongoose");

const ReminderSchema = new mongoose.Schema(
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
      required: false,
      index: true,
    },
    habitTitle: { type: String, required: true, trim: true },
    time: { type: String, required: true, trim: true }, // e.g. 7:00 AM
    note: { type: String, default: "", trim: true },
    createdAtClient: { type: Date, required: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model("ReminderHabit", ReminderSchema, "reminder_habit");
