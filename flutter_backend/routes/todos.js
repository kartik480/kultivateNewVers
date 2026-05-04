const express = require("express");
const mongoose = require("mongoose");
const StandaloneTodo = require("../models/StandaloneTodo");

const router = express.Router();

function normalizeDayKey(v) {
  if (v == null || v === "") return null;
  const s = String(v).trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  return s;
}

function todoToClient(doc) {
  return {
    id: doc._id.toString(),
    title: doc.title,
    completedDayKey: doc.completedDayKey || null,
  };
}

async function buildStatePayload(userId) {
  const rows = await StandaloneTodo.find({ userId })
    .sort({ createdAt: -1 })
    .lean();
  return { tasks: rows.map((r) => todoToClient(r)) };
}

router.get("/state", async (req, res) => {
  try {
    const payload = await buildStatePayload(req.userId);
    res.json(payload);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load todos" });
  }
});

/// Upload device-only todos when Atlas has none for this user (same idea as habits bootstrap).
router.post("/bootstrap", async (req, res) => {
  try {
    const count = await StandaloneTodo.countDocuments({ userId: req.userId });
    if (count > 0) {
      return res.status(409).json({ message: "Already has todos on server" });
    }

    const { tasks: taskList } = req.body;
    if (!Array.isArray(taskList) || taskList.length === 0) {
      return res.status(400).json({ message: "tasks array required" });
    }

    let inserted = 0;
    for (const item of taskList) {
      const title = typeof item.title === "string" ? item.title.trim() : "";
      if (!title) continue;
      const cdk = normalizeDayKey(item.completedDayKey);
      await StandaloneTodo.create({
        userId: req.userId,
        title,
        completedDayKey: cdk,
      });
      inserted++;
    }
    console.log(
      "todo_list bootstrap",
      inserted,
      "doc(s) user",
      String(req.userId)
    );

    const payload = await buildStatePayload(req.userId);
    res.status(201).json(payload);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Bootstrap failed" });
  }
});

router.post("/", async (req, res) => {
  try {
    const { title: rawTitle, completedDayKey: rawDay } = req.body;
    if (typeof rawTitle !== "string") {
      return res.status(400).json({ message: "title required" });
    }
    const title = rawTitle.trim();
    if (!title) return res.status(400).json({ message: "title required" });

    const cdk = normalizeDayKey(rawDay);
    const doc = await StandaloneTodo.create({
      userId: req.userId,
      title,
      completedDayKey: cdk,
    });
    console.log(
      "todo_list insert",
      doc._id.toString(),
      "user",
      String(req.userId),
      "title",
      title.slice(0, 40)
    );
    res.status(201).json({ task: todoToClient(doc) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to create todo" });
  }
});

router.patch("/:todoId", async (req, res) => {
  try {
    const { todoId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(todoId)) {
      return res.status(400).json({ message: "Invalid todo id" });
    }
    const todo = await StandaloneTodo.findOne({
      _id: todoId,
      userId: req.userId,
    });
    if (!todo) return res.status(404).json({ message: "Todo not found" });

    const { title, completedDayKey } = req.body;
    if (typeof title === "string") {
      const tt = title.trim();
      if (tt) todo.title = tt;
    }
    if (Object.prototype.hasOwnProperty.call(req.body, "completedDayKey")) {
      if (req.body.completedDayKey === null || req.body.completedDayKey === "") {
        todo.completedDayKey = null;
      } else {
        const cdk = normalizeDayKey(req.body.completedDayKey);
        if (!cdk) {
          return res.status(400).json({
            message: "completedDayKey must be null or YYYY-MM-DD",
          });
        }
        todo.completedDayKey = cdk;
      }
    }

    await todo.save();
    res.json({ task: todoToClient(todo) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to update todo" });
  }
});

router.delete("/:todoId", async (req, res) => {
  try {
    const { todoId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(todoId)) {
      return res.status(400).json({ message: "Invalid todo id" });
    }
    const doc = await StandaloneTodo.findOneAndDelete({
      _id: todoId,
      userId: req.userId,
    });
    if (!doc) return res.status(404).json({ message: "Todo not found" });
    res.json({ message: "Deleted" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to delete" });
  }
});

module.exports = router;
