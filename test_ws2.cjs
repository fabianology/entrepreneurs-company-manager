const WebSocket = require('ws');
const url = 'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=AIzaSyDjMa5RCyBu5-IlNPNCs8JZhdRmXjkCBqk';
console.log('Connecting to Gemini Live...');
const ws = new WebSocket(url);
ws.on('open', () => {
  console.log('✅ Connected!');
  const setup = JSON.stringify({
    setup: {
      model: "models/gemini-2.5-flash-native-audio-latest",
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
  if (msg.setupComplete) console.log('✅ Setup complete! Gemini Live is ready for audio.');
  else if (msg.serverContent) console.log('✅ Got server content (audio response)');
  else console.log('Received:', JSON.stringify(msg).substring(0, 300));
  setTimeout(() => { ws.close(); process.exit(0); }, 2000);
});
ws.on('error', (err) => { console.log('❌ Error:', err.message); process.exit(1); });
ws.on('close', (code, reason) => { console.log('Closed:', code, reason.toString()); process.exit(0); });
setTimeout(() => { console.log('❌ Timeout - no response'); process.exit(1); }, 10000);
