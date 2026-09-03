const DAY_MS = 86_400_000;

export type BriefingObligation = {
  owner_user_id: string;
  due_at?: string | null;
  deferred_at?: string | null;
  snoozed_until?: string | null;
  severity: string;
  state: string;
};

export type WeeklyBriefingSchedule = {
  weekday: number;
  hour: number;
  minute: number;
  targetWeekday: number;
  targetHour: number;
  targetMinute: number;
};

const MINUTES_PER_DAY = 24 * 60;
const MINUTES_PER_WEEK = 7 * MINUTES_PER_DAY;

/**
 * Returns true for the 15 minutes after the owner's chosen local briefing
 * time. This makes an every-15-minute worker honor an exact minute selection
 * without sending the same briefing more than once; the delivery claim remains
 * the final deduplication guard.
 */
export function isWeeklyBriefingDue(schedule: WeeklyBriefingSchedule): boolean {
  const values = [
    schedule.weekday,
    schedule.hour,
    schedule.minute,
    schedule.targetWeekday,
    schedule.targetHour,
    schedule.targetMinute,
  ];
  if (
    values.some((value) => !Number.isInteger(value)) ||
    schedule.weekday < 1 || schedule.weekday > 7 ||
    schedule.targetWeekday < 1 || schedule.targetWeekday > 7 ||
    schedule.hour < 0 || schedule.hour > 23 ||
    schedule.targetHour < 0 || schedule.targetHour > 23 ||
    schedule.minute < 0 || schedule.minute > 59 ||
    schedule.targetMinute < 0 || schedule.targetMinute > 59
  ) return false;

  const currentWeekMinute = (schedule.weekday - 1) * MINUTES_PER_DAY +
    schedule.hour * 60 + schedule.minute;
  const targetWeekMinute = (schedule.targetWeekday - 1) * MINUTES_PER_DAY +
    schedule.targetHour * 60 + schedule.targetMinute;
  const elapsed = (currentWeekMinute - targetWeekMinute + MINUTES_PER_WEEK) %
    MINUTES_PER_WEEK;
  return elapsed < 15;
}

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
