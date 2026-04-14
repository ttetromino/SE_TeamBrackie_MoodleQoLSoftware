const axios = require('axios');
const cheerio = require('cheerio');
const { CookieJar } = require('tough-cookie');
const { wrapper } = require('axios-cookiejar-support');
const User = require('../models/User');

// Store user sessions
const userSessions = new Map();

// Create LMS client with cookie support
const createLMSClient = (cookies = []) => {
  const jar = new CookieJar();
  
  if (cookies.length > 0) {
    cookies.forEach(cookie => {
      try {
        jar.setCookieSync(cookie, 'https://uphslms.com');
      } catch (e) {
        console.error('Error setting cookie:', e.message);
      }
    });
  }

  return wrapper(axios.create({
    jar,
    withCredentials: true,
    maxRedirects: 5,
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9'
    }
  }));
};

// LMS Login
const lmsLogin = async (req, res) => {
  console.log('📥 LMS login for:', req.headers['x-user-id']);
  const { username, password } = req.body;
  const loginUrl = 'https://uphslms.com/login/index.php';

  try {
    const client = createLMSClient();

    // Get login page and extract token
    const loginPage = await client.get(loginUrl);
    const $ = cheerio.load(loginPage.data);
    const logintoken = $('input[name="logintoken"]').val();

    // Submit login form
    await client.post(loginUrl,
      new URLSearchParams({
        username, password,
        logintoken, anchor: ''
      }), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': 'https://uphslms.com/',
          'Referer': loginUrl
        }
      });

    // Verify dashboard access
    const dashboard = await client.get('https://uphslms.com/');

    if (!dashboard.data.includes('Log in')) {

      // US-06-T-01: Cookie Retrieval 

      // US-06-T-01: Cookie Retrieval

      // Get cookies from jar
      const cookies = await client.defaults.jar.getCookies('https://uphslms.com');
      const cookieStrings = cookies.map(c => c.cookieString());

      const sessionId = req.headers['x-user-id'];
      if (sessionId) {
        userSessions.set(sessionId, {
          cookies: cookieStrings,
          timestamp: Date.now()
        });
        
        // Also store in database for persistence
        try {
          await User.findOneAndUpdate(
            { email: sessionId },
            { 
              lmsCookies: cookieStrings,
              lmsSessionExpiry: new Date(Date.now() + 60 * 60 * 1000) // 1 hour
            }
          );
          console.log('Session stored in memory and database');
        } catch (dbError) {
          console.log('Failed to store cookies in database:', dbError.message);
        }
      }

      res.json({ success: true });
    } else {
      throw new Error('Login failed - still on login page');
    }

  } catch (error) {
    console.error('Login error:', error.message);
    res.status(500).json({ error: 'Login failed' });
  }
};

// Verify LMS Credentials (for signup)
const verifyLMSCredentials = async (req, res) => {
  console.log('🔍 Verifying LMS credentials');
  const { username, password } = req.body;

  try {
    const client = createLMSClient();

    // Get login page and extract token
    const loginPage = await client.get('https://uphslms.com/login/index.php');
    const $ = cheerio.load(loginPage.data);
    const logintoken = $('input[name="logintoken"]').val();

    // Submit login form
    await client.post('https://uphslms.com/login/index.php',
      new URLSearchParams({
        username, password,
        logintoken, anchor: ''
      }), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': 'https://uphslms.com/',
          'Referer': 'https://uphslms.com/login/index.php'
        }
      });

    // Verify dashboard access
    const dashboard = await client.get('https://uphslms.com/');

    if (!dashboard.data.includes('Log in')) {
      res.json({ success: true, message: 'LMS credentials verified' });
    } else {
      res.status(401).json({ success: false, error: 'Invalid LMS credentials' });
    }

  } catch (error) {
    console.error('Verification error:', error.message);
    res.status(500).json({ success: false, error: 'Verification failed' });
  }
};

// Auto Login LMS (check if session exists)
const autoLoginLMS = async (req, res) => {
  console.log('Auto-login for user:', req.body.userId);
  
  try {
    // First check in-memory session
    const session = userSessions.get(req.body.userId);
    if (session) {
      // Check if session is still valid
      const client = createLMSClient(session.cookies);
      try {
        const dashboard = await client.get('https://uphslms.com/');
        if (!dashboard.data.includes('Log in')) {
          console.log('Existing in-memory session still valid');
          return res.json({ success: true });
        }
      } catch (e) {
        console.log('In-memory session expired');
        userSessions.delete(req.body.userId);
      }
    }

    // If no in-memory session, try to restore from database
    console.log('🔄 Trying to restore session from database');
    const user = await User.findOne({ email: req.body.userId });
    
    if (user && user.lmsCookies && user.lmsCookies.length > 0) {
      // Check if session hasn't expired
      if (user.lmsSessionExpiry && new Date() < new Date(user.lmsSessionExpiry)) {
        // Try to use stored cookies
        const client = createLMSClient(user.lmsCookies);
        try {
          const dashboard = await client.get('https://uphslms.com/');
          if (!dashboard.data.includes('Log in')) {
            console.log('Restored session from database');
            
            // Restore to in-memory storage
            userSessions.set(req.body.userId, {
              cookies: user.lmsCookies,
              timestamp: Date.now()
            });
            
            return res.json({ success: true });
          }
        } catch (e) {
          console.log('Stored cookies expired');
        }
      }
    }

    // No valid session
    console.log('No valid session found');
    res.json({ success: false, message: 'No valid session' });
    
  } catch (error) {
    console.error('Auto-login error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

// Get Courses
const getCourses = async (req, res) => {
  try {
    const session = userSessions.get(req.body.userId);
    if (!session) {
      return res.status(401).json({ error: 'Not logged in' });
    }

    console.log('📚 Fetching courses...');
    const client = createLMSClient(session.cookies);
    const response = await client.get('https://uphslms.com/my/courses.php');

    const $ = cheerio.load(response.data);
    const courses = [];

    $('a[href*="course/view.php"]').each((i, el) => {
      const href = $(el).attr('href');
      const name = $(el).text().trim();
      if (href && name && !href.includes('login')) {
        courses.push({
          name,
          link: href.startsWith('http') ? href : `https://uphslms.com${href}`,
          id: href.split('=')[1] || i
        });
      }
    });

    console.log(`📊 Found ${courses.length} courses`);
    res.json({ courses });

  } catch (error) {
    console.error('Get courses error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

// Get Course Contents (Sections and Activities) - REPLACES getCourseFiles
const getCourseContents = async (req, res) => {
  try {
    const session = userSessions.get(req.body.userId);
    if (!session) {
      return res.status(401).json({ error: 'Not logged in' });
    }

    const url = req.body.courseUrl.startsWith('http')
      ? req.body.courseUrl
      : `https://uphslms.com${req.body.courseUrl}`;

    console.log('📚 Fetching course contents from:', url);
    const client = createLMSClient(session.cookies);
    const response = await client.get(url);

    const $ = cheerio.load(response.data);
    const courseContents = [];

    // Get course title
    const courseTitle = $('h1').first().text().trim();
    console.log('📖 Course:', courseTitle);

    // US-06-T-02: Data Scrape Script 

    // US-06-T-02: Data Scrape Script

    // Extract sections
    $('li.section.course-section.main').each((sectionIndex, section) => {
      const sectionElement = $(section);
      
      // Get section name and link
      const sectionHeader = sectionElement.find('.sectionname a');
      const sectionName = sectionHeader.text().trim();
      const sectionLink = sectionHeader.attr('href');
      
      // Get section ID from data-sectionid
      const sectionId = sectionElement.attr('data-sectionid');
      
      // Get section number
      const sectionNumber = sectionElement.attr('data-number');
      
      // Create section object
      const sectionData = {
        id: sectionId,
        number: sectionNumber,
        name: sectionName,
        link: sectionLink ? (sectionLink.startsWith('http') ? sectionLink : `https://uphslms.com${sectionLink}`) : null,
        activities: []
      };

      // Extract activities within this section
      sectionElement.find('li.activity').each((activityIndex, activity) => {
        const activityElement = $(activity);
        
        // Get activity name and link
        const activityLink = activityElement.find('.activityname a');
        const activityName = activityLink.text().trim();
        const activityHref = activityLink.attr('href');
        
        // Get activity type from class (modtype_forum, modtype_assign, etc.)
        const activityClasses = activityElement.attr('class').split(' ');
        let activityType = 'unknown';
        for (const cls of activityClasses) {
          if (cls.startsWith('modtype_')) {
            activityType = cls.replace('modtype_', '');
            break;
          }
        }

        // Get activity icon
        const activityIcon = activityElement.find('.activityicon').attr('src');
        
        // Get activity ID from data-id
        const activityId = activityElement.attr('data-id');
        
        // Check if activity is indented
        const isIndented = activityElement.hasClass('indented');
        
        // Get activity badge (PDF, HTML, etc.)
        const activityBadge = activityElement.find('.activitybadge').text().trim();
        
        // Get completion status
        const completionButton = activityElement.find('.completion-dropdown button');
        let completionStatus = 'unknown';
        if (completionButton.length > 0) {
          const buttonText = completionButton.text().trim();
          if (buttonText.includes('Done')) {
            completionStatus = 'done';
          } else if (buttonText.includes('To do')) {
            completionStatus = 'todo';
          }
        }

        // Get dates (for assignments)
        const dates = [];
        activityElement.find('[data-region="activity-dates"] div').each((i, dateEl) => {
          const dateText = $(dateEl).text().trim();
          if (dateText) {
            dates.push(dateText);
          }
        });

        // Create activity object
        const activityData = {
          id: activityId,
          name: activityName || 'Unnamed Activity',
          type: activityType,
          url: activityHref ? (activityHref.startsWith('http') ? activityHref : `https://uphslms.com${activityHref}`) : null,
          icon: activityIcon || null,
          badge: activityBadge || null,
          isIndented: isIndented,
          completionStatus: completionStatus,
          dates: dates
        };

        sectionData.activities.push(activityData);
      });

      // Only add section if it has a name
      if (sectionName) {
        courseContents.push(sectionData);
      }
    });

    console.log(`Found ${courseContents.length} sections with total ${courseContents.reduce((acc, section) => acc + section.activities.length, 0)} activities`);

    res.json({
      courseTitle,
      sections: courseContents
    });

  } catch (error) {
    console.error('Get course contents error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

// Cleanup old sessions (run every hour)
setInterval(() => {
  const oneHour = 3600000;
  for (const [id, session] of userSessions.entries()) {
    if (Date.now() - session.timestamp > oneHour) {
      userSessions.delete(id);
      console.log('Removed expired session for user:', id);
    }
  }
}, 3600000);

module.exports = {
  lmsLogin,
  verifyLMSCredentials,
  autoLoginLMS,
  getCourses,
  getCourseContents 
};
