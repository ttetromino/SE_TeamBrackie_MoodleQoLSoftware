// controllers/backlogController.js
const BacklogItem = require('../models/BacklogItem');
const User = require('../models/User');
const { userSessions } = require('../utils/sessionStore');
const { createLMSClient } = require('../utils/lmsClient');
const cheerio = require('cheerio');

// EXCLUDED COURSES (same as courseController)
const EXCLUDED_COURSES = [
  'B-Library', 'B-LIBRARY', 'Library', 'Binan - College E-library',
  'orientation', 'Orientation'
];

// EXCLUDED ACTIVITY KEYWORDS (same as courseController)
const EXCLUDED_ACTIVITY_KEYWORDS = [
  'recitation', 'discussion', 'forum', 'participation',
  'attendance', 'feedback', 'survey', 'poll', 'evaluation',
  'seatwork', 'activity', 'handout', 'resource', 'hands-on',
  'assignment #', 'assignment no', 'pre-assignment', 'preassignment',
  'pre-act', 'preact', 'mid-act', 'midact', 'mid-assignment',
  'f-assignment', 'f-sw', 'prelim act', 'task', 'exercise',
  'group presentation', 'groupwork', 'group work'
];

// Helper function to check if activity should be included
function shouldIncludeActivity(activityName, activityType) {
  if (!activityName) return false;
  const lowerName = activityName.toLowerCase();
  for (const keyword of EXCLUDED_ACTIVITY_KEYWORDS) {
    if (lowerName.includes(keyword)) return false;
  }
  const isExam = ['exam', 'prelim', 'midterm', 'final', 'project'].some(keyword => lowerName.includes(keyword) && !lowerName.includes('group'));
  if (isExam) return true;
  return activityType === 'assign' || activityType === 'quiz';
}

// Parse due date
const parseDueDate = (text) => {
  if (!text) return null;
  const patterns = [
    { regex: /Due:\s*(\w+,\s*\d{1,2}\s+\w+\s+\d{4},\s*\d{1,2}:\d{2}\s*(?:AM|PM))/, parse: (d) => new Date(d) },
    { regex: /Due:\s*(\d{1,2}\/\d{1,2}\/\d{4})/, parse: (d) => new Date(d) },
    { regex: /(\d{1,2}\s+\w+\s+\d{4})/, parse: (d) => new Date(d) }
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern.regex);
    if (match) {
      try {
        const date = new Date(match[1]);
        if (!isNaN(date.getTime())) return date;
      } catch (e) {}
    }
  }
  return null;
};

// Calculate priority
const calculatePriority = (dueDate) => {
  if (!dueDate) return 'no_deadline';
  const now = new Date();
  const diffHours = (dueDate - now) / (1000 * 60 * 60);
  if (diffHours < 0) return 'past_due';
  if (diffHours < 24) return 'urgent';
  if (diffHours < 72) return 'high';
  if (diffHours < 168) return 'medium';
  return 'low';
};

// Extract course code
const extractCourseCode = (courseName) => {
  const patterns = [/[A-Z]{2,4}\s*\d{3,4}/i, /[A-Z]{2,4}-\d{3,4}/i, /[A-Z]{3,5}\d{3,4}/i];
  for (const pattern of patterns) {
    const match = courseName.match(pattern);
    if (match) return match[0].toUpperCase();
  }
  const words = courseName.split(' ');
  if (words.length >= 2) {
    const first = words[0].toUpperCase();
    const second = words[1].replace(/[^A-Z0-9]/g, '');
    if (first.length <= 5 && second.length <= 4) return `${first} ${second}`.trim();
  }
  return courseName.substring(0, 10).toUpperCase();
};

// Check completion status
function checkCompletionStatus(activityElement, $) {
  const completionButton = activityElement.find('.completion-dropdown button');
  if (completionButton.length > 0 && (completionButton.text().trim().includes('Done') || completionButton.text().trim().includes('Complete'))) return true;
  const completionInfo = activityElement.find('.completioninfo');
  if (completionInfo.length > 0 && (completionInfo.text().trim().includes('Complete') || completionInfo.text().trim().includes('Done'))) return true;
  if (activityElement.hasClass('completed')) return true;
  return false;
}

// Sync backlog
// Sync backlog from LMS (PRESERVE completed items)
const syncBacklog = async (req, res) => {
  try {
    const { email } = req.body;
    console.log(`🔄 Syncing backlog for: ${email}`);

    const session = userSessions.get(email);
    if (!session) return res.status(401).json({ error: 'Not logged in' });

    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Get existing completed items to preserve them
    const existingCompletedItems = await BacklogItem.find({
      userId: email,
      isCompleted: true
    });

    // Create a map of completed items by unique key
    const completedMap = new Map();
    for (const item of existingCompletedItems) {
      const key = `${item.courseId}_${item.activityId}`;
      completedMap.set(key, true);
    }

    const client = createLMSClient(session.cookies);
    const coursesResponse = await client.get('https://uphslms.com/my/courses.php');
    let $ = cheerio.load(coursesResponse.data);

    const courses = [];
    $('a[href*="course/view.php"]').each((i, el) => {
      const href = $(el).attr('href');
      const name = $(el).text().trim();
      if (href && name && !href.includes('login')) {
        if (EXCLUDED_COURSES.some(ex => name.toLowerCase().includes(ex))) return;
        courses.push({ id: href.split('=')[1] || i.toString(), name: name, url: href.startsWith('http') ? href : `https://uphslms.com${href}` });
      }
    });

    console.log(`Found ${courses.length} courses to scan`);
    const backlogItems = [];

    for (const course of courses) {
      try {
        const courseResponse = await client.get(course.url);
        $ = cheerio.load(courseResponse.data);
        const courseCode = extractCourseCode(course.name);

        $('li.activity').each((i, activity) => {
          const activityElement = $(activity);
          const activityLink = activityElement.find('.activityname a');
          const activityName = activityLink.text().trim();
          const activityHref = activityLink.attr('href');
          const activityClasses = activityElement.attr('class')?.split(' ') || [];
          let activityType = 'unknown';
          for (const cls of activityClasses) {
            if (cls.startsWith('modtype_')) {
              activityType = cls.replace('modtype_', '');
              break;
            }
          }
          if (!activityName) return;

          // Only include assignments and quizzes
          if (!shouldIncludeActivity(activityName, activityType)) return;

          let activityId = activityElement.attr('data-id');
          if (!activityId && activityHref) {
            const idMatch = activityHref.match(/id=(\d+)/);
            if (idMatch) activityId = idMatch[1];
          }
          if (!activityId) activityId = `${course.id}_${i}`;

          // Parse due date (optional - DON'T skip if missing)
          let dueDate = null;
          let dateText = '';
          activityElement.find('[data-region="activity-dates"] div').each((j, dateEl) => {
            const text = $(dateEl).text().trim();
            dateText += text;
          });
          const dueDateMatch = dateText.match(/Due:\s*(.+?)(?:\s*\||$)/i);
          if (dueDateMatch) dueDate = parseDueDate(dueDateMatch[1]);

          // Check if already completed in Moodle OR was completed by user
          const isAlreadyCompleted = checkCompletionStatus(activityElement, $);
          const key = `${course.id}_${activityId}`;
          const wasCompletedByUser = completedMap.has(key);

          // If completed in Moodle OR user marked it as completed, mark as completed
          const isCompleted = isAlreadyCompleted || wasCompletedByUser;

          // Calculate priority (handles null dueDate)
          const priority = calculatePriority(dueDate);

          const sectionElement = activityElement.closest('.section');
          const sectionName = sectionElement.find('.sectionname').text().trim();

          backlogItems.push({
            userId: email,
            courseId: course.id,
            courseName: course.name,
            courseCode: courseCode,
            activityId: activityId,
            activityName: activityName,
            activityType: activityType,
            dueDate: dueDate,  // Can be null for items without deadlines
            priority: priority,
            isCompleted: isCompleted,
            sectionName: sectionName,
            activityUrl: activityHref ? `https://uphslms.com${activityHref}` : null
          });
        });
      } catch (e) {
        console.log(`Error scanning ${course.name}:`, e.message);
      }
    }

    // Delete only the pending items (not completed ones) - BUT easier: delete all and re-add with preserved status
    await BacklogItem.deleteMany({ userId: email });
    if (backlogItems.length > 0) await BacklogItem.insertMany(backlogItems);

    const completedCount = backlogItems.filter(i => i.isCompleted).length;
    console.log(`✅ Synced ${backlogItems.length} backlog items (${completedCount} completed, ${backlogItems.length - completedCount} pending)`);

    res.json({ success: true, message: `Synced ${backlogItems.length} items`, count: backlogItems.length });
  } catch (err) {
    console.error('Sync backlog error:', err);
    res.status(500).json({ error: err.message });
  }
};
// Get backlog items
const getBacklogItems = async (req, res) => {
  try {
    const { email } = req.params;
    const { filterBy, priority, courseCode, showPinnedOnly, showCompleted } = req.query;

    let query = { userId: email };

    // If showCompleted is true, show all items (for stats)
    // Otherwise, only show non-completed items
    if (showCompleted !== 'true') {
      query.isCompleted = false;
      // Include ALL priority types - no filtering by priority here
      // The priority filter will handle specific selections
      query.priority = { $in: ['urgent', 'high', 'medium', 'low', 'no_deadline', 'past_due'] };
    }

    // Apply priority filter if specified and not 'all'
    if (priority && priority !== 'all') {
      query.priority = priority;
    }

    if (courseCode && courseCode !== 'all') query.courseCode = courseCode;
    if (showPinnedOnly === 'true') query.isPinned = true;
    if (filterBy === 'deadline') query.dueDate = { $exists: true, $ne: null };

    let items = await BacklogItem.find(query).sort({ dueDate: 1, priority: 1 });
    const courseCodes = await BacklogItem.distinct('courseCode', { userId: email });

    res.json({ success: true, items: items, filters: { courseCodes, priorities: ['urgent', 'high', 'medium', 'low', 'no_deadline', 'past_due'] } });
  } catch (err) {
    console.error('Get backlog items error:', err);
    res.status(500).json({ error: err.message });
  }
};

// FIXED: Mark item as completed - UPDATES COURSE ACTIVITY
const completeItem = async (req, res) => {
  try {
    const { itemId } = req.params;
    const { email } = req.body;

    const item = await BacklogItem.findOne({ _id: itemId, userId: email });
    if (!item) return res.status(404).json({ error: 'Item not found' });

    item.isCompleted = true;
    await item.save();

    const user = await User.findOne({ email });
    if (user) {
      let activityFound = false;
      for (let c = 0; c < user.courses.length; c++) {
        const course = user.courses[c];
        if (course.courseId === item.courseId) {
          for (let s = 0; s < course.sections.length; s++) {
            const section = course.sections[s];
            for (let a = 0; a < section.activities.length; a++) {
              const activity = section.activities[a];
              if (activity.id === item.activityId || activity.name === item.activityName) {
                activity.completionStatus = 'done';
                activity.lastSynced = new Date();
                activityFound = true;
                console.log(`✅ Updated course activity: ${activity.name}`);
                break;
              }
            }
            if (activityFound) break;
          }
          break;
        }
      }

      // Recalculate stats
      let totalQuizzes = 0, completedQuizzes = 0;
      let totalAssignments = 0, completedAssignments = 0;
      for (const c of user.courses) {
        if (EXCLUDED_COURSES.some(ex => c.courseName.toLowerCase().includes(ex))) continue;
        for (const s of c.sections) {
          for (const a of s.activities) {
            if (!shouldIncludeActivity(a.name, a.type)) continue;
            if (a.type === 'quiz') { totalQuizzes++; if (a.completionStatus === 'done') completedQuizzes++; }
            if (a.type === 'assign') { totalAssignments++; if (a.completionStatus === 'done') completedAssignments++; }
          }
        }
      }
      user.courseStats = { totalTasks: 0, completedTasks: 0, totalQuizzes, completedQuizzes, totalAssignments, completedAssignments, lastUpdated: new Date() };
      await user.save();
    }

    res.json({ success: true, message: 'Task marked as completed' });
  } catch (err) {
    console.error('Complete item error:', err);
    res.status(500).json({ error: err.message });
  }
};

const saveLayoutPreference = async (req, res) => {
  try {
    const { email, layoutMode } = req.body;
    await User.findOneAndUpdate({ email }, { 'preferences.backlogLayout': layoutMode }, { upsert: true });
    res.json({ success: true, layoutMode: layoutMode });
  } catch (err) {
    console.error('Save layout preference error:', err);
    res.status(500).json({ error: err.message });
  }
};

const getLayoutPreference = async (req, res) => {
  try {
    const { email } = req.params;
    const user = await User.findOne({ email });
    res.json({ success: true, layoutMode: user?.preferences?.backlogLayout || 'compact' });
  } catch (err) {
    console.error('Get layout preference error:', err);
    res.status(500).json({ error: err.message });
  }
};

const completeItemByActivity = async (req, res) => {
  try {
    const { email, courseId, activityId } = req.body;
    const item = await BacklogItem.findOne({ userId: email, courseId, activityId, isCompleted: false });
    if (!item) return res.json({ success: true, message: 'Item already completed or not found' });
    item.isCompleted = true;
    await item.save();
    res.json({ success: true, message: 'Backlog item marked as completed', itemId: item._id });
  } catch (err) {
    console.error('Complete item by activity error:', err);
    res.status(500).json({ error: err.message });
  }
};

const getBacklogItem = async (req, res) => {
  try {
    const { itemId } = req.params;
    const { email } = req.query;
    const item = await BacklogItem.findOne({ _id: itemId, userId: email });
    if (!item) return res.status(404).json({ error: 'Item not found' });
    res.json({ success: true, item: item });
  } catch (err) {
    console.error('Get backlog item error:', err);
    res.status(500).json({ error: err.message });
  }
};

const togglePin = async (req, res) => {
  try {
    const { itemId } = req.params;
    const { email } = req.body;

    const item = await BacklogItem.findOne({ _id: itemId, userId: email });
    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }

    item.isPinned = !item.isPinned;
    await item.save();

    res.json({
      success: true,
      isPinned: item.isPinned
    });

  } catch (err) {
    console.error('Toggle pin error:', err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = {
  syncBacklog,
  getBacklogItems,
  getBacklogItem,
  togglePin,
  completeItem,
  completeItemByActivity,
  saveLayoutPreference,
  getLayoutPreference
};