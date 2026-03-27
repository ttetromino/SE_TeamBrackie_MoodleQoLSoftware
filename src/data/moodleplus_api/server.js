const express = require('express');
require('dotenv').config();

const connectDB = require('./config/db');
const { startSessionCleanup } = require('./utils/sessionStore');

const { 
  signup, 
  login, 
  updateLMSCredentials,
  autoLoginLMS,
  enableBiometricLogin,
  disableBiometricLogin,
  biometricLogin,
  getBiometricStatus
} = require('./controllers/authController');

const { 
  lmsLogin, 
  verifyLMSCredentials,
  getCourses, 
  getCourseContents
} = require('./controllers/lmsController');

const app = express();
app.use(express.json());

// Connect to MongoDB
connectDB();

// Start session cleanup
startSessionCleanup();

// Routes
app.post('/users', signup);
app.post('/login', login);
app.post('/api/lms/login', lmsLogin);
app.post('/api/lms/verify', verifyLMSCredentials);
app.post('/api/lms/auto-login', autoLoginLMS);
app.post('/api/lms/courses', getCourses);
app.post('/api/lms/course-contents', getCourseContents); 
app.put('/api/user/lms-credentials', updateLMSCredentials);

// Biometric routes
app.post('/api/biometric/enable', enableBiometricLogin);
app.post('/api/biometric/disable', disableBiometricLogin);
app.post('/api/biometric/login', biometricLogin);
app.get('/api/biometric/status/:email', getBiometricStatus);

// Test route
app.get('/', (req, res) => {
  res.json({ message: 'Server is running' });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
