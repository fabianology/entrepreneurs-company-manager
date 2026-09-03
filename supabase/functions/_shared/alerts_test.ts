import { assertEquals } from "jsr:@std/assert@1";
import {
  type AlertEvaluationData,
  type AlertRule,
  buildAlertCandidates,
  defaultAlertRows,
} from "./alerts.ts";

const now = new Date("2026-08-31T12:00:00Z");

function data(
  overrides: Partial<AlertEvaluationData> = {},
): AlertEvaluationData {
  return {
    transactions: [],
    institutions: [],
    cards: [],
    documents: [],
    subscriptions: [],
    loans: [],
    balanceSnapshots: [],
    ...overrides,
  };
}

function rule(
  value: Partial<AlertRule> & Pick<AlertRule, "rule_type">,
): AlertRule {
  return { enabled: true, ...value };
}

Deno.test("default alert rows always provide non-null config", () => {
  const rows = defaultAlertRows("user-id");
  assertEquals(rows.every((row) => row.config !== null), true);
  assertEquals(rows.find((row) => row.rule_type === "large_transaction")?.config, {});
  assertEquals(
    rows.find((row) => row.rule_type === "unusual_spending")?.config,
    { minimum_history: 10, multiplier: 3 },
  );
});

Deno.test("large transaction alerts ignore transfers and older history", () => {
  const candidates = buildAlertCandidates(
    [
      rule({
        rule_type: "large_transaction",
        threshold_amount: 1_000,
        lookback_days: 3,
      }),
    ],
    data({
      transactions: [
        {
          id: "recent",
          amount: 1_500,
          date: "2026-08-30",
          merchant_name: "Vendor",
        },
        {
          id: "transfer",
          amount: 2_000,
          date: "2026-08-30",
          personal_finance_primary: "TRANSFER_OUT",
        },
        {
          id: "old",
          amount: 5_000,
          date: "2026-08-01",
          merchant_name: "Old Vendor",
        },
      ],
    }),
    now,
  );
  assertEquals(candidates.map((candidate) => candidate.sourceId), ["recent"]);
});

Deno.test("duplicate rule requires same account merchant amount and nearby dates", () => {
  const candidates = buildAlertCandidates(
    [
      rule({ rule_type: "possible_duplicate", lookback_days: 3 }),
    ],
    data({
      transactions: [
        {
          id: "one",
          account_id: "account",
          amount: 15,
          date: "2026-08-30",
          merchant_name: "Figma",
        },
        {
          id: "two",
          account_id: "account",
          amount: 15,
          date: "2026-08-31",
          merchant_name: "FIGMA*",
        },
        {
          id: "other",
          account_id: "other-account",
          amount: 15,
          date: "2026-08-31",
          merchant_name: "Figma",
        },
        {
          id: "three",
          account_id: "account",
          amount: 15,
          date: "2026-08-31",
          merchant_name: "Figma",
        },
      ],
    }),
    now,
  );
  assertEquals(candidates.length, 2);
  assertEquals(candidates[0].ruleType, "possible_duplicate");
});

Deno.test("unusual spending requires sufficient comparable history", () => {
  const history = Array.from({ length: 10 }, (_, index) => ({
    id: `history-${index}`,
    amount: 20,
    date: `2026-08-${String(10 + index).padStart(2, "0")}`,
    personal_finance_primary: "FOOD_AND_DRINK",
  }));
  const candidates = buildAlertCandidates(
    [
      rule({
        rule_type: "unusual_spending",
        threshold_amount: 100,
        lookback_days: 90,
        config: { minimum_history: 10, multiplier: 3 },
      }),
    ],
    data({
      transactions: [
        ...history,
        {
          id: "unusual",
          amount: 250,
          date: "2026-08-31",
          merchant_name: "Dinner",
          personal_finance_primary: "FOOD_AND_DRINK",
        },
      ],
    }),
    now,
  );
  assertEquals(candidates.map((candidate) => candidate.sourceId), ["unusual"]);
});

Deno.test("balance alerts require both amount and percentage thresholds", () => {
  const candidates = buildAlertCandidates(
    [
      rule({
        rule_type: "balance_change",
        threshold_amount: 500,
        threshold_percent: 25,
      }),
    ],
    data({
      institutions: [{
        id: "institution",
        accounts_data: [{
          id: "account",
          name: "Checking",
          balance: 1_500,
          currency: "USD",
        }],
      }],
      balanceSnapshots: [{
        institution_id: "institution",
        account_id: "account",
        balance: 1_000,
      }],
    }),
    now,
  );
  assertEquals(candidates.length, 1);
  assertEquals(candidates[0].sourceType, "institution");
});

Deno.test("time-based and disconnected rules produce stable resource alerts", () => {
  const candidates = buildAlertCandidates(
    [
      rule({ rule_type: "upcoming_payment", lead_days: 7 }),
      rule({ rule_type: "expiring_item", lead_days: 30 }),
      rule({ rule_type: "disconnected_institution" }),
    ],
    data({
      subscriptions: [{
        id: "subscription",
        name: "Hosting",
        status: "Active",
        next_renewal_at: "2026-09-03T00:00:00Z",
      }],
      cards: [{
        id: "card",
        name: "Business card",
        status: "Active",
        expires_at: "2026-09-20T00:00:00Z",
      }],
      institutions: [{
        id: "institution",
        name: "Bank",
        is_disconnected: true,
        last_synced_at: "2026-08-30T00:00:00Z",
      }],
    }),
    now,
  );
  assertEquals(candidates.map((candidate) => candidate.ruleType), [
    "upcoming_payment",
    "expiring_item",
    "disconnected_institution",
  ]);
});
