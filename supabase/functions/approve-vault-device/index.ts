import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type ApprovalRequest = {
  challenge_id: string;
  actor_device_id: string;
  target_device_id: string;
  key_version: number;
  signature: string;
  ephemeral_public_key: string;
  wrapped_vault_key: string;
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function decodeBase64(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function approvalPayload(
  userID: string,
  challengeID: string,
  actorDeviceID: string,
  targetDeviceID: string,
  keyVersion: number,
  nonce: string,
  ephemeralPublicKey: string,
  wrappedVaultKey: string,
): Uint8Array<ArrayBuffer> {
  return new TextEncoder().encode([
    "miloom-vault-approval-v1",
    userID.toLowerCase(),
    challengeID.toLowerCase(),
    actorDeviceID.toLowerCase(),
    targetDeviceID.toLowerCase(),
    String(keyVersion),
    nonce,
    ephemeralPublicKey,
    wrappedVaultKey,
  ].join("|"));
}

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json(405, { error: "METHOD_NOT_ALLOWED" });
  }

  try {
    const authorization = request.headers.get("Authorization");
    const supabaseURL = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!authorization || !supabaseURL || !anonKey || !serviceKey) {
      return json(401, { error: "UNAUTHORIZED" });
    }

    const userClient = createClient(supabaseURL, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const token = authorization.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userError } = await userClient.auth.getUser(token);
    if (userError || !user) return json(401, { error: "UNAUTHORIZED" });

    const body = await request.json() as ApprovalRequest;
    if (
      !body.challenge_id || !body.actor_device_id || !body.target_device_id ||
      !Number.isInteger(body.key_version) || body.key_version < 1 ||
      !body.signature || !body.ephemeral_public_key || !body.wrapped_vault_key
    ) {
      return json(400, { error: "INVALID_APPROVAL_REQUEST" });
    }
    if (
      decodeBase64(body.signature).byteLength !== 64 ||
      decodeBase64(body.ephemeral_public_key).byteLength !== 65 ||
      decodeBase64(body.wrapped_vault_key).byteLength !== 60
    ) {
      return json(400, { error: "INVALID_APPROVAL_CRYPTOGRAPHY" });
    }

    const admin = createClient(supabaseURL, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: challenge, error: challengeError } = await admin
      .from("vault_device_approval_challenges")
      .select("id,user_id,actor_device_id,target_device_id,key_version,nonce,expires_at,consumed_at")
      .eq("id", body.challenge_id)
      .eq("user_id", user.id)
      .maybeSingle();
    if (
      challengeError || !challenge || challenge.consumed_at ||
      new Date(challenge.expires_at).getTime() <= Date.now() ||
      challenge.actor_device_id !== body.actor_device_id ||
      challenge.target_device_id !== body.target_device_id ||
      challenge.key_version !== body.key_version
    ) {
      return json(403, { error: "APPROVAL_CHALLENGE_INVALID" });
    }

    const { data: actor, error: actorError } = await admin
      .from("vault_devices")
      .select("signing_public_key,status")
      .eq("id", body.actor_device_id)
      .eq("user_id", user.id)
      .maybeSingle();
    if (actorError || !actor || actor.status !== "approved") {
      return json(403, { error: "APPROVING_DEVICE_NOT_AUTHORIZED" });
    }

    const publicKey = await crypto.subtle.importKey(
      "raw",
      decodeBase64(actor.signing_public_key),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"],
    );
    const valid = await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      publicKey,
      decodeBase64(body.signature),
      approvalPayload(
        user.id,
        body.challenge_id,
        body.actor_device_id,
        body.target_device_id,
        body.key_version,
        challenge.nonce,
        body.ephemeral_public_key,
        body.wrapped_vault_key,
      ),
    );
    if (!valid) return json(403, { error: "APPROVAL_SIGNATURE_INVALID" });

    const { error: consumeError } = await admin.rpc(
      "miloom_consume_vault_approval_challenge",
      {
        p_user_id: user.id,
        p_challenge_id: body.challenge_id,
        p_actor_device_id: body.actor_device_id,
        p_target_device_id: body.target_device_id,
        p_key_version: body.key_version,
        p_ephemeral_public_key: body.ephemeral_public_key,
        p_wrapped_vault_key: body.wrapped_vault_key,
      },
    );
    if (consumeError) {
      console.error("Vault approval finalization failed", consumeError.code);
      return json(409, { error: "APPROVAL_FINALIZATION_FAILED" });
    }
    return json(200, { approved: true, device_id: body.target_device_id });
  } catch (error) {
    console.error("Vault device approval failed", error instanceof Error ? error.name : "unknown");
    return json(400, { error: "APPROVAL_REQUEST_FAILED" });
  }
});
