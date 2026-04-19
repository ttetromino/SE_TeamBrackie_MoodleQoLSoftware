const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

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
  // US-03: Add profile picture field
  profilePicture: {
    type: String,
    default: null
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
  }
}, { timestamps: true });

// Only hash the main app password, NOT the LMS password
userSchema.pre('save', async function() {
  console.log('Pre-save hook triggered');
  
  if (this.isModified('password')) {
    console.log('Hashing main password');
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
  
  // Remove LMS password hashing - store as plain text
  // LMS password needs to be plain text to login to uphslms.com
  
  console.log('Pre-save hook completed');
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