const express = require('express');
require('dotenv').config();

const connectDB = require('./config/db');
const { signup, login, updateLMSCredentials } = require('./controllers/authController');
const { 
  lmsLogin, 
  verifyLMSCredentials,
  autoLoginLMS,
  getCourses, 
  getCourseContents  // Changed from getCourseFiles
} = require('./controllers/lmsController');

const app = express();
app.use(express.json());

// Connect to MongoDB
connectDB();

// Routes
app.post('/users', signup);
app.post('/login', login);
app.post('/api/lms/login', lmsLogin);
app.post('/api/lms/verify', verifyLMSCredentials);
app.post('/api/lms/auto-login', autoLoginLMS);
app.post('/api/lms/courses', getCourses);
app.post('/api/lms/course-contents', getCourseContents); 
app.put('/api/user/lms-credentials', updateLMSCredentials);

// Test route
app.get('/', (req, res) => {
  res.json({ message: 'Server is running' });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});