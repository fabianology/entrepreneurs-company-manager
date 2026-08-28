const DAY_MS = 86_400_000;

export type BriefingObligation = {
  owner_user_id: string;
  due_at?: string | null;
  deferred_at?: string | null;
  snoozed_until?: string | null;
  severity: string;
  state: string;
};

function validDate(value?: string | null): Date | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function isImmediateCriticalItem(
  item: BriefingObligation,
  userId: string,
): boolean {
  return item.owner_user_id === userId && item.severity === "urgent" && item.state === "open";
}

export function isWeeklyBriefingItem(
  item: BriefingObligation,
  userId: string,
  now: Date,
): boolean {
  if (item.owner_user_id !== userId) return false;
  if (item.state === "open") {
    const dueAt = validDate(item.due_at);
    return item.due_at == null || (dueAt !== null && dueAt <= new Date(now.getTime() + 30 * DAY_MS));
  }
  if (item.state !== "snoozed") return false;

  const explicitDeferredAt = validDate(item.deferred_at);
  const legacySnoozedUntil = validDate(item.snoozed_until);
  const deferredAt = explicitDeferredAt ?? (
    legacySnoozedUntil ? new Date(legacySnoozedUntil.getTime() - 7 * DAY_MS) : null
  );
  return deferredAt !== null && deferredAt <= new Date(now.getTime() - 14 * DAY_MS);
}
