const mongoose = require("mongoose");

/// Dedicated **MongoDB collection** for the app to-do list (separate from `habits` / `habit_completions`).
/// Collection name: `todo_list` (one document per task row; see Flutter [TodoStore] + routes/todos.js).
const StandaloneTodoSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    title: { type: String, required: true, trim: true },
    /// `YYYY-MM-DD` when marked done for that calendar day; unset when not done today.
    completedDayKey: { type: String, default: null },
  },
  { timestamps: true }
);

StandaloneTodoSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model(
  "StandaloneTodo",
  StandaloneTodoSchema,
  "todo_list"
);
