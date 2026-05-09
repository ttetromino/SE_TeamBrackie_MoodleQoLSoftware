// controllers/adminController.js
const User = require('../models/User');
const BacklogItem = require('../models/BacklogItem');
const mongoose = require('mongoose');

// US-12-T-02: Get scraper connectivity status
const getScraperStatus = async (req, res) => {
  try {
    const axios = require('axios');

    // Test Moodle connectivity
    let moodleStatus = 'disconnected';
    let moodleResponseTime = null;
    let lastSuccessfulSync = null;

    try {
      const startTime = Date.now();
      const response = await axios.get('https://uphslms.com/my/courses.php', {
        timeout: 10000,
        headers: {
          'User-Agent': 'MoodlePlus-Admin/1.0'
        }
      });
      const responseTime = Date.now() - startTime;

      if (response.status === 200) {
        moodleStatus = 'connected';
        moodleResponseTime = responseTime;
      } else {
        moodleStatus = 'degraded';
      }
    } catch (error) {
      if (error.code === 'ECONNABORTED') {
        moodleStatus = 'degraded';
      } else {
        moodleStatus = 'disconnected';
      }
    }

    // Get last successful sync from any user
    const lastSyncUser = await User.findOne(
      { lmsLastLogin: { $ne: null } },
      { lmsLastLogin: 1 }
    ).sort({ lmsLastLogin: -1 });

    if (lastSyncUser && lastSyncUser.lmsLastLogin) {
      lastSuccessfulSync = lastSyncUser.lmsLastLogin;
    }

    res.json({
      success: true,
      status: moodleStatus,
      responseTime: moodleResponseTime,
      lastSuccessfulSync: lastSuccessfulSync,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Get scraper status error:', error);
    res.status(500).json({ error: error.message });
  }
};

// US-12-T-04: Get storage usage statistics
const getStorageStats = async (req, res) => {
  try {
    // Get database stats
    const db = mongoose.connection.db;
    const stats = await db.stats();

    // Count users
    const totalUsers = await User.countDocuments();
    const adminUsers = await User.countDocuments({ role: 'admin' });
    const studentUsers = totalUsers - adminUsers;

    // Count courses (sum of all courses in all users)
    const usersWithCourses = await User.find({}, { courses: 1 });
    let totalCourses = 0;
    let totalArchivedCourses = 0;

    for (const user of usersWithCourses) {
      totalCourses += (user.courses || []).length;
      totalArchivedCourses += (user.archivedCourses || []).length;
    }

    // Count backlog items
    const totalBacklogItems = await BacklogItem.countDocuments();
    const completedBacklogItems = await BacklogItem.countDocuments({ isCompleted: true });
    const pendingBacklogItems = totalBacklogItems - completedBacklogItems;

    // Calculate storage in MB
    const dataSizeMB = (stats.dataSize || 0) / (1024 * 1024);
    const storageSizeMB = (stats.storageSize || 0) / (1024 * 1024);
    const indexSizeMB = (stats.indexSize || 0) / (1024 * 1024);

    // Free tier limit warning (512MB)
    const freeTierLimit = 512;
    const usagePercentage = (storageSizeMB / freeTierLimit) * 100;
    const isNearLimit = usagePercentage > 80;

    res.json({
      success: true,
      database: {
        dataSizeMB: dataSizeMB.toFixed(2),
        storageSizeMB: storageSizeMB.toFixed(2),
        indexSizeMB: indexSizeMB.toFixed(2),
        freeTierLimitMB: freeTierLimit,
        usagePercentage: usagePercentage.toFixed(1),
        isNearLimit: isNearLimit
      },
      users: {
        total: totalUsers,
        admin: adminUsers,
        student: studentUsers
      },
      courses: {
        active: totalCourses,
        archived: totalArchivedCourses,
        total: totalCourses + totalArchivedCourses
      },
      backlog: {
        total: totalBacklogItems,
        completed: completedBacklogItems,
        pending: pendingBacklogItems
      },
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Get storage stats error:', error);
    res.status(500).json({ error: error.message });
  }
};

// US-12-T-04: Get all users (for admin view)
const getAllUsers = async (req, res) => {
  try {
    const users = await User.find(
      {},
      {
        name: 1,
        email: 1,
        role: 1,
        lmsUsername: 1,
        lmsLastLogin: 1,
        createdAt: 1,
        'courseStats.totalQuizzes': 1,
        'courseStats.completedQuizzes': 1,
        'courseStats.totalAssignments': 1,
        'courseStats.completedAssignments': 1
      }
    ).sort({ createdAt: -1 });

    // Add course count and backlog count for each user
    const usersWithStats = await Promise.all(users.map(async (user) => {
      const courseCount = (user.courses || []).length;
      const archivedCount = (user.archivedCourses || []).length;
      const backlogCount = await BacklogItem.countDocuments({ userId: user.email });
      const completedBacklogCount = await BacklogItem.countDocuments({
        userId: user.email,
        isCompleted: true
      });

      const userObj = user.toObject();
      delete userObj.password;
      delete userObj.lmsPassword;
      delete userObj.lmsCookies;
      delete userObj.biometricToken;

      return {
        ...userObj,
        courseCount,
        archivedCount,
        backlogCount,
        completedBacklogCount
      };
    }));

    res.json({
      success: true,
      users: usersWithStats,
      total: usersWithStats.length
    });
  } catch (error) {
    console.error('Get all users error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get single user details (for admin viewing)
const getUserDetails = async (req, res) => {
  try {
    const { email } = req.params;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const backlogCount = await BacklogItem.countDocuments({ userId: email });
    const completedBacklogCount = await BacklogItem.countDocuments({
      userId: email,
      isCompleted: true
    });

    const userObj = user.toObject();
    delete userObj.password;
    delete userObj.lmsPassword;
    delete userObj.lmsCookies;
    delete userObj.biometricToken;

    res.json({
      success: true,
      user: {
        ...userObj,
        backlogCount,
        completedBacklogCount,
        activeCourseCount: (user.courses || []).length,
        archivedCourseCount: (user.archivedCourses || []).length
      }
    });
  } catch (error) {
    console.error('Get user details error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get user's courses (for admin viewing)
const getUserCourses = async (req, res) => {
  try {
    const { email } = req.params;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const activeCourses = (user.courses || []).map(c => ({
      courseId: c.courseId,
      courseName: c.courseName,
      totalActivities: c.totalActivities,
      completedActivities: c.completedActivities,
      lastSynced: c.lastSynced,
      isArchived: false
    }));

    const archivedCourses = (user.archivedCourses || []).map(c => ({
      courseId: c.courseId,
      courseName: c.courseName,
      archivedAt: c.archivedAt,
      totalActivities: c.metadata?.totalActivities || 0,
      completedActivities: c.metadata?.completedActivities || 0,
      isArchived: true
    }));

    res.json({
      success: true,
      courses: [...activeCourses, ...archivedCourses]
    });
  } catch (error) {
    console.error('Get user courses error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get user's backlog (for admin viewing)
const getUserBacklog = async (req, res) => {
  try {
    const { email } = req.params;
    const { showCompleted } = req.query;

    let query = { userId: email };
    if (showCompleted !== 'true') {
      query.isCompleted = false;
    }

    const backlog = await BacklogItem.find(query).sort({ dueDate: 1, priority: 1 });

    res.json({
      success: true,
      backlog: backlog,
      count: backlog.length
    });
  } catch (error) {
    console.error('Get user backlog error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Force sync for a user (admin action)
const forceUserSync = async (req, res) => {
  try {
    const { email } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Trigger sync in background
    console.log(`🔧 Admin forcing sync for: ${email}`);

    // Import the sync function dynamically to avoid circular dependency
    const { syncAllCourses } = require('./courseController');

    // Call sync (non-blocking)
    syncAllCourses({ body: { email } }, {
      json: () => {},
      status: () => ({ json: () => {} })
    });

    res.json({
      success: true,
      message: `Sync triggered for ${email}`,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Force user sync error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Soft delete user (admin action)
const removeUser = async (req, res) => {
  try {
    const { email } = req.body;

    // Don't allow deleting yourself
    if (email === req.adminUser.email) {
      return res.status(400).json({ error: 'Cannot remove your own admin account' });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Delete user's backlog items
    await BacklogItem.deleteMany({ userId: email });

    // Delete user (soft delete - actually remove since we don't have soft delete flag)
    await User.deleteOne({ email });

    console.log(`🗑️ Admin ${req.adminUser.email} removed user: ${email}`);

    res.json({
      success: true,
      message: `User ${email} has been removed`
    });
  } catch (error) {
    console.error('Remove user error:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getScraperStatus,
  getStorageStats,
  getAllUsers,
  getUserDetails,
  getUserCourses,
  getUserBacklog,
  forceUserSync,
  removeUser
};