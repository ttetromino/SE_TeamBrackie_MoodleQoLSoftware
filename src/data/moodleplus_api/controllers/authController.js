const User = require('../models/User');
const bcrypt = require('bcrypt');

// Signup with required LMS credentials
const signup = async (req, res) => {
  try {
    console.log('📝 Signup request received:', { 
      name: req.body.name, 
      email: req.body.email,
      lmsUsername: req.body.lmsUsername ? 'provided' : 'missing'
    });

    const { name, email, password, lmsUsername, lmsPassword } = req.body;
    
    // Validate all required fields
    if (!name || !email || !password || !lmsUsername || !lmsPassword) {
      console.log('❌ Missing fields');
      return res.status(400).json({ 
        error: 'All fields are required including LMS credentials' 
      });
    }

    // Check if user already exists
    const existing = await User.findOne({ email });
    if (existing) {
      console.log('❌ User already exists:', email);
      return res.status(400).json({ error: 'Email already registered' });
    }

    // Create user with required LMS credentials
    console.log('👤 Creating new user...');
    const user = new User({ 
      name, 
      email, 
      password,
      lmsUsername,
      lmsPassword 
    });
    
    await user.save();
    console.log('✅ User created successfully:', user.email);



    res.status(201).json({ 
      message: 'Signup successful',
      user: { 
        name: user.name, 
        email: user.email,
        lmsUsername: user.lmsUsername
      }
    });
  } catch (err) {
    console.error('❌ Signup error details:', err);
    res.status(500).json({ 
      error: err.message || 'Internal server error'
    });
  }
};

// Login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    console.log('🔑 Login attempt for:', email);
    
    const user = await User.findOne({ email });
    
    if (!user) {
      console.log('❌ User not found:', email);
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      console.log('❌ Invalid password for:', email);
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    console.log('✅ Login successful for:', email);

    res.json({ 
      user: { 
        name: user.name, 
        email: user.email,
        lmsUsername: user.lmsUsername
      },
      hasLMSCredentials: true
    });
  } catch (err) {
    console.error('❌ Login error:', err);
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
    console.error('❌ Update error:', err);
    res.status(500).json({ error: err.message });
  }
};


// Auto Login LMS (check if session exists)
const autoLoginLMS = async (req, res) => {
  console.log('🤖 Auto-login for user:', req.body.userId);
  
  try {
    const userId = req.body.userId;
    
    // First check in-memory session
    const session = userSessions.get(userId);
    if (session) {
      console.log('📝 Found in-memory session');
      // Check if session is still valid
      const client = createLMSClient(session.cookies);
      try {
        const dashboard = await client.get('https://uphslms.com/');
        if (!dashboard.data.includes('Log in')) {
          console.log('✅ Existing in-memory session still valid');
          return res.json({ success: true });
        } else {
          console.log('⚠️ In-memory session expired');
          userSessions.delete(userId);
        }
      } catch (e) {
        console.log('❌ In-memory session error:', e.message);
        userSessions.delete(userId);
      }
    }

    // If no in-memory session, try to restore from database
    console.log('🔄 Trying to restore session from database');
    const user = await User.findOne({ email: userId });
    
    if (user && user.lmsCookies && user.lmsCookies.length > 0) {
      console.log(`📦 Found ${user.lmsCookies.length} stored cookies`);
      
      // Check if session hasn't expired
      if (user.lmsSessionExpiry) {
        const now = new Date();
        const expiry = new Date(user.lmsSessionExpiry);
        console.log(`⏰ Session expiry: ${expiry}, Current: ${now}`);
        
        if (now < expiry) {
          console.log('⏳ Session not expired, attempting to use');
          // Try to use stored cookies
          const client = createLMSClient(user.lmsCookies);
          try {
            const dashboard = await client.get('https://uphslms.com/');
            if (!dashboard.data.includes('Log in')) {
              console.log('✅ Restored session from database');
              
              // Restore to in-memory storage
              userSessions.set(userId, {
                cookies: user.lmsCookies,
                timestamp: Date.now()
              });
              
              return res.json({ success: true });
            } else {
              console.log('❌ Stored cookies are invalid');
            }
          } catch (e) {
            console.log('❌ Error using stored cookies:', e.message);
          }
        } else {
          console.log('⏰ Session expired in database');
        }
      } else {
        console.log('⚠️ No expiry date in database');
      }
    } else {
      console.log('❌ No stored cookies found for user');
    }

    // No valid session
    console.log('❌ No valid session found');
    res.json({ success: false, message: 'No valid session' });
    
  } catch (error) {
    console.error('❌ Auto-login error:', error.message);
    res.status(500).json({ error: error.message });
  }
};
module.exports = { signup, login, updateLMSCredentials, autoLoginLMS };