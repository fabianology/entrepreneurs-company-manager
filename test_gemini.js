const https = require('https');
const data = JSON.stringify({
  contents: [{ parts: [{ text: "Hello" }] }]
});
const options = {
  hostname: 'generativelanguage.googleapis.com',
  path: '/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyDjMa5RCyBu5-IlNPNCs8JZhdRmXjkCBqk',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};
const req = https.request(options, (res) => {
  let resData = '';
  res.on('data', (chunk) => { resData += chunk; });
  res.on('end', () => { console.log("Status:", res.statusCode); console.log(resData); });
});
req.write(data);
req.end();
