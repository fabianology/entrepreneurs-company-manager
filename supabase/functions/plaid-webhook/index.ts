import { createClient } from "npm:@supabase/supabase-js@2";
import { json } from "../_shared/http.ts";
import { evaluateUserAlerts } from "../_shared/alerts.ts";
import {
  PlaidAPIError,
  plaidConfigFromEnvironment,
  requestPlaidTransactionSync,
  verifyPlaidWebhook,
} from "../_shared/plaid.ts";

const transactionWebhookCodes = new Set([
  "SYNC_UPDATES_AVAILABLE",
  "INITIAL_UPDATE",
  "HISTORICAL_UPDATE",
  "DEFAULT_UPDATE",
  "TRANSACTIONS_REMOVED",
]);

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const rawBody = await request.text();
  let bodyHash: string;
  let payload: any;
  const config = plaidConfigFromEnvironment();
  try {
    ({ bodyHash } = await verifyPlaidWebhook(
      rawBody,
      request.headers.get("Plaid-Verification"),
      config,
    ));
    payload = JSON.parse(rawBody);
  } catch (error) {
    console.error("Rejected Plaid webhook", error);
    return json({ error: "Webhook verification failed" }, 401);
  }

  const webhookType = String(payload?.webhook_type || "UNKNOWN");
  const webhookCode = String(payload?.webhook_code || "UNKNOWN");
  const externalItemID = typeof payload?.item_id === "string" ? payload.item_id : null;
  if (!externalItemID) return json({ ok: true, ignored: true });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: item, error: itemError } = await admin.from("plaid_items")
    .select("id,access_token,user_id,company_id,institution_id,cursor,status")
    .eq("item_id", externalItemID)
    .maybeSingle();
  if (itemError) return json({ error: "Could not resolve Plaid Item" }, 500);

  const { data: event, error: eventError } = await admin.from("plaid_webhook_events")
    .insert({
      plaid_item_id: item?.id ?? null,
      plaid_external_item_id: externalItemID,
      webhook_type: webhookType,
      webhook_code: webhookCode,
      environment: payload?.environment ?? null,
      body_sha256: bodyHash,
      status: item ? "received" : "ignored",
      processed_at: item ? null : new Date().toISOString(),
    })
    .select("id")
    .single();
  if (eventError) return json({ error: "Could not record Plaid webhook" }, 500);
  if (!item) return json({ ok: true, ignored: true });

  try {
    if (webhookType === "ITEM" && webhookCode === "ERROR") {
      const errorCode = String(payload?.error?.error_code || "PLAID_ITEM_ERROR");
      const requiresReauth = errorCode === "ITEM_LOGIN_REQUIRED";
      const { error } = await admin.from("plaid_items")
        .update({ status: requiresReauth ? "requires_reauth" : "error", error_code: errorCode })
        .eq("id", item.id);
      if (error) throw error;
      if (item.institution_id) {
        await admin.from("institutions")
          .update({ is_disconnected: requiresReauth })
          .eq("id", item.institution_id);
      }
      await admin.from("plaid_webhook_events").update({
        status: "processed",
        error_code: errorCode,
        processed_at: new Date().toISOString(),
      }).eq("id", event.id);
      try {
        await evaluateUserAlerts(admin, item.user_id);
      } catch (alertError) {
        console.error("Alert evaluation failed after Plaid Item error", alertError);
      }
      return json({ ok: true });
    }

    if (webhookType !== "TRANSACTIONS" || !transactionWebhookCodes.has(webhookCode)) {
      await admin.from("plaid_webhook_events").update({
        status: "ignored",
        processed_at: new Date().toISOString(),
      }).eq("id", event.id);
      return json({ ok: true, ignored: true });
    }

    if (item.status !== "active") {
      await admin.from("plaid_webhook_events").update({
        status: "ignored",
        error_code: item.status,
        processed_at: new Date().toISOString(),
      }).eq("id", event.id);
      return json({ ok: true, ignored: true });
    }

    await admin.from("plaid_webhook_events").update({ status: "processing" }).eq("id", event.id);
    const result = await requestPlaidTransactionSync(admin, item, config);
    await admin.from("plaid_webhook_events").update({
      status: result.claimed ? "processed" : "coalesced",
      processed_at: new Date().toISOString(),
    }).eq("id", event.id);
    return json({
      ok: true,
      coalesced: !result.claimed,
      added: result.added,
      modified: result.modified,
      removed: result.removed,
    });
  } catch (error) {
    const errorCode = error instanceof PlaidAPIError ? error.errorCode : "TRANSACTION_SYNC_FAILED";
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error("Plaid webhook processing failed", error);
    await admin.from("plaid_webhook_events").update({
      status: "failed",
      error_code: errorCode,
      error_message: errorMessage.slice(0, 500),
      processed_at: new Date().toISOString(),
    }).eq("id", event.id);
    await admin.from("plaid_items").update({
      status: errorCode === "ITEM_LOGIN_REQUIRED" ? "requires_reauth" : item.status,
      error_code: errorCode,
    }).eq("id", item.id);
    return json({ error: "Plaid update could not be processed" }, 500);
  }
});
