// Pure policy: no credentials, storage, provider calls, or model-written explanations.
export const POLICY_VERSION = "business-review-v1";
export type SourceTransaction = {
  id: string; user_id: string; account_id: string; canonical_account_id?: string;
  amount: number | null; currency: string; date: string; name?: string; merchant_name?: string;
  personal_finance_primary?: string; personal_finance_detailed?: string; category?: string[];
  screening_excluded?: boolean; pending?: boolean; is_superseded_duplicate?: boolean; is_stale_pending_duplicate?: boolean;
};
export type Correction = { merchant_name?: string; category_primary?: string; category_detailed?: string; flow_override?: string };
export type Profile = { company_id: string; activity: string; enabled: boolean };
export type Evidence = { id: string; company_id: string; merchant: string; decision?: string };
export function sanitize(value: string | undefined, limit = 160): string {
  return (value ?? "").replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, "[email]")
    .replace(/\b(?:\d[ -]?){6,}\b/g, "[number]").replace(/[\u0000-\u001f]/g, " ").slice(0, limit);
}
export function merchantKey(value: string): string { return value.toLowerCase().replace(/[^a-z0-9]/g, ""); }
export function eligible(t: SourceTransaction, correction: Correction = {}, excluded: string[] = []): boolean {
  if (t.screening_excluded || t.pending || t.is_superseded_duplicate || t.is_stale_pending_duplicate || t.amount == null || !Number.isFinite(t.amount) || t.amount === 0) return false;
  if (excluded.includes(t.account_id) || excluded.includes(t.canonical_account_id ?? t.account_id)) return false;
  if (correction.flow_override) return correction.flow_override === "expense";
  if (t.amount < 0) return false;
  const category = [t.personal_finance_primary,t.personal_finance_detailed,...(t.category ?? [])].join(" ").toLowerCase();
  if (["transfer","payment","cash","deposit","withdrawal"].some(x => category.includes(x))) return false;
  return !/\bzelle\b|\batm\b|\bwithdrawal\b|\bpayment to\b|\bautopay\b|\bmonthly payment\b|\b(card|loan) payment\b|\btransfer (to|from)\b|\bmobile check deposit\b/i.test(correction.merchant_name || t.merchant_name || t.name || "");
}
export function features(t: SourceTransaction, correction: Correction, profiles: Profile[], evidence: Evidence[]) {
  const merchant = sanitize(correction.merchant_name || t.merchant_name || t.name);
  const matches = evidence.filter(e => merchantKey(e.merchant) === merchantKey(merchant));
  return {
    transaction_ref: t.id, merchant, amount: Math.abs(t.amount!), currency: t.currency,
    date: t.date, category: sanitize(correction.category_primary || t.personal_finance_primary || t.category?.[0]),
    detail: sanitize(correction.category_detailed || t.personal_finance_detailed),
    prior_personal_examples: matches.filter(e => e.decision === "personal").slice(0, 6).length,
    account_use: "unknown", // Account ownership is not itself evidence of business use.
    entities: profiles.filter(p => p.enabled && p.activity.trim()).map(p => ({
      entity_ref: p.company_id, activity: sanitize(p.activity, 500),
      confirmations: matches.filter(e => e.company_id === p.company_id && e.decision !== "personal").slice(0, 6).map(e => e.id),
    })),
  };
}
export type Feature = ReturnType<typeof features>;
export type ValidCandidate = { company_id: string; score: number; confidence: string; explanation: string; evidence_ids: string[] };
export function validateCandidates(raw: unknown, input: Feature): ValidCandidate[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const candidates: ValidCandidate[] = [];
  for (const value of raw) {
    if (!value || typeof value !== "object") continue;
    const v = value as Record<string, unknown>;
    const profile = input.entities.find(p => p.entity_ref === v.entity_ref);
    if (!profile || seen.has(profile.entity_ref) || typeof v.score !== "number" || !Number.isFinite(v.score) || v.score < 0.65 || v.score > 1) continue;
    if (!Array.isArray(v.evidence_ids) || v.evidence_ids.some(id => typeof id !== "string" || !profile.confirmations.includes(id))) continue;
    const evidence = [...new Set(v.evidence_ids as string[])];
    const high = v.score >= 0.85 && evidence.length >= 3;
    const explanation = evidence.length > 0
      ? `You associated ${evidence.length} previous ${input.merchant || "similar merchant"} charge${evidence.length === 1 ? "" : "s"} with this Entity.`
      : "This purchase may relate to the business activity you described. Please confirm its purpose.";
    seen.add(profile.entity_ref);
    candidates.push({ company_id: profile.entity_ref, score: v.score, confidence: high ? "high" : "worth_reviewing", explanation, evidence_ids: evidence });
  }
  candidates.sort((a,b) => b.score-a.score);
  if (candidates.length > 1 && candidates[0].score-candidates[1].score >= 0.15) return [candidates[0]];
  return candidates.slice(0, 3);
}
export async function fingerprint(value: unknown): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify(value)));
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2,"0")).join("");
}
