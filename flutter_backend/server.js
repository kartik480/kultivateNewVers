const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const User = require("./models/User");
const authRequired = require("./middleware/auth");
const habitsRouter = require("./routes/habits");
const statsCalendarRouter = require("./routes/statsCalendar");

const app = express();

app.use(cors());
app.use(express.json());

const MONGO_URI = process.env.MONGO_URI;
const JWT_SECRET = process.env.JWT_SECRET;

if (!MONGO_URI) {
  console.error("Missing MONGO_URI in .env (repo root)");
  process.exit(1);
}
if (!JWT_SECRET) {
  console.error("Missing JWT_SECRET in .env (repo root)");
  process.exit(1);
}

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log("DB connected:", mongoose.connection.name);
  })
  .catch((err) => {
    console.error("DB connection error:", err.message);
    process.exit(1);
});

app.get("/", (req, res) => {
  res.send("Backend working");
});

app.post("/register", async (req, res) => {
  const { name, email, password } = req.body;

  try {
    if (
      typeof name !== "string" ||
      typeof email !== "string" ||
      typeof password !== "string"
    ) {
      return res.status(400).json({
        message: "Name, email, and password must be provided",
      });
    }

    const nameTrim = name.trim();
    const emailTrim = email.toLowerCase().trim();
    if (!nameTrim || !emailTrim || !password) {
      return res.status(400).json({
        message: "Name, email, and password are required",
      });
    }

    const existing = await User.findOne({ email: emailTrim });
    if (existing) {
      return res.status(400).json({ message: "User already exists" });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newUser = new User({
      name: nameTrim,
      email: emailTrim,
      password: hashedPassword,
    });

    await newUser.save();

    const token = jwt.sign({ id: newUser._id }, JWT_SECRET, { expiresIn: "7d" });

    res.json({ message: "User registered successfully", token });
  } catch (error) {
    console.error("register error:", error);
    if (error.name === "ValidationError") {
      const msg = Object.values(error.errors)
        .map((e) => e.message)
        .join(" ");
      return res.status(400).json({ message: msg || "Validation failed" });
    }
    if (error.code === 11000) {
      return res.status(400).json({ message: "User already exists" });
    }
    const payload = { message: "Internal server error" };
    if (process.env.NODE_ENV !== "production") {
      payload.detail = error.message;
    }
    res.status(500).json(payload);
  }
});

app.post("/login", async (req, res) => {
  const { email, password } = req.body;

  try {
    const user = await User.findOne({ email: email?.toLowerCase()?.trim() });

    if (!user) {
      return res.status(400).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid password" });
    }

    const token = jwt.sign({ id: user._id }, JWT_SECRET, { expiresIn: "7d" });

    res.json({
      message: "Login successful",
      token,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Internal server error" });
  }
});

app.use("/api/habits", authRequired, habitsRouter);
app.use("/api/me", authRequired, statsCalendarRouter);

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
