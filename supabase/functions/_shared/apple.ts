import {
  Environment,
  SignedDataVerifier,
  type JWSTransactionDecodedPayload,
} from "npm:@apple/app-store-server-library@3.1.0";

const bundleId = Deno.env.get("APPLE_BUNDLE_ID") ?? "com.vibing.miloom";
const environmentName = Deno.env.get("APPLE_ENVIRONMENT") ?? "Sandbox";
const environment = environmentName.toLowerCase() === "production"
  ? Environment.PRODUCTION
  : Environment.SANDBOX;
const appAppleId = environment === Environment.PRODUCTION
  ? Number(Deno.env.get("APPLE_APP_ID"))
  : undefined;

function decodeCertificate(value: string): Buffer {
  const bytes = Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  return Buffer.from(bytes);
}

function verifier(): SignedDataVerifier {
  const encodedCertificates = (Deno.env.get("APPLE_ROOT_CA_B64") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  if (encodedCertificates.length === 0) {
    throw new Error("APPLE_ROOT_CA_B64 is not configured");
  }
  return new SignedDataVerifier(
    encodedCertificates.map(decodeCertificate),
    true,
    environment,
    bundleId,
    appAppleId,
  );
}

export async function verifyTransaction(signedTransaction: string): Promise<JWSTransactionDecodedPayload> {
  return await verifier().verifyAndDecodeTransaction(signedTransaction);
}

export async function verifyNotification(signedPayload: string) {
  return await verifier().verifyAndDecodeNotification(signedPayload);
}

export function entitlementFromTransaction(transaction: JWSTransactionDecodedPayload) {
  const now = Date.now();
  const expiresAt = transaction.expiresDate ? new Date(transaction.expiresDate) : null;
  const revoked = transaction.revocationDate !== undefined;
  const active = !revoked && (expiresAt === null || expiresAt.getTime() > now);
  const introductoryOffer = transaction.offerType === 1;

  return {
    tier: active ? "pro" : "free",
    status: revoked ? "revoked" : active ? (introductoryOffer ? "trial" : "active") : "expired",
    product_id: transaction.productId ?? null,
    original_transaction_id: transaction.originalTransactionId ?? null,
    trial_ends_at: active && introductoryOffer ? expiresAt?.toISOString() ?? null : null,
    renews_at: expiresAt?.toISOString() ?? null,
    grace_ends_at: null,
    updated_at: new Date().toISOString(),
  };
}

export const supportedProducts = new Set([
  "com.miloom.premium.monthly",
  "com.miloom.premium.yearly",
]);
