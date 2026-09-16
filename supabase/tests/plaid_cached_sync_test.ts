import { assert, assertEquals } from "jsr:@std/assert@1";
import { handlers } from "./plaid_serve_stub.ts";
import "../functions/exchange-public-token/index.ts";
import "../functions/plaid-nightly-sync/index.ts";

const [exchange, sync] = handlers;
type Call = { url: URL; method: string; body: any };
const account = (id: string, type: string, current: number | null) => ({
  account_id: id,
  name: id,
  type,
  subtype: type === "loan" ? "mortgage" : type,
  mask: "1234",
  balances: { current, available: null, limit: 5000, iso_currency_code: "USD" },
});
const accounts = [
  account("checking", "depository", 1200),
  account("card", "credit", 450),
  account("loan", "loan", 80000),
];
const liabilities = {
  credit: [{
    account_id: "card",
    minimum_payment_amount: 25,
    next_payment_due_date: "2026-10-15",
    aprs: [{ apr_type: "purchase_apr", apr_percentage: 19 }],
  }],
  mortgage: [{
    account_id: "loan",
    next_monthly_payment: 900,
    next_payment_due_date: "2026-10-01",
    interest_rate: { percentage: 4 },
  }],
};
const item = (id: string) => ({
  id,
  access_token: `token-${id}`,
  user_id: "user-1",
  company_id: "company-1",
  institution_id: `institution-${id}`,
  institution_name: "Test Bank",
  status: "active",
  webhook_url: "https://supabase.test/functions/v1/plaid-webhook",
  cursor: null,
  institutions: {
    name: "Test Bank",
    accounts_data: [{
      id: "checking",
      name: "checking",
      balance: 1000,
      routingNumber: "encrypted-routing",
    }],
  },
});

async function withServices(
  run: (calls: Call[]) => Promise<void>,
  options: {
    items?: any[];
    accountError?: string;
    nullBalances?: boolean;
    badSession?: boolean;
    malformedAccounts?: boolean;
    missingCronSecret?: boolean;
    awaitingInitialData?: boolean;
  } = {},
) {
  const calls: Call[] = [];
  const originalFetch = globalThis.fetch;
  // The real Supabase SDK starts auth-maintenance intervals for each client.
  // Keep those isolated to each HTTP handler test and clean them up afterward.
  const originalSetInterval = globalThis.setInterval;
  const intervals: number[] = [];
  globalThis.setInterval = (
    handler: TimerHandler,
    timeout?: number,
    ...args: any[]
  ) => {
    const id = originalSetInterval(handler, timeout, ...args);
    intervals.push(id);
    return id;
  };
  const environment = {
    SUPABASE_URL: "https://supabase.test",
    SUPABASE_ANON_KEY: "test-anon",
    PLAID_SYNC_CRON_SECRET: options.missingCronSecret ? "" : "test-cron",
    SUPABASE_SERVICE_ROLE_KEY: "test-service",
    PLAID_CLIENT_ID: "test-client",
    PLAID_SECRET: "test-secret",
    PLAID_ENV: "sandbox",
    PLAID_WEBHOOK_URL: "https://supabase.test/functions/v1/plaid-webhook",
  };
  const previous = new Map(
    Object.keys(environment).map((key) => [key, Deno.env.get(key)]),
  );
  for (const [key, value] of Object.entries(environment)) {
    Deno.env.set(key, value);
  }
  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { "Content-Type": "application/json" },
    });
  globalThis.fetch = async (input, init) => {
    const req = new Request(input, init);
    const body = await req.text();
    const call = {
      url: new URL(req.url),
      method: req.method,
      body: body ? JSON.parse(body) : null,
    };
    calls.push(call);
    const path = call.url.pathname;
    if (call.url.hostname === "sandbox.plaid.com") {
      if (path === "/item/public_token/exchange") {
        return json({ access_token: "token-new", item_id: "new" });
      }
      if (path === "/accounts/get") {
        if (options.malformedAccounts) return json({});
        if (options.accountError && call.body.access_token !== "token-good") {
          return json({
            error_code: options.accountError,
            error_message: "Reconnect this bank",
          }, 400);
        }
        return json({
          accounts: options.nullBalances
            ? accounts.map((a) => ({
              ...a,
              balances: { ...a.balances, current: null },
            }))
            : accounts,
        });
      }
      if (path === "/auth/get") {
        return json({
          accounts: [],
          numbers: {
            ach: [{
              account_id: "checking",
              account: "test-account-number",
              routing: "test-routing-number",
            }],
          },
        });
      }
      if (path === "/liabilities/get") return json({ liabilities });
      if (path === "/transactions/sync") {
        if (options.awaitingInitialData) {
          return json({
            added: [],
            modified: [],
            removed: [],
            next_cursor: "",
            has_more: false,
          });
        }
        return json({
          added: [{
            transaction_id: "tx-1",
            account_id: "checking",
            amount: 12,
            date: "2026-09-15",
            name: "Coffee",
          }],
          modified: [],
          removed: [{ transaction_id: "old-pending" }],
          next_cursor: "cursor-1",
          has_more: false,
        });
      }
      throw new Error(`Unexpected Plaid call: ${path}`);
    }
    assertEquals(
      call.url.hostname,
      "supabase.test",
      "Tests must not contact real services",
    );
    if (path === "/auth/v1/user") {
      return options.badSession
        ? json({ message: "Invalid session" }, 401)
        : json({ id: "user-1" });
    }
    if (path.startsWith("/rest/v1/rpc/")) {
      if (path.endsWith("claim_plaid_item_sync")) return json("claim-token");
      if (path.endsWith("finish_plaid_item_sync")) return json(false);
      return json(null);
    }
    if (path === "/rest/v1/plaid_items" && req.method === "GET") {
      return json(options.items ?? [item("good")]);
    }
    if (path === "/rest/v1/financial_cards" && req.method === "GET") {
      return json({ id: "existing-card" });
    }
    if (path === "/rest/v1/loans" && req.method === "GET") {
      return json({ id: "existing-loan" });
    }
    if (req.method === "GET") return json([]);
    return new Response(null, { status: 204 });
  };
  try {
    await run(calls);
    assertEquals(
      calls.filter((c) =>
        ["/accounts/balance/get", "/transactions/refresh"].includes(
          c.url.pathname,
        )
      ),
      [],
      "Routine operations must never force a paid refresh",
    );
  } finally {
    await new Promise((resolve) => setTimeout(resolve, 0));
    for (const id of intervals) clearInterval(id);
    globalThis.setInterval = originalSetInterval;
    globalThis.fetch = originalFetch;
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

const request = (body: object, token = "test-user", cronSecret?: string) =>
  new Request("https://supabase.test/functions/v1/test", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(cronSecret ? { "x-cron-secret": cronSecret } : {}),
    },
    body: JSON.stringify(body),
  });

Deno.test("Link returns cached accounts with Auth and Liabilities enrichment and preserves its response contract", async () => {
  await withServices(async (calls) => {
    const response = await exchange(
      request({ public_token: "public", company_id: "company-1" }),
    );
    assertEquals(response.status, 200);
    const result = await response.json();
    assertEquals(result.success, true);
    assertEquals(result.item_id, "new");
    assertEquals(result.accounts.length, 3);
    assertEquals(result.accounts[0].balances.current, 1200);
    assertEquals(result.accounts[0].routing_number, "test-routing-number");
    assertEquals(
      result.accounts[1].liability_details.minimum_payment_amount,
      25,
    );
    assertEquals(
      calls.filter((c) => c.url.pathname === "/accounts/get").length,
      1,
    );
  });
});

Deno.test("Manual sync preserves cached balances, encrypted fields, debt updates, transaction import and user scope", async () => {
  await withServices(async (calls) => {
    const response = await sync(
      request({ institution_id: "institution-good" }),
    );
    const result = await response.json();
    assertEquals(response.status, 200);
    assertEquals(result.synced, 1);
    assertEquals(result.failed, 0);
    assertEquals(result.items[0].transactions_added, 1);
    assertEquals(result.items[0].transactions_removed, 1);
    const selection = calls.find((c) =>
      c.url.pathname === "/rest/v1/plaid_items" && c.method === "GET"
    )!;
    assertEquals(selection.url.searchParams.get("user_id"), "eq.user-1");
    assert(
      selection.url.searchParams.getAll("institution_id").includes(
        "eq.institution-good",
      ),
    );
    const institution = calls.find((c) =>
      c.url.pathname === "/rest/v1/institutions" && c.method === "PATCH"
    )!.body;
    assertEquals(institution.accounts_data[0].balance, 1200);
    assertEquals(
      institution.accounts_data[0].routingNumber,
      "encrypted-routing",
    );
    assert(Number.isFinite(Date.parse(institution.last_synced_at)));
    const card = calls.find((c) =>
      c.url.pathname === "/rest/v1/financial_cards" && c.method === "PATCH"
    )!.body;
    assertEquals([card.balance, card.mo_payment, card.apr], [450, 25, 19]);
    const loan = calls.find((c) =>
      c.url.pathname === "/rest/v1/loans" && c.method === "PATCH"
    )!.body;
    assertEquals([loan.remaining_balance, loan.monthly_payment], [80000, 900]);
    const transaction = calls.find((c) =>
      c.url.pathname === "/rest/v1/plaid_transactions" && c.method === "POST"
    )!.body[0];
    assertEquals(transaction.user_id, "user-1");
    assertEquals(transaction.plaid_transaction_id, "tx-1");
    assert(calls.some((c) =>
      c.body?.cursor === "cursor-1"
    ));
  });
});

Deno.test("Scheduled sync isolates a reauth failure and still imports the next bank without a paid fallback", async () => {
  await withServices(async (calls) => {
    const result = await (await sync(request({}, "test-anon", "test-cron")))
      .json();
    assertEquals([result.synced, result.failed], [1, 1]);
    assertEquals(result.items[0].error_code, "ITEM_LOGIN_REQUIRED");
    assert(calls.some((c) => c.body?.status === "requires_reauth"));
    assert(calls.some((c) => c.body?.is_disconnected === true));
    const selection = calls.find((c) =>
      c.url.pathname === "/rest/v1/plaid_items" && c.method === "GET"
    )!;
    assertEquals(selection.url.searchParams.get("user_id"), null);
  }, {
    items: [item("bad"), item("good")],
    accountError: "ITEM_LOGIN_REQUIRED",
  });
});

Deno.test("Missing cached balances preserve stored amounts instead of overwriting them with zero", async () => {
  await withServices(async (calls) => {
    assertEquals((await (await sync(request({}))).json()).synced, 1);
    const institution = calls.find((c) =>
      c.url.pathname === "/rest/v1/institutions" && c.method === "PATCH"
    )!.body;
    assertEquals(institution.accounts_data[0].balance, 1000);
    const card = calls.find((c) =>
      c.url.pathname === "/rest/v1/financial_cards" && c.method === "PATCH"
    )!.body;
    const loan = calls.find((c) =>
      c.url.pathname === "/rest/v1/loans" && c.method === "PATCH"
    )!.body;
    assertEquals(card.balance, undefined);
    assertEquals(loan.remaining_balance, undefined);
  }, { nullBalances: true });
});

Deno.test("Invalid sessions cannot issue Plaid requests", async () => {
  await withServices(async (calls) => {
    assertEquals((await sync(request({}))).status, 401);
    assertEquals(
      calls.filter((c) => c.url.hostname === "sandbox.plaid.com").length,
      0,
    );
  }, { badSession: true });
});

Deno.test("Initial data preparation keeps balances available without a false transaction freshness timestamp", async () => {
  await withServices(async (calls) => {
    const result = await (await sync(request({}))).json();
    assertEquals([result.synced, result.failed], [1, 0]);
    assertEquals(result.items[0].transactions_pending, true);
    const updates = calls.filter((c) =>
      c.url.pathname === "/rest/v1/plaid_items" && c.method === "PATCH"
    );
    assert(updates.some((c) => c.body.error_code === null));
    assert(
      updates.every((c) =>
        c.body.last_synced_at === undefined && c.body.cursor === undefined
      ),
    );
  }, { awaitingInitialData: true });
});

Deno.test("Wrong or unconfigured scheduler secrets never grant service-wide access", async () => {
  for (const missingCronSecret of [false, true]) {
    await withServices(async (calls) => {
      assertEquals(
        (await sync(
          request(
            {},
            "test-anon",
            missingCronSecret ? "test-cron" : "wrong-secret",
          ),
        )).status,
        401,
      );
      assertEquals(
        calls.filter((c) => c.url.pathname === "/rest/v1/plaid_items").length,
        0,
      );
      assertEquals(
        calls.filter((c) => c.url.hostname === "sandbox.plaid.com").length,
        0,
      );
    }, { badSession: true, missingCronSecret });
  }
});

Deno.test("Existing service-role callers remain compatible", async () => {
  await withServices(async (calls) => {
    assertEquals(
      (await (await sync(request({}, "test-service"))).json()).synced,
      1,
    );
    assertEquals(
      calls.filter((c) => c.url.pathname === "/auth/v1/user").length,
      0,
    );
  });
});

Deno.test("Unavailable cached account data fails without a paid fallback or a false retrieval timestamp", async () => {
  await withServices(async (calls) => {
    assertEquals(
      (await exchange(
        request({ public_token: "public", company_id: "company-1" }),
      )).status,
      400,
    );
    const result = await (await sync(request({}))).json();
    assertEquals([result.synced, result.failed], [0, 1]);
    assertEquals(
      calls.filter((c) =>
        c.url.pathname === "/rest/v1/institutions" && c.body?.last_synced_at
      ).length,
      0,
    );
  }, { malformedAccounts: true });
});
