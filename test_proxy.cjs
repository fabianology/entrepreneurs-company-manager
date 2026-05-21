const WebSocket = require('ws');

const SUPABASE_URL = "https://xxqdytdbpiqjilhutvhz.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cWR5dGRicGlxamlsaHV0dmh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MTYwMDMsImV4cCI6MjA5MzE5MjAwM30.LzjILfwR6mW4EcwG2e_f9Q9NNgc4mlpPV8qy537jYYw";

async function run() {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'apikey': SUPABASE_ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'apple@miloom.com', password: 'miloombeta' })
  });
  const data = await res.json();
  const token = data.access_token;

  console.log("Got token. Connecting to proxy...");
  const ws = new WebSocket("wss://xxqdytdbpiqjilhutvhz.supabase.co/functions/v1/gemini-live-proxy", {
    headers: { Authorization: `Bearer ${token}` }
  });

  ws.on('open', () => {
    console.log('✅ Connected to Proxy!');
    const setup = JSON.stringify({
      setup: {
        model: 'models/gemini-2.5-flash-native-audio-latest',
        generationConfig: {
          responseModalities: ['AUDIO'],
          speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: 'Aoede' } } }
        }
      }
    });
    ws.send(setup);
  });

  ws.on('message', (data) => console.log('Message:', data.toString().substring(0, 200)));
  ws.on('error', (err) => console.log('❌ Error:', err.message));
  ws.on('close', (code, reason) => { 
    console.log('Closed:', code, reason.toString()); 
    process.exit(0); 
  });
}

run();
