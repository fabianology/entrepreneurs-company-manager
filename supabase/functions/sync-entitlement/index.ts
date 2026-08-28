import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/http.ts";
import { entitlementFromTransaction, supportedProducts, verifyTransaction } from "../_shared/apple.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = request.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData.user) return json({ error: "Authentication required" }, 401);

    const { signedTransaction } = await request.json();
    if (typeof signedTransaction !== "string" || signedTransaction.length < 20) {
      return json({ error: "signedTransaction is required" }, 400);
    }

    const transaction = await verifyTransaction(signedTransaction);
    if (!transaction.productId || !supportedProducts.has(transaction.productId)) {
      return json({ error: "Unsupported product" }, 400);
    }
    if (!transaction.appAccountToken || transaction.appAccountToken.toLowerCase() !== authData.user.id.toLowerCase()) {
      return json({ error: "Transaction is not bound to this account" }, 403);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const entitlement = {
      user_id: authData.user.id,
      ...entitlementFromTransaction(transaction),
    };
    const { error: upsertError } = await admin
      .from("user_entitlements")
      .upsert(entitlement, { onConflict: "user_id" });
    if (upsertError) throw upsertError;

    const { data: snapshot, error: snapshotError } = await userClient.rpc("get_miloom_access_snapshot");
    if (snapshotError) throw snapshotError;
    return json(snapshot);
  } catch (error) {
    console.error("sync-entitlement", error);
    return json({ error: error instanceof Error ? error.message : "Entitlement sync failed" }, 400);
  }
});
