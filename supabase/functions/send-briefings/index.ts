import { createClient } from "npm:@supabase/supabase-js@2";
import { json } from "../_shared/http.ts";
import { sendPrivateBriefing } from "../_shared/apns.ts";

type Preference = {
  user_id: string;
  briefing_weekday?: number;
  briefing_time?: string;
  timezone?: string;
  weekly_briefing_enabled?: boolean;
  critical_alerts_enabled?: boolean;
};

function localSchedule(now: Date, preference?: Preference) {
  const timezone = preference?.timezone || "UTC";
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    weekday: "short", year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(now);
  const value = (type: string) => parts.find((part) => part.type === type)?.value ?? "";
  const weekday = ({ Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 } as Record<string, number>)[value("weekday")];
  return {
    weekday,
    hour: Number(value("hour")),
    minute: Number(value("minute")),
    date: `${value("year")}-${value("month")}-${value("day")}`,
    targetWeekday: preference?.briefing_weekday ?? 1,
    targetHour: Number((preference?.briefing_time || "08:00").slice(0, 2)),
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (request.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return json({ error: "Unauthorized" }, 401);
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { error: refreshError } = await admin.rpc("refresh_miloom_obligations", { p_user_id: null });
  if (refreshError) return json({ error: refreshError.message }, 500);
  await admin.rpc("maintain_miloom_downgrades");

  const [{ data: entitlements }, { data: preferences }, { data: tokens }, { data: obligations }] = await Promise.all([
    admin.from("user_entitlements").select("user_id,status,grace_ends_at").eq("tier", "pro").in("status", ["trial", "active", "grace"]),
    admin.from("user_preferences").select("user_id,briefing_weekday,briefing_time,timezone,weekly_briefing_enabled,critical_alerts_enabled"),
    admin.from("device_push_tokens").select("user_id,token,environment"),
    admin.from("obligations").select("owner_user_id,id,due_at,severity,state,snoozed_until").in("state", ["open", "snoozed"]),
  ]);

  const prefs = new Map((preferences ?? []).map((value) => [value.user_id, value as Preference]));
  const now = new Date();
  let delivered = 0;

  // Optional immediate alerts are still private: only a generic item count is sent.
  for (const entitlement of entitlements ?? []) {
    if (entitlement.status === "grace" && entitlement.grace_ends_at && new Date(entitlement.grace_ends_at) < now) continue;
    const preference = prefs.get(entitlement.user_id);
    if (!preference || preference.critical_alerts_enabled !== true) continue;
    const urgent = (obligations ?? []).filter((item) =>
      item.owner_user_id === entitlement.user_id && item.severity === "urgent" && item.state === "open"
    );
    let newlyClaimed = 0;
    for (const item of urgent) {
      const { error } = await admin.from("critical_alert_deliveries").insert({
        user_id: entitlement.user_id, obligation_id: item.id,
      });
      if (!error) newlyClaimed += 1;
    }
    if (newlyClaimed > 0) {
      const userTokens = (tokens ?? []).filter((token) => token.user_id === entitlement.user_id);
      await Promise.allSettled(userTokens.map((token) =>
        sendPrivateBriefing(token.token, newlyClaimed, token.environment, true)
      ));
    }
  }

  for (const entitlement of entitlements ?? []) {
    if (entitlement.status === "grace" && entitlement.grace_ends_at && new Date(entitlement.grace_ends_at) < now) continue;
    const preference = prefs.get(entitlement.user_id);
    if (preference?.weekly_briefing_enabled === false) continue;
    const schedule = localSchedule(now, preference);
    if (schedule.weekday !== schedule.targetWeekday || schedule.hour !== schedule.targetHour || schedule.minute >= 15) continue;

    const active = (obligations ?? []).filter((item) =>
      item.owner_user_id === entitlement.user_id &&
      (item.state === "open" || !item.snoozed_until || new Date(item.snoozed_until) <= now) &&
      (!item.due_at || new Date(item.due_at) <= new Date(now.getTime() + 30 * 86_400_000))
    );
    if (!active.length) continue;

    const { error: claimError } = await admin.from("briefing_deliveries").insert({
      user_id: entitlement.user_id,
      local_date: schedule.date,
      item_count: active.length,
    });
    if (claimError) continue; // already delivered, or another worker won the claim

    const userTokens = (tokens ?? []).filter((token) => token.user_id === entitlement.user_id);
    const results = await Promise.allSettled(userTokens.map((token) =>
      sendPrivateBriefing(token.token, active.length, token.environment)
    ));
    if (results.some((result) => result.status === "fulfilled")) delivered += 1;

    await admin.from("app_notifications").insert({
      user_id: entitlement.user_id,
      notification_type: "owner_briefing",
      title: "Weekly Owner Briefing",
      body: `${active.length} items need your attention this week.`,
      is_read: false,
    });
  }
  return json({ ok: true, delivered });
});
