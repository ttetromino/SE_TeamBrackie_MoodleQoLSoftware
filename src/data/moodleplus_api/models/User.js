const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
// US-01-T-03: Designing Database Schema
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
  // US-01-T-02: Biometrics Verification 
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
});

// Hash passwords before saving
userSchema.pre('save', async function() {
  console.log('Pre-save hook triggered');
  
  if (this.isModified('password')) {
    console.log('Hashing main password');
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
  
  if (this.isModified('lmsPassword')) {
    console.log('Hashing LMS password');
    const salt = await bcrypt.genSalt(10);
    this.lmsPassword = await bcrypt.hash(this.lmsPassword, salt);
  }
  
  console.log('Pre-save hook completed');
});

// Method to compare LMS password
userSchema.methods.compareLMSPassword = async function(candidatePassword) {
  try {
    return await bcrypt.compare(candidatePassword, this.lmsPassword);
  } catch (error) {
    console.error('Error comparing LMS password:', error);
    return false;
  }
};

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
