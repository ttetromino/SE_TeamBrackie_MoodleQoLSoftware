// utils/lmsClient.js
const axios = require('axios');
const { CookieJar } = require('tough-cookie');
const { wrapper } = require('axios-cookiejar-support');
const User = require('../models/User');
const { userSessions } = require('./sessionStore');
const cheerio = require('cheerio');

const createLMSClient = (cookies = []) => {
  const jar = new CookieJar();
  
  if (cookies && cookies.length > 0) {
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
    timeout: 30000,
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9'
    }
  }));
};

// Ensure valid session and auto-renew if expired
const ensureValidSession = async (userId, client, user) => {
  try {
    console.log(`🔍 Checking session validity for ${userId}...`);
    
    const dashboard = await client.get('https://uphslms.com/my/', {
      timeout: 10000,
      validateStatus: (status) => status < 500
    });
    
    // Check if we're on login page
    if (dashboard.data.includes('Log in') || dashboard.data.includes('login')) {
      console.log('🔄 Session expired, attempting auto-renewal...');
      
      // Try to renew session using stored credentials
      if (user && user.lmsUsername && user.lmsPassword) {
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
        
        // Verify login succeeded
        const verifyDashboard = await client.get('https://uphslms.com/my/');
        if (!verifyDashboard.data.includes('Log in')) {
          console.log('✅ Session renewed successfully!');
          
          // Update cookies in session store and database
          const cookies = await client.defaults.jar.getCookies('https://uphslms.com');
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
              lmsSessionExpiry: new Date(Date.now() + 60 * 60 * 1000),
              lmsLastLogin: new Date()
            }
          );
          
          return true;
        }
      }
      
      console.log('❌ Session renewal failed');
      return false;
    }
    
    console.log('✅ Session is valid');
    return true;
    
  } catch (error) {
    console.log('Session check error:', error.message);
    return false;
  }
};

module.exports = { createLMSClient, ensureValidSession };