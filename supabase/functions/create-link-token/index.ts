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
    const { company_id, institution_id } = JSON.parse(bodyText)
    
    if (!company_id) throw new Error("Missing company_id")

    // 3. Get Plaid Environment Variables
    const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')
    const plaidSecret = Deno.env.get('PLAID_SECRET')
    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'

    if (!plaidClientId || !plaidSecret) {
      throw new Error('Plaid secrets are missing from Edge Function environment')
    }

    // 4. Check if this is an Update Mode request (has institution_id)
    let accessToken: string | undefined = undefined
    if (institution_id) {
        const { data: itemData, error: itemError } = await supabase
            .from('plaid_items')
            .select('access_token')
            .eq('institution_id', institution_id)
            .single()
            
        if (!itemError && itemData) {
            accessToken = itemData.access_token
        }
    }

    // 5. Call Plaid API to create link token
    const plaidPayload: any = {
      client_id: plaidClientId,
      secret: plaidSecret,
      user: { client_user_id: user.id },
      client_name: 'Miloom',
      country_codes: ['US'],
      language: 'en',
    }

    if (accessToken) {
      // Update Mode
      plaidPayload.access_token = accessToken
    } else {
      // Standard Mode
      plaidPayload.products = ['transactions', 'auth']
    }

    const plaidRes = await fetch(`https://${plaidEnv}.plaid.com/link/token/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(plaidPayload)
    })

    const plaidData = await plaidRes.json()
    if (plaidData.error_code) throw new Error(plaidData.error_message || plaidData.error_code)

    return new Response(JSON.stringify({ link_token: plaidData.link_token }), {
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
