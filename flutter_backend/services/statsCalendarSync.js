const mongoose = require("mongoose");
const Habit = require("../models/Habit");
const HabitCompletion = require("../models/HabitCompletion");
const UserStatsCache = require("../models/UserStatsCache");
const DailyRollup = require("../models/DailyRollup");
const CalendarOrbitDay = require("../models/CalendarOrbitDay");

function dayKeyUtc(d) {
  return d.toISOString().slice(0, 10);
}

function parseDayString(dayStr) {
  const [y, m, d] = dayStr.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

function bestStreakFromSortedDays(sortedAsc) {
  if (!sortedAsc.length) return 0;
  let best = 1;
  let run = 1;
  for (let i = 1; i < sortedAsc.length; i++) {
    const prev = parseDayString(sortedAsc[i - 1]).getTime();
    const cur = parseDayString(sortedAsc[i]).getTime();
    const diffDays = (cur - prev) / 86400000;
    if (diffDays === 1) {
      run++;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }
  return best;
}

function currentStreakUtc(daySet) {
  const now = new Date();
  const start = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
  );
  let streak = 0;
  let d = start;
  while (daySet.has(dayKeyUtc(d))) {
    streak++;
    d = new Date(d.getTime() - 86400000);
  }
  return streak;
}

async function distinctDaysWithActivity(userId) {
  const uid =
    typeof userId === "string"
      ? new mongoose.Types.ObjectId(userId)
      : userId;
  const rows = await HabitCompletion.aggregate([
    { $match: { userId: uid } },
    { $group: { _id: "$day" } },
  ]);
  return rows.map((r) => r._id).filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d));
}

async function upsertDailyRollup(userId, day) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return;
  const uid =
    typeof userId === "string"
      ? new mongoose.Types.ObjectId(userId)
      : userId;
  const habitsCheckedInCount = await HabitCompletion.countDocuments({
    userId: uid,
    day,
  });
  const activeHabitsCount = await Habit.countDocuments({ userId: uid });
  const dailyCompletionRatio =
    activeHabitsCount > 0 ? habitsCheckedInCount / activeHabitsCount : 0;

  if (habitsCheckedInCount === 0) {
    await DailyRollup.deleteOne({ userId: uid, day });
    return;
  }

  await DailyRollup.findOneAndUpdate(
    { userId: uid, day },
    {
      habitsCheckedInCount,
      activeHabitsCount,
      dailyCompletionRatio,
    },
    { upsert: true, new: true }
  );
}

async function rebuildAllDailyRollups(userId) {
  const uid =
    typeof userId === "string"
      ? new mongoose.Types.ObjectId(userId)
      : userId;
  await DailyRollup.deleteMany({ userId: uid });
  const days = await distinctDaysWithActivity(userId);
  for (const day of days) {
    await upsertDailyRollup(userId, day);
  }
}

async function upsertCalendarOrbitDay(userId, day) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return;
  const uid =
    typeof userId === "string"
      ? new mongoose.Types.ObjectId(userId)
      : userId;
  const completions = await HabitCompletion.find({ userId: uid, day }).lean();
  if (completions.length === 0) {
    await CalendarOrbitDay.deleteOne({ userId: uid, day });
    return;
  }
  const habitIdStrs = [
    ...new Set(completions.map((c) => c.habitId.toString())),
  ];
  const habitIds = habitIdStrs.map((id) => new mongoose.Types.ObjectId(id));
  const habits = await Habit.find({ _id: { $in: habitIds } }).lean();
  const titleById = Object.fromEntries(
    habits.map((h) => [h._id.toString(), h.title ?? "Habit"])
  );
  const lines = habitIdStrs
    .map((id) => `Done · ${titleById[id] ?? "Habit"}`)
    .sort();
  await CalendarOrbitDay.findOneAndUpdate(
    { userId: uid, day },
    {
      habitsCompletedCount: habitIdStrs.length,
      lines,
    },
    { upsert: true, new: true }
  );
}

async function rebuildAllCalendarOrbitDays(userId) {
  const uid =
    typeof userId === "string"
      ? new mongoose.Types.ObjectId(userId)
      : userId;
  await CalendarOrbitDay.deleteMany({ userId: uid });
  const days = await distinctDaysWithActivity(userId);
  for (const day of days) {
    await upsertCalendarOrbitDay(userId, day);
  }
}

function utcToday() {
  const n = new Date();
  return new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()));
}

function dayKeyFromUtcDate(d) {
  return d.toISOString().slice(0, 10);
}

const HABIT_CATEGORY_KEYS = [
  "focus",
  "move",
  "mind",
  "learn",
  "gym",
  "nutrition",
  "sleep",
  "social",
  "creative",
  "other",
];

function categoryFractionsFromHabits(habits) {
  const counts = Object.fromEntries(HABIT_CATEGORY_KEYS.map((k) => [k, 0]));
  for (const h of habits) {
    const c = HABIT_CATEGORY_KEYS.includes(h.category) ? h.category : "other";
    counts[c]++;
  }
  const total = habits.length;
  if (!total) {
    return Object.fromEntries(HABIT_CATEGORY_KEYS.map((k) => [k, 0]));
  }
  return Object.fromEntries(
    HABIT_CATEGORY_KEYS.map((k) => [k, counts[k] / total])
  );
}

function trendLabelFromAvgs(recent, prev, habitCount) {
  if (!habitCount) return "Add habits to see weekly trends";
  if (prev < 0.001 && recent < 0.001) return "Log a completion to start";
  if (prev < 0.001) return "Strong start this week";
  const ch = Math.round(((recent - prev) / prev) * 100);
  if (ch >= 0) return `+${ch}% vs prior week`;
  return `${ch}% vs prior week`;
}

function insightNudgeBodyText(activeHabitsCount, doneToday) {
  if (!activeHabitsCount) {
    return "Tap + to add your first habit. Completions here power stats, calendar, and your score.";
  }
  const left = activeHabitsCount - doneToday;
  if (left <= 0) {
    return "All habits checked off today. Come back tomorrow or add another habit.";
  }
  return `Finish ${left} more habit${left === 1 ? "" : "s"} today to max out your daily completion.`;
}

async function last7IntensityArray(uid, habitCount) {
  if (!habitCount) return [0, 0, 0, 0, 0, 0, 0];
  const today = utcToday();
  const keys = [];
  for (let i = 6; i >= 0; i--) {
    keys.push(
      dayKeyFromUtcDate(new Date(today.getTime() - i * 86400000))
    );
  }
  const rows = await HabitCompletion.aggregate([
    { $match: { userId: uid, day: { $in: keys } } },
    { $group: { _id: "$day", n: { $sum: 1 } } },
  ]);
  const map = Object.fromEntries(rows.map((r) => [r._id, r.n]));
  return keys.map((k) => Math.min(1, (map[k] || 0) / habitCount));
}

async function twoWindowAvgs(uid, habitCount) {
  if (!habitCount) return { recent: 0, prev: 0 };
  const today = utcToday();
  const keys14 = [];
  for (let o = 0; o <= 13; o++) {
    keys14.push(
      dayKeyFromUtcDate(new Date(today.getTime() - o * 86400000))
    );
  }
  const rows = await HabitCompletion.aggregate([
    { $match: { userId: uid, day: { $in: keys14 } } },
    { $group: { _id: "$day", n: { $sum: 1 } } },
  ]);
  const map = Object.fromEntries(rows.map((r) => [r._id, r.n]));
  let sumRecent = 0;
  for (let o = 0; o <= 6; o++) {
    sumRecent += (map[keys14[o]] || 0) / habitCount;
  }
  let sumPrev = 0;
  for (let o = 7; o <= 13; o++) {
    sumPrev += (map[keys14[o]] || 0) / habitCount;
  }
  return { recent: sumRecent / 7, prev: sumPrev / 7 };
}

async function recomputeUserStatsCache(userId) {
  const uid =
    typeof userId === "string"
      ? new mongoose.Types.ObjectId(userId)
      : userId;

  const habits = await Habit.find({ userId: uid }).lean();
  const activeHabitsCount = habits.length;

  const totalCompletions = await HabitCompletion.countDocuments({
    userId: uid,
  });

  const days = await distinctDaysWithActivity(userId);
  const sortedAsc = [...days].sort();
  const daySet = new Set(days);

  const bestFromHistory = bestStreakFromSortedDays(sortedAsc);
  const current = currentStreakUtc(daySet);
  const bestStreakRecorded = Math.max(bestFromHistory, current);

  const totalPoints = totalCompletions * 25 + current * 15;
  const level = 1 + Math.floor(totalPoints / 500);

  const todayStr = dayKeyFromUtcDate(utcToday());
  const completedTodayIds = await HabitCompletion.find({
    userId: uid,
    day: todayStr,
  }).distinct("habitId");
  const doneToday = completedTodayIds.length;

  const todayProgressFraction =
    activeHabitsCount > 0 ? doneToday / activeHabitsCount : 0;
  const todayCompletion = Math.round(todayProgressFraction * 100);
  const streakPart = Math.min(40, current * 4);
  const todayPart = Math.round(todayProgressFraction * 40);
  const volumePart = Math.min(20, Math.round(totalCompletions * 0.5));
  const focusScore = Math.max(
    0,
    Math.min(100, streakPart + todayPart + volumePart)
  );
  const ringProgress = focusScore / 100;
  const estimatedFocusMinutesToday = doneToday * 25;

  const fm = estimatedFocusMinutesToday;
  let tileDeepWorkValue = 0;
  let tileDeepWorkUnit = "m";
  if (fm <= 0) {
    tileDeepWorkValue = 0;
    tileDeepWorkUnit = "m";
  } else if (fm < 60) {
    tileDeepWorkValue = fm;
    tileDeepWorkUnit = "m";
  } else if (fm >= 600) {
    tileDeepWorkValue = Math.round(fm / 60);
    tileDeepWorkUnit = "h";
  } else {
    tileDeepWorkValue = Math.round((fm / 60) * 10) / 10;
    tileDeepWorkUnit = "h";
  }

  const momentumLast7 = await last7IntensityArray(uid, activeHabitsCount);
  const avgDailyCompletionLast7 =
    momentumLast7.reduce((a, b) => a + b, 0) /
    (momentumLast7.length || 1);

  const { recent, prev } = await twoWindowAvgs(uid, activeHabitsCount);
  const trendLabel = trendLabelFromAvgs(recent, prev, activeHabitsCount);

  const categoryFractions = categoryFractionsFromHabits(habits);
  const insightNudgeBody = insightNudgeBodyText(activeHabitsCount, doneToday);

  await UserStatsCache.findOneAndUpdate(
    { userId: uid },
    {
      currentStreak: current,
      bestStreakRecorded,
      totalCompletions,
      activeHabitsCount,
      totalPoints,
      level,
      pulseDetails: {
        todayCompletion,
        doneTodayCount: doneToday,
        focusScore,
        ringProgress,
        estimatedFocusMinutesToday,
        trendLabel,
        momentumLast7,
        avgDailyCompletionLast7,
        categoryFractions,
        insightNudgeBody,
        tileStreakDays: current,
        tileActiveHabits: activeHabitsCount,
        tileDeepWorkValue,
        tileDeepWorkUnit,
      },
    },
    { upsert: true, new: true }
  );
}

async function refreshStatsAndRollupsAfterToggle(userId, day) {
  await upsertDailyRollup(userId, day);
  await upsertCalendarOrbitDay(userId, day);
  await recomputeUserStatsCache(userId);
}

async function refreshStatsAndRollupsFull(userId) {
  await rebuildAllDailyRollups(userId);
  await rebuildAllCalendarOrbitDays(userId);
  await recomputeUserStatsCache(userId);
}

module.exports = {
  upsertDailyRollup,
  rebuildAllDailyRollups,
  upsertCalendarOrbitDay,
  rebuildAllCalendarOrbitDays,
  recomputeUserStatsCache,
  refreshStatsAndRollupsAfterToggle,
  refreshStatsAndRollupsFull,
};
