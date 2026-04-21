const mongoose = require("mongoose");

const HabitSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    title: { type: String, required: true, trim: true },
    category: { type: String, required: true, trim: true },
    /// Optional motivation / reminder from the habit form (Flutter).
    notes: { type: String, default: "", trim: true },
    /// Repeat hint: daily | weekdays | weekly
    frequency: {
      type: String,
      enum: ["daily", "weekdays", "weekly"],
      default: "daily",
    },
    /// Soft-archive without deleting completions history (optional future use).
    isArchived: { type: Boolean, default: false, index: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Habit", HabitSchema);
