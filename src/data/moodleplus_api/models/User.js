// models/User.js (updated)
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

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

// US-11: Personal Event Schema
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
  name: {
    type: String,
    required: true
  },
  email: {
    type: String,
    unique: true,
    required: true
  },
  password: {
    type: String,
    required: true
  },
  lmsUsername: {
    type: String,
    required: true
  },
  lmsPassword: {
    type: String,
    required: true
  },
  // Session persistence fields
  lmsCookies: {
    type: [String],
    default: []
  },
  lmsSessionExpiry: {
    type: Date,
    default: null
  },
  lmsLastLogin: {
    type: Date,
    default: null
  },
  // Biometric fields
  biometricEnabled: {
    type: Boolean,
    default: false
  },
  biometricToken: {
    type: String,
    default: null
  },
  biometricEnabledAt: {
    type: Date,
    default: null
  },
  // US-04: Archived courses storage
  archivedCourses: {
    type: [archivedCourseSchema],
    default: []
  },
  // US-13: User preferences
  preferences: {
    backlogLayout: { type: String, enum: ['compact', 'expanded'], default: 'compact' },
    lastBacklogSync: { type: Date, default: null }
  },
  // US-11: Personal events storage
  personalEvents: {
    type: [personalEventSchema],
    default: []
  }
});

// Only hash the main app password, NOT the LMS password
userSchema.pre('save', async function() {
  console.log('Pre-save hook triggered');
  
  if (this.isModified('password')) {
    console.log('Hashing main password');
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
});

// Method to compare main password
userSchema.methods.comparePassword = async function(candidatePassword) {
  try {
    return await bcrypt.compare(candidatePassword, this.password);
  } catch (error) {
    console.error('Error comparing password:', error);
    return false;
  }
};

const User = mongoose.model('User', userSchema);

module.exports = User;