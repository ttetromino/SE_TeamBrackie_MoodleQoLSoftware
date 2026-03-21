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
  lmsPassword: { type: String, required: true }
});


userSchema.pre('save', async function() {
  console.log('Pre-save hook triggered');
  

  if (this.isModified('password')) {
    console.log('Hashing main password');
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
  
  
  
  console.log('Pre-save hook completed');
  
});


userSchema.methods.compareLMSPassword = async function(candidatePassword) {
  try {
    return await bcrypt.compare(candidatePassword, this.lmsPassword);
  } catch (error) {
    console.error('Error comparing LMS password:', error);
    return false;
  }
};


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
