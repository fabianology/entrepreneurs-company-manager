import { decodeProtectedHeader, importJWK, jwtVerify, type JWK } from "npm:jose@5.9.6";
import { plaidRequest, type PlaidConfig } from "./plaid.ts";

type PlaidVerificationJWK = JWK & { expired_at?: number | null };
const cachedVerificationKeys = new Map<string, PlaidVerificationJWK>();

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left: string, right: string): boolean {
  const size = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let index = 0; index < size; index += 1) {
    difference |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return difference === 0;
}

export async function verifyPlaidWebhook(
  rawBody: string,
  verificationHeader: string | null,
  config: PlaidConfig,
): Promise<{ bodyHash: string }> {
  if (!verificationHeader) throw new Error("Missing Plaid-Verification header");
  const protectedHeader = decodeProtectedHeader(verificationHeader);
  if (protectedHeader.alg !== "ES256" || !protectedHeader.kid) {
    throw new Error("Unsupported Plaid webhook signature");
  }

  let jwk = cachedVerificationKeys.get(protectedHeader.kid);
  if (jwk?.expired_at && jwk.expired_at <= Math.floor(Date.now() / 1000)) {
    cachedVerificationKeys.delete(protectedHeader.kid);
    jwk = undefined;
  }
  if (!jwk) {
    const response = await plaidRequest(config, "/webhook_verification_key/get", {
      key_id: protectedHeader.kid,
    });
    jwk = response.key as PlaidVerificationJWK;
    if (
      !jwk || jwk.alg !== "ES256" || jwk.kid !== protectedHeader.kid ||
      (jwk.expired_at != null && jwk.expired_at <= Math.floor(Date.now() / 1000))
    ) {
      throw new Error("Plaid returned an invalid webhook verification key");
    }
    cachedVerificationKeys.set(protectedHeader.kid, jwk);
  }

  const key = await importJWK(jwk, "ES256");
  const { payload } = await jwtVerify(verificationHeader, key, {
    algorithms: ["ES256"],
    maxTokenAge: "5 min",
  });
  const issuedAt = payload.iat;
  if (typeof issuedAt !== "number" || issuedAt > Math.floor(Date.now() / 1000) + 60) {
    throw new Error("Invalid Plaid webhook issued-at time");
  }

  const claimedHash = payload.request_body_sha256;
  const bodyHash = await sha256Hex(rawBody);
  if (typeof claimedHash !== "string" || !constantTimeEqual(bodyHash, claimedHash.toLowerCase())) {
    throw new Error("Plaid webhook body hash mismatch");
  }
  return { bodyHash };
}
