// server.js
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
  updateProfilePicture,
  addPersonalEvent,
  getPersonalEvents,
  deletePersonalEvent,
  updatePersonalEvent
} = require('./controllers/authController');

const {
  lmsLogin,
  verifyLMSCredentials,
  getCourses,
  getCourseContents,
  changeLMSPassword,
  getGrades,
  getCourseDetailedGrades,
  getCalendarEvents
} = require('./controllers/lmsController');

// Course controllers - only import what exists
const {
  getStoredCourses,
  getStoredCourse,
  getCourseContentsFromDB,
  updateActivityCompletion,
  getCourseStats,
  triggerBackgroundSync,
  syncAllCourses,
  syncCourseToDatabase,
  syncCourseById,
  updateActivityByUrl,

} = require('./controllers/courseController');

// US-04: Archive controllers
const {
  archiveCourse,
  getArchivedCourses,
  getArchivedCourseDetails,
  restoreArchivedCourse,
  deleteArchivedCourse
} = require('./controllers/archiveController');

const {
  syncBacklog,
  getBacklogItems,
  getBacklogItem,
  togglePin,
  completeItem,
  saveLayoutPreference,
  getLayoutPreference,
  completeItemByActivity
} = require('./controllers/backlogController');

const {
  getPendingNotifications,
  markNotificationSent,
  saveNotificationPreference,
  getNotificationPreference
} = require('./controllers/notificationController');

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
app.put('/api/backlog/complete-by-activity', completeItemByActivity);

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

// Grade routes
app.post('/api/lms/grades', getGrades);
app.post('/api/lms/course-grades', getCourseDetailedGrades);

// Calendar routes
app.post('/api/lms/calendar', getCalendarEvents);

// US-13: Backlog routes
app.post('/api/backlog/sync', syncBacklog);
app.get('/api/backlog/items/:email', getBacklogItems);
app.put('/api/backlog/pin/:itemId', togglePin);
app.put('/api/backlog/complete/:itemId', completeItem);
app.post('/api/backlog/layout', saveLayoutPreference);
app.get('/api/backlog/layout/:email', getLayoutPreference);
app.get('/api/backlog/item/:itemId', getBacklogItem);

// Personal events routes
app.post('/api/user/personal-event', addPersonalEvent);
app.get('/api/user/personal-events/:email', getPersonalEvents);
app.delete('/api/user/personal-event/:eventId', deletePersonalEvent);
app.put('/api/user/personal-event/:eventId', updatePersonalEvent);

// Course storage routes - FIXED: only use existing functions
app.get('/api/course/stored/:email', getStoredCourses);
app.get('/api/course/stored/:email/:courseId', getStoredCourse);
app.get('/api/course/contents/:email/:courseId', getCourseContentsFromDB);
app.put('/api/course/activity-complete', updateActivityCompletion);
app.get('/api/course/stats/:email', getCourseStats);
app.post('/api/course/sync-background', triggerBackgroundSync);
app.post('/api/course/sync', syncCourseToDatabase);
app.post('/api/course/sync-all', syncAllCourses);
app.post('/api/course/sync-by-id', syncCourseById);
app.put('/api/course/activity-complete-by-url', updateActivityByUrl);
app.get('/api/notifications/pending/:email', getPendingNotifications);
app.post('/api/notifications/mark-sent', markNotificationSent);
app.get('/api/notifications/preference/:email', getNotificationPreference);
app.post('/api/notifications/preference', saveNotificationPreference);

// Test route
app.get('/', (req, res) => {
  res.json({ message: 'Server is running' });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});