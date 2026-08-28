import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
      },
    });
  }

  const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
  if (!GEMINI_API_KEY) {
    return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Verify the user is authenticated
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: usage, error: usageError } = await supabase.rpc("consume_miloom_usage", {
    p_kind: "ai_actions",
    p_amount: 1,
  });
  if (usageError) {
    return new Response(JSON.stringify({ error: "Usage check failed" }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
  if (!usage?.allowed) {
    return new Response(JSON.stringify({ error: "MILOOM_LIMIT:ai_actions", usage }), {
      status: 429, headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const model = body.model || "gemini-2.0-flash";

    // Forward the request to the Gemini REST API
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY.trim()}`;

    // Build the Gemini request body — pass through contents, systemInstruction, tools, and generationConfig
    const geminiBody: Record<string, unknown> = {};
    if (body.contents) geminiBody.contents = body.contents;
    if (body.systemInstruction) geminiBody.systemInstruction = body.systemInstruction;
    if (body.tools) geminiBody.tools = body.tools;
    if (body.generationConfig) geminiBody.generationConfig = body.generationConfig;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiBody),
    });

    const geminiData = await geminiResponse.json();

    return new Response(JSON.stringify(geminiData), {
      status: geminiResponse.status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (e: any) {
    console.error("Gemini REST proxy error:", e);
    return new Response(JSON.stringify({ error: e.message || "Internal error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
