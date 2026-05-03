const express = require("express");
const mongoose = require("mongoose");
const Reminder = require("../models/Reminder");

const router = express.Router();

function reminderToClient(r) {
  return {
    id: r._id.toString(),
    habitId: r.habitId ? r.habitId.toString() : null,
    alarmId: r.alarmId != null ? Number(r.alarmId) : null,
    habitTitle: r.habitTitle,
    time: r.time,
    note: r.note && String(r.note).trim() ? String(r.note).trim() : null,
    createdAt:
      r.createdAtClient instanceof Date
        ? r.createdAtClient.toISOString()
        : r.createdAt.toISOString(),
  };
}

router.get("/", async (req, res) => {
  try {
    const list = await Reminder.find({ userId: req.userId })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    res.json({ reminders: list.map((r) => reminderToClient(r)) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load reminders" });
  }
});

router.post("/", async (req, res) => {
  try {
    const { alarmId, habitId, habitTitle, time, note, createdAt } = req.body ?? {};
    if (typeof habitTitle !== "string" || !habitTitle.trim()) {
      return res.status(400).json({ message: "habitTitle required" });
    }
    if (typeof time !== "string" || !time.trim()) {
      return res.status(400).json({ message: "time required" });
    }
    const payload = {
      userId: req.userId,
      habitTitle: habitTitle.trim(),
      time: time.trim(),
      note: typeof note === "string" ? note.trim() : "",
    };
    if (alarmId != null && Number.isFinite(Number(alarmId))) {
      payload.alarmId = Number(alarmId);
    }
    if (habitId && mongoose.Types.ObjectId.isValid(habitId)) {
      payload.habitId = habitId;
    }
    if (typeof createdAt === "string" && createdAt.trim()) {
      const dt = new Date(createdAt);
      if (!Number.isNaN(dt.getTime())) payload.createdAtClient = dt;
    }
    const created = await Reminder.create(payload);
    res.status(201).json({ reminder: reminderToClient(created) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to save reminder" });
  }
});

router.delete("/:reminderId", async (req, res) => {
  try {
    const { reminderId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(reminderId)) {
      return res.status(400).json({ message: "Invalid reminder id" });
    }
    const removed = await Reminder.findOneAndDelete({
      _id: reminderId,
      userId: req.userId,
    });
    if (!removed) return res.status(404).json({ message: "Reminder not found" });
    res.json({ message: "Deleted" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to delete reminder" });
  }
});

module.exports = router;
