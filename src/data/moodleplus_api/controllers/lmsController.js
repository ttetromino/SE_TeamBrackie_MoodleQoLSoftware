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

    const loginPage = await client.get(loginUrl);
    const $ = cheerio.load(loginPage.data);
    const logintoken = $('input[name="logintoken"]').val();

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

    const dashboard = await client.get('https://uphslms.com/');

    if (!dashboard.data.includes('Log in')) {
      const cookies = await client.defaults.jar.getCookies('https://uphslms.com');
      const cookieStrings = cookies.map(c => c.cookieString());

      const sessionId = req.headers['x-user-id'];
      if (sessionId) {
        userSessions.set(sessionId, {
          cookies: cookieStrings,
          timestamp: Date.now()
        });

        try {
          await User.findOneAndUpdate(
            { email: sessionId },
            {
              lmsCookies: cookieStrings,
              lmsSessionExpiry: new Date(Date.now() + 60 * 60 * 1000)
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

// Verify LMS Credentials
const verifyLMSCredentials = async (req, res) => {
  console.log('🔍 Verifying LMS credentials');
  const { username, password } = req.body;

  try {
    const client = createLMSClient();

    const loginPage = await client.get('https://uphslms.com/login/index.php');
    const $ = cheerio.load(loginPage.data);
    const logintoken = $('input[name="logintoken"]').val();

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

// Auto Login LMS
const autoLoginLMS = async (req, res) => {
  console.log('Auto-login for user:', req.body.userId);

  try {
    const session = userSessions.get(req.body.userId);
    if (session) {
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

    console.log('🔄 Trying to restore session from database');
    const user = await User.findOne({ email: req.body.userId });

    if (user && user.lmsCookies && user.lmsCookies.length > 0) {
      if (user.lmsSessionExpiry && new Date() < new Date(user.lmsSessionExpiry)) {
        const client = createLMSClient(user.lmsCookies);
        try {
          const dashboard = await client.get('https://uphslms.com/');
          if (!dashboard.data.includes('Log in')) {
            console.log('Restored session from database');

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

// Get Course Contents
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

    const courseTitle = $('h1').first().text().trim();
    console.log('📖 Course:', courseTitle);

    $('li.section.course-section.main').each((sectionIndex, section) => {
      const sectionElement = $(section);
      const sectionHeader = sectionElement.find('.sectionname a');
      const sectionName = sectionHeader.text().trim();
      const sectionLink = sectionHeader.attr('href');
      const sectionId = sectionElement.attr('data-sectionid');
      const sectionNumber = sectionElement.attr('data-number');

      const sectionData = {
        id: sectionId,
        number: sectionNumber,
        name: sectionName,
        link: sectionLink ? (sectionLink.startsWith('http') ? sectionLink : `https://uphslms.com${sectionLink}`) : null,
        activities: []
      };

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
          if (buttonText.includes('Done')) {
            completionStatus = 'done';
          } else if (buttonText.includes('To do')) {
            completionStatus = 'todo';
          }
        }

        const dates = [];
        activityElement.find('[data-region="activity-dates"] div').each((i, dateEl) => {
          const dateText = $(dateEl).text().trim();
          if (dateText) {
            dates.push(dateText);
          }
        });

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

// Cleanup old sessions
setInterval(() => {
  const oneHour = 3600000;
  for (const [id, session] of userSessions.entries()) {
    if (Date.now() - session.timestamp > oneHour) {
      userSessions.delete(id);
      console.log('Removed expired session for user:', id);
    }
  }
}, 3600000);

const changeLMSPassword = async (req, res) => {
  console.log('Changing LMS password for user:', req.body.userId);
  const { userId, currentPassword, newPassword } = req.body;

  try {
    const User = require('../models/User');
    const user = await User.findOne({ email: userId });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const client = createLMSClient();
    const loginUrl = 'https://uphslms.com/login/index.php';

    console.log('Step 1: Logging in with current credentials...');

    const loginPage = await client.get(loginUrl);
    let $ = cheerio.load(loginPage.data);
    let logintoken = $('input[name="logintoken"]').val();

    if (!logintoken) {
      return res.status(500).json({ error: 'Could not retrieve login token' });
    }

    await client.post(loginUrl,
      new URLSearchParams({
        username: user.lmsUsername,
        password: currentPassword,
        logintoken: logintoken,
        anchor: ''
      }), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': loginUrl
        }
      });

    const dashboard = await client.get('https://uphslms.com/my/');
    if (dashboard.data.includes('Log in')) {
      return res.status(401).json({ success: false, error: 'Current password is incorrect' });
    }

    console.log('Step 2: Login successful, accessing change password page...');

    const changePasswordUrl = 'https://uphslms.com/login/change_password.php';
    const changePasswordPage = await client.get(changePasswordUrl);
    $ = cheerio.load(changePasswordPage.data);

    const sesskey = $('input[name="sesskey"]').val();
    const userId_lms = $('input[name="id"]').val();

    console.log('Step 3: Extracted sesskey:', sesskey);
    console.log('User ID from form:', userId_lms);

    if (!sesskey) {
      return res.status(500).json({ error: 'Could not retrieve session key' });
    }

    console.log('Step 4: Submitting password change...');

    const formData = new URLSearchParams();
    formData.append('id', userId_lms || '1');
    formData.append('sesskey', sesskey);
    formData.append('password', currentPassword);
    formData.append('newpassword1', newPassword);
    formData.append('newpassword2', newPassword);
    formData.append('logoutothersessions', '1');
    formData.append('submitbutton', 'Save changes');

    const submitResponse = await client.post(changePasswordUrl, formData.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': changePasswordUrl,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      },
      maxRedirects: 5,
      validateStatus: (status) => status < 400
    });

    const responseHtml = submitResponse.data;

    const hasSuccess = responseHtml.includes('Password changed') ||
                      responseHtml.includes('Your password has been changed') ||
                      responseHtml.includes('password was updated') ||
                      (submitResponse.status === 302) ||
                      responseHtml.includes('profile was updated');

    const hasError = responseHtml.includes('Invalid password') ||
                    responseHtml.includes('Current password is incorrect') ||
                    (responseHtml.includes('error') && responseHtml.includes('password'));

    if (hasSuccess) {
      console.log('✅ Password changed successfully!');

      user.lmsPassword = newPassword;
      await user.save();

      const { userSessions } = require('../utils/sessionStore');
      userSessions.delete(userId);

      try {
        const newClient = createLMSClient();
        const newLoginPage = await newClient.get(loginUrl);
        const newLoginPage$ = cheerio.load(newLoginPage.data);
        const newLogintoken = newLoginPage$('input[name="logintoken"]').val();

        await newClient.post(loginUrl,
          new URLSearchParams({
            username: user.lmsUsername,
            password: newPassword,
            logintoken: newLogintoken,
            anchor: ''
          }), {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
          });

        const cookies = await newClient.defaults.jar.getCookies('https://uphslms.com');
        const cookieStrings = cookies.map(c => c.cookieString());

        userSessions.set(userId, {
          cookies: cookieStrings,
          timestamp: Date.now(),
          username: user.lmsUsername
        });

        await User.findOneAndUpdate(
          { email: userId },
          {
            lmsCookies: cookieStrings,
            lmsSessionExpiry: new Date(Date.now() + 60 * 60 * 1000)
          }
        );
      } catch (loginError) {
        console.log('New login verification failed:', loginError.message);
      }

      res.json({ success: true, message: 'Password changed successfully' });

    } else if (hasError) {
      console.log('❌ Password change failed - current password incorrect');
      res.status(401).json({ success: false, error: 'Current password is incorrect' });
    } else {
      console.log('❌ Password change failed - unknown error');
      const errorDiv = $('.alert-danger, .error, .alert').first().text();
      const errorMsg = errorDiv || 'Failed to change password. Please try again.';
      console.log('Error message from page:', errorMsg);
      res.status(500).json({ success: false, error: errorMsg });
    }

  } catch (error) {
    console.error('Change password error:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response headers:', error.response.headers);
    }
    res.status(500).json({ error: error.message });
  }
};

// US-05: Get Grades - FIXED
const getGrades = async (req, res) => {
  try {
    const session = userSessions.get(req.body.userId);
    if (!session) {
      return res.status(401).json({ error: 'Not logged in' });
    }

    console.log('📊 Fetching grades for user:', req.body.userId);
    const client = createLMSClient(session.cookies);

    // Get the overview page
    const overviewUrl = 'https://uphslms.com/grade/report/overview/index.php';
    const overviewResponse = await client.get(overviewUrl);
    const $overview = cheerio.load(overviewResponse.data);

    const courses = [];

    // Parse overview table
    $overview('#overview-grade tbody tr').each((i, row) => {
      const cells = $overview(row).find('td');
      if (cells.length >= 2) {
        const courseLink = $overview(cells[0]).find('a');
        const courseName = courseLink.text().trim();
        const courseUrl = courseLink.attr('href');
        const gradeText = $overview(cells[1]).text().trim();

        if (courseName && courseUrl) {
          const idMatch = courseUrl.match(/id=(\d+)/);
          const courseId = idMatch ? idMatch[1] : null;

          courses.push({
            courseId: courseId,
            courseName: courseName,
            courseUrl: courseUrl,
            overviewGrade: gradeText !== '-' ? gradeText : null
          });
        }
      }
    });

    console.log(`📚 Found ${courses.length} courses`);

    const allGrades = [];

    // For each course, get detailed grades
    for (const course of courses) {
      if (!course.courseUrl) continue;

      try {
        console.log(`📖 Fetching grades for: ${course.courseName}`);
        const gradeUrl = course.courseUrl.startsWith('http')
          ? course.courseUrl
          : `https://uphslms.com${course.courseUrl}`;

        const gradeResponse = await client.get(gradeUrl);
        const $grade = cheerio.load(gradeResponse.data);

        let courseTotal = null;
        let courseTotalRaw = null;
        let courseLetterGrade = null;

        // Look for course total row
        $grade('tr').each((i, row) => {
          const rowText = $grade(row).text().toLowerCase();
          if (rowText.includes('course total')) {
            const avgCell = $grade(row).find('.column-average, .column-percentage, .grade');
            const avgText = avgCell.text().trim();
            if (avgText && avgText !== '-') {
              const numMatch = avgText.match(/(\d+(?:\.\d+)?)/);
              if (numMatch) {
                courseTotal = parseFloat(numMatch[1]);
                courseTotalRaw = avgText;
              }
            }
            const letterCell = $grade(row).find('.column-lettergrade');
            if (letterCell.length > 0) {
              const letterText = letterCell.text().trim();
              if (letterText && letterText !== '-') {
                courseLetterGrade = letterText;
              }
            }
          }
        });

        // Extract category grades (PRELIM, MIDTERM, FINAL)
        let prelimGrade = null;
        let midtermGrade = null;
        let finalGrade = null;

        $grade('tr').each((i, row) => {
          const rowText = $grade(row).text();
          const avgCell = $grade(row).find('.column-average, .column-percentage');
          const avgText = avgCell.text().trim();

          if (avgText && avgText !== '-') {
            const numMatch = avgText.match(/(\d+(?:\.\d+)?)/);
            const gradeValue = numMatch ? parseFloat(numMatch[1]) : null;

            if (rowText.includes('PRELIM total') && gradeValue) {
              prelimGrade = gradeValue;
            } else if (rowText.includes('MIDTERM total') && gradeValue) {
              midtermGrade = gradeValue;
            } else if (rowText.includes('FINAL total') && gradeValue) {
              finalGrade = gradeValue;
            }
          }
        });

        // Calculate average from categories
        let calculatedTotal = null;
        const validCategories = [];
        if (prelimGrade !== null) validCategories.push(prelimGrade);
        if (midtermGrade !== null) validCategories.push(midtermGrade);
        if (finalGrade !== null) validCategories.push(finalGrade);

        if (validCategories.length > 0) {
          const sum = validCategories.reduce((a, b) => a + b, 0);
          calculatedTotal = sum / validCategories.length;
        }

        const finalGradeValue = courseTotal !== null ? courseTotal : calculatedTotal;

        let overviewGradeNum = null;
        if (course.overviewGrade && course.overviewGrade !== '-') {
          const percentMatch = course.overviewGrade.match(/(\d+(?:\.\d+)?)/);
          if (percentMatch) {
            overviewGradeNum = parseFloat(percentMatch[1]);
          }
        }

        const bestGrade = finalGradeValue !== null ? finalGradeValue : overviewGradeNum;

        const categoryGrades = [];
        if (prelimGrade !== null) categoryGrades.push({ name: 'Prelim', grade: prelimGrade });
        if (midtermGrade !== null) categoryGrades.push({ name: 'Midterm', grade: midtermGrade });
        if (finalGrade !== null) categoryGrades.push({ name: 'Final', grade: finalGrade });

        allGrades.push({
          courseId: course.courseId,
          courseName: course.courseName,
          grade: bestGrade,
          gradeDisplay: bestGrade !== null ? bestGrade.toFixed(2) + '%' : (course.overviewGrade || 'N/A'),
          letterGrade: courseLetterGrade,
          weight: 3.0,
          gradeType: 'percentage',
          categoryGrades: categoryGrades,
          lastUpdated: new Date()
        });

        // Delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 300));

      } catch (e) {
        console.log(`Error fetching grades for ${course.courseName}:`, e.message);

        let overviewGradeNum = null;
        if (course.overviewGrade && course.overviewGrade !== '-') {
          const percentMatch = course.overviewGrade.match(/(\d+(?:\.\d+)?)/);
          if (percentMatch) {
            overviewGradeNum = parseFloat(percentMatch[1]);
          }
        }

        allGrades.push({
          courseId: course.courseId,
          courseName: course.courseName,
          grade: overviewGradeNum,
          gradeDisplay: course.overviewGrade || 'N/A',
          letterGrade: null,
          weight: 3.0,
          gradeType: 'percentage',
          categoryGrades: [],
          lastUpdated: new Date(),
          error: e.message
        });
      }
    }

    // Calculate GWA
    let totalWeightedScore = 0;
    let totalCredits = 0;
    let gradedCourses = 0;

    for (const grade of allGrades) {
      if (grade.grade !== null && !isNaN(grade.grade)) {
        totalWeightedScore += grade.grade * grade.weight;
        totalCredits += grade.weight;
        gradedCourses++;
      }
    }

    const gwa = totalCredits > 0 ? totalWeightedScore / totalCredits : 0;

    console.log(`📊 Successfully fetched ${allGrades.length} grades`);
    console.log(`   Graded courses: ${gradedCourses}/${allGrades.length}`);
    console.log(`   Calculated GWA: ${gwa.toFixed(2)}%`);

    res.json({
      success: true,
      grades: allGrades,
      gwa: gwa,
      totalCourses: allGrades.length,
      gradedCourses: gradedCourses,
      lastUpdated: new Date()
    });

  } catch (error) {
    console.error('Get grades error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

// Get course detailed grades
const getCourseDetailedGrades = async (req, res) => {
  try {
    const session = userSessions.get(req.body.userId);
    if (!session) {
      return res.status(401).json({ error: 'Not logged in' });
    }

    const { courseUrl } = req.body;
    const client = createLMSClient(session.cookies);

    const url = courseUrl.startsWith('http')
      ? courseUrl
      : `https://uphslms.com${courseUrl}`;

    const response = await client.get(url);
    const $ = cheerio.load(response.data);

    const gradeItems = [];

    $('tr[data-hidden="false"]').each((i, row) => {
      const itemName = $(row).find('.item .rowtitle a, .item .rowtitle span').first().text().trim();
      const gradeCell = $(row).find('.column-grade');
      const gradeText = gradeCell.find('div:first-child').text().trim();
      const percentageCell = $(row).find('.column-percentage, .column-average');
      const percentageText = percentageCell.text().trim();
      const rangeCell = $(row).find('.column-range');
      const rangeText = rangeCell.text().trim();
      const letterCell = $(row).find('.column-lettergrade');
      const letterText = letterCell.text().trim();

      if (itemName && (gradeText !== '-' || percentageText !== '-')) {
        let grade = null;
        let gradeType = 'unknown';

        if (percentageText && percentageText !== '-') {
          const percentMatch = percentageText.match(/(\d+(?:\.\d+)?)/);
          if (percentMatch) {
            grade = parseFloat(percentMatch[1]);
            gradeType = 'percentage';
          }
        } else if (gradeText && gradeText !== '-') {
          const numMatch = gradeText.match(/(\d+(?:\.\d+)?)/);
          if (numMatch) {
            grade = parseFloat(numMatch[1]);
            gradeType = 'numeric';
          }
        }

        if (itemName && !itemName.includes('Aggregation') && !itemName.toLowerCase().includes('total')) {
          gradeItems.push({
            itemName: itemName,
            grade: grade,
            gradeDisplay: gradeText !== '-' ? gradeText : (percentageText !== '-' ? percentageText : 'N/A'),
            letterGrade: letterText !== '-' ? letterText : null,
            range: rangeText !== '-' ? rangeText : null,
            gradeType: gradeType
          });
        }
      }
    });

    res.json({
      success: true,
      courseName: $('h1').first().text().trim(),
      gradeItems: gradeItems
    });

  } catch (error) {
    console.error('Get course detailed grades error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  lmsLogin,
  verifyLMSCredentials,
  autoLoginLMS,
  getCourses,
  getCourseContents,
  changeLMSPassword,
  getGrades,
  getCourseDetailedGrades
};