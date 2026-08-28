import { createClient } from "npm:@supabase/supabase-js@2";
import { json } from "../_shared/http.ts";
import { entitlementFromTransaction, supportedProducts, verifyNotification, verifyTransaction } from "../_shared/apple.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { signedPayload } = await request.json();
    if (typeof signedPayload !== "string") return json({ error: "signedPayload is required" }, 400);

    const notification = await verifyNotification(signedPayload);
    const signedTransaction = notification.data?.signedTransactionInfo;
    if (!signedTransaction) return json({ ok: true });

    const transaction = await verifyTransaction(signedTransaction);
    if (!transaction.productId || !supportedProducts.has(transaction.productId)) {
      return json({ error: "Unsupported product" }, 400);
    }
    if (!transaction.appAccountToken) {
      return json({ error: "Transaction has no appAccountToken" }, 400);
    }

    const entitlement = entitlementFromTransaction(transaction);
    if (notification.notificationType === "DID_FAIL_TO_RENEW") {
      entitlement.status = "grace";
      entitlement.tier = "pro";
      entitlement.grace_ends_at = new Date(Date.now() + 7 * 86_400_000).toISOString();
    } else if (["EXPIRED", "GRACE_PERIOD_EXPIRED"].includes(notification.notificationType ?? "")) {
      entitlement.status = "expired";
      entitlement.tier = "free";
    } else if (["REFUND", "REVOKE"].includes(notification.notificationType ?? "")) {
      entitlement.status = "revoked";
      entitlement.tier = "free";
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { error } = await admin.from("user_entitlements").upsert({
      user_id: transaction.appAccountToken,
      ...entitlement,
    }, { onConflict: "user_id" });
    if (error) throw error;
    return json({ ok: true });
  } catch (error) {
    console.error("app-store-notifications", error);
    return json({ error: error instanceof Error ? error.message : "Notification verification failed" }, 400);
  }
});
