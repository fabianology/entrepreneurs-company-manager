import { evaluateUserAlerts } from "./alerts.ts";

export type PlaidConfig = {
  clientId: string;
  secret: string;
  baseUrl: string;
};

export type PlaidSyncItem = {
  id: string;
  access_token: string;
  user_id: string;
  company_id: string;
  institution_id: string | null;
  cursor?: string | null;
};

export type PlaidSyncResult = {
  claimed: boolean;
  cycles: number;
  added: number;
  modified: number;
  removed: number;
  cursor?: string;
};

export class PlaidAPIError extends Error {
  constructor(
    public readonly errorCode: string,
    message: string,
    public readonly status = 502,
  ) {
    super(message);
    this.name = "PlaidAPIError";
  }
}

export async function forEachPlaidItemIndependently<T>(
  items: T[],
  operation: (item: T) => Promise<void>,
  onFailure: (item: T, error: unknown) => Promise<void>,
): Promise<void> {
  for (const item of items) {
    try {
      await operation(item);
    } catch (error) {
      // A bad Item must never prevent the remaining institutions from syncing.
      // Failure recording is also isolated because the database can be the
      // failing dependency.
      try {
        await onFailure(item, error);
      } catch (reportingError) {
        console.error("Could not record isolated Plaid Item failure", reportingError);
      }
    }
  }
}

function requireValue(name: string, value?: string): string {
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

export function plaidConfigFromEnvironment(): PlaidConfig {
  const environment = Deno.env.get("PLAID_ENV") || "sandbox";
  return {
    clientId: requireValue("PLAID_CLIENT_ID", Deno.env.get("PLAID_CLIENT_ID")),
    secret: requireValue("PLAID_SECRET", Deno.env.get("PLAID_SECRET")),
    baseUrl: `https://${environment}.plaid.com`,
  };
}

export function plaidWebhookURL(): string {
  const configured = Deno.env.get("PLAID_WEBHOOK_URL")?.trim();
  if (configured) return configured;
  const supabaseURL = requireValue("SUPABASE_URL", Deno.env.get("SUPABASE_URL"));
  return `${supabaseURL.replace(/\/$/, "")}/functions/v1/plaid-webhook`;
}

export async function plaidRequest(
  config: PlaidConfig,
  path: string,
  body: Record<string, unknown>,
): Promise<any> {
  const response = await fetch(`${config.baseUrl}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: config.clientId,
      secret: config.secret,
      ...body,
    }),
  });
  const value = await response.json().catch(() => ({}));
  if (!response.ok || value.error_code) {
    throw new PlaidAPIError(
      value.error_code || `HTTP_${response.status}`,
      value.error_message || "Plaid request failed",
      response.status,
    );
  }
  return value;
}

export function plaidTransactionRow(item: PlaidSyncItem, transaction: any) {
  return {
    user_id: item.user_id,
    plaid_item_id: item.id,
    plaid_transaction_id: transaction.transaction_id,
    account_id: transaction.account_id,
    canonical_account_id: transaction.account_id,
    account_match_method: "source",
    is_superseded_duplicate: false,
    superseded_by_transaction_id: null,
    amount: transaction.amount,
    currency: transaction.iso_currency_code || transaction.unofficial_currency_code || "USD",
    category: transaction.category || [],
    merchant_name: transaction.merchant_name || transaction.name,
    merchant_website: transaction.website ?? null,
    merchant_logo_url: transaction.logo_url ?? null,
    merchant_entity_id: transaction.merchant_entity_id ?? null,
    name: transaction.name || transaction.merchant_name,
    date: transaction.date,
    authorized_date: transaction.authorized_date ?? null,
    pending: transaction.pending || false,
    pending_transaction_id: transaction.pending_transaction_id ?? null,
    payment_channel: transaction.payment_channel ?? null,
    personal_finance_primary: transaction.personal_finance_category?.primary ?? null,
    personal_finance_detailed: transaction.personal_finance_category?.detailed ?? null,
    personal_finance_confidence: transaction.personal_finance_category?.confidence_level ?? null,
    transaction_code: transaction.transaction_code ?? null,
    location: transaction.location ?? null,
    counterparties: transaction.counterparties ?? [],
    is_stale_pending_duplicate: false,
    posted_transaction_id: null,
    company_id: item.company_id,
    institution_id: item.institution_id,
  };
}

function batches<T>(values: T[], size = 500): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}

export async function fetchPlaidTransactionChanges(
  item: PlaidSyncItem,
  config: PlaidConfig,
  request: typeof plaidRequest = plaidRequest,
) {
  const startingCursor = item.cursor || undefined;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    let cursor = startingCursor;
    const added: any[] = [];
    const modified: any[] = [];
    const removed: any[] = [];
    try {
      while (true) {
        const response = await request(config, "/transactions/sync", {
          access_token: item.access_token,
          ...(cursor ? { cursor } : {}),
          count: 500,
          options: { include_personal_finance_category: true },
        });
        added.push(...(response.added || []));
        modified.push(...(response.modified || []));
        removed.push(...(response.removed || []));
        cursor = response.next_cursor;
        if (!response.has_more) {
          if (!cursor) throw new Error("Plaid sync response did not include next_cursor");
          return { added, modified, removed, cursor };
        }
      }
    } catch (error) {
      if (
        error instanceof PlaidAPIError &&
        error.errorCode === "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION" &&
        attempt < 3
      ) continue;
      throw error;
    }
  }
  throw new Error("Plaid transaction pagination could not stabilize");
}

async function applyTransactionChanges(admin: any, item: PlaidSyncItem, changes: any) {
  const changedRows = [...changes.added, ...changes.modified]
    .filter((transaction: any) => transaction?.transaction_id)
    .map((transaction: any) => plaidTransactionRow(item, transaction));

  for (const batch of batches(changedRows)) {
    const { error } = await admin.from("plaid_transactions")
      .upsert(batch, { onConflict: "plaid_transaction_id" });
    if (error) throw error;
  }

  const removedIDs = changes.removed
    .map((transaction: any) => transaction?.transaction_id)
    .filter(Boolean);
  for (const batch of batches(removedIDs)) {
    const { error } = await admin.from("plaid_transactions")
      .delete()
      .eq("plaid_item_id", item.id)
      .in("plaid_transaction_id", batch);
    if (error) throw error;
  }

  for (const [rpc, parameters] of [
    ["reconcile_plaid_history_by_overlap", { p_user_id: item.user_id, p_current_item_id: item.id }],
    ["reconcile_plaid_transaction_duplicates", { p_user_id: item.user_id }],
    ["reconcile_plaid_pending_transactions", { p_user_id: item.user_id }],
  ] as const) {
    const { error } = await admin.rpc(rpc, parameters);
    if (error) throw error;
  }

  // Advance the cursor only after every mutation and reconciliation succeeds.
  // Retrying a failed page is therefore safe and idempotent.
  const { error: cursorError } = await admin.from("plaid_items")
    .update({
      cursor: changes.cursor,
      last_synced_at: new Date().toISOString(),
      status: "active",
      error_code: null,
    })
    .eq("id", item.id);
  if (cursorError) throw cursorError;
  item.cursor = changes.cursor;
}

export async function requestPlaidTransactionSync(
  admin: any,
  item: PlaidSyncItem,
  config: PlaidConfig,
  maxCycles = 4,
  request: typeof plaidRequest = plaidRequest,
  evaluateAlerts: typeof evaluateUserAlerts = evaluateUserAlerts,
): Promise<PlaidSyncResult> {
  const { data: claimToken, error: claimError } = await admin.rpc("claim_plaid_item_sync", {
    p_plaid_item_id: item.id,
    p_lease_seconds: 240,
  });
  if (claimError) throw claimError;
  if (!claimToken) return { claimed: false, cycles: 0, added: 0, modified: 0, removed: 0 };

  const total: PlaidSyncResult = {
    claimed: true,
    cycles: 0,
    added: 0,
    modified: 0,
    removed: 0,
  };
  try {
    for (let cycle = 0; cycle < maxCycles; cycle += 1) {
      const changes = await fetchPlaidTransactionChanges(item, config, request);
      await applyTransactionChanges(admin, item, changes);
      total.cycles += 1;
      total.added += changes.added.length;
      total.modified += changes.modified.length;
      total.removed += changes.removed.length;
      total.cursor = changes.cursor;

      const { data: shouldContinue, error } = await admin.rpc("continue_plaid_item_sync", {
        p_plaid_item_id: item.id,
        p_claim_token: claimToken,
        p_lease_seconds: 240,
      });
      if (error) throw error;
      if (!shouldContinue) {
        try {
          await evaluateAlerts(admin, item.user_id);
        } catch (alertError) {
          console.error("Alert evaluation failed after Plaid sync", alertError);
        }
        return total;
      }
    }

    await admin.rpc("release_plaid_item_sync", {
      p_plaid_item_id: item.id,
      p_claim_token: claimToken,
    });
    try {
      await evaluateAlerts(admin, item.user_id);
    } catch (alertError) {
      console.error("Alert evaluation failed after Plaid sync", alertError);
    }
    return total;
  } catch (error) {
    await admin.rpc("release_plaid_item_sync", {
      p_plaid_item_id: item.id,
      p_claim_token: claimToken,
    });
    throw error;
  }
}
