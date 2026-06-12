import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let body: any = {}
    try {
      if (req.method === 'POST') {
        const text = await req.text()
        if (text) {
          body = JSON.parse(text)
        }
      }
    } catch (e) {
    }

    if (body.action === 'fix_missing_institution_id') {
      const { data: missing, error: missErr } = await supabaseAdmin.from('plaid_items').select('*').is('institution_id', null)
      if (missErr) throw missErr

      let fixed = 0
      for (const item of (missing || [])) {
         const { data: insts } = await supabaseAdmin.from('institutions')
            .select('id')
            .eq('company_id', item.company_id)
            .ilike('name', item.institution_name)
         
         if (insts && insts.length > 0) {
            await supabaseAdmin.from('plaid_items').update({ institution_id: insts[0].id }).eq('id', item.id)
            fixed++
         }
      }
      return new Response(JSON.stringify({ fixed, missing: missing?.length }), { status: 200, headers: { "Content-Type": "application/json" } })
    }

    const { data: plaidItems, error } = await supabaseAdmin
      .from('plaid_items')
      .select('*')

    const { data: institutions, error: instError } = await supabaseAdmin
      .from('institutions')
      .select('id, name, company_id, accounts_data')
    
    if (instError) throw instError

    const sofiItem = plaidItems?.find(i => i.institution_name === 'SoFi' && i.user_id === '4ca8519f-cf55-4219-a711-1baefdcd35d5')
    let recurringData = null
    let balanceData = null
    if (sofiItem) {
      const clientId = Deno.env.get('PLAID_CLIENT_ID')
      const secret = Deno.env.get('PLAID_SECRET')
      const env = Deno.env.get('PLAID_ENV') || 'sandbox'
      const balRes = await fetch(`https://${env}.plaid.com/accounts/balance/get`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            client_id: clientId,
            secret: secret,
            access_token: sofiItem.access_token
          })
      })
      balanceData = await balRes.json()

      const d = new Date()
      const endDate = d.toISOString().split('T')[0]
      d.setDate(d.getDate() - 30)
      const startDate = d.toISOString().split('T')[0]

      const txRes = await fetch(`https://${env}.plaid.com/transactions/get`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            client_id: clientId,
            secret: secret,
            access_token: sofiItem.access_token,
            start_date: startDate,
            end_date: endDate,
            options: {
              count: 100
            }
          })
      })
      recurringData = await txRes.json()
    }

    return new Response(JSON.stringify({ plaidItems, institutions, recurringData, balanceData }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    const msg = error instanceof Error ? error.message : JSON.stringify(error)
    return new Response(JSON.stringify({ error: msg }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
