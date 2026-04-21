const express = require("express");
const mongoose = require("mongoose");
const Habit = require("../models/Habit");

function normalizeFrequency(f) {
  if (typeof f !== "string") return "daily";
  const t = f.trim().toLowerCase();
  if (t === "weekdays" || t === "weekly") return t;
  return "daily";
}

function habitToClient(h) {
  return {
    id: h._id.toString(),
    title: h.title,
    category: h.category,
    notes: h.notes && String(h.notes).trim() ? String(h.notes).trim() : null,
    frequency: h.frequency || "daily",
  };
}
const HabitCompletion = require("../models/HabitCompletion");
const {
  refreshStatsAndRollupsAfterToggle,
  refreshStatsAndRollupsFull,
  recomputeUserStatsCache,
} = require("../services/statsCalendarSync");

const router = express.Router();

function buildStatePayload(userId) {
  return Habit.find({ userId })
    .lean()
    .then((habits) =>
      HabitCompletion.find({ userId }).lean().then((comps) => {
        const compByHabit = {};
        for (const c of comps) {
          const hid = c.habitId.toString();
          if (!compByHabit[hid]) compByHabit[hid] = [];
          compByHabit[hid].push(c.day);
        }
        return {
          habits: habits.map((h) => habitToClient(h)),
          completions: compByHabit,
        };
      })
    );
}

router.get("/state", async (req, res) => {
  try {
    const payload = await buildStatePayload(req.userId);
    res.json(payload);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load habits" });
  }
});

/// One-time upload of local-only habits + completions when Atlas is empty.
router.post("/bootstrap", async (req, res) => {
  try {
    const count = await Habit.countDocuments({ userId: req.userId });
    if (count > 0) {
      return res.status(409).json({ message: "Already has habits on server" });
    }

    const { habits: habitList, completions: completionMap } = req.body;
    if (!Array.isArray(habitList) || habitList.length === 0) {
      return res.status(400).json({ message: "habits array required" });
    }

    const idMap = {};
    for (const h of habitList) {
      if (!h.title || !h.category) continue;
      const notesRaw = h.notes != null ? String(h.notes).trim() : "";
      const doc = await Habit.create({
        userId: req.userId,
        title: String(h.title).trim(),
        category: String(h.category),
        notes: notesRaw,
        frequency: normalizeFrequency(h.frequency),
      });
      const tempId = h.tempId != null ? String(h.tempId) : doc._id.toString();
      idMap[tempId] = doc._id;
    }

    const cmap = completionMap && typeof completionMap === "object" ? completionMap : {};
    for (const [tempId, days] of Object.entries(cmap)) {
      const hid = idMap[tempId];
      if (!hid || !Array.isArray(days)) continue;
      for (const day of days) {
        if (typeof day !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(day)) continue;
        try {
          await HabitCompletion.create({
            userId: req.userId,
            habitId: hid,
            day,
            checkedAt: new Date(),
          });
        } catch (err) {
          if (err.code !== 11000) throw err;
        }
      }
    }

    const payload = await buildStatePayload(req.userId);
    await refreshStatsAndRollupsFull(req.userId);
    res.status(201).json(payload);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Bootstrap failed" });
  }
});

router.post("/", async (req, res) => {
  try {
    const { title, category, notes, frequency } = req.body;
    if (typeof title !== "string" || typeof category !== "string") {
      return res.status(400).json({ message: "title and category required" });
    }
    const t = title.trim();
    if (!t) return res.status(400).json({ message: "title required" });
    const notesStr =
      typeof notes === "string" ? notes.trim() : notes != null ? String(notes).trim() : "";
    const h = await Habit.create({
      userId: req.userId,
      title: t,
      category: category.trim() || "focus",
      notes: notesStr,
      frequency: normalizeFrequency(frequency),
    });
    await recomputeUserStatsCache(req.userId);
    res.status(201).json({
      habit: habitToClient(h),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to create habit" });
  }
});

/// Partial update for habit form fields (notes, frequency, title, category).
router.patch("/:habitId", async (req, res) => {
  try {
    const { habitId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(habitId)) {
      return res.status(400).json({ message: "Invalid habit id" });
    }
    const habit = await Habit.findOne({ _id: habitId, userId: req.userId });
    if (!habit) return res.status(404).json({ message: "Habit not found" });

    const { title, category, notes, frequency, isArchived } = req.body;
    if (typeof title === "string") {
      const tt = title.trim();
      if (tt) habit.title = tt;
    }
    if (typeof category === "string" && category.trim()) {
      habit.category = category.trim();
    }
    if (notes !== undefined) {
      if (notes === null) habit.notes = "";
      else habit.notes = String(notes).trim();
    }
    if (frequency !== undefined) habit.frequency = normalizeFrequency(frequency);
    if (typeof isArchived === "boolean") habit.isArchived = isArchived;

    await habit.save();
    await recomputeUserStatsCache(req.userId);
    res.json({ habit: habitToClient(habit) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to update habit" });
  }
});

router.delete("/:habitId", async (req, res) => {
  try {
    const { habitId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(habitId)) {
      return res.status(400).json({ message: "Invalid habit id" });
    }
    const h = await Habit.findOneAndDelete({
      _id: habitId,
      userId: req.userId,
    });
    if (!h) return res.status(404).json({ message: "Habit not found" });
    await HabitCompletion.deleteMany({ userId: req.userId, habitId });
    await refreshStatsAndRollupsFull(req.userId);
    res.json({ message: "Deleted" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to delete" });
  }
});

router.post("/:habitId/toggle", async (req, res) => {
  try {
    const { habitId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(habitId)) {
      return res.status(400).json({ message: "Invalid habit id" });
    }
    const habit = await Habit.findOne({ _id: habitId, userId: req.userId });
    if (!habit) return res.status(404).json({ message: "Habit not found" });

    let day = req.body?.day;
    if (typeof day !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(day)) {
      return res.status(400).json({ message: "day (yyyy-MM-dd) required" });
    }

    const existing = await HabitCompletion.findOne({
      userId: req.userId,
      habitId,
      day,
    });

    if (existing) {
      await existing.deleteOne();
    } else {
      await HabitCompletion.create({
        userId: req.userId,
        habitId,
        day,
        checkedAt: new Date(),
      });
    }

    await refreshStatsAndRollupsAfterToggle(req.userId, day);
    const payload = await buildStatePayload(req.userId);
    res.json(payload);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Toggle failed" });
  }
});

module.exports = router;
