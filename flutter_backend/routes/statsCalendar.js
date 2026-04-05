const express = require("express");
const UserStatsCache = require("../models/UserStatsCache");
const DailyRollup = require("../models/DailyRollup");
const CalendarOrbitDay = require("../models/CalendarOrbitDay");
const {
  recomputeUserStatsCache,
  upsertCalendarOrbitDay,
} = require("../services/statsCalendarSync");
const HabitCompletion = require("../models/HabitCompletion");

const router = express.Router();

/// Cached aggregates for the Stats UI (also in Atlas collection `user_stats_cache`).
router.get("/stats-cache", async (req, res) => {
  try {
    let doc = await UserStatsCache.findOne({ userId: req.userId }).lean();
    if (!doc || !doc.pulseDetails) {
      await recomputeUserStatsCache(req.userId);
      doc = await UserStatsCache.findOne({ userId: req.userId }).lean();
    }
    if (!doc) {
      return res.json({
        currentStreak: 0,
        bestStreakRecorded: 0,
        totalCompletions: 0,
        activeHabitsCount: 0,
        totalPoints: 0,
        level: 1,
        pulseDetails: null,
        updatedAt: null,
      });
    }
    res.json({
      currentStreak: doc.currentStreak,
      bestStreakRecorded: doc.bestStreakRecorded,
      totalCompletions: doc.totalCompletions,
      activeHabitsCount: doc.activeHabitsCount,
      totalPoints: doc.totalPoints,
      level: doc.level,
      pulseDetails: doc.pulseDetails ?? null,
      updatedAt: doc.updatedAt,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load stats cache" });
  }
});

/// Calendar / heatmap rows between two yyyy-MM-dd bounds (collection `daily_rollups`).
router.get("/calendar-days", async (req, res) => {
  try {
    const from = req.query.from;
    const to = req.query.to;
    if (
      typeof from !== "string" ||
      typeof to !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(from) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(to)
    ) {
      return res.status(400).json({
        message: "Query from and to are required as yyyy-MM-dd",
      });
    }
    if (from > to) {
      return res.status(400).json({ message: "from must be <= to" });
    }

    const rows = await DailyRollup.find({
      userId: req.userId,
      day: { $gte: from, $lte: to },
    })
      .sort({ day: 1 })
      .lean();

    res.json({
      days: rows.map((r) => ({
        day: r.day,
        habitsCheckedInCount: r.habitsCheckedInCount,
        activeHabitsCount: r.activeHabitsCount,
        dailyCompletionRatio: r.dailyCompletionRatio,
      })),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load calendar rollups" });
  }
});

/// Calendar Orbit sheet: per-day habit lines (collection `calendar_orbit_days`).
router.get("/calendar-orbit", async (req, res) => {
  try {
    const y = parseInt(req.query.year, 10);
    const m = parseInt(req.query.month, 10);
    if (!Number.isFinite(y) || !Number.isFinite(m) || m < 1 || m > 12) {
      return res
        .status(400)
        .json({ message: "Query year and month (1–12) are required" });
    }
    const pad = (n) => String(n).padStart(2, "0");
    const from = `${y}-${pad(m)}-01`;
    const lastDay = new Date(y, m, 0).getDate();
    const to = `${y}-${pad(m)}-${pad(lastDay)}`;

    let rows = await CalendarOrbitDay.find({
      userId: req.userId,
      day: { $gte: from, $lte: to },
    })
      .sort({ day: 1 })
      .lean();

    if (rows.length === 0) {
      const daysInRange = await HabitCompletion.distinct("day", {
        userId: req.userId,
        day: { $gte: from, $lte: to },
      });
      for (const d of daysInRange) {
        await upsertCalendarOrbitDay(req.userId, d);
      }
      rows = await CalendarOrbitDay.find({
        userId: req.userId,
        day: { $gte: from, $lte: to },
      })
        .sort({ day: 1 })
        .lean();
    }

    res.json({
      year: y,
      month: m,
      days: rows.map((r) => ({
        day: r.day,
        habitsCompletedCount: r.habitsCompletedCount,
        lines: r.lines,
      })),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load calendar orbit" });
  }
});

module.exports = router;
