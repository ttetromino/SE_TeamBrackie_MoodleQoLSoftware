const axios = require('axios');
const cheerio = require('cheerio');
const { CookieJar } = require('tough-cookie');
const { wrapper } = require('axios-cookiejar-support');

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
  const loginUrl = 'https://uphslms.com/blended/login/index.php';

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
          'Origin': 'https://uphslms.com',
          'Referer': loginUrl
        }
      });

    // Verify dashboard access
    const dashboard = await client.get('https://uphslms.com/blended/');

    if (!dashboard.data.includes('Log in')) {
      // Get cookies from jar
      const cookies = await client.defaults.jar.getCookies('https://uphslms.com');
      const cookieStrings = cookies.map(c => c.cookieString());

      const sessionId = req.headers['x-user-id'];
      if (sessionId) {
        userSessions.set(sessionId, {
          cookies: cookieStrings,
          timestamp: Date.now()
        });
        console.log('✅ Session stored with', cookieStrings.length, 'cookies');
      }

      res.json({ success: true });
    } else {
      throw new Error('Login failed - still on login page');
    }

  } catch (error) {
    console.error('❌ Login error:', error.message);
    res.status(500).json({ error: 'Login failed' });
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
    const response = await client.get('https://uphslms.com/blended/my/courses.php');

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

// Get Course Files
const getCourseFiles = async (req, res) => {
  try {
    const session = userSessions.get(req.body.userId);
    if (!session) {
      return res.status(401).json({ error: 'Not logged in' });
    }

    const url = req.body.courseUrl.startsWith('http')
      ? req.body.courseUrl
      : `https://uphslms.com${req.body.courseUrl}`;

    const client = createLMSClient(session.cookies);
    const response = await client.get(url);

    const $ = cheerio.load(response.data);
    const files = [];

    $('a[href*="pluginfile.php"], a[href$=".pdf"], a[href$=".docx"], a[href$=".pptx"]').each((i, el) => {
      const href = $(el).attr('href');
      if (href && !href.includes('login')) {
        files.push({
          name: $(el).text().trim() || href.split('/').pop(),
          url: href.startsWith('http') ? href : `https://uphslms.com${href}`,
          type: href.split('.').pop().toLowerCase()
        });
      }
    });

    res.json({ files });

  } catch (error) {
    console.error('Get files error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

// Download File
const downloadFile = async (req, res) => {
  try {
    const session = userSessions.get(req.body.userId);
    if (!session) {
      return res.status(401).json({ error: 'Not logged in' });
    }

    const client = createLMSClient(session.cookies);
    const response = await client({
      method: 'GET',
      url: req.body.fileUrl,
      responseType: 'stream'
    });

    response.data.pipe(res);

  } catch (error) {
    console.error('Download error:', error.message);
    res.status(500).json({ error: error.message });
  }
};

// Cleanup old sessions (run every hour)
setInterval(() => {
  const oneHour = 3600000;
  for (const [id, session] of userSessions.entries()) {
    if (Date.now() - session.timestamp > oneHour) {
      userSessions.delete(id);
      console.log('🧹 Removed expired session for user:', id);
    }
  }
}, 3600000);

module.exports = {
  lmsLogin,
  getCourses,
  getCourseFiles,
  downloadFile
};