const mongoose = require('mongoose');

const backlogItemSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  courseId: { type: String, required: true },
  courseName: { type: String, required: true },
  courseCode: { type: String, required: true },
  activityId: { type: String, required: true },
  activityName: { type: String, required: true },
  activityType: { type: String, required: true },
  dueDate: { type: Date, required: false, default: null },  // CHANGED: required: false
  priority: { 
    type: String, 
    enum: ['urgent', 'high', 'medium', 'low', 'no_deadline', 'past_due'],
    default: 'medium'
  },
  isPinned: { type: Boolean, default: false },
  isCompleted: { type: Boolean, default: false },
  sectionName: { type: String, default: '' },
  activityUrl: { type: String, default: '' },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  isNotified24h: { type: Boolean, default: false },
  isNotified3h: { type: Boolean, default: false }
});

backlogItemSchema.index({ userId: 1, dueDate: 1 });
backlogItemSchema.index({ userId: 1, priority: 1 });
backlogItemSchema.index({ userId: 1, courseCode: 1 });

const BacklogItem = mongoose.model('BacklogItem', backlogItemSchema);

module.exports = BacklogItem;