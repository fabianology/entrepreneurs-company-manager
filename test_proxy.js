const { createClient } = require('@supabase/supabase-js');
const WebSocket = require('ws');

const SUPABASE_URL = "https://xxqdytdbpiqjilhutvhz.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cWR5dGRicGlxamlsaHV0dmh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MTYwMDMsImV4cCI6MjA5MzE5MjAwM30.LzjILfwR6mW4EcwG2e_f9Q9NNgc4mlpPV8qy537jYYw";

async function run() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // Try to login anonymously or create a fake user just for testing
  let { data, error } = await supabase.auth.signInAnonymously();
  if (error) {
    console.log("Anon login failed, trying email...");
    ({ data, error } = await supabase.auth.signInWithPassword({
      email: 'apple@miloom.com',
      password: 'miloombeta'
    }));
  }

  if (error) {
    console.error("Auth failed:", error.message);
    return;
  }

  const token = data.session.access_token;
  console.log("Got token. Connecting to proxy...");

  const ws = new WebSocket("wss://xxqdytdbpiqjilhutvhz.supabase.co/functions/v1/gemini-live-proxy", {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });

  ws.on('open', () => {
    console.log('✅ Connected to proxy!');
    const setup = JSON.stringify({
      setup: {
        model: 'models/gemini-2.0-flash-exp',
        generationConfig: {
          responseModalities: ['AUDIO'],
          speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: 'Aoede' } } }
        }
      }
    });
    ws.send(setup);
  });

  ws.on('message', (data) => console.log('Message:', data.toString().substring(0, 100)));
  ws.on('error', (err) => console.log('❌ Error:', err.message));
  ws.on('close', (code, reason) => { 
    console.log('Closed:', code, reason.toString()); 
    process.exit(0); 
  });
}

run();
