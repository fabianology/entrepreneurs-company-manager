const WebSocket = require('ws');
const url = 'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=AIzaSyDjMa5RCyBu5-IlNPNCs8JZhdRmXjkCBqk';
console.log('Connecting to Gemini Live...');
const ws = new WebSocket(url);
ws.on('open', () => {
  console.log('✅ Connected!');
  const setup = JSON.stringify({
    setup: {
      model: "models/gemini-2.0-flash",
      generationConfig: {
        responseModalities: ["AUDIO"],
        speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: "Aoede" } } }
      }
    }
  });
  ws.send(setup);
  console.log('Sent setup message');
});
ws.on('message', (data) => {
  const msg = JSON.parse(data.toString());
  if (msg.setupComplete) console.log('✅ Setup complete! Gemini is ready.');
  else if (msg.serverContent) console.log('✅ Got server content');
  else console.log('Received:', JSON.stringify(msg).substring(0, 200));
  setTimeout(() => { ws.close(); process.exit(0); }, 1000);
});
ws.on('error', (err) => { console.log('❌ Error:', err.message); process.exit(1); });
ws.on('close', (code, reason) => { console.log('Closed:', code, reason.toString()); process.exit(0); });
setTimeout(() => { console.log('❌ Timeout - no response'); process.exit(1); }, 10000);
