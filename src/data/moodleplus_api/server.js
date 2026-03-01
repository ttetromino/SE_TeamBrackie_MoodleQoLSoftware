const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const dns = require('dns');
require('dotenv').config();

// Force Node.js to use Google DNS
dns.setServers(['8.8.8.8', '8.8.4.4']);

const app = express();
app.use(express.json());

// MongoDB connection
const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ MongoDB connected successfully!');
    console.log('Database:', mongoose.connection.name);
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error.message);
    process.exit(1);
  }
};

connectDB();

// Handle connection events
mongoose.connection.on('error', err => {
  console.error('MongoDB connection error:', err);
});

mongoose.connection.on('disconnected', () => {
  console.log('MongoDB disconnected');
});

// User Schema - FIXED VERSION
const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, unique: true, required: true },
  password: { type: String, required: true },
});

// Hash password - FIXED: Removed the 'next' parameter since we're using async/await
userSchema.pre('save', async function() {
  // Only hash if password is modified or new
  if (!this.isModified('password')) return;
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  } catch (error) {
    throw new Error('Password hashing failed');
  }
});

const User = mongoose.model('User', userSchema);

// Test route
app.get('/', (req, res) => {
  res.json({ 
    message: 'Server is running',
    mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

// Signup - FIXED: Better error handling
app.post('/users', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    // Validate input
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'All fields are required' });
    }

    // Check if user exists
    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(400).json({ error: 'Email already registered' });
    }

    // Create new user
    const user = new User({ 
      name: name.trim(), 
      email: email.trim().toLowerCase(), 
      password: password 
    });
    
    await user.save();

    res.status(201).json({ 
      message: 'Signup successful',
      user: {
        name: user.name,
        email: user.email
      }
    });
  } catch (err) {
    console.error('❌ Signup error:', err);
    res.status(500).json({ error: 'Server error: ' + err.message });
  }
});

// Login - FIXED: Return user data properly
app.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    const user = await User.findOne({ email: email.trim().toLowerCase() });
    if (!user) {
      return res.status(400).json({ error: 'User not found' });
    }

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) {
      return res.status(400).json({ error: 'Invalid password' });
    }

    // Return user data without password
    res.json({ 
      message: 'Login successful', 
      user: {
        name: user.name,
        email: user.email
      }
    });
  } catch (err) {
    console.error('❌ Login error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📝 Test the server at http://localhost:${PORT}`);
  console.log(`📝 API endpoints:`);
  console.log(`   POST http://localhost:${PORT}/users - Signup`);
  console.log(`   POST http://localhost:${PORT}/login - Login`);
});
