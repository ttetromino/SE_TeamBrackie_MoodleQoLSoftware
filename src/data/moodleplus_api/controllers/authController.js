const User = require('../models/User');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { createLMSClient } = require('../utils/lmsClient');
const { userSessions } = require('../utils/sessionStore');
const cheerio = require('cheerio');

// Signup with required LMS credentials
const signup = async (req, res) => {
  try {
    console.log('Signup request received:', { 
      name: req.body.name, 
      email: req.body.email,
      lmsUsername: req.body.lmsUsername ? 'provided' : 'missing'
    });

    const { name, email, password, lmsUsername, lmsPassword } = req.body;
    
    // Validate all required fields
    if (!name || !email || !password || !lmsUsername || !lmsPassword) {
      console.log('Missing fields');
      return res.status(400).json({ 
        error: 'All fields are required including LMS credentials' 
      });
    }
      // US-01-T-04: Develop Data Access Layer
    // Check if user already exists
    const existing = await User.findOne({ email });
    if (existing) {
      console.log('User already exists:', email);
      return res.status(400).json({ error: 'Email already registered' });
    }
    
      // US-01-T-01: Add Student Account
    // Create user with required LMS credentials
    console.log('Creating new user...');
    const user = new User({ 
      name, 
      email, 
      password,
      lmsUsername,
      lmsPassword 
    });
    
    await user.save();
    console.log('User created successfully:', user.email);



    res.status(201).json({ 
      message: 'Signup successful',
      user: { 
        name: user.name, 
        email: user.email,
        lmsUsername: user.lmsUsername
      }
    });
  } catch (err) {
    console.error('Signup error details:', err);
    res.status(500).json({ 
      error: err.message || 'Internal server error'
    });
  }
};

// US-01-T-05: Create Login
// Login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    console.log('Login attempt for:', email);
    
    const user = await User.findOne({ email });
    
    if (!user) {
      console.log('User not found:', email);
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      console.log('Invalid password for:', email);
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    console.log('Login successful for:', email);

    res.json({ 
      user: { 
        name: user.name, 
        email: user.email,
        lmsUsername: user.lmsUsername
      },
      hasLMSCredentials: true
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Update LMS credentials
const updateLMSCredentials = async (req, res) => {
  try {
    const { email, lmsUsername, lmsPassword } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (!lmsUsername || !lmsPassword) {
      return res.status(400).json({ error: 'LMS username and password are required' });
    }

    user.lmsUsername = lmsUsername;
    user.lmsPassword = lmsPassword;

    await user.save();

    res.json({ 
      message: 'LMS credentials updated',
      user: {
        name: user.name,
        email: user.email,
        lmsUsername: user.lmsUsername
      }
    });
  } catch (err) {
    console.error('Update error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Auto Login LMS (check if session exists)
const autoLoginLMS = async (req, res) => {
  console.log('Auto-login for user:', req.body.userId);
  
  try {
    const userId = req.body.userId;
    
    // First check in-memory session
    const session = userSessions.get(userId);
    if (session && session.cookies) {
      console.log('Found in-memory session');
      // Check if session is still valid
      const client = createLMSClient(session.cookies);
      try {
        const dashboard = await client.get('https://uphslms.com/my/', {
          timeout: 10000
        });
        if (!dashboard.data.includes('Log in')) {
          console.log('Existing in-memory session still valid');
          return res.json({ success: true });
        } else {
          console.log('In-memory session expired');
          userSessions.delete(userId);
        }
      } catch (e) {
        console.log('In-memory session error:', e.message);
        userSessions.delete(userId);
      }
    }

    // If no in-memory session, try to restore from database
    console.log('🔄 Trying to restore session from database');
    const user = await User.findOne({ email: userId });

    if (user && user.lmsCookies && user.lmsCookies.length > 0) {
      console.log(`Found ${user.lmsCookies.length} stored cookies`);

      // Check if session hasn't expired
      if (user.lmsSessionExpiry && new Date() < new Date(user.lmsSessionExpiry)) {
        console.log(`Session expiry: ${user.lmsSessionExpiry}, Current: ${new Date()}`);
        console.log('⏳ Session not expired, attempting to use');

        // Try to use stored cookies
        const client = createLMSClient(user.lmsCookies);
        try {
          const dashboard = await client.get('https://uphslms.com/my/', {
            timeout: 10000
          });
          if (!dashboard.data.includes('Log in')) {
            console.log('Restored session from database');
            userSessions.set(userId, {
              cookies: user.lmsCookies,
              timestamp: Date.now(),
              username: user.lmsUsername
            });
            return res.json({ success: true });
          } else {
            console.log('Stored cookies are invalid - will attempt fresh login');
            // Clear invalid cookies from database
            await User.findOneAndUpdate(
              { email: userId },
              { $set: { lmsCookies: [], lmsSessionExpiry: null } }
            );
          }
        } catch (e) {
          console.log('Error using stored cookies:', e.message);
          // Clear invalid cookies from database
          await User.findOneAndUpdate(
            { email: userId },
            { $set: { lmsCookies: [], lmsSessionExpiry: null } }
          );
        }
      } else {
        console.log('Session expired in database, clearing...');
        await User.findOneAndUpdate(
          { email: userId },
          { $set: { lmsCookies: [], lmsSessionExpiry: null } }
        );
      }
    }

    // Try to login fresh using stored LMS credentials
    if (user && user.lmsUsername && user.lmsPassword) {
      console.log('🔄 Attempting fresh login with stored credentials...');
      const client = createLMSClient();
      const loginUrl = 'https://uphslms.com/login/index.php';

      try {
        const loginPage = await client.get(loginUrl);
        let $ = cheerio.load(loginPage.data);
        const logintoken = $('input[name="logintoken"]').val();

        await client.post(loginUrl,
          new URLSearchParams({
            username: user.lmsUsername,
            password: user.lmsPassword,
            logintoken: logintoken,
            anchor: ''
          }), {
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Origin': 'https://uphslms.com/',
              'Referer': loginUrl
            }
          });

        const dashboard = await client.get('https://uphslms.com/my/');
        if (!dashboard.data.includes('Log in')) {
          console.log('✅ Fresh login successful!');

          const cookies = await client.defaults.jar.getCookies('https://uphslms.com');
          const cookieStrings = cookies.map(c => c.cookieString());

          userSessions.set(userId, {
            cookies: cookieStrings,
            timestamp: Date.now(),
            username: user.lmsUsername
          });

          await User.findOneAndUpdate(
            { email: userId },
            {
              lmsCookies: cookieStrings,
              lmsSessionExpiry: new Date(Date.now() + 24 * 60 * 60 * 1000),
              lmsLastLogin: new Date()
            }
          );

          console.log('✅ Session created and stored');
          return res.json({ success: true });
        } else {
          console.log('❌ Fresh login failed - invalid credentials');
          return res.json({ success: false, message: 'Invalid LMS credentials' });
        }
      } catch (loginError) {
        console.error('Fresh login error:', loginError.message);
        return res.json({ success: false, message: 'Login failed' });
      }
    }

    console.log('No valid session and no stored credentials');
    res.json({ success: false, message: 'No valid session' });
    
  } catch (error) {
    console.error('Auto-login error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

// Enable biometric login for user
const enableBiometricLogin = async (req, res) => {
  try {
    const { email, biometricToken } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Generate a unique token if not provided
    const token = biometricToken || crypto.randomBytes(32).toString('hex');
    
    user.biometricEnabled = true;
    user.biometricToken = token;
    user.biometricEnabledAt = new Date();
    
    await user.save();
    
    console.log(`Biometric login enabled for user: ${email}`);
    res.json({ 
      success: true,
      message: 'Biometric login enabled',
      token: token
    });
  } catch (err) {
    console.error('Enable biometric error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Disable biometric login for user
const disableBiometricLogin = async (req, res) => {
  try {
    const { email } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    user.biometricEnabled = false;
    user.biometricToken = null;
    user.biometricEnabledAt = null;
    
    await user.save();
    
    console.log(`Biometric login disabled for user: ${email}`);
    res.json({ 
      success: true,
      message: 'Biometric login disabled'
    });
  } catch (err) {
    console.error('Disable biometric error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Biometric login
const biometricLogin = async (req, res) => {
  try {
    const { email, biometricToken } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Check if biometric is enabled and token matches
    if (!user.biometricEnabled || user.biometricToken !== biometricToken) {
      return res.status(401).json({ error: 'Invalid biometric authentication' });
    }
    
    console.log(`Biometric login successful for: ${email}`);
    res.json({ 
      success: true,
      user: { 
        name: user.name, 
        email: user.email,
        lmsUsername: user.lmsUsername,
        biometricEnabled: user.biometricEnabled
      }
    });
  } catch (err) {
    console.error('Biometric login error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Get biometric status
const getBiometricStatus = async (req, res) => {
  try {
    const { email } = req.params;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({
      biometricEnabled: user.biometricEnabled,
      enabledAt: user.biometricEnabledAt
    });
  } catch (err) {
    console.error('Get biometric status error:', err);
    res.status(500).json({ error: err.message });
  }
};

const changeAppPassword = async (req, res) => {
  try {
    const { email, currentPassword, newPassword } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Verify current password
    const isValid = await user.comparePassword(currentPassword);
    if (!isValid) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    // Set the new password directly (pre-save hook will hash it)
    user.password = newPassword;
    await user.save();  // This triggers the pre('save') hook

    res.json({ success: true, message: 'App password changed successfully' });
  } catch (err) {
    console.error('Change app password error:', err);
    res.status(500).json({ error: err.message });
  }
};
// US-03: Update email
const updateEmail = async (req, res) => {
  try {
    const { email, newEmail, password } = req.body;
    
    console.log('Update email request:', { email, newEmail });
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Verify current password
    const isValid = await user.comparePassword(password);
    if (!isValid) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }
    
    // Check if new email already exists
    const existingUser = await User.findOne({ email: newEmail });
    if (existingUser && existingUser.email !== email) {
      return res.status(400).json({ error: 'Email already in use' });
    }
    
    // Update email
    user.email = newEmail;
    await user.save();
    
    console.log('Email updated successfully for:', newEmail);
    
    res.json({
      success: true,
      message: 'Email updated successfully',
      user: {
        name: user.name,
        email: user.email,
        lmsUsername: user.lmsUsername
      }
    });
  } catch (err) {
    console.error('Update email error:', err);
    res.status(500).json({ error: err.message });
  }
};

// US-03: Update profile picture
const updateProfilePicture = async (req, res) => {
  try {
    const { email, profilePicture, password } = req.body;
    
    console.log('Update profile picture request for:', email);
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Verify current password
    const isValid = await user.comparePassword(password);
    if (!isValid) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }
    
    console.log('Profile picture updated for:', email);
    
    res.json({
      success: true,
      message: 'Profile picture updated successfully'
    });
  } catch (err) {
    console.error('Update profile picture error:', err);
    res.status(500).json({ error: err.message });
  }
};
const addPersonalEvent = async (req, res) => {
  try {
    const { email, event } = req.body;

    console.log('📝 Adding personal event for:', email);
    console.log('   Event:', event.title);

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const newEvent = {
      id: event.id || Date.now().toString(),
      title: event.title,
      description: event.description || '',
      date: new Date(event.date),
      timeHour: event.timeHour || null,
      timeMinute: event.timeMinute || null,
      isAllDay: event.isAllDay ?? true,
      courseName: event.courseName || null,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    user.personalEvents.push(newEvent);
    await user.save();

    console.log('✅ Personal event added successfully');
    res.json({
      success: true,
      message: 'Personal event added',
      event: newEvent
    });

  } catch (err) {
    console.error('Add personal event error:', err);
    res.status(500).json({ error: err.message });
  }
};

// US-11: Get all personal events
const getPersonalEvents = async (req, res) => {
  try {
    const { email } = req.params;

    console.log('📋 Fetching personal events for:', email);

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const events = user.personalEvents.sort((a, b) => a.date - b.date);

    res.json({
      success: true,
      events: events
    });

  } catch (err) {
    console.error('Get personal events error:', err);
    res.status(500).json({ error: err.message });
  }
};

// US-11: Delete personal event
const deletePersonalEvent = async (req, res) => {
  try {
    const { eventId } = req.params;
    const { email } = req.body;

    console.log('🗑️ Deleting personal event:', eventId, 'for user:', email);

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const eventIndex = user.personalEvents.findIndex(e => e.id === eventId);
    if (eventIndex === -1) {
      return res.status(404).json({ error: 'Event not found' });
    }

    user.personalEvents.splice(eventIndex, 1);
    await user.save();

    console.log('✅ Personal event deleted');
    res.json({
      success: true,
      message: 'Personal event deleted'
    });

  } catch (err) {
    console.error('Delete personal event error:', err);
    res.status(500).json({ error: err.message });
  }
};

// US-11: Update personal event
const updatePersonalEvent = async (req, res) => {
  try {
    const { eventId } = req.params;
    const { email, event } = req.body;

    console.log('✏️ Updating personal event:', eventId, 'for user:', email);

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const eventIndex = user.personalEvents.findIndex(e => e.id === eventId);
    if (eventIndex === -1) {
      return res.status(404).json({ error: 'Event not found' });
    }

    user.personalEvents[eventIndex] = {
      ...user.personalEvents[eventIndex],
      title: event.title,
      description: event.description,
      date: new Date(event.date),
      timeHour: event.timeHour,
      timeMinute: event.timeMinute,
      isAllDay: event.isAllDay,
      courseName: event.courseName,
      updatedAt: new Date()
    };

    await user.save();

    console.log('✅ Personal event updated');
    res.json({
      success: true,
      message: 'Personal event updated',
      event: user.personalEvents[eventIndex]
    });

  } catch (err) {
    console.error('Update personal event error:', err);
    res.status(500).json({ error: err.message });
  }
};
module.exports = { 
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
};