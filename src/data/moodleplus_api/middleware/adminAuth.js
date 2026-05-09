// middleware/adminAuth.js
const User = require('../models/User');

const requireAdmin = async (req, res, next) => {
  try {
    // Get email from query string, body, or params
    const email = req.query.email || req.body.email || req.params.email || req.body.adminEmail;

    console.log('🔐 Admin auth check - email:', email);

    if (!email) {
      console.log('❌ No email provided in request');
      return res.status(401).json({ error: 'Authentication required - no email provided' });
    }

    const user = await User.findOne({ email });

    if (!user) {
      console.log('❌ User not found:', email);
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.role !== 'admin') {
      console.log('❌ Not admin:', email, 'role:', user.role);
      return res.status(403).json({ error: 'Access denied. Admin privileges required.' });
    }

    console.log('✅ Admin access granted:', email);
    req.adminUser = user;
    next();
  } catch (error) {
    console.error('Admin auth error:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = { requireAdmin };