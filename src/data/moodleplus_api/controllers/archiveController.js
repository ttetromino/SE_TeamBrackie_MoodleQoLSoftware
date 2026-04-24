// controllers/archiveController.js
const User = require('../models/User');
const { userSessions } = require('../utils/sessionStore');
const { createLMSClient } = require('../utils/lmsClient');
const cheerio = require('cheerio');

// US-04-T-02: Archive course - move from active to archive
const archiveCourse = async (req, res) => {
  try {
    const { email, courseId, courseName, courseUrl } = req.body;
    
    console.log(`📦 Archiving course: ${courseName} for user: ${email}`);
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Check if course is already archived
    const alreadyArchived = user.archivedCourses.some(c => c.courseId === courseId);
    if (alreadyArchived) {
      return res.status(400).json({ error: 'Course already archived' });
    }
    
    // Get full course contents before archiving
    const session = userSessions.get(email);
    let courseContents = null;
    
    if (session) {
      try {
        const client = createLMSClient(session.cookies);
        const url = courseUrl.startsWith('http') 
          ? courseUrl 
          : `https://uphslms.com${courseUrl}`;
        
        const response = await client.get(url);
        const $ = cheerio.load(response.data);
        
        // Extract course contents
        const sections = [];
        $('li.section.course-section.main').each((sectionIndex, section) => {
          const sectionElement = $(section);
          const sectionHeader = sectionElement.find('.sectionname a');
          const sectionName = sectionHeader.text().trim();
          const sectionId = sectionElement.attr('data-sectionid');
          const sectionNumber = sectionElement.attr('data-number');
          
          const activities = [];
          sectionElement.find('li.activity').each((activityIndex, activity) => {
            const activityElement = $(activity);
            const activityLink = activityElement.find('.activityname a');
            const activityName = activityLink.text().trim();
            const activityHref = activityLink.attr('href');
            
            const activityClasses = activityElement.attr('class').split(' ');
            let activityType = 'unknown';
            for (const cls of activityClasses) {
              if (cls.startsWith('modtype_')) {
                activityType = cls.replace('modtype_', '');
                break;
              }
            }
            
            const activityIcon = activityElement.find('.activityicon').attr('src');
            const activityId = activityElement.attr('data-id');
            const isIndented = activityElement.hasClass('indented');
            const activityBadge = activityElement.find('.activitybadge').text().trim();
            
            const completionButton = activityElement.find('.completion-dropdown button');
            let completionStatus = 'unknown';
            if (completionButton.length > 0) {
              const buttonText = completionButton.text().trim();
              if (buttonText.includes('Done')) completionStatus = 'done';
              else if (buttonText.includes('To do')) completionStatus = 'todo';
            }
            
            const dates = [];
            activityElement.find('[data-region="activity-dates"] div').each((i, dateEl) => {
              const dateText = $(dateEl).text().trim();
              if (dateText) dates.push(dateText);
            });
            
            activities.push({
              id: activityId,
              name: activityName || 'Unnamed Activity',
              type: activityType,
              url: activityHref ? (activityHref.startsWith('http') ? activityHref : `https://uphslms.com${activityHref}`) : null,
              icon: activityIcon || null,
              badge: activityBadge || null,
              isIndented: isIndented,
              completionStatus: completionStatus,
              dates: dates
            });
          });
          
          if (sectionName) {
            sections.push({
              id: sectionId,
              number: sectionNumber,
              name: sectionName,
              link: sectionHeader.attr('href') ? `https://uphslms.com${sectionHeader.attr('href')}` : null,
              activities: activities
            });
          }
        });
        
        const courseTitle = $('h1').first().text().trim();
        
        courseContents = {
          courseTitle: courseTitle || courseName,
          sections: sections,
          totalActivities: sections.reduce((acc, s) => acc + s.activities.length, 0),
          completedActivities: sections.reduce((acc, s) => 
            acc + s.activities.filter(a => a.completionStatus === 'done').length, 0)
        };
      } catch (e) {
        console.log('Error fetching course contents for archive:', e.message);
        courseContents = {
          courseTitle: courseName,
          sections: [],
          totalActivities: 0,
          completedActivities: 0
        };
      }
    } else {
      courseContents = {
        courseTitle: courseName,
        sections: [],
        totalActivities: 0,
        completedActivities: 0
      };
    }
    
    // Add to archived courses
    user.archivedCourses.push({
      courseId: courseId,
      courseName: courseName,
      courseUrl: courseUrl,
      archivedAt: new Date(),
      contents: courseContents,
      thumbnail: null,
      metadata: {
        originalEnrollmentDate: new Date(),
        lastAccessed: new Date(),
        totalActivities: courseContents.totalActivities,
        completedActivities: courseContents.completedActivities
      }
    });
    
    await user.save();
    
    console.log(`✅ Course archived: ${courseName}`);
    res.json({ 
      success: true, 
      message: 'Course archived successfully',
      archivedCourse: user.archivedCourses[user.archivedCourses.length - 1]
    });
    
  } catch (err) {
    console.error('Archive course error:', err);
    res.status(500).json({ error: err.message });
  }
};

// US-04-T-04: Get all archived courses
const getArchivedCourses = async (req, res) => {
  try {
    const { email } = req.params;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Return archived courses sorted by archived date (newest first)
    const archivedCourses = user.archivedCourses.sort((a, b) => 
      b.archivedAt - a.archivedAt
    );
    
    res.json({ 
      success: true,
      archivedCourses: archivedCourses
    });
    
  } catch (err) {
    console.error('Get archived courses error:', err);
    res.status(500).json({ error: err.message });
  }
};

// US-04-T-04: Get single archived course details
const getArchivedCourseDetails = async (req, res) => {
  try {
    const { email, courseId } = req.params;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const archivedCourse = user.archivedCourses.find(c => c.courseId === courseId);
    if (!archivedCourse) {
      return res.status(404).json({ error: 'Archived course not found' });
    }
    
    res.json({ 
      success: true,
      archivedCourse: archivedCourse
    });
    
  } catch (err) {
    console.error('Get archived course details error:', err);
    res.status(500).json({ error: err.message });
  }
};

// US-04-T-04: Restore course from archive
const restoreArchivedCourse = async (req, res) => {
  try {
    const { email, courseId } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const archivedIndex = user.archivedCourses.findIndex(c => c.courseId === courseId);
    if (archivedIndex === -1) {
      return res.status(404).json({ error: 'Archived course not found' });
    }
    
    // Remove from archived
    const restoredCourse = user.archivedCourses[archivedIndex];
    user.archivedCourses.splice(archivedIndex, 1);
    
    await user.save();
    
    console.log(`🔄 Course restored from archive: ${restoredCourse.courseName}`);
    res.json({ 
      success: true, 
      message: 'Course restored successfully',
      restoredCourse: restoredCourse
    });
    
  } catch (err) {
    console.error('Restore archived course error:', err);
    res.status(500).json({ error: err.message });
  }
};

// US-04-T-02: Delete archived course permanently
const deleteArchivedCourse = async (req, res) => {
  try {
    const { email, courseId } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const archivedIndex = user.archivedCourses.findIndex(c => c.courseId === courseId);
    if (archivedIndex === -1) {
      return res.status(404).json({ error: 'Archived course not found' });
    }
    
    const deletedCourse = user.archivedCourses[archivedIndex];
    user.archivedCourses.splice(archivedIndex, 1);
    
    await user.save();
    
    console.log(`🗑️ Archived course permanently deleted: ${deletedCourse.courseName}`);
    res.json({ 
      success: true, 
      message: 'Archived course deleted permanently'
    });
    
  } catch (err) {
    console.error('Delete archived course error:', err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = {
  archiveCourse,
  getArchivedCourses,
  getArchivedCourseDetails,
  restoreArchivedCourse,
  deleteArchivedCourse
};