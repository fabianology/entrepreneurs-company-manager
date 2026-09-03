import { assertEquals } from "jsr:@std/assert@1";
import {
  fetchPlaidTransactionChanges,
  PlaidAPIError,
  plaidTransactionRow,
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
