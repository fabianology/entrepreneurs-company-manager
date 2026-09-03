import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  fetchPlaidTransactionChanges,
  forEachPlaidItemIndependently,
  PlaidAPIError,
  plaidTransactionRow,
  requestPlaidTransactionSync,
  type PlaidConfig,
  type PlaidSyncItem,
} from "./plaid.ts";

const config: PlaidConfig = {
  clientId: "client",
  secret: "secret",
  baseUrl: "https://sandbox.plaid.test",
};

const item: PlaidSyncItem = {
  id: "item-row-id",
  access_token: "access-token",
  user_id: "user-id",
  company_id: "company-id",
  institution_id: "institution-id",
  cursor: "cursor-0",
};

Deno.test("transaction sync combines all cursor pages", async () => {
  const requestedCursors: Array<string | undefined> = [];
  const request = async (_config: PlaidConfig, _path: string, body: Record<string, unknown>) => {
    requestedCursors.push(body.cursor as string | undefined);
    if (body.cursor === "cursor-0") {
      return {
        added: [{ transaction_id: "added-1" }],
        modified: [],
        removed: [],
        next_cursor: "cursor-1",
        has_more: true,
      };
    }
    return {
      added: [],
      modified: [{ transaction_id: "modified-1" }],
      removed: [{ transaction_id: "removed-1" }],
      next_cursor: "cursor-2",
      has_more: false,
    };
  };

  const result = await fetchPlaidTransactionChanges(item, config, request);
  assertEquals(requestedCursors, ["cursor-0", "cursor-1"]);
  assertEquals(result.added.map((value: any) => value.transaction_id), ["added-1"]);
  assertEquals(result.modified.map((value: any) => value.transaction_id), ["modified-1"]);
  assertEquals(result.removed.map((value: any) => value.transaction_id), ["removed-1"]);
  assertEquals(result.cursor, "cursor-2");
});

Deno.test("pagination mutation restarts from the original cursor", async () => {
  const requestedCursors: Array<string | undefined> = [];
  let mutationThrown = false;
  const request = async (_config: PlaidConfig, _path: string, body: Record<string, unknown>) => {
    const cursor = body.cursor as string | undefined;
    requestedCursors.push(cursor);
    if (cursor === "cursor-1" && !mutationThrown) {
      mutationThrown = true;
      throw new PlaidAPIError(
        "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION",
        "restart",
      );
    }
    return cursor === "cursor-0"
      ? { added: [], modified: [], removed: [], next_cursor: "cursor-1", has_more: true }
      : { added: [], modified: [], removed: [], next_cursor: "cursor-2", has_more: false };
  };

  const result = await fetchPlaidTransactionChanges(item, config, request);
  assertEquals(requestedCursors, ["cursor-0", "cursor-1", "cursor-0", "cursor-1"]);
  assertEquals(result.cursor, "cursor-2");
});

Deno.test("transaction mapping preserves enrichment and ownership scope", () => {
  const row = plaidTransactionRow(item, {
    transaction_id: "transaction-id",
    account_id: "account-id",
    amount: 42.5,
    iso_currency_code: "USD",
    merchant_name: "Merchant",
    website: "https://merchant.example",
    logo_url: "https://merchant.example/logo.png",
    date: "2026-08-31",
    pending: false,
    personal_finance_category: {
      primary: "GENERAL_MERCHANDISE",
      detailed: "GENERAL_MERCHANDISE_OTHER",
      confidence_level: "VERY_HIGH",
    },
  });

  assertEquals(row.user_id, "user-id");
  assertEquals(row.company_id, "company-id");
  assertEquals(row.institution_id, "institution-id");
  assertEquals(row.plaid_transaction_id, "transaction-id");
  assertEquals(row.canonical_account_id, "account-id");
  assertEquals(row.merchant_website, "https://merchant.example");
  assertEquals(row.personal_finance_primary, "GENERAL_MERCHANDISE");
});

Deno.test("one failing bank does not stop the remaining Items", async () => {
  const attempted: string[] = [];
  const failed: string[] = [];
  await forEachPlaidItemIndependently(
    ["healthy-one", "expired-bank", "healthy-two"],
    async (value) => {
      attempted.push(value);
      if (value === "expired-bank") throw new Error("expired");
    },
    async (value) => { failed.push(value); },
  );

  assertEquals(attempted, ["healthy-one", "expired-bank", "healthy-two"]);
  assertEquals(failed, ["expired-bank"]);
});

Deno.test("failure-reporting errors also remain isolated per bank", async () => {
  const attempted: string[] = [];
  await forEachPlaidItemIndependently(
    ["broken", "healthy"],
    async (value) => {
      attempted.push(value);
      if (value === "broken") throw new Error("sync failed");
    },
    async () => { throw new Error("database unavailable"); },
  );

  assertEquals(attempted, ["broken", "healthy"]);
});

function syncAdmin(options: {
  claimToken?: string | null;
  continueResults?: boolean[];
}) {
  const rpcCalls: string[] = [];
  const continueResults = [...(options.continueResults ?? [false])];
  const terminal = { error: null };
  const query: any = {};
  for (const method of ["upsert", "delete", "update", "eq", "in"]) {
    query[method] = () => query;
  }
  query.then = (resolve: (value: typeof terminal) => void) => resolve(terminal);
  const admin = {
    rpc: async (name: string) => {
      rpcCalls.push(name);
      if (name === "claim_plaid_item_sync") {
        return { data: options.claimToken ?? null, error: null };
      }
      if (name === "continue_plaid_item_sync") {
        return { data: continueResults.shift() ?? false, error: null };
      }
      return { ...terminal, data: null };
    },
    from: () => query,
  };
  return { admin, rpcCalls };
}

const noAlerts = async () => ({ evaluated: 0, created: 0 });

Deno.test("webhook replay coalesces while an Item lease is held", async () => {
  const { admin, rpcCalls } = syncAdmin({ claimToken: null });
  let requestCount = 0;
  const result = await requestPlaidTransactionSync(
    admin,
    { ...item },
    config,
    4,
    async () => {
      requestCount += 1;
      return {};
    },
    noAlerts,
  );

  assertEquals(result.claimed, false);
  assertEquals(requestCount, 0);
  assertEquals(rpcCalls, ["claim_plaid_item_sync"]);
});

Deno.test("a webhook received during sync queues one follow-up cursor cycle", async () => {
  const { admin, rpcCalls } = syncAdmin({
    claimToken: "claim-token",
    continueResults: [true, false],
  });
  const requestedCursors: Array<string | undefined> = [];
  const workingItem = { ...item };
  const result = await requestPlaidTransactionSync(
    admin,
    workingItem,
    config,
    4,
    async (_config, _path, body) => {
      requestedCursors.push(body.cursor as string | undefined);
      return {
        added: [], modified: [], removed: [],
        next_cursor: `cursor-${requestedCursors.length}`,
        has_more: false,
      };
    },
    noAlerts,
  );

  assertEquals(result.cycles, 2);
  assertEquals(requestedCursors, ["cursor-0", "cursor-1"]);
  assertEquals(rpcCalls.filter((name) => name === "continue_plaid_item_sync").length, 2);
});

for (const failure of [
  new PlaidAPIError("ITEM_LOGIN_REQUIRED", "expired credentials", 400),
  new PlaidAPIError("RATE_LIMIT_EXCEEDED", "try later", 429),
]) {
  Deno.test(`${failure.errorCode} releases the Item lease without advancing its cursor`, async () => {
    const { admin, rpcCalls } = syncAdmin({ claimToken: "claim-token" });
    const workingItem = { ...item };

    await assertRejects(
      () => requestPlaidTransactionSync(
        admin,
        workingItem,
        config,
        4,
        async () => { throw failure; },
        noAlerts,
      ),
      PlaidAPIError,
      failure.errorCode === "ITEM_LOGIN_REQUIRED" ? "expired credentials" : "try later",
    );

    assertEquals(workingItem.cursor, "cursor-0");
    assertEquals(rpcCalls.at(-1), "release_plaid_item_sync");
  });
}
