import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/http.ts";
import {
  isEmail,
  isShareRole,
  resourceName,
  shareEmailHtml,
  shareEmailSubject,
} from "../_shared/share_email.ts";

type InvitationRow = {
  id: string;
  email: string;
  role: string;
  resource_type: string;
  invited_by: string;
  status: string;
};

type InvitationToken = {
  token: string;
  expires_at: string;
};

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    console.error("send-share-email configuration is incomplete");
    return json({ error: "Invitation email delivery is unavailable." }, 503);
  }

  const authorization = request.headers.get("authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) {
    return json({ error: "Authentication required." }, 401);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  const user = authData.user;
  if (authError || !user) {
    return json({ error: "Authentication required." }, 401);
  }

  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const sender = Deno.env.get("SHARE_EMAIL_FROM");
  if (!serviceRoleKey || !resendApiKey || !sender) {
    console.error("send-share-email configuration is incomplete");
    return json({ error: "Invitation email delivery is unavailable." }, 503);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "A valid invitation ID is required." }, 400);
  }

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "A valid invitation ID is required." }, 400);
  }

  const payload = body as Record<string, unknown>;
  if (
    Object.keys(payload).some((key) => key !== "invitationId") ||
    typeof payload.invitationId !== "string" ||
    !UUID_PATTERN.test(payload.invitationId)
  ) {
    return json({ error: "A valid invitation ID is required." }, 400);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error: invitationError } = await adminClient
    .from("resource_invitations")
    .select("id,email,role,resource_type,invited_by,status")
    .eq("id", payload.invitationId)
    .eq("invited_by", user.id)
    .maybeSingle<InvitationRow>();

  if (invitationError) {
    console.error("send-share-email invitation lookup failed", {
      invitationId: payload.invitationId,
      code: invitationError.code,
    });
    return json({ error: "Invitation email delivery is unavailable." }, 503);
  }

  if (!data) {
    return json({ error: "Invitation not found." }, 404);
  }

  if (data.status.toLowerCase() !== "pending") {
    return json({ error: "Only pending invitations can be emailed." }, 409);
  }

  if (!isEmail(data.email) || !isShareRole(data.role) || !resourceName(data.resource_type)) {
    console.error("send-share-email rejected invalid invitation data", {
      invitationId: data.id,
    });
    return json({ error: "Invitation data is invalid." }, 422);
  }

  const { data: tokenData, error: tokenError } = await adminClient.rpc(
    "miloom_issue_invitation_token",
    { p_invitation_id: data.id, p_invited_by: user.id },
  );
  if (tokenError || !tokenData) {
    console.error("send-share-email token issuance failed", {
      invitationId: data.id,
      code: tokenError?.code,
    });
    const status = tokenError?.message?.includes("INVITATION_SEND_RATE_LIMITED") ? 429 : 503;
    return json({ error: status === 429 ? "Please wait before resending this invitation." : "Invitation email delivery is unavailable." }, status);
  }

  const invitationToken = tokenData as InvitationToken;
  if (!/^[0-9a-f]{64}$/.test(invitationToken.token)) {
    console.error("send-share-email received invalid invitation token", { invitationId: data.id });
    return json({ error: "Invitation email delivery is unavailable." }, 503);
  }

  const invitationUrl = new URL("https://miloom.co/invite");
  invitationUrl.searchParams.set("token", invitationToken.token);

  const subject = shareEmailSubject(data.resource_type);
  const html = shareEmailHtml({
    inviter: user.email ?? "A Miloom member",
    invitationUrl: invitationUrl.toString(),
    role: data.role,
    resourceType: data.resource_type,
  });
  if (!subject || !html) {
    return json({ error: "Invitation data is invalid." }, 422);
  }

  let providerResponse: Response;
  try {
    providerResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: sender,
        to: [data.email],
        subject,
        html,
      }),
    });
  } catch {
    console.error("send-share-email provider request failed", {
      invitationId: data.id,
    });
    return json({ error: "Invitation email could not be delivered." }, 502);
  }

  if (!providerResponse.ok) {
    console.error("send-share-email provider rejected request", {
      invitationId: data.id,
      status: providerResponse.status,
    });
    return json({ error: "Invitation email could not be delivered." }, 502);
  }

  console.info("send-share-email delivered", { invitationId: data.id });
  return json({ ok: true, status: "sent", invitationId: data.id });
});
