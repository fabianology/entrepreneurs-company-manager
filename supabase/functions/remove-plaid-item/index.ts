import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"
import {
  PlaidAPIError,
  plaidConfigFromEnvironment,
  plaidRequest,
} from "../_shared/plaid.ts"

serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) throw new Error("Missing Authorization header")

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!supabaseUrl || !supabaseAnonKey || !serviceRole) {
      throw new Error("Supabase environment variables missing")
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const jwt = authHeader.replace(/^Bearer\s+/i, "")
    const { data: { user }, error: authError } = await userClient.auth.getUser(jwt)
    if (authError || !user) throw new Error("Unauthorized")

    const { institution_id } = await req.json()
    if (!institution_id) throw new Error("Missing institution_id")

    const admin = createClient(supabaseUrl, serviceRole)
    const { data: institution, error: institutionError } = await admin
      .from("institutions")
      .select("id,user_id,company_id,name")
      .eq("id", institution_id)
      .eq("user_id", user.id)
      .maybeSingle()
    if (institutionError) throw institutionError

    // An already-completed retry is successful, but never let a user target an
    // existing institution owned by somebody else.
    if (!institution) {
      const { count, error: remainingError } = await admin
        .from("plaid_items")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
        .eq("institution_id", institution_id)
      if (remainingError) throw remainingError
      return jsonResponse({
        success: (count ?? 0) === 0,
        removed_items: 0,
        remaining_items: count ?? 0,
        institution_deleted: (count ?? 0) === 0,
      })
    }

    const { data: items, error: itemsError } = await admin
      .from("plaid_items")
      .select("id,access_token")
      .eq("user_id", user.id)
      .eq("institution_id", institution_id)
    if (itemsError) throw itemsError

    const plaidConfig = (items?.length ?? 0) > 0
      ? plaidConfigFromEnvironment()
      : null
    let removedItems = 0
    for (const item of items ?? []) {
      try {
        await plaidRequest(plaidConfig!, "/item/remove", {
          access_token: item.access_token,
        })
      } catch (error) {
        // This means Plaid no longer recognizes the Item, so local cleanup is
        // safe and makes retries idempotent.
        if (!(error instanceof PlaidAPIError) || error.errorCode !== "INVALID_ACCESS_TOKEN") {
          throw error
        }
      }

      const { error: webhookEventError } = await admin
        .from("plaid_webhook_events")
        .delete()
        .eq("plaid_item_id", item.id)
      if (webhookEventError) throw webhookEventError

      const { error: deleteItemError } = await admin
        .from("plaid_items")
        .delete()
        .eq("id", item.id)
        .eq("user_id", user.id)
      if (deleteItemError) throw deleteItemError
      removedItems += 1
    }

    // Match the app's existing institution cascade. Service-role deletes are
    // constrained by the authenticated owner's verified company and bank name.
    const { error: cardsError } = await admin
      .from("financial_cards")
      .delete()
      .eq("user_id", user.id)
      .eq("company_id", institution.company_id)
      .eq("institution_name", institution.name)
    if (cardsError) throw cardsError

    const { error: loansError } = await admin
      .from("loans")
      .delete()
      .eq("user_id", user.id)
      .eq("company_id", institution.company_id)
      .eq("lender", institution.name)
    if (loansError) throw loansError

    const { error: deleteInstitutionError } = await admin
      .from("institutions")
      .delete()
      .eq("id", institution.id)
      .eq("user_id", user.id)
    if (deleteInstitutionError) throw deleteInstitutionError

    const { count: remainingItems, error: remainingError } = await admin
      .from("plaid_items")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("institution_id", institution_id)
    if (remainingError) throw remainingError

    const { count: remainingInstitutions, error: verifyInstitutionError } = await admin
      .from("institutions")
      .select("id", { count: "exact", head: true })
      .eq("id", institution_id)
      .eq("user_id", user.id)
    if (verifyInstitutionError) throw verifyInstitutionError

    const confirmed = (remainingItems ?? 0) === 0 && (remainingInstitutions ?? 0) === 0
    return jsonResponse({
      success: confirmed,
      removed_items: removedItems,
      remaining_items: remainingItems ?? 0,
      institution_deleted: (remainingInstitutions ?? 0) === 0,
    }, confirmed ? 200 : 500)
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return jsonResponse({ error: message }, 400)
  }
})

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
