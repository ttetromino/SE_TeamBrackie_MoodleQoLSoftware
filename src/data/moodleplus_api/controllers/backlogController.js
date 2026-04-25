// controllers/backlogController.js
const BacklogItem = require('../models/BacklogItem');
const User = require('../models/User');
const { userSessions } = require('../utils/sessionStore');
const { createLMSClient } = require('../utils/lmsClient');
const cheerio = require('cheerio');

// Parse due date from activity text
const parseDueDate = (text) => {
  const patterns = [
    { regex: /Due:\s*(\d{1,2}\s+\w+\s+\d{4},\s*\d{1,2}:\d{2}\s*(?:AM|PM))/, format: 'MMMM D, YYYY, h:mm A' },
    { regex: /Due:\s*(\d{1,2}\/\d{1,2}\/\d{4})/, format: 'MM/DD/YYYY' },
    { regex: /(\d{1,2}\s+\w+\s+\d{4})/, format: 'D MMMM YYYY' },
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

// Calculate priority based on due date
const calculatePriority = (dueDate) => {
  if (!dueDate) return 'no_deadline';
  
  const now = new Date();
  const diffHours = (dueDate - now) / (1000 * 60 * 60);
  
  if (diffHours < 0) return 'urgent';
  if (diffHours < 24) return 'urgent';
  if (diffHours < 72) return 'high';
  if (diffHours < 168) return 'medium';
  return 'low';
};

// Extract course code from course name
const extractCourseCode = (courseName) => {
  const patterns = [
    /([A-Z]{2,4}\s*\d{3,4})/i,
    /([A-Z]{2,4}-\d{3,4})/i,
    /([A-Z]{3,5}\d{3,4})/i
  ];
  
  for (const pattern of patterns) {
    const match = courseName.match(pattern);
    if (match) return match[1].toUpperCase();
  }
  
  const words = courseName.split(' ');
  if (words.length >= 2) {
    const first = words[0].toUpperCase();
    const second = words[1].replace(/[^A-Z0-9]/g, '');
    if (first.length <= 5 && second.length <= 4) {
      return `${first} ${second}`.trim();
    }
  }
  
  return courseName.substring(0, 10).toUpperCase();
};

// Sync backlog from LMS
const syncBacklog = async (req, res) => {
  try {
    const { email } = req.body;
    console.log(`🔄 Syncing backlog for: ${email}`);
    
    const session = userSessions.get(email);
    if (!session) {
      return res.status(401).json({ error: 'Not logged in' });
    }
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const client = createLMSClient(session.cookies);
    
    // Get all courses
    const coursesResponse = await client.get('https://uphslms.com/my/courses.php');
    let $ = cheerio.load(coursesResponse.data);
    
    const courses = [];
    $('a[href*="course/view.php"]').each((i, el) => {
      const href = $(el).attr('href');
      const name = $(el).text().trim();
      if (href && name && !href.includes('login')) {
        courses.push({
          id: href.split('=')[1] || i.toString(),
          name: name,
          url: href.startsWith('http') ? href : `https://uphslms.com${href}`
        });
      }
    });
    
    console.log(`Found ${courses.length} courses to scan for backlog`);
    
    const backlogItems = [];
    
    // Scan each course for activities with due dates
    for (const course of courses) {
      try {
        const courseResponse = await client.get(course.url);
        $ = cheerio.load(courseResponse.data);
        
        const courseCode = extractCourseCode(course.name);
        
        // Find activities with due dates
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
          
          // Skip non-assignment types
          if (!['assign', 'quiz', 'forum'].includes(activityType)) return;
          
          // Extract due date
          let dueDate = null;
          let dateText = '';
          
          activityElement.find('[data-region="activity-dates"] div').each((j, dateEl) => {
            const text = $(dateEl).text().trim();
            dateText += text;
          });
          
          const dueDateMatch = dateText.match(/Due:\s*(.+?)(?:\s*\||$)/i);
          if (dueDateMatch) {
            dueDate = parseDueDate(dueDateMatch[1]);
          }
          
          if (!dueDate) return;
          
          // Check completion status
          const completionButton = activityElement.find('.completion-dropdown button');
          let isCompleted = false;
          if (completionButton.length > 0) {
            const buttonText = completionButton.text().trim();
            isCompleted = buttonText.includes('Done');
          }
          
          const priority = calculatePriority(dueDate);
          const sectionElement = activityElement.closest('.section');
          const sectionName = sectionElement.find('.sectionname').text().trim();
          
          backlogItems.push({
            userId: email,
            courseId: course.id,
            courseName: course.name,
            courseCode: courseCode,
            activityId: `${course.id}_${i}`,
            activityName: activityName,
            activityType: activityType,
            dueDate: dueDate,
            priority: priority,
            isCompleted: isCompleted,
            sectionName: sectionName,
            activityUrl: activityHref ? `https://uphslms.com${activityHref}` : null
          });
        });
      } catch (e) {
        console.log(`Error scanning course ${course.name}:`, e.message);
      }
    }
    
    // Update database - delete old and insert new
    await BacklogItem.deleteMany({ userId: email });
    if (backlogItems.length > 0) {
      await BacklogItem.insertMany(backlogItems);
    }
    
    console.log(`✅ Synced ${backlogItems.length} backlog items`);
    
    res.json({
      success: true,
      message: `Synced ${backlogItems.length} items`,
      count: backlogItems.length
    });
    
  } catch (err) {
    console.error('Sync backlog error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Get backlog items with filters
const getBacklogItems = async (req, res) => {
  try {
    const { email } = req.params;
    const { filterBy, priority, courseCode, showPinnedOnly } = req.query;
    
    let query = { userId: email, isCompleted: false };
    
    // US-13-T-02: Apply filters
    if (filterBy === 'deadline') {
      query.dueDate = { $exists: true, $ne: null };
    }
    
    if (priority && priority !== 'all') {
      query.priority = priority;
    }
    
    if (courseCode && courseCode !== 'all') {
      query.courseCode = courseCode;
    }
    
    if (showPinnedOnly === 'true') {
      query.isPinned = true;
    }
    
    let items = await BacklogItem.find(query).sort({ dueDate: 1, priority: 1 });
    
    // Custom sorting for deadline filter
    if (filterBy === 'deadline') {
      items = items.sort((a, b) => {
        if (!a.dueDate) return 1;
        if (!b.dueDate) return -1;
        return a.dueDate - b.dueDate;
      });
    }
    
    // Get unique course codes for filter
    const courseCodes = await BacklogItem.distinct('courseCode', { userId: email });
    
    res.json({
      success: true,
      items: items,
      filters: {
        courseCodes: courseCodes,
        priorities: ['urgent', 'high', 'medium', 'low', 'no_deadline']
      }
    });
    
  } catch (err) {
    console.error('Get backlog items error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Toggle pin status
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

// Mark item as completed
const completeItem = async (req, res) => {
  try {
    const { itemId } = req.params;
    const { email } = req.body;
    
    const item = await BacklogItem.findOne({ _id: itemId, userId: email });
    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }
    
    item.isCompleted = true;
    await item.save();
    
    res.json({
      success: true,
      message: 'Task marked as completed'
    });
    
  } catch (err) {
    console.error('Complete item error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Save layout preference
const saveLayoutPreference = async (req, res) => {
  try {
    const { email, layoutMode } = req.body;
    
    await User.findOneAndUpdate(
      { email },
      { 'preferences.backlogLayout': layoutMode },
      { upsert: true }
    );
    
    res.json({ success: true, layoutMode: layoutMode });
    
  } catch (err) {
    console.error('Save layout preference error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Get layout preference
const getLayoutPreference = async (req, res) => {
  try {
    const { email } = req.params;
    
    const user = await User.findOne({ email });
    const layoutMode = user?.preferences?.backlogLayout || 'compact';
    
    res.json({ success: true, layoutMode: layoutMode });
    
  } catch (err) {
    console.error('Get layout preference error:', err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = {
  syncBacklog,
  getBacklogItems,
  togglePin,
  completeItem,
  saveLayoutPreference,
  getLayoutPreference
};