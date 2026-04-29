// services/notificationService.js
const BacklogItem = require('../models/BacklogItem');
const User = require('../models/User');

class NotificationService {
  constructor() {
    this.checkedNotifications = new Map(); // Track sent notifications per user
  }

  // US-09-T-01: Check for upcoming deadlines
  async checkUpcomingDeadlines() {
    try {
      const now = new Date();
      const twentyFourHoursLater = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const threeHoursLater = new Date(now.getTime() + 3 * 60 * 60 * 1000);

      // Find items due in 24 hours
      const dueIn24Hours = await BacklogItem.find({
        dueDate: { $gte: now, $lte: twentyFourHoursLater },
        isCompleted: false,
        isNotified24h: { $ne: true }
      }).populate('userId');

      // Find items due in 3 hours
      const dueIn3Hours = await BacklogItem.find({
        dueDate: { $gte: now, $lte: threeHoursLater },
        isCompleted: false,
        isNotified3h: { $ne: true }
      }).populate('userId');

      const notifications = [];

      for (const item of dueIn24Hours) {
        notifications.push({
          userId: item.userId,
          itemId: item._id,
          title: `📅 Deadline Tomorrow: ${item.activityName}`,
          body: `Due in 24 hours - ${this.getTaskTypeLabel(item.activityType)}`,
          scheduledAt: 24,
          item: item
        });
      }

      for (const item of dueIn3Hours) {
        notifications.push({
          userId: item.userId,
          itemId: item._id,
          title: `⚠️ Deadline Approaching: ${item.activityName}`,
          body: `Due in 3 hours - ${this.getTaskTypeLabel(item.activityType)}`,
          scheduledAt: 3,
          item: item
        });
      }

      return notifications;
    } catch (error) {
      console.error('Check deadlines error:', error);
      return [];
    }
  }

  getTaskTypeLabel(activityType) {
    const labels = {
      'assign': '📝 Assignment',
      'quiz': '📝 Quiz',
      'forum': '💬 Discussion',
      'resource': '📄 Resource',
      'page': '📄 Activity'
    };
    return labels[activityType] || '📋 Task';
  }

  // Mark notifications as sent
  async markNotified(itemId, type) {
    const updateField = type === 24 ? { isNotified24h: true } : { isNotified3h: true };
    await BacklogItem.findByIdAndUpdate(itemId, updateField);
  }
}

module.exports = NotificationService;