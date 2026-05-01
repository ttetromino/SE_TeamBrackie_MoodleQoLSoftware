// controllers/courseController.js
const User = require('../models/User');
const { createLMSClient, ensureValidSession } = require('../utils/lmsClient');
const { userSessions } = require('../utils/sessionStore');
const cheerio = require('cheerio');

// EXCLUDED COURSES (same as backlog)
const EXCLUDED_COURSES = [
  'B-Library', 'B-LIBRARY', 'Library', 'Binan - College E-library',
  'orientation', 'Orientation'
];

// EXCLUDED ACTIVITY KEYWORDS (same as backlog)
const EXCLUDED_ACTIVITY_KEYWORDS = [
  'recitation', 'discussion', 'forum', 'participation',
  'attendance', 'feedback', 'survey', 'poll', 'evaluation',
  'seatwork', 'activity', 'handout', 'resource', 'hands-on',
  'assignment #', 'assignment no', 'pre-assignment', 'preassignment',
  'pre-act', 'preact', 'mid-act', 'midact', 'mid-assignment',
  'f-assignment', 'f-sw', 'prelim act', 'task', 'exercise',
  'group presentation', 'groupwork', 'group work'
];

// Helper function to check if activity should be counted (SAME AS BACKLOG)
function shouldCountForStats(activityName, activityType) {
  if (!activityName) return false;

  const lowerName = activityName.toLowerCase();

  // Always count exams
  const isExam = ['exam', 'prelim', 'midterm', 'final', 'project'].some(keyword =>
    lowerName.includes(keyword) && !lowerName.includes('group')
  );
  if (isExam) return true;

  // Check for excluded keywords
  for (const keyword of EXCLUDED_ACTIVITY_KEYWORDS) {
    if (lowerName.includes(keyword)) {
      return false;
    }
  }

  // Only count assignments and quizzes
  return activityType === 'assign' || activityType === 'quiz';
}

// Parse due date from text
const parseDueDate = (dateText) => {
  if (!dateText) return null;
  const patterns = [
    { regex: /Due:\s*(\w+,\s*\d{1,2}\s+\w+\s+\d{4},\s*\d{1,2}:\d{2}\s*(?:AM|PM))/, parse: (d) => new Date(d) },
    { regex: /Due:\s*(\d{1,2}\/\d{1,2}\/\d{4})/, parse: (d) => new Date(d) },
    { regex: /(\d{1,2}\s+\w+\s+\d{4})/, parse: (d) => new Date(d) }
  ];
  for (const pattern of patterns) {
    const match = dateText.match(pattern.regex);
    if (match) {
      try {
        const date = new Date(match[1]);
        if (!isNaN(date.getTime())) return date;
      } catch (e) {}
    }
  }
  return null;
};

// Helper function to calculate stats (SAME FILTERING AS BACKLOG)
const calculateStats = (courses) => {
  let totalQuizzes = 0, completedQuizzes = 0;
  let totalAssignments = 0, completedAssignments = 0;

  for (const c of courses) {
    if (c.isArchived) continue;

    // Skip excluded courses
    const isExcludedCourse = EXCLUDED_COURSES.some(excluded =>
      c.courseName.toLowerCase().includes(excluded.toLowerCase())
    );
    if (isExcludedCourse) continue;

    for (const s of c.sections) {
      for (const a of s.activities) {
        // USE shouldCountForStats (correct function name) NOT shouldIncludeActivity
        if (!shouldCountForStats(a.name, a.type)) continue;

        const isDone = a.completionStatus === 'done';
        switch (a.type) {
          case 'assign':
            totalAssignments++;
            if (isDone) completedAssignments++;
            break;
          case 'quiz':
            totalQuizzes++;
            if (isDone) completedQuizzes++;
            break;
        }
      }
    }
  }

  return {
    totalTasks: 0,
    completedTasks: 0,
    totalQuizzes,
    completedQuizzes,
    totalAssignments,
    completedAssignments
  };
};

// Get stored courses from database
const getStoredCourses = async (req, res) => {
  try {
    const { email } = req.params;
    let user = await User.findOne({ email }).select('courses courseStats');
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Filter out archived and excluded courses
    const activeCourses = user.courses.filter(c => {
      if (c.isArchived) return false;
      const isExcluded = EXCLUDED_COURSES.some(excluded =>
        c.courseName.toLowerCase().includes(excluded.toLowerCase())
      );
      return !isExcluded;
    });

    // Recalculate stats using same filtering
    const freshStats = calculateStats(user.courses);
    user.courseStats = freshStats;
    await user.save();

    console.log(`📦 Returning ${activeCourses.length} courses for ${email}`);
    console.log(`📊 Stats - Quizzes: ${freshStats.completedQuizzes}/${freshStats.totalQuizzes}, Assignments: ${freshStats.completedAssignments}/${freshStats.totalAssignments}`);

    res.json({ success: true, courses: activeCourses, stats: freshStats, fromCache: true });
  } catch (error) {
    console.error('Get stored courses error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get single stored course
const getStoredCourse = async (req, res) => {
  try {
    const { email, courseId } = req.params;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    const course = user.courses.find(c => c.courseId === courseId);
    if (!course) return res.status(404).json({ error: 'Course not found' });
    res.json({ success: true, course: course, fromCache: true });
  } catch (error) {
    console.error('Get stored course error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get course contents from database
const getCourseContentsFromDB = async (req, res) => {
  try {
    const { email, courseId } = req.params;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    const course = user.courses.find(c => c.courseId === courseId);
    if (!course) return res.status(404).json({ error: 'Course not found' });
    res.json({ success: true, courseTitle: course.courseTitle, sections: course.sections, totalActivities: course.totalActivities, completedActivities: course.completedActivities, fromCache: true });
  } catch (error) {
    console.error('Get course contents error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Sync course to database
const syncCourseToDatabase = async (req, res) => {
  try {
    const { email, courseId, courseName, courseUrl, forceRefresh = false } = req.body;
    console.log(`🔄 Syncing course: ${courseName} for ${email}`);

    let session = userSessions.get(email);
    if (!session) {
      const user = await User.findOne({ email });
      if (user && user.lmsCookies && user.lmsCookies.length > 0) {
        session = { cookies: user.lmsCookies, timestamp: Date.now(), username: user.lmsUsername };
        userSessions.set(email, session);
      } else {
        return res.status(401).json({ error: 'Not logged in to LMS' });
      }
    }

    const client = createLMSClient(session.cookies);
    let user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const existingCourse = user.courses.find(c => c.courseId === courseId);
    if (existingCourse && !forceRefresh) {
      const hoursSinceSync = (Date.now() - new Date(existingCourse.lastSynced).getTime()) / (1000 * 60 * 60);
      if (hoursSinceSync < 24) {
        console.log(`📦 Using cached course data (${hoursSinceSync.toFixed(1)} hours old)`);
        return res.json({ success: true, cached: true, course: existingCourse });
      }
    }

    const sessionValid = await ensureValidSession(email, client, user);
    if (!sessionValid) return res.status(401).json({ error: 'LMS session expired' });

    const url = courseUrl.startsWith('http') ? courseUrl : `https://uphslms.com${courseUrl}`;
    const response = await client.get(url);
    const $ = cheerio.load(response.data);
    const courseTitle = $('h1').first().text().trim();
    const sections = [];
    let totalActivities = 0, completedActivities = 0;

    $('li.section.course-section.main').each((sectionIndex, section) => {
      const sectionElement = $(section);
      const sectionHeader = sectionElement.find('.sectionname a');
      const sectionName = sectionHeader.text().trim();
      const sectionId = sectionElement.attr('data-sectionid');
      const sectionNumber = sectionElement.attr('data-number');
      if (!sectionName) return;

      const activities = [];
      sectionElement.find('li.activity').each((activityIndex, activity) => {
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
        const activityId = activityElement.attr('data-id');
        const isIndented = activityElement.hasClass('indented');
        const activityBadge = activityElement.find('.activitybadge').text().trim();
        const completionButton = activityElement.find('.completion-dropdown button');
        let completionStatus = 'todo';
        if (completionButton.length > 0) {
          const buttonText = completionButton.text().trim();
          if (buttonText.includes('Done')) completionStatus = 'done';
        }
        const dates = [];
        let dueDate = null;
        activityElement.find('[data-region="activity-dates"] div').each((i, dateEl) => {
          const dateText = $(dateEl).text().trim();
          if (dateText) {
            dates.push(dateText);
            if (!dueDate) dueDate = parseDueDate(dateText);
          }
        });
        if (completionStatus === 'done') completedActivities++;
        totalActivities++;
        activities.push({
          id: activityId || `${sectionId}_${activityIndex}`,
          name: activityName || 'Unnamed Activity',
          type: activityType,
          url: activityHref ? (activityHref.startsWith('http') ? activityHref : `https://uphslms.com${activityHref}`) : null,
          icon: null,
          badge: activityBadge || null,
          isIndented: isIndented,
          completionStatus: completionStatus,
          dates: dates,
          dueDate: dueDate,
          sectionId: sectionId,
          lastSynced: new Date()
        });
      });

      if (activities.length > 0) {
        sections.push({
          id: sectionId,
          number: sectionNumber,
          name: sectionName,
          link: sectionHeader.attr('href') ? `https://uphslms.com${sectionHeader.attr('href')}` : null,
          activities: activities,
          lastSynced: new Date()
        });
      }
    });

    const courseData = {
      courseId: courseId,
      courseName: courseName,
      courseUrl: courseUrl,
      courseTitle: courseTitle,
      sections: sections,
      isArchived: false,
      lastAccessed: new Date(),
      lastSynced: new Date(),
      totalActivities: totalActivities,
      completedActivities: completedActivities
    };

    let retries = 3;
    let updated = false;
    while (retries > 0 && !updated) {
      try {
        user = await User.findOne({ email });
        const existingIndex = user.courses.findIndex(c => c.courseId === courseId);
        if (existingIndex >= 0) {
          user.courses[existingIndex] = { ...user.courses[existingIndex].toObject(), ...courseData };
        } else {
          user.courses.push(courseData);
        }
        const stats = calculateStats(user.courses);
        user.courseStats = { ...stats, lastUpdated: new Date() };
        await user.save();
        updated = true;
        console.log(`✅ Synced ${courseName}: ${totalActivities} activities, ${completedActivities} completed`);
      } catch (err) {
        if (err.name === 'VersionError') {
          retries--;
          await new Promise(resolve => setTimeout(resolve, 500));
        } else {
          throw err;
        }
      }
    }

    res.json({ success: true, cached: false, course: courseData, stats: user.courseStats });
  } catch (error) {
    console.error('Sync course error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Update activity completion
const updateActivityCompletion = async (req, res) => {
  try {
    const { email, courseId, activityId, isCompleted } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    const course = user.courses.find(c => c.courseId === courseId);
    if (!course) return res.status(404).json({ error: 'Course not found' });

    let activityFound = false;
    for (const section of course.sections) {
      const activity = section.activities.find(a => a.id === activityId);
      if (activity) {
        activity.completionStatus = isCompleted ? 'done' : 'todo';
        activity.lastSynced = new Date();
        activityFound = true;
        break;
      }
    }
    if (!activityFound) return res.status(404).json({ error: 'Activity not found' });

    const stats = calculateStats(user.courses);
    let totalActivities = 0, completedActivities = 0;
    for (const c of user.courses) {
      if (c.isArchived) continue;
      for (const s of c.sections) {
        for (const a of s.activities) {
          totalActivities++;
          if (a.completionStatus === 'done') completedActivities++;
        }
      }
    }
    if (course) {
      course.totalActivities = totalActivities;
      course.completedActivities = completedActivities;
    }
    user.courseStats = { ...stats, lastUpdated: new Date() };
    await user.save();

    res.json({ success: true, stats: user.courseStats, courseStats: { totalActivities: course?.totalActivities || 0, completedActivities: course?.completedActivities || 0 } });
  } catch (error) {
    console.error('Update activity error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get course stats
const getCourseStats = async (req, res) => {
  try {
    const { email } = req.params;
    const user = await User.findOne({ email }).select('courseStats');
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ success: true, stats: user.courseStats });
  } catch (error) {
    console.error('Get course stats error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Trigger background sync
const triggerBackgroundSync = async (req, res) => {
  try {
    const { email, courses } = req.body;
    console.log(`📡 Background sync triggered for ${email}`);
    res.json({ success: true, message: 'Background sync started' });
  } catch (error) {
    console.error('Trigger background sync error:', error);
    res.status(500).json({ error: error.message });
  }
};

const syncSingleCourseToDB = async (email, courseId, courseName, courseUrl) => {
  console.log(`🔄 Syncing single course: ${courseName}`);
  let session = userSessions.get(email);
  if (!session) {
    const user = await User.findOne({ email });
    if (user && user.lmsCookies && user.lmsCookies.length > 0) {
      session = { cookies: user.lmsCookies, timestamp: Date.now(), username: user.lmsUsername };
      userSessions.set(email, session);
    } else {
      throw new Error('Not logged in to LMS');
    }
  }
  const user = await User.findOne({ email });
  if (!user) throw new Error('User not found');
  const client = createLMSClient(session.cookies);
  const sessionValid = await ensureValidSession(email, client, user);
  if (!sessionValid) throw new Error('Session invalid');
  const url = courseUrl.startsWith('http') ? courseUrl : `https://uphslms.com${courseUrl}`;
  const response = await client.get(url);
  const $ = cheerio.load(response.data);
  const courseTitle = $('h1').first().text().trim();
  const sections = [];
  let totalActivities = 0, completedActivities = 0;
  $('li.section.course-section.main').each((sectionIndex, section) => {
    const sectionElement = $(section);
    const sectionHeader = sectionElement.find('.sectionname a');
    const sectionName = sectionHeader.text().trim();
    const sectionId = sectionElement.attr('data-sectionid');
    const sectionNumber = sectionElement.attr('data-number');
    if (!sectionName) return;
    const activities = [];
    sectionElement.find('li.activity').each((activityIndex, activity) => {
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
      const activityId = activityElement.attr('data-id');
      const isIndented = activityElement.hasClass('indented');
      const activityBadge = activityElement.find('.activitybadge').text().trim();
      const completionButton = activityElement.find('.completion-dropdown button');
      let completionStatus = 'todo';
      if (completionButton.length > 0) {
        const buttonText = completionButton.text().trim();
        if (buttonText.includes('Done')) completionStatus = 'done';
      }
      const dates = [];
      let dueDate = null;
      activityElement.find('[data-region="activity-dates"] div').each((i, dateEl) => {
        const dateText = $(dateEl).text().trim();
        if (dateText) {
          dates.push(dateText);
          if (!dueDate) dueDate = parseDueDate(dateText);
        }
      });
      if (completionStatus === 'done') completedActivities++;
      totalActivities++;
      activities.push({
        id: activityId || `${sectionId}_${activityIndex}`,
        name: activityName || 'Unnamed Activity',
        type: activityType,
        url: activityHref ? (activityHref.startsWith('http') ? activityHref : `https://uphslms.com${activityHref}`) : null,
        icon: null,
        badge: activityBadge || null,
        isIndented: isIndented,
        completionStatus: completionStatus,
        dates: dates,
        dueDate: dueDate,
        sectionId: sectionId,
        lastSynced: new Date()
      });
    });
    if (activities.length > 0) {
      sections.push({
        id: sectionId,
        number: sectionNumber,
        name: sectionName,
        link: sectionHeader.attr('href') ? `https://uphslms.com${sectionHeader.attr('href')}` : null,
        activities: activities,
        lastSynced: new Date()
      });
    }
  });
  const existingCourseIndex = user.courses.findIndex(c => c.courseId === courseId);
  const courseData = {
    courseId: courseId,
    courseName: courseName,
    courseUrl: courseUrl,
    courseTitle: courseTitle,
    sections: sections,
    isArchived: false,
    lastAccessed: new Date(),
    lastSynced: new Date(),
    totalActivities: totalActivities,
    completedActivities: completedActivities
  };
  if (existingCourseIndex >= 0) {
    user.courses[existingCourseIndex] = { ...user.courses[existingCourseIndex].toObject(), ...courseData };
  } else {
    user.courses.push(courseData);
  }
  await user.save();
  return { courseData, stats: { totalActivities, completedActivities } };
};

// Sync all courses
const syncAllCourses = async (req, res) => {
  try {
    const { email } = req.body;
    console.log(`🔄 Full sync triggered for ${email}`);

    let user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });

    let session = userSessions.get(email);

    // If no session in memory, try to restore from database or login fresh
    if (!session) {
      console.log('🔄 No session in memory, attempting to restore or login...');

      // Try to restore from database first
      if (user.lmsCookies && user.lmsCookies.length > 0) {
        session = {
          cookies: user.lmsCookies,
          timestamp: Date.now(),
          username: user.lmsUsername
        };
        userSessions.set(email, session);
      }

      // If still no session or cookies are invalid, login fresh
      if (!session || !user.lmsCookies || user.lmsCookies.length === 0) {
        console.log('🔄 No valid session found, logging in with stored credentials...');
        const client = createLMSClient();
        const loginUrl = 'https://uphslms.com/login/index.php';
        const loginPage = await client.get(loginUrl);
        let $ = cheerio.load(loginPage.data);
        const logintoken = $('input[name="logintoken"]').val();

        await client.post(loginUrl, new URLSearchParams({
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
          const cookies = await client.defaults.jar.getCookies('https://uphslms.com');
          const cookieStrings = cookies.map(c => c.cookieString());
          session = { cookies: cookieStrings, timestamp: Date.now(), username: user.lmsUsername };
          userSessions.set(email, session);
          await User.findOneAndUpdate({ email }, {
            lmsCookies: cookieStrings,
            lmsSessionExpiry: new Date(Date.now() + 24 * 60 * 60 * 1000),
            lmsLastLogin: new Date()
          });
          console.log('✅ Login successful, session created');
        } else {
          return res.status(401).json({ error: 'LMS login failed - invalid credentials' });
        }
      }
    }

    // Now proceed with syncing courses using the validated session
    const client = createLMSClient(session.cookies);

    // Also ensure session is valid before proceeding
    const sessionValid = await ensureValidSession(email, client, user);
    if (!sessionValid) {
      console.log('⚠️ Session validation failed, but continuing with existing session...');
    }

    const coursesResponse = await client.get('https://uphslms.com/my/courses.php');
    let $ = cheerio.load(coursesResponse.data);
    const courses = [];

    $('a[href*="course/view.php"]').each((i, el) => {
      const href = $(el).attr('href');
      const name = $(el).text().trim();
      if (href && name && !href.includes('login')) {
        courses.push({ id: href.split('=')[1] || i.toString(), name: name, url: href.startsWith('http') ? href : `https://uphslms.com${href}` });
      }
    });

    console.log(`📚 Found ${courses.length} courses to sync`);
    res.json({ success: true, message: `Syncing ${courses.length} courses...`, coursesCount: courses.length });

    const syncedCourses = [];
    for (let i = 0; i < courses.length; i++) {
      const course = courses[i];
      try {
        console.log(`📚 Syncing (${i + 1}/${courses.length}): ${course.name}`);
        const result = await syncSingleCourseToDB(email, course.id, course.name, course.url);
        syncedCourses.push(result.courseData);
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (e) {
        console.log(`❌ Failed to sync ${course.name}:`, e.message);
      }
    }

    const updatedUser = await User.findOne({ email });
    const stats = calculateStats(updatedUser.courses);
    updatedUser.courseStats = { ...stats, lastUpdated: new Date() };
    await updatedUser.save();

    console.log(`✅ Full sync completed: ${syncedCourses.length} courses synced`);
  } catch (error) {
    console.error('Sync all courses error:', error);
    if (!res.headersSent) res.status(500).json({ error: error.message });
  }
};

const syncCourseById = async (req, res) => {
  try {
    const { email, courseId, forceRefresh } = req.body;
    console.log(`🔄 Syncing course by ID: ${courseId} for ${email}`);
    res.json({ success: true, message: 'Course sync queued' });
  } catch (error) {
    console.error('Sync course by ID error:', error);
    res.status(500).json({ error: error.message });
  }
};

const updateActivityByUrl = async (req, res) => {
  try {
    let { email, courseId, activityUrl, isCompleted } = req.body;
    if (activityUrl) {
      activityUrl = activityUrl.replace(/https:\/\/uphslms\.comhttps:\/\/uphslms\.com/g, 'https://uphslms.com');
      activityUrl = activityUrl.replace(/https:\/\/uphslms\.comhttps:\/\//g, 'https://uphslms.com/');
      if (!activityUrl.startsWith('http')) activityUrl = `https://uphslms.com${activityUrl}`;
    }
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    const course = user.courses.find(c => c.courseId === courseId);
    if (!course) return res.status(404).json({ error: 'Course not found' });
    let activityFound = false;
    let matchedActivity = null;
    const getActivityIdFromUrl = (url) => url?.match(/id=(\d+)/)?.[1] || null;
    const requestActivityId = getActivityIdFromUrl(activityUrl);
    for (const section of course.sections) {
      for (const activity of section.activities) {
        const storedActivityId = getActivityIdFromUrl(activity.url);
        if ((requestActivityId && storedActivityId && requestActivityId === storedActivityId) || activity.url === activityUrl) {
          matchedActivity = activity;
          activityFound = true;
          break;
        }
      }
      if (activityFound) break;
    }
    if (!matchedActivity) return res.status(404).json({ error: 'Activity not found' });
    matchedActivity.completionStatus = isCompleted ? 'done' : 'todo';
    matchedActivity.lastSynced = new Date();
    const stats = calculateStats(user.courses);
    user.courseStats = { ...stats, lastUpdated: new Date() };
    await user.save();
    res.json({ success: true, stats: user.courseStats });
  } catch (error) {
    console.error('Update activity by URL error:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getStoredCourses,
  getStoredCourse,
  getCourseContentsFromDB,
  updateActivityCompletion,
  getCourseStats,
  triggerBackgroundSync,
  syncAllCourses,
  syncCourseToDatabase,
  syncCourseById,
  updateActivityByUrl,
  syncSingleCourseToDB
};