// models/User.js
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

// Activity schema for stored course data
const storedActivitySchema = new mongoose.Schema({
  id: { type: String, required: true },
  name: { type: String, required: true },
  type: { type: String, required: true },
  url: { type: String, default: null },
  icon: { type: String, default: null },
  badge: { type: String, default: null },
  isIndented: { type: Boolean, default: false },
  completionStatus: { type: String, enum: ['todo', 'done', 'unknown'], default: 'todo' },
  dates: { type: [String], default: [] },
  dueDate: { type: Date, default: null },
  sectionId: { type: String, default: null },
  lastSynced: { type: Date, default: Date.now }
});

// Section schema for stored course data
const storedSectionSchema = new mongoose.Schema({
  id: { type: String, required: true },
  number: { type: String, default: '' },
  name: { type: String, required: true },
  link: { type: String, default: null },
  activities: { type: [storedActivitySchema], default: [] },
  lastSynced: { type: Date, default: Date.now }
});

// Course schema for stored course data
const storedCourseSchema = new mongoose.Schema({
  courseId: { type: String, required: true },
  courseName: { type: String, required: true },
  courseUrl: { type: String, required: true },
  courseTitle: { type: String, default: '' },
  sections: { type: [storedSectionSchema], default: [] },
  isArchived: { type: Boolean, default: false },
  archivedAt: { type: Date, default: null },
  lastAccessed: { type: Date, default: Date.now },
  lastSynced: { type: Date, default: Date.now },
  totalActivities: { type: Number, default: 0 },
  completedActivities: { type: Number, default: 0 }
});

const archivedCourseSchema = new mongoose.Schema({
  courseId: { type: String, required: true },
  courseName: { type: String, required: true },
  courseUrl: { type: String, required: true },
  archivedAt: { type: Date, default: Date.now },
  contents: { type: mongoose.Schema.Types.Mixed, default: {} },
  thumbnail: { type: String, default: null },
  metadata: {
    originalEnrollmentDate: { type: Date, default: null },
    lastAccessed: { type: Date, default: null },
    totalActivities: { type: Number, default: 0 },
    completedActivities: { type: Number, default: 0 }
  }
});

// Personal Event Schema
const personalEventSchema = new mongoose.Schema({
  id: { type: String, required: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  date: { type: Date, required: true },
  timeHour: { type: Number, default: null },
  timeMinute: { type: Number, default: null },
  isAllDay: { type: Boolean, default: true },
  courseName: { type: String, default: null },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, unique: true, required: true },
  password: { type: String, required: true },
  role: { type: String, enum: ['student', 'admin'], default: 'student' },
  lmsUsername: { type: String, required: true },
  lmsPassword: { type: String, required: true },

  // Session persistence fields
  lmsCookies: { type: [String], default: [] },
  lmsSessionExpiry: { type: Date, default: null },
  lmsLastLogin: { type: Date, default: null },

  // Biometric fields
  biometricEnabled: { type: Boolean, default: false },
  biometricToken: { type: String, default: null },
  biometricEnabledAt: { type: Date, default: null },

  // NEW: Stored courses (active courses)
  courses: { type: [storedCourseSchema], default: [] },

  // Archived courses storage
  archivedCourses: { type: [archivedCourseSchema], default: [] },

  // User preferences
  preferences: {
    backlogLayout: { type: String, enum: ['compact', 'expanded'], default: 'compact' },
    lastBacklogSync: { type: Date, default: null }
  },

  // Personal events storage
  personalEvents: { type: [personalEventSchema], default: [] },

  // Course stats cache
  courseStats: {
    totalTasks: { type: Number, default: 0 },
    completedTasks: { type: Number, default: 0 },
    totalQuizzes: { type: Number, default: 0 },
    completedQuizzes: { type: Number, default: 0 },
    totalAssignments: { type: Number, default: 0 },
    completedAssignments: { type: Number, default: 0 },
    lastUpdated: { type: Date, default: null }
  }
});

// Hash main app password only
userSchema.pre('save', async function() {
  if (this.isModified('password')) {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
});

userSchema.methods.comparePassword = async function(candidatePassword) {
  try {
    console.log('🔐 Comparing password...');
    const result = await bcrypt.compare(candidatePassword, this.password);
    console.log('🔐 Password match result:', result);
    return result;
  } catch (error) {
    console.error('Error comparing password:', error);
    return false;
  }
};

const User = mongoose.model('User', userSchema);
module.exports = User;