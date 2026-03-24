const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");

const app = express();

const User = require("./models/User");

app.use(cors());
app.use(express.json());

/// MongoDB Atlas Connection
mongoose.connect(
"mongodb+srv://basireddykarthik551:R81YfHUK8N6fVGEB@kratos0.qp3hznm.mongodb.net/kultivate20?retryWrites=true&w=majority"
)

.then(() => {
  console.log("DB Connected");
})

.catch(err => {
  console.log(err);
});


/// Test Route
app.get("/", (req,res) => {
  res.send("Backend working");
});


/// REGISTER API
app.post("/register", async (req,res) => {

const { name, email, password } = req.body;

try {

const newUser = new User({
  name,
  email,
  password
});

await newUser.save();

res.json({
  message: "User registered successfully"
});

}

catch(error){

res.status(500).json({
  message: "Internal server error"
});

}

});


/// LOGIN API
app.post("/login", async (req,res) => {

const { email, password } = req.body;

try {

const user =
await User.findOne({ email });

if (!user){

return res.status(400).json({
message: "User not found"
});

}

if (password !== user.password){

return res.status(400).json({
message: "Invalid password"
});

}

res.json({
message: "Login successful"
});

}

catch(error){

res.status(500).json({
message: "Internal server error"
});

}

});


/// Start Server
const PORT = 5000;

app.listen(PORT, () => {

console.log(
`Server running on port ${PORT}`
);

});