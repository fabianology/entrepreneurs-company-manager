import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    // 1. Authenticate the requesting user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    
    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error('Supabase environment variables missing')
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, { 
      global: { headers: { Authorization: authHeader } } 
    })
    
    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt)
    if (authError || !user) throw new Error('Unauthorized')

    // 2. Parse request body
    const bodyText = await req.text()
    if (!bodyText) throw new Error("Empty request body")
    const { institution_id } = JSON.parse(bodyText)
    
    if (!institution_id) throw new Error("Missing institution_id")

    // 3. Get Plaid Environment Variables
    const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')
    const plaidSecret = Deno.env.get('PLAID_SECRET')
    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'

    if (!plaidClientId || !plaidSecret) {
      throw new Error('Plaid secrets are missing from Edge Function environment')
    }

    // 4. Get the access token for this institution
    const { data: plaidItem, error: fetchError } = await supabase
      .from('plaid_items')
      .select('access_token')
      .eq('institution_id', institution_id)
      .single()

    // If there is no plaid item, the user might just be deleting a manual institution.
    // If there is a Plaid item, we must revoke it on Plaid's end.
    if (plaidItem && plaidItem.access_token) {
        // 5. Call Plaid API to remove the item
        const plaidPayload = {
            client_id: plaidClientId,
            secret: plaidSecret,
            access_token: plaidItem.access_token,
        }

        const plaidRes = await fetch(`https://${plaidEnv}.plaid.com/item/remove`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(plaidPayload)
        })

        const plaidData = await plaidRes.json()
        
        // Log error if it failed, but continue to delete from our DB anyway
        if (plaidData.error_code) {
            console.error(`Plaid item/remove failed for institution ${institution_id}:`, plaidData)
        }
    }

    // 6. Delete the institution from the database
    // (This will cascade and delete the plaid_item row automatically)
    const { error: deleteError } = await supabase
        .from('institutions')
        .delete()
        .eq('id', institution_id)

    if (deleteError) {
        throw new Error(`Database delete failed: ${deleteError.message}`)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    const errObj = error instanceof Error ? error : new Error(String(error))
    return new Response(JSON.stringify({ error: errObj.message }), { 
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
