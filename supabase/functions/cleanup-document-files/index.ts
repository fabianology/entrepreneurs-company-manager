import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { cleanDetachedDocumentFiles } from "../_shared/document_file_cleanup.ts";
import { json } from "../_shared/http.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const cronSecret = Deno.env.get("CRON_SECRET");
  const url = Deno.env.get("SUPABASE_URL");
  if (!serviceKey || !url || !cronSecret) return json({ error: "Not configured" }, 503);
  const authorized = request.headers.get("Authorization") === `Bearer ${serviceKey}`
    || request.headers.get("x-cron-secret") === cronSecret;
  if (!authorized) return json({ error: "Unauthorized" }, 401);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  try {
    return json(await cleanDetachedDocumentFiles(admin));
  } catch {
    return json({ error: "Document file cleanup could not complete" }, 500);
  }
});
