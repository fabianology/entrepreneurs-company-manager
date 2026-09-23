import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { json } from "../_shared/http.ts";
import { parseDocumentUploadRequest } from "../_shared/document_upload_request.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "Not configured" }, 503);
  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token || token === serviceKey) return json({ error: "Unauthorized" }, 401);
  if (Number(request.headers.get("Content-Length") ?? "0") > 4096) {
    return json({ error: "Invalid upload request" }, 400);
  }
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: auth, error: authError } = await admin.auth.getUser(token);
  if (authError || !auth.user) return json({ error: "Unauthorized" }, 401);

  let input;
  try { input = parseDocumentUploadRequest(await request.json()); }
  catch { return json({ error: "Invalid upload request" }, 400); }
  const caller = createClient(url, anonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  try {
    const { data: reservation, error: reserveError } = await caller.rpc(
      "miloom_prepare_document_upload", {
        p_document_id: input.document_id,
        p_expected_url: input.expected_url,
        p_extension: input.extension,
        p_byte_count: input.byte_count,
      },
    );
    if (reserveError || !reservation || typeof reservation !== "object"
      || typeof reservation.path !== "string"
      || typeof reservation.reservation_id !== "string") {
      return json({ error: "Document upload is not available for this account or file" }, 403);
    }
    const { data: signed, error: signError } = await admin.storage
      .from("CompanyDocuments").createSignedUploadUrl(reservation.path);
    if (signError || !signed?.token) throw new Error("Could not sign upload");
    return json({
      reservation_id: reservation.reservation_id,
      path: reservation.path,
      token: signed.token,
    });
  } catch {
    return json({ error: "Document upload could not be prepared" }, 500);
  }
});
