import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

serve(async (req) => {
  // 1. Validate the WebSocket upgrade request
  if (req.headers.get("upgrade") !== "websocket") {
    return new Response("Expected WebSocket", { status: 426 });
  }

  // 2. Validate Authorization
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Missing Authorization header", { status: 401 });
  }

  // Verify the JWT with Supabase
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  });
  
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) {
    console.error("Unauthorized connection attempt", error);
    return new Response("Unauthorized", { status: 401 });
  }

  if (!GEMINI_API_KEY) {
    console.error("GEMINI_API_KEY is not set in environment");
    return new Response("Server configuration error", { status: 500 });
  }

  // 3. Upgrade the connection
  const { socket: clientSocket, response } = Deno.upgradeWebSocket(req);

  const url = new URL("wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent");
  url.searchParams.set("key", GEMINI_API_KEY);

  let geminiSocket: WebSocket;
  const messageBuffer: any[] = [];

  clientSocket.onopen = () => {
    console.log(`Client connected (User: ${user.id}). Connecting to Gemini...`);
    
    // 4. Open connection to Google Gemini Live API
    geminiSocket = new WebSocket(url.toString());

    geminiSocket.onopen = () => {
      console.log("Connected to Gemini API");
      // Flush buffer
      while (messageBuffer.length > 0) {
        geminiSocket.send(messageBuffer.shift()!);
      }
    };

    // 5. Pipe messages Gemini -> iOS Client
    geminiSocket.onmessage = (event) => {
      if (clientSocket.readyState === WebSocket.OPEN) {
        clientSocket.send(event.data);
      }
    };

    geminiSocket.onclose = () => {
      console.log("Gemini connection closed");
      if (clientSocket.readyState === WebSocket.OPEN) {
        clientSocket.close();
      }
    };

    geminiSocket.onerror = (error) => {
      console.error("Gemini WebSocket error:", error);
    };
  };

  // 6. Pipe messages iOS Client -> Gemini
  clientSocket.onmessage = (event) => {
    if (geminiSocket && geminiSocket.readyState === WebSocket.OPEN) {
      geminiSocket.send(event.data);
    } else {
      messageBuffer.push(event.data);
    }
  };

  clientSocket.onclose = () => {
    console.log("Client connection closed");
    if (geminiSocket && geminiSocket.readyState === WebSocket.OPEN) {
      geminiSocket.close();
    }
  };

  clientSocket.onerror = (error) => {
    console.error("Client WebSocket error:", error);
  };

  return response;
});
