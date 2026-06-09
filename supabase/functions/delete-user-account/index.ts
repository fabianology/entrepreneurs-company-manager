import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    // 1. Authenticate the request
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRole) {
      throw new Error('Supabase environment variables missing')
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, { 
      global: { headers: { Authorization: authHeader } } 
    })
    
    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt)
    if (authError || !user) throw new Error('Unauthorized')

    // 2. Initialize Admin Client
    const adminClient = createClient(supabaseUrl, supabaseServiceRole)

    // 3. Get Plaid Environment Variables
    const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')
    const plaidSecret = Deno.env.get('PLAID_SECRET')
    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'

    if (plaidClientId && plaidSecret) {
      // 4. Fetch all Plaid connections for the user
      const { data: plaidItems, error: itemsError } = await adminClient
        .from('plaid_items')
        .select('access_token, item_id')
        .eq('user_id', user.id)

      if (!itemsError && plaidItems && plaidItems.length > 0) {
        // 5. Explicitly revoke each Plaid access token
        for (const item of plaidItems) {
          try {
            await fetch(`https://${plaidEnv}.plaid.com/item/remove`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                client_id: plaidClientId,
                secret: plaidSecret,
                access_token: item.access_token
              })
            })
            // Ignore individual fetch errors so we can continue with other deletions
          } catch (e) {
            console.error(`Failed to remove Plaid item ${item.item_id}:`, e)
          }
        }
      }
    }

    // 6. Delete user's data from Supabase
    // We explicitly delete top-level records to ensure cleanup even if CASCADE is missing
    
    // Delete plaid_items
    await adminClient.from('plaid_items').delete().eq('user_id', user.id)
    
    // Delete companies (assuming owner_id links to user.id, adjust if needed)
    await adminClient.from('companies').delete().eq('owner_id', user.id)
    
    // Delete activity logs
    await adminClient.from('activity_logs').delete().eq('user_id', user.id)

    // 7. Delete the user from Supabase Auth
    const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(user.id)
    
    if (deleteUserError) {
      throw new Error(`Failed to delete user profile: ${deleteUserError.message}`)
    }

    return new Response(JSON.stringify({ success: true }), { 
      status: 200,
      headers: { 'Content-Type': 'application/json' } 
    })
  } catch (error) {
    const errObj = error instanceof Error ? error : new Error(String(error))
    return new Response(JSON.stringify({ error: errObj.message }), { 
      status: 400,
      headers: { 'Content-Type': 'application/json' } 
    })
  }
})
