import {
  type BriefingObligation,
  isImmediateCriticalItem,
  isWeeklyBriefingDue,
  isWeeklyBriefingItem,
} from "./briefing.ts";

const DAY_MS = 86_400_000;
const now = new Date("2027-05-05T12:00:00.000Z");

function obligation(overrides: Partial<BriefingObligation> = {}): BriefingObligation {
  return {
    owner_user_id: "owner",
    severity: "attention",
    state: "open",
    ...overrides,
  };
}

function assertEqual(actual: boolean, expected: boolean, message: string) {
  if (actual !== expected) throw new Error(`${message}: expected ${expected}, received ${actual}`);
}

Deno.test("weekly briefing includes open items due within 30 days", () => {
  assertEqual(
    isWeeklyBriefingItem(
      obligation({
        due_at: new Date(now.getTime() + 30 * DAY_MS).toISOString(),
      }),
      "owner",
      now,
    ),
    true,
    "30-day item",
  );
  assertEqual(
    isWeeklyBriefingItem(
      obligation({
        due_at: new Date(now.getTime() + 31 * DAY_MS).toISOString(),
      }),
      "owner",
      now,
    ),
    false,
    "31-day item",
  );
});

Deno.test("weekly briefing starts including deferred items at 14 days", () => {
  assertEqual(
    isWeeklyBriefingItem(
      obligation({
        state: "snoozed",
        deferred_at: new Date(now.getTime() - 14 * DAY_MS).toISOString(),
      }),
      "owner",
      now,
    ),
    true,
    "14-day deferred item",
  );
  assertEqual(
    isWeeklyBriefingItem(
      obligation({
        state: "snoozed",
        deferred_at: new Date(now.getTime() - 14 * DAY_MS + 1).toISOString(),
      }),
      "owner",
      now,
    ),
    false,
    "item just under 14 days",
  );
});

Deno.test("weekly briefing derives legacy deferral time from snoozed_until", () => {
  const legacyReturnDate = new Date(now.getTime() - 7 * DAY_MS).toISOString();
  assertEqual(
    isWeeklyBriefingItem(
      obligation({ state: "snoozed", snoozed_until: legacyReturnDate }),
      "owner",
      now,
    ),
    true,
    "legacy 14-day deferred item",
  );
});

Deno.test("immediate critical alerts never include deferred items", () => {
  assertEqual(
    isImmediateCriticalItem(
      obligation({ severity: "urgent", state: "open" }),
      "owner",
    ),
    true,
    "open urgent item",
  );
  assertEqual(
    isImmediateCriticalItem(
      obligation({ severity: "urgent", state: "snoozed" }),
      "owner",
    ),
    false,
    "deferred urgent item",
  );
});

Deno.test("weekly briefing honors the selected minute for a 15-minute worker window", () => {
  assertEqual(
    isWeeklyBriefingDue({
      weekday: 4, hour: 10, minute: 15,
      targetWeekday: 4, targetHour: 10, targetMinute: 6,
    }),
    true,
    "nine minutes after the selected time",
  );
  assertEqual(
    isWeeklyBriefingDue({
      weekday: 4, hour: 10, minute: 21,
      targetWeekday: 4, targetHour: 10, targetMinute: 6,
    }),
    false,
    "fifteen minutes after the selected time",
  );
});

Deno.test("weekly briefing window carries across midnight", () => {
  assertEqual(
    isWeeklyBriefingDue({
      weekday: 5, hour: 0, minute: 5,
      targetWeekday: 4, targetHour: 23, targetMinute: 58,
    }),
    true,
    "seven minutes after Thursday 23:58",
  );
});
