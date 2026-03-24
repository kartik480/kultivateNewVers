const express = require("express");
const router = express.Router();

const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const User = require("../models/User");

/// SIGNUP API
router.post("/signup", async (req, res) => {

  try {

    const { name, email, password } = req.body;

    // Check user exists
    const existingUser =
      await User.findOne({ email });

    if (existingUser) {
      return res.status(400).json({
        message: "User already exists",
      });
    }

    // Hash password
    const salt =
      await bcrypt.genSalt(10);

    const hashedPassword =
      await bcrypt.hash(password, salt);

    // Create user
    const newUser = new User({
      name,
      email,
      password: hashedPassword,
    });

    await newUser.save();

    res.status(201).json({
      message: "User registered successfully",
    });

  }
  catch (error) {

    res.status(500).json({
      message: "Server error",
    });

  }

});


/// LOGIN API
router.post("/login", async (req, res) => {

  try {

    const { email, password } = req.body;

    const user =
      await User.findOne({ email });

    if (!user) {
      return res.status(400).json({
        message: "User not found",
      });
    }

    // Compare password
    const isMatch =
      await bcrypt.compare(
        password,
        user.password
      );

    if (!isMatch) {
      return res.status(400).json({
        message: "Invalid credentials",
      });
    }

    // Create token
    const token =
      jwt.sign(
        { id: user._id },
        process.env.JWT_SECRET,
        { expiresIn: "1d" }
      );

    res.json({
      token,
      message: "Login successful",
    });

  }
  catch (error) {

    res.status(500).json({
      message: "Server error",
    });

  }

});

module.exports = router;