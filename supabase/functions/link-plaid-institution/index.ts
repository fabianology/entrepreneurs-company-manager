import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!supabaseUrl || !supabaseAnonKey || !serviceRole) {
      throw new Error('Supabase environment variables missing')
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const jwt = authHeader.replace(/^Bearer\s+/i, '')
    const { data: { user }, error: authError } = await userClient.auth.getUser(jwt)
    if (authError || !user) throw new Error('Unauthorized')

    const { item_id, institution_id } = await req.json()
    if (!item_id || !institution_id) throw new Error('Missing item_id or institution_id')

    const admin = createClient(supabaseUrl, serviceRole)
    const { data: institution, error: institutionError } = await admin
      .from('institutions')
      .select('id,user_id,company_id')
      .eq('id', institution_id)
      .eq('user_id', user.id)
      .single()
    if (institutionError || !institution) throw new Error('Institution was not found for this user')

    const { data: item, error: itemError } = await admin
      .from('plaid_items')
      .select('id,plaid_institution_id')
      .eq('item_id', item_id)
      .eq('user_id', user.id)
      .single()
    if (itemError || !item) throw new Error('Plaid connection was not found for this user')

    // A reconnect or reinstall can produce a new Item for an existing visible
    // institution. Archive the replaced row before activating the new one so
    // history stays intact and the unique active-connection invariant holds.
    const { error: replaceError } = await admin
      .from('plaid_items')
      .update({
        status: 'archived',
        error_code: 'SUPERSEDED_CONNECTION',
        updated_at: new Date().toISOString()
      })
      .eq('user_id', user.id)
      .eq('institution_id', institution.id)
      .eq('status', 'active')
      .neq('id', item.id)
    if (replaceError) throw replaceError

    const { error: updateError } = await admin
      .from('plaid_items')
      .update({
        institution_id: institution.id,
        company_id: institution.company_id,
        status: 'active',
        error_code: null,
        updated_at: new Date().toISOString()
      })
      .eq('id', item.id)
      .eq('user_id', user.id)
    if (updateError) throw updateError

    // Archive only orphaned rows. A second legitimate login remains active when
    // it is linked to its own visible institution record.
    const { data: archived, error: archiveError } = await admin
      .from('plaid_items')
      .update({
        status: 'archived',
        error_code: 'SUPERSEDED_CONNECTION',
        updated_at: new Date().toISOString()
      })
      .eq('user_id', user.id)
      .eq('plaid_institution_id', item.plaid_institution_id)
      .eq('status', 'active')
      .is('institution_id', null)
      .neq('id', item.id)
      .select('id')
    if (archiveError) throw archiveError

    return new Response(JSON.stringify({
      success: true,
      archived_connections: archived?.length ?? 0
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
