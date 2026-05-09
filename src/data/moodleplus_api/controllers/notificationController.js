// controllers/notificationController.js
const BacklogItem = require('../models/BacklogItem');
const User = require('../models/User');
const NotificationService = require('../services/notificationService');

const notificationService = new NotificationService();

// Get pending notifications for a user
const getPendingNotifications = async (req, res) => {
  try {
    const { email } = req.params;

    // Get user to check preferences
    const user = await User.findOne({ email });
    const preferences = user?.notificationPreferences || {
      enabled24h: true,
      enabled3h: true
    };

    // Get all pending items for this user
    const now = new Date();
    const twentyFourHoursLater = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const threeHoursLater = new Date(now.getTime() + 3 * 60 * 60 * 1000);

    const query = {
      userId: email,
      isCompleted: false,
      dueDate: { $exists: true, $ne: null }
    };

    if (!preferences.enabled24h) {
      query.dueDate = { $gt: twentyFourHoursLater };
    }
    if (!preferences.enabled3h) {
      query.dueDate = { $gt: threeHoursLater };
    }

    const items = await BacklogItem.find(query);

    const notifications = [];

    for (const item of items) {
      const dueDate = new Date(item.dueDate);
      const hoursUntilDue = (dueDate - now) / (1000 * 60 * 60);

      if (hoursUntilDue <= 24 && hoursUntilDue > 0 && !item.isNotified24h && preferences.enabled24h) {
        notifications.push({
          id: `${item._id}_24h`,
          itemId: item._id,
          title: `📅 Deadline Tomorrow`,
          body: `${item.activityName} - Due in 24 hours`,
          type: 'assignment' in item ? 'assignment' : 'quiz',
          courseName: item.courseName,
          activityId: item.activityId,
          courseId: item.courseId,
          activityUrl: item.activityUrl,
          scheduledAt: 24
        });
      }

      if (hoursUntilDue <= 3 && hoursUntilDue > 0 && !item.isNotified3h && preferences.enabled3h) {
        notifications.push({
          id: `${item._id}_3h`,
          itemId: item._id,
          title: `⚠️ Deadline Approaching`,
          body: `${item.activityName} - Due in 3 hours`,
          type: item.activityType,
          courseName: item.courseName,
          activityId: item.activityId,
          courseId: item.courseId,
          activityUrl: item.activityUrl,
          scheduledAt: 3
        });
      }
    }

    res.json({
      success: true,
      notifications: notifications,
      preferences: preferences
    });

  } catch (error) {
    console.error('Get pending notifications error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Mark notification as sent
const markNotificationSent = async (req, res) => {
  try {
    const { itemId, scheduledAt } = req.body;

    const updateField = scheduledAt === 24 ? { isNotified24h: true } : { isNotified3h: true };
    await BacklogItem.findByIdAndUpdate(itemId, updateField);

    res.json({ success: true });

  } catch (error) {
    console.error('Mark notification error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Save notification preference
const saveNotificationPreference = async (req, res) => {
  try {
    const { email, enabled24h, enabled3h } = req.body;

    await User.findOneAndUpdate(
      { email },
      {
        notificationPreferences: { enabled24h, enabled3h }
      },
      { upsert: true }
    );

    res.json({ success: true });

  } catch (error) {
    console.error('Save notification preference error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get notification preference
const getNotificationPreference = async (req, res) => {
  try {
    const { email } = req.params;

    const user = await User.findOne({ email });
    const preferences = user?.notificationPreferences || {
      enabled24h: true,
      enabled3h: true
    };

    res.json({ success: true, preferences: preferences });

  } catch (error) {
    console.error('Get notification preference error:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getPendingNotifications,
  markNotificationSent,
  saveNotificationPreference,
  getNotificationPreference
};