const axios = require('axios');
const { CookieJar } = require('tough-cookie');
const { wrapper } = require('axios-cookiejar-support');

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

  const client = wrapper(axios.create({
    jar,
    withCredentials: true,
    maxRedirects: 5,
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9'
    }
  }));

  return client;
};

module.exports = { createLMSClient };