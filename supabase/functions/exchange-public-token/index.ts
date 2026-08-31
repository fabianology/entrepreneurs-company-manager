import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    // 1. Authenticate the user
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

    // 2. Parse request body
    const bodyText = await req.text()
    if (!bodyText) throw new Error("Empty request body")
    const { public_token, institution_name, institution_id, company_id } = JSON.parse(bodyText)
    
    if (!public_token || !company_id) throw new Error("Missing required fields")

    // 3. Get Plaid Environment Variables
    const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')
    const plaidSecret = Deno.env.get('PLAID_SECRET')
    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'

    if (!plaidClientId || !plaidSecret) {
      throw new Error('Plaid secrets are missing')
    }

    // 4. Exchange public token for access token
    const exchangeRes = await fetch(
      `https://${plaidEnv}.plaid.com/item/public_token/exchange`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_id: plaidClientId,
          secret: plaidSecret,
          public_token
        })
      }
    )
    const exchangeData = await exchangeRes.json()
    if (exchangeData.error_code) throw new Error(exchangeData.error_message || exchangeData.error_code)

    // 5. Store securely using service role (bypasses RLS for insert since we provide the user_id explicitly)
    const adminClient = createClient(supabaseUrl, supabaseServiceRole)

    const { error: insertError } = await adminClient.from('plaid_items').insert({
      user_id: user.id,
      company_id,
      access_token: exchangeData.access_token,
      item_id: exchangeData.item_id,
      plaid_institution_id: institution_id,
      institution_name,
      products: ['transactions', 'auth', 'liabilities', 'balance'],
      // The item becomes active only after the institution cascade is saved and
      // link-plaid-institution attaches it. Cancelled Link flows no longer count
      // as visible connections or get picked up by nightly sync.
      status: 'pending_link'
    })
    
    if (insertError) throw new Error(`Database Insert Error: ${insertError.message}`)

    // 6. Fetch every supported enrichment source. Auth and Liabilities are
    // best-effort because not every institution/account supports them.
    const plaidRequest = async (path: string) => {
      const response = await fetch(`https://${plaidEnv}.plaid.com${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_id: plaidClientId,
          secret: plaidSecret,
          access_token: exchangeData.access_token
        })
      })
      return await response.json()
    }

    const balanceData = await plaidRequest('/accounts/balance/get')
    if (balanceData.error_code) {
      throw new Error(balanceData.error_message || balanceData.error_code)
    }

    const [authData, liabilityData] = await Promise.all([
      plaidRequest('/auth/get').catch(() => ({})),
      plaidRequest('/liabilities/get').catch(() => ({}))
    ])

    const achByAccount = new Map(
      (authData.numbers?.ach || []).map((number: any) => [number.account_id, number])
    )
    const authAccountById = new Map(
      (authData.accounts || []).map((account: any) => [account.account_id, account])
    )
    const liabilityByAccount = new Map<string, any>()
    for (const liability of (liabilityData.liabilities?.credit || [])) {
      if (liability.account_id) liabilityByAccount.set(liability.account_id, { ...liability, liability_type: 'credit' })
    }
    for (const liability of (liabilityData.liabilities?.mortgage || [])) {
      if (liability.account_id) liabilityByAccount.set(liability.account_id, { ...liability, liability_type: 'mortgage' })
    }
    for (const liability of (liabilityData.liabilities?.student || [])) {
      if (liability.account_id) liabilityByAccount.set(liability.account_id, { ...liability, liability_type: 'student' })
    }

    const enrichedAccounts = (balanceData.accounts || []).map((account: any) => {
      const ach = achByAccount.get(account.account_id) as any
      const authAccount = authAccountById.get(account.account_id) as any
      const liability = liabilityByAccount.get(account.account_id)
      return {
        ...account,
        account_number: ach?.account || liability?.account_number || null,
        routing_number: ach?.routing || null,
        wire_routing_number: ach?.wire_routing || null,
        is_tokenized_account_number: ach?.is_tokenized_account_number || false,
        verification_status: authAccount?.verification_status || account.verification_status || null,
        liability_details: liability || null
      }
    })

    return new Response(JSON.stringify({
      success: true,
      item_id: exchangeData.item_id,
      accounts: enrichedAccounts
    }), { 
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
