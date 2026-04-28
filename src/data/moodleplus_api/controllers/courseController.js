// controllers/courseController.js
const User = require('../models/User');
const { createLMSClient, ensureValidSession } = require('../utils/lmsClient');
const { userSessions } = require('../utils/sessionStore');
const cheerio = require('cheerio');

// Add this constant at the top of the file
const EXCLUDED_COURSES = ['B-Library', 'B-LIBRARY', 'Library', 'Binan - College E-library'];

// Parse due date from text
const parseDueDate = (dateText) => {
  if (!dateText) return null;

  const patterns = [
    { regex: /Due:\s*(\w+,\s*\d{1,2}\s+\w+\s+\d{4},\s*\d{1,2}:\d{2}\s*(?:AM|PM))/, parse: (d) => new Date(d) },
    { regex: /Due:\s*(\d{1,2}\/\d{1,2}\/\d{4})/, parse: (d) => new Date(d) },
    { regex: /Closed:\s*(\w+,\s*\d{1,2}\s+\w+\s+\d{4},\s*\d{1,2}:\d{2}\s*(?:AM|PM))/, parse: (d) => new Date(d) }
  ];

  for (const pattern of patterns) {
    const match = dateText.match(pattern.regex);
    if (match) {
      const parsed = pattern.parse(match[1]);
      if (!isNaN(parsed.getTime())) return parsed;
    }
  }
  return null;
};

// Helper function to calculate stats (reusable)
const calculateStats = (courses) => {
  let totalTasks = 0, completedTasks = 0;
  let totalQuizzes = 0, completedQuizzes = 0;
  let totalAssignments = 0, completedAssignments = 0;

  for (const c of courses) {
    // Skip archived courses
    if (c.isArchived) continue;

    // Check if course should be excluded from progress tracker
    const isExcluded = EXCLUDED_COURSES.some(excluded =>
      c.courseName.toLowerCase().includes(excluded.toLowerCase())
    );
    if (isExcluded) {
      continue;
    }

    for (const s of c.sections) {
      for (const a of s.activities) {
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
          default:
            // Only count actual learning activities, not forum posts or resources
            if (a.type !== 'forum' && a.type !== 'resource' && a.type !== 'url') {
              totalTasks++;
              if (isDone) completedTasks++;
            }
        }
      }
    }
  }

  return {
    totalTasks, completedTasks,
    totalQuizzes, completedQuizzes,
    totalAssignments, completedAssignments
  };
};

// Get stored courses from database
const getStoredCourses = async (req, res) => {
  try {
    const { email } = req.params;

    const user = await User.findOne({ email }).select('courses courseStats');
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Filter out archived courses
    const activeCourses = user.courses.filter(c => !c.isArchived);

    console.log(`📦 Returning ${activeCourses.length} cached courses for ${email}`);

    res.json({
      success: true,
      courses: activeCourses,
      stats: user.courseStats || {
        totalTasks: 0, completedTasks: 0,
        totalQuizzes: 0, completedQuizzes: 0,
        totalAssignments: 0, completedAssignments: 0,
        lastUpdated: null
      },
      fromCache: true
    });

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

    res.json({
      success: true,
      courseTitle: course.courseTitle,
      sections: course.sections,
      totalActivities: course.totalActivities,
      completedActivities: course.completedActivities,
      fromCache: true
    });

  } catch (error) {
    console.error('Get course contents error:', error);
    res.status(500).json({ error: error.message });
  }
};

const syncCourseToDatabase = async (req, res) => {
  try {
    const { email, courseId, courseName, courseUrl, forceRefresh = false } = req.body;

    console.log(`🔄 Syncing course: ${courseName} for ${email}`);

    // Get session
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

    // Get user once
    let user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Check if we have recent cached data
    const existingCourse = user.courses.find(c => c.courseId === courseId);
    if (existingCourse && !forceRefresh) {
      const hoursSinceSync = (Date.now() - new Date(existingCourse.lastSynced).getTime()) / (1000 * 60 * 60);
      if (hoursSinceSync < 24) {
        console.log(`📦 Using cached course data (${hoursSinceSync.toFixed(1)} hours old)`);
        return res.json({ success: true, cached: true, course: existingCourse });
      }
    }

    // Ensure valid session
    const sessionValid = await ensureValidSession(email, client, user);
    if (!sessionValid) {
      return res.status(401).json({ error: 'LMS session expired. Please login again.' });
    }

    const url = courseUrl.startsWith('http') ? courseUrl : `https://uphslms.com${courseUrl}`;
    const response = await client.get(url);
    const $ = cheerio.load(response.data);

    const courseTitle = $('h1').first().text().trim();
    const sections = [];
    let totalActivities = 0;
    let completedActivities = 0;

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

    // Prepare course data
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

    // Update user
    let retries = 3;
    let updated = false;

    while (retries > 0 && !updated) {
      try {
        // Get fresh user document
        user = await User.findOne({ email });

        // Find index of existing course
        const existingIndex = user.courses.findIndex(c => c.courseId === courseId);

        if (existingIndex >= 0) {
          // Update existing course
          user.courses[existingIndex] = { ...user.courses[existingIndex].toObject(), ...courseData };
        } else {
          // Add new course
          user.courses.push(courseData);
        }

        // Calculate stats using the helper function
        const stats = calculateStats(user.courses);

        user.courseStats = {
          ...stats,
          lastUpdated: new Date()
        };

        // Save with version check
        await user.save();
        updated = true;

        console.log(`✅ Synced ${courseName}: ${totalActivities} activities, ${completedActivities} completed`);

      } catch (err) {
        if (err.name === 'VersionError') {
          retries--;
          console.log(`⚠️ Version conflict for ${courseName}, retrying... (${retries} left)`);
          await new Promise(resolve => setTimeout(resolve, 500));
        } else {
          throw err;
        }
      }
    }

    if (!updated) {
      throw new Error('Failed to sync after multiple retries');
    }

    res.json({
      success: true,
      cached: false,
      course: courseData,
      stats: user.courseStats
    });

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

    // Find and update activity
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

    // Recalculate stats using helper function
    const stats = calculateStats(user.courses);

    // Update course totals
    let totalActivities = 0;
    let completedActivities = 0;

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

    user.courseStats = {
      ...stats,
      lastUpdated: new Date()
    };

    await user.save();

    res.json({
      success: true,
      stats: user.courseStats,
      courseStats: {
        totalActivities: course?.totalActivities || 0,
        completedActivities: course?.completedActivities || 0
      }
    });

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

  // Ensure valid session
  const sessionValid = await ensureValidSession(email, client, user);
  if (!sessionValid) {
    throw new Error('Session invalid');
  }

  const url = courseUrl.startsWith('http') ? courseUrl : `https://uphslms.com${courseUrl}`;
  const response = await client.get(url);
  const $ = cheerio.load(response.data);

  const courseTitle = $('h1').first().text().trim();
  const sections = [];
  let totalActivities = 0;
  let completedActivities = 0;

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

  // Update or add course
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

  console.log(`✅ Synced ${courseName}: ${totalActivities} activities, ${completedActivities} completed`);

  return { courseData, stats: { totalActivities, completedActivities } };
};

// Sync all courses (initial full sync)
const syncAllCourses = async (req, res) => {
  try {
    const { email } = req.body;

    console.log(`🔄 Full sync triggered for ${email}`);

    // Get user
    let user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Get or create session
    let session = userSessions.get(email);
    if (!session) {
      // Try to login with stored credentials
      if (user.lmsUsername && user.lmsPassword) {
        console.log('🔄 Logging in with stored credentials...');

        const client = createLMSClient();
        const loginUrl = 'https://uphslms.com/login/index.php';

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
          const cookies = await client.defaults.jar.getCookies('https://uphslms.com');
          const cookieStrings = cookies.map(c => c.cookieString());

          session = {
            cookies: cookieStrings,
            timestamp: Date.now(),
            username: user.lmsUsername
          };
          userSessions.set(email, session);

          // Update user with cookies
          await User.findOneAndUpdate(
            { email },
            {
              lmsCookies: cookieStrings,
              lmsSessionExpiry: new Date(Date.now() + 24 * 60 * 60 * 1000),
              lmsLastLogin: new Date()
            }
          );
          console.log('✅ Login successful, session created');
        } else {
          console.log('❌ Login failed');
          return res.status(401).json({ error: 'LMS login failed. Please check your credentials.' });
        }
      } else {
        return res.status(401).json({ error: 'No LMS credentials found. Please login first.' });
      }
    }

    const client = createLMSClient(session.cookies);

    // Get all courses from LMS
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

    console.log(`📚 Found ${courses.length} courses to sync`);

    // Send immediate response that sync started
    res.json({
      success: true,
      message: `Syncing ${courses.length} courses. This may take a minute...`,
      coursesCount: courses.length
    });

    // Sync each course and SAVE to database
    const syncedCourses = [];

    for (let i = 0; i < courses.length; i++) {
      const course = courses[i];
      try {
        console.log(`📚 Syncing (${i + 1}/${courses.length}): ${course.name}`);

        // Sync the course
        const result = await syncSingleCourseToDB(email, course.id, course.name, course.url);
        syncedCourses.push(result.courseData);

        // Add delay between syncs
        await new Promise(resolve => setTimeout(resolve, 2000));

      } catch (e) {
        console.log(`❌ Failed to sync ${course.name}:`, e.message);
      }
    }

    // Get updated user with all synced courses
    const updatedUser = await User.findOne({ email });

    // Recalculate all stats
    const EXCLUDED_COURSES = ['B-Library', 'B-LIBRARY', 'Library', 'Binan - College E-library'];
    let totalTasks = 0, completedTasks = 0;
    let totalQuizzes = 0, completedQuizzes = 0;
    let totalAssignments = 0, completedAssignments = 0;

    for (const c of updatedUser.courses) {
      if (c.isArchived) continue;

      const isExcluded = EXCLUDED_COURSES.some(excluded =>
        c.courseName.toLowerCase().includes(excluded.toLowerCase())
      );
      if (isExcluded) continue;

      for (const s of c.sections) {
        for (const a of s.activities) {
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
            default:
              if (a.type !== 'forum' && a.type !== 'resource' && a.type !== 'url') {
                totalTasks++;
                if (isDone) completedTasks++;
              }
          }
        }
      }
    }

    updatedUser.courseStats = {
      totalTasks, completedTasks,
      totalQuizzes, completedQuizzes,
      totalAssignments, completedAssignments,
      lastUpdated: new Date()
    };

    await updatedUser.save();

    console.log(`✅ Full sync completed: ${syncedCourses.length} courses synced`);
    console.log(`📊 Stats - Tasks: ${completedTasks}/${totalTasks}, Quizzes: ${completedQuizzes}/${totalQuizzes}, Assignments: ${completedAssignments}/${totalAssignments}`);

  } catch (error) {
    console.error('Sync all courses error:', error);
    // Don't send error response if already sent
    if (!res.headersSent) {
      res.status(500).json({ error: error.message });
    }
  }
};

const syncCourseById = async (req, res) => {
  try {
    const { email, courseId, forceRefresh } = req.body;
    console.log(`🔄 Syncing course by ID: ${courseId} for ${email}`);

    res.json({
      success: true,
      message: 'Course sync queued'
    });
  } catch (error) {
    console.error('Sync course by ID error:', error);
    res.status(500).json({ error: error.message });
  }
};

const updateActivityByUrl = async (req, res) => {
  try {
    let { email, courseId, activityUrl, isCompleted } = req.body;

    // Clean the URL - remove any duplicate https prefixes
    if (activityUrl) {
      // Remove duplicate https://
      activityUrl = activityUrl.replace(/https:\/\/uphslms\.comhttps:\/\/uphslms\.com/g, 'https://uphslms.com');
      activityUrl = activityUrl.replace(/https:\/\/uphslms\.comhttps:\/\//g, 'https://uphslms.com/');
      // Also handle relative paths
      if (!activityUrl.startsWith('http')) {
        activityUrl = `https://uphslms.com${activityUrl}`;
      }
    }

    console.log(`🔍 Looking for activity by URL: ${activityUrl}`);

    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const course = user.courses.find(c => c.courseId === courseId);
    if (!course) return res.status(404).json({ error: 'Course not found' });

    // Find activity by URL - try multiple matching strategies
    let activityFound = false;
    let matchedActivity = null;

    for (const section of course.sections) {
      for (const activity of section.activities) {
        // Extract ID from URLs for comparison
        const getActivityIdFromUrl = (url) => {
          const match = url?.match(/id=(\d+)/);
          return match ? match[1] : null;
        };

        const requestActivityId = getActivityIdFromUrl(activityUrl);
        const storedActivityId = getActivityIdFromUrl(activity.url);

        // Match by ID if both have IDs
        if (requestActivityId && storedActivityId && requestActivityId === storedActivityId) {
          matchedActivity = activity;
          activityFound = true;
          break;
        }

        // Also try direct URL match
        if (activity.url === activityUrl ||
            activity.url?.includes(`id=${getActivityIdFromUrl(activityUrl)}`)) {
          matchedActivity = activity;
          activityFound = true;
          break;
        }
      }
      if (activityFound) break;
    }

    if (!activityFound || !matchedActivity) {
      console.log(`⚠️ Activity not found for URL: ${activityUrl}`);
      return res.status(404).json({ error: 'Activity not found' });
    }

    matchedActivity.completionStatus = isCompleted ? 'done' : 'todo';
    matchedActivity.lastSynced = new Date();

    console.log(`✅ Found and updated activity: ${matchedActivity.name}`);

    // Recalculate stats (same as before)
    const EXCLUDED_COURSES = ['B-Library', 'B-LIBRARY', 'Library', 'Binan - College E-library'];

    let totalTasks = 0, completedTasks = 0;
    let totalQuizzes = 0, completedQuizzes = 0;
    let totalAssignments = 0, completedAssignments = 0;

    for (const c of user.courses) {
      if (c.isArchived) continue;

      const isExcluded = EXCLUDED_COURSES.some(excluded =>
        c.courseName.toLowerCase().includes(excluded.toLowerCase())
      );
      if (isExcluded) continue;

      for (const s of c.sections) {
        for (const a of s.activities) {
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
            default:
              if (a.type !== 'forum' && a.type !== 'resource' && a.type !== 'url') {
                totalTasks++;
                if (isDone) completedTasks++;
              }
          }
        }
      }
    }

    user.courseStats = {
      totalTasks, completedTasks,
      totalQuizzes, completedQuizzes,
      totalAssignments, completedAssignments,
      lastUpdated: new Date()
    };

    await user.save();

    res.json({
      success: true,
      stats: user.courseStats
    });

  } catch (error) {
    console.error('Update activity by URL error:', error);
    res.status(500).json({ error: error.message });
  }
};

// Export all functions
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