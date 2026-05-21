import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

serve(async (req) => {
  const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
  
  if (!GEMINI_API_KEY) {
    console.error("GEMINI_API_KEY is not set in environment");
    return new Response("Server configuration error", { status: 500 });
  }

  // 1. Validate the WebSocket upgrade request
  if (req.headers.get("upgrade") !== "websocket") {
    return new Response("Expected WebSocket", { status: 426 });
  }

  // 3. Upgrade the connection
  const { socket: clientSocket, response } = Deno.upgradeWebSocket(req);

  const url = new URL("wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent");
  url.searchParams.set("key", GEMINI_API_KEY.trim());

  let geminiSocket: WebSocket;
  const messageBuffer: any[] = [];

  try {
    geminiSocket = new WebSocket(url.toString());
  } catch (e: any) {
    console.error("Failed to create Gemini WebSocket", e);
    // Since clientSocket is not yet open, we can't send.
    return new Response("Internal Server Error", { status: 500 });
  }

  geminiSocket.onopen = () => {
    console.log("Connected to Gemini API");
    while (messageBuffer.length > 0) {
      geminiSocket.send(messageBuffer.shift()!);
    }
  };

  geminiSocket.onmessage = (event) => {
    if (clientSocket.readyState === WebSocket.OPEN) {
      clientSocket.send(event.data);
    }
  };

  geminiSocket.onclose = (event) => {
    console.log("Gemini connection closed", event.code, event.reason);
    if (clientSocket.readyState === WebSocket.OPEN) {
      clientSocket.send(JSON.stringify({ error: `Gemini closed connection: ${event.code} ${event.reason}` }));
      setTimeout(() => {
        if (clientSocket.readyState === WebSocket.OPEN) {
          if (event.code === 1000 || (event.code >= 3000 && event.code <= 4999)) {
              clientSocket.close(event.code, event.reason);
          } else {
              clientSocket.close();
          }
        }
      }, 500);
    }
  };

  geminiSocket.onerror = (error) => {
    console.error("Gemini WebSocket error:", error);
    if (clientSocket.readyState === WebSocket.OPEN) {
      clientSocket.send(JSON.stringify({ error: "Gemini WebSocket error occurred" }));
    }
  };

  clientSocket.onopen = () => {
    console.log(`Client connected.`);
  };

  clientSocket.onmessage = (event) => {
    if (geminiSocket.readyState === WebSocket.OPEN) {
      geminiSocket.send(event.data);
    } else {
      messageBuffer.push(event.data);
    }
  };

  clientSocket.onclose = () => {
    console.log("Client closed connection");
    if (geminiSocket.readyState === WebSocket.OPEN) {
      geminiSocket.close();
    }
  };

  clientSocket.onerror = (error) => {
    console.error("Client WebSocket error:", error);
  };

  return response;
});
