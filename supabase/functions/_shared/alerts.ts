export type AlertRuleType =
  | "large_transaction"
  | "possible_duplicate"
  | "unusual_spending"
  | "balance_change"
  | "upcoming_payment"
  | "expiring_item"
  | "disconnected_institution";

export type AlertRule = {
  user_id?: string;
  rule_type: AlertRuleType;
  enabled: boolean;
  threshold_amount?: number | string | null;
  threshold_percent?: number | string | null;
  lookback_days?: number | null;
  lead_days?: number | null;
  config?: Record<string, unknown> | null;
};

export const DEFAULT_ALERT_RULES: ReadonlyArray<Omit<AlertRule, "user_id">> = [
  {
    rule_type: "large_transaction",
    enabled: true,
    threshold_amount: 1_000,
    lookback_days: 3,
  },
  { rule_type: "possible_duplicate", enabled: true, lookback_days: 3 },
  {
    rule_type: "unusual_spending",
    enabled: false,
    threshold_amount: 250,
    lookback_days: 90,
    config: { minimum_history: 10, multiplier: 3 },
  },
  {
    rule_type: "balance_change",
    enabled: false,
    threshold_amount: 500,
    threshold_percent: 25,
  },
  { rule_type: "upcoming_payment", enabled: true, lead_days: 7 },
  { rule_type: "expiring_item", enabled: true, lead_days: 30 },
  { rule_type: "disconnected_institution", enabled: true },
];

export function defaultAlertRows(userId: string): AlertRule[] {
  return DEFAULT_ALERT_RULES.map((rule) => ({
    user_id: userId,
    ...rule,
    config: rule.config ?? {},
  }));
}

export type AlertCandidate = {
  ruleType: AlertRuleType;
  sourceType:
    | "transaction"
    | "institution"
    | "subscription"
    | "loan"
    | "card"
    | "document";
  sourceId: string;
  eventVersion: string;
  severity: "info" | "attention" | "urgent";
  title: string;
  body: string;
  fingerprintParts: string[];
};

export type AlertEvaluationData = {
  transactions: any[];
  institutions: any[];
  cards: any[];
  documents: any[];
  subscriptions: any[];
  loans: any[];
  balanceSnapshots: any[];
};

function numberValue(value: unknown, fallback = 0): number {
  if (value === null || value === undefined || value === "") return fallback;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function validDate(value: unknown): Date | null {
  if (typeof value !== "string" || !value) return null;
  const date = new Date(value.length === 10 ? `${value}T00:00:00Z` : value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function daysBefore(now: Date, days: number): Date {
  return new Date(now.getTime() - days * 86_400_000);
}

function daysAfter(now: Date, days: number): Date {
  return new Date(now.getTime() + days * 86_400_000);
}

function normalizedMerchant(transaction: any): string {
  return String(transaction.merchant_name || transaction.name || "")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
}

function transactionAccount(transaction: any): string {
  return String(
    transaction.canonical_account_id || transaction.account_id || "",
  );
}

function isTransfer(transaction: any): boolean {
  const primary = String(transaction.personal_finance_primary || "")
    .toUpperCase();
  const categories = Array.isArray(transaction.category)
    ? transaction.category
    : [];
  return primary.includes("TRANSFER") ||
    categories.some((value: unknown) =>
      String(value).toUpperCase().includes("TRANSFER")
    );
}

function isVisibleExpense(transaction: any): boolean {
  return transaction.pending !== true &&
    transaction.is_superseded_duplicate !== true &&
    transaction.is_stale_pending_duplicate !== true &&
    numberValue(transaction.amount) > 0 &&
    !isTransfer(transaction);
}

function activeStatus(value: unknown): boolean {
  return !value || ["active", "current"].includes(String(value).toLowerCase());
}

function currencyValue(amount: number, currency: unknown): string {
  const code = typeof currency === "string" && currency.length === 3
    ? currency
    : "USD";
  try {
    return new Intl.NumberFormat("en-US", { style: "currency", currency: code })
      .format(amount);
  } catch {
    return `$${amount.toFixed(2)}`;
  }
}

function ruleNumber(
  rule: AlertRule,
  field: "threshold_amount" | "threshold_percent",
  fallback: number,
) {
  return numberValue(rule[field], fallback);
}

function dueWithin(value: unknown, now: Date, leadDays: number): Date | null {
  const due = validDate(value);
  if (!due || due < daysBefore(now, 1) || due > daysAfter(now, leadDays)) {
    return null;
  }
  return due;
}

function dateVersion(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function buildAlertCandidates(
  rules: AlertRule[],
  data: AlertEvaluationData,
  now = new Date(),
): AlertCandidate[] {
  const enabled = new Map(
    rules.filter((rule) => rule.enabled).map((rule) => [rule.rule_type, rule]),
  );
  const candidates: AlertCandidate[] = [];
  const transactions = data.transactions.filter(isVisibleExpense);

  const largeRule = enabled.get("large_transaction");
  if (largeRule) {
    const threshold = ruleNumber(largeRule, "threshold_amount", 1_000);
    const cutoff = daysBefore(now, largeRule.lookback_days ?? 3);
    for (const transaction of transactions) {
      const date = validDate(transaction.date);
      const amount = numberValue(transaction.amount);
      if (!date || date < cutoff || amount < threshold) continue;
      const merchant = transaction.merchant_name || transaction.name ||
        "A merchant";
      candidates.push({
        ruleType: "large_transaction",
        sourceType: "transaction",
        sourceId: transaction.id,
        eventVersion: transaction.plaid_transaction_id || transaction.id,
        severity: amount >= threshold * 2 ? "urgent" : "attention",
        title: "Large transaction detected",
        body: `${
          currencyValue(amount, transaction.currency)
        } at ${merchant} needs review.`,
        fingerprintParts: ["large_transaction", transaction.id],
      });
    }
  }

  const duplicateRule = enabled.get("possible_duplicate");
  if (duplicateRule) {
    const lookback = duplicateRule.lookback_days ?? 3;
    const cutoff = daysBefore(now, lookback);
    const recent = transactions
      .filter((transaction) =>
        (validDate(transaction.date)?.getTime() ?? 0) >= cutoff.getTime()
      )
      .sort((left, right) => {
        const dateOrder = String(left.date).localeCompare(String(right.date));
        return dateOrder || String(left.id).localeCompare(String(right.id));
      });
    const alertedDuplicateIDs = new Set<string>();
    for (let leftIndex = 0; leftIndex < recent.length; leftIndex += 1) {
      const left = recent[leftIndex];
      const leftDate = validDate(left.date);
      const merchant = normalizedMerchant(left);
      if (!leftDate || !merchant || numberValue(left.amount) < 5) continue;
      for (
        let rightIndex = leftIndex + 1;
        rightIndex < recent.length;
        rightIndex += 1
      ) {
        const right = recent[rightIndex];
        if (alertedDuplicateIDs.has(String(right.id))) continue;
        const rightDate = validDate(right.date);
        if (
          !rightDate ||
          Math.abs(rightDate.getTime() - leftDate.getTime()) >
            lookback * 86_400_000
        ) continue;
        if (transactionAccount(left) !== transactionAccount(right)) continue;
        if (normalizedMerchant(right) !== merchant) continue;
        if (
          Math.round(numberValue(left.amount) * 100) !==
            Math.round(numberValue(right.amount) * 100)
        ) continue;
        const ids = [String(left.id), String(right.id)].sort();
        alertedDuplicateIDs.add(String(right.id));
        candidates.push({
          ruleType: "possible_duplicate",
          sourceType: "transaction",
          sourceId: right.id,
          eventVersion: ids.join(":"),
          severity: "attention",
          title: "Possible duplicate transaction",
          body: `Two ${
            currencyValue(numberValue(right.amount), right.currency)
          } charges at ${
            right.merchant_name || right.name || "the same merchant"
          } may be duplicates.`,
          fingerprintParts: ["possible_duplicate", ...ids],
        });
      }
    }
  }

  const unusualRule = enabled.get("unusual_spending");
  if (unusualRule) {
    const lookback = unusualRule.lookback_days ?? 90;
    const minimumHistory = Math.max(
      5,
      numberValue(unusualRule.config?.minimum_history, 10),
    );
    const multiplier = Math.max(
      2,
      numberValue(unusualRule.config?.multiplier, 3),
    );
    const minimumAmount = ruleNumber(unusualRule, "threshold_amount", 250);
    const recentCutoff = daysBefore(now, 3);
    const historyCutoff = daysBefore(now, lookback);
    for (const transaction of transactions) {
      const date = validDate(transaction.date);
      if (!date || date < recentCutoff) continue;
      const category = String(
        transaction.personal_finance_primary || "UNCATEGORIZED",
      );
      const history = transactions.filter((candidate) => {
        const candidateDate = validDate(candidate.date);
        return candidate.id !== transaction.id && candidateDate !== null &&
          candidateDate >= historyCutoff && candidateDate < date &&
          String(candidate.personal_finance_primary || "UNCATEGORIZED") ===
            category;
      }).map((candidate) => numberValue(candidate.amount));
      if (history.length < minimumHistory) continue;
      const average = history.reduce((sum, value) => sum + value, 0) /
        history.length;
      const variance = history.reduce((sum, value) =>
        sum + (value - average) ** 2, 0) / history.length;
      const threshold = Math.max(
        minimumAmount,
        average * multiplier,
        average + 3 * Math.sqrt(variance),
      );
      const amount = numberValue(transaction.amount);
      if (amount < threshold) {
        continue;
      }
      candidates.push({
        ruleType: "unusual_spending",
        sourceType: "transaction",
        sourceId: transaction.id,
        eventVersion: transaction.plaid_transaction_id || transaction.id,
        severity: "attention",
        title: "Unusual spending detected",
        body: `${currencyValue(amount, transaction.currency)} at ${
          transaction.merchant_name || transaction.name || "a merchant"
        } is unusually high for this category.`,
        fingerprintParts: ["unusual_spending", transaction.id],
      });
    }
  }

  const balanceRule = enabled.get("balance_change");
  if (balanceRule) {
    const amountThreshold = ruleNumber(balanceRule, "threshold_amount", 500);
    const percentThreshold = ruleNumber(balanceRule, "threshold_percent", 25);
    const snapshots = new Map(data.balanceSnapshots.map((snapshot) => [
      `${snapshot.institution_id}:${snapshot.account_id}`,
      snapshot,
    ]));
    for (const institution of data.institutions) {
      for (
        const account of Array.isArray(institution.accounts_data)
          ? institution.accounts_data
          : []
      ) {
        const accountId = String(account.id || account.plaid_account_id || "");
        const current = numberValue(account.balance, Number.NaN);
        const previous = snapshots.get(`${institution.id}:${accountId}`);
        if (!accountId || !Number.isFinite(current) || !previous) continue;
        const prior = numberValue(previous.balance, Number.NaN);
        if (!Number.isFinite(prior)) continue;
        const change = Math.abs(current - prior);
        const percent = Math.abs(prior) > 0
          ? change / Math.abs(prior) * 100
          : 100;
        if (change < amountThreshold || percent < percentThreshold) continue;
        candidates.push({
          ruleType: "balance_change",
          sourceType: "institution",
          sourceId: institution.id,
          eventVersion: dateVersion(now),
          severity: "attention",
          title: "Significant balance change",
          body: `${account.name || "An account"} changed by ${
            currencyValue(change, account.currency)
          } since the previous sync.`,
          fingerprintParts: [
            "balance_change",
            institution.id,
            accountId,
            dateVersion(now),
            String(Math.round(current * 100)),
          ],
        });
      }
    }
  }

  const paymentRule = enabled.get("upcoming_payment");
  if (paymentRule) {
    const leadDays = paymentRule.lead_days ?? 7;
    for (const subscription of data.subscriptions) {
      const due = activeStatus(subscription.status) &&
        dueWithin(subscription.next_renewal_at, now, leadDays);
      if (!due) continue;
      candidates.push({
        ruleType: "upcoming_payment",
        sourceType: "subscription",
        sourceId: subscription.id,
        eventVersion: dateVersion(due),
        severity: "info",
        title: "Subscription payment coming up",
        body: `${subscription.name || "A subscription"} is scheduled for ${
          dateVersion(due)
        }.`,
        fingerprintParts: [
          "upcoming_payment",
          "subscription",
          subscription.id,
          dateVersion(due),
        ],
      });
    }
    for (const loan of data.loans) {
      const due = activeStatus(loan.status) &&
        dueWithin(loan.next_payment_at, now, leadDays);
      if (!due) continue;
      candidates.push({
        ruleType: "upcoming_payment",
        sourceType: "loan",
        sourceId: loan.id,
        eventVersion: dateVersion(due),
        severity: "attention",
        title: "Loan payment coming up",
        body: `${
          loan.name || loan.lender || "A loan"
        } has a payment scheduled for ${dateVersion(due)}.`,
        fingerprintParts: [
          "upcoming_payment",
          "loan",
          loan.id,
          dateVersion(due),
        ],
      });
    }
  }

  const expiryRule = enabled.get("expiring_item");
  if (expiryRule) {
    const leadDays = expiryRule.lead_days ?? 30;
    for (const card of data.cards) {
      const due = activeStatus(card.status) &&
        dueWithin(card.expires_at, now, leadDays);
      if (!due) continue;
      candidates.push({
        ruleType: "expiring_item",
        sourceType: "card",
        sourceId: card.id,
        eventVersion: dateVersion(due),
        severity: "attention",
        title: "Card expiration coming up",
        body: `${card.name || "A card"} expires by ${dateVersion(due)}.`,
        fingerprintParts: ["expiring_item", "card", card.id, dateVersion(due)],
      });
    }
    for (const document of data.documents) {
      const due = dueWithin(document.expires_at, now, leadDays);
      if (!due) continue;
      candidates.push({
        ruleType: "expiring_item",
        sourceType: "document",
        sourceId: document.id,
        eventVersion: dateVersion(due),
        severity: "attention",
        title: "Document expiration coming up",
        body: `${document.name || "A document"} expires by ${
          dateVersion(due)
        }.`,
        fingerprintParts: [
          "expiring_item",
          "document",
          document.id,
          dateVersion(due),
        ],
      });
    }
  }

  if (enabled.has("disconnected_institution")) {
    for (
      const institution of data.institutions.filter((value) =>
        value.is_disconnected === true
      )
    ) {
      const version = String(institution.last_synced_at || "not-synced");
      candidates.push({
        ruleType: "disconnected_institution",
        sourceType: "institution",
        sourceId: institution.id,
        eventVersion: version,
        severity: "urgent",
        title: "Bank connection needs attention",
        body: `${
          institution.name || "A bank connection"
        } needs to be reconnected.`,
        fingerprintParts: ["disconnected_institution", institution.id, version],
      });
    }
  }

  return candidates;
}

async function fingerprint(parts: string[]): Promise<string> {
  const bytes = new TextEncoder().encode(parts.join("\u001f"));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(
    new Uint8Array(digest),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

function rows(result: { data?: any; error?: any }, label: string): any[] {
  if (result.error) {
    throw new Error(`${label}: ${result.error.message || result.error}`);
  }
  return result.data ?? [];
}

export async function evaluateUserAlerts(
  admin: any,
  userId: string,
  now = new Date(),
): Promise<{ evaluated: number; created: number }> {
  const defaults = defaultAlertRows(userId);
  const { error: seedError } = await admin.from("alert_rules")
    .upsert(defaults, {
      onConflict: "user_id,rule_type",
      ignoreDuplicates: true,
    });
  if (seedError) throw seedError;

  const rulesResult = await admin.from("alert_rules").select("*").eq(
    "user_id",
    userId,
  );
  const rules = rows(rulesResult, "alert rules") as AlertRule[];
  const maxLookback = Math.max(
    90,
    ...rules.map((rule) => rule.lookback_days ?? 0),
  );
  const transactionCutoff = daysBefore(now, maxLookback).toISOString().slice(
    0,
    10,
  );

  const results = await Promise.all([
    admin.from("plaid_transactions")
      .select(
        "id,plaid_transaction_id,account_id,canonical_account_id,amount,currency,category,merchant_name,name,date,pending,personal_finance_primary,is_superseded_duplicate,is_stale_pending_duplicate",
      )
      .eq("user_id", userId).gte("date", transactionCutoff),
    admin.from("institutions")
      .select("id,name,accounts_data,is_disconnected,last_synced_at").eq(
        "user_id",
        userId,
      ),
    admin.from("financial_cards").select("id,name,status,expires_at").eq(
      "user_id",
      userId,
    ),
    admin.from("company_documents").select("id,name,expires_at").eq(
      "user_id",
      userId,
    ),
    admin.from("subscriptions").select("id,name,status,next_renewal_at").eq(
      "user_id",
      userId,
    ),
    admin.from("loans").select("id,name,lender,status,next_payment_at").eq(
      "user_id",
      userId,
    ),
    admin.from("alert_balance_snapshots").select("*").eq("user_id", userId),
  ]);

  const data: AlertEvaluationData = {
    transactions: rows(results[0], "transactions"),
    institutions: rows(results[1], "institutions"),
    cards: rows(results[2], "cards"),
    documents: rows(results[3], "documents"),
    subscriptions: rows(results[4], "subscriptions"),
    loans: rows(results[5], "loans"),
    balanceSnapshots: rows(results[6], "balance snapshots"),
  };
  const candidates = buildAlertCandidates(rules, data, now);
  let created = 0;
  for (const candidate of candidates) {
    const { data: eventId, error } = await admin.rpc(
      "record_miloom_alert_event",
      {
        p_user_id: userId,
        p_rule_type: candidate.ruleType,
        p_source_type: candidate.sourceType,
        p_source_id: candidate.sourceId,
        p_event_version: candidate.eventVersion,
        p_severity: candidate.severity,
        p_title: candidate.title,
        p_body: candidate.body,
        p_fingerprint: await fingerprint(candidate.fingerprintParts),
      },
    );
    if (error) throw error;
    if (eventId) created += 1;
  }

  const snapshots = data.institutions.flatMap((institution) =>
    (Array.isArray(institution.accounts_data) ? institution.accounts_data : [])
      .flatMap((account: any) => {
        const accountId = String(account.id || account.plaid_account_id || "");
        const balance = numberValue(account.balance, Number.NaN);
        if (!accountId || !Number.isFinite(balance)) return [];
        return [{
          user_id: userId,
          institution_id: institution.id,
          account_id: accountId,
          balance,
          currency: typeof account.currency === "string"
            ? account.currency
            : "USD",
          observed_at: now.toISOString(),
        }];
      })
  );
  if (snapshots.length > 0) {
    const { error } = await admin.from("alert_balance_snapshots")
      .upsert(snapshots, { onConflict: "user_id,institution_id,account_id" });
    if (error) throw error;
  }

  return { evaluated: candidates.length, created };
}
