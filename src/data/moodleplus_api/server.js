// server.js (updated routes section)
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
  getBiometricStatus,
  changeAppPassword,
  updateEmail,
  updateProfilePicture
} = require('./controllers/authController');

const { 
  lmsLogin, 
  verifyLMSCredentials,
  getCourses, 
  getCourseContents,
  changeLMSPassword 
} = require('./controllers/lmsController');

// US-04: Archive controllers
const {
  archiveCourse,
  getArchivedCourses,
  getArchivedCourseDetails,
  restoreArchivedCourse,
  deleteArchivedCourse
} = require('./controllers/archiveController');

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
app.post('/api/lms/change-password', changeLMSPassword);
app.post('/api/user/change-password', changeAppPassword);
app.put('/api/user/email', updateEmail);
app.put('/api/user/profile-picture', updateProfilePicture);

// Biometric routes
app.post('/api/biometric/enable', enableBiometricLogin);
app.post('/api/biometric/disable', disableBiometricLogin);
app.post('/api/biometric/login', biometricLogin);
app.get('/api/biometric/status/:email', getBiometricStatus);

// US-04: Archive routes
app.post('/api/archive/course', archiveCourse);
app.get('/api/archive/courses/:email', getArchivedCourses);
app.get('/api/archive/course/:email/:courseId', getArchivedCourseDetails);
app.post('/api/archive/restore', restoreArchivedCourse);
app.delete('/api/archive/course', deleteArchivedCourse);

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Test route
app.get('/', (req, res) => {
  res.json({ message: 'Server is running' });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});