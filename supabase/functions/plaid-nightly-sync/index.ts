import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Fetch active Plaid items with their institution references
    const { data: plaidItems, error } = await supabaseAdmin
      .from('plaid_items')
      .select(`
        id,
        access_token,
        institution_id,
        institutions (
          id,
          accounts_data
        )
      `)
      .eq('status', 'active')
      .not('institution_id', 'is', null)

    if (error) throw error

    let syncedCount = 0

    // 2. Iterate and sync via Plaid API
    for (const item of (plaidItems || [])) {
      if (!item.institutions) continue;
      
      const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
      const clientId = Deno.env.get('PLAID_CLIENT_ID')
      const secret = Deno.env.get('PLAID_SECRET')

      try {
        // Fetch real-time balances from Plaid
        const balanceRes = await fetch(`https://${plaidEnv}.plaid.com/accounts/balance/get`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            client_id: clientId,
            secret: secret,
            access_token: item.access_token
          })
        })
        
        const balanceData = await balanceRes.json()

        const liabRes = await fetch(`https://${plaidEnv}.plaid.com/liabilities/get`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              client_id: clientId,
              secret: secret,
              access_token: item.access_token
            })
        })
        const liabData = await liabRes.json()
        
        if (balanceData.error_code) {
          console.error(`Plaid error for item ${item.id}:`, balanceData.error_message)
          // Update item status if auth revoked
          if (balanceData.error_code === 'ITEM_LOGIN_REQUIRED') {
            await supabaseAdmin.from('plaid_items').update({ status: 'requires_reauth', error_code: balanceData.error_code }).eq('id', item.id)
            await supabaseAdmin.from('institutions').update({ is_disconnected: true }).eq('id', item.institution_id)
          }
          continue
        }

        // Update balances in 'institutions' JSONB array
        const currentAccounts = item.institutions.accounts_data || []
        const plaidAccounts = balanceData.accounts || []
        const liabilities = liabData.liabilities || { credit: [], student: [], mortgage: [] }

        // Merge algorithm to avoid overriding user edits:
        // We match by `last4` or Plaid account_id suffix.
        const updatedAccounts = currentAccounts.map((acc: any) => {
          // Try to find matching Plaid account
          const pAcc = plaidAccounts.find((p: any) => 
            p.mask === acc.last4 || (p.account_id && p.account_id.endsWith(acc.last4))
          )
          
          if (pAcc) {
            // Update balance, but preserve user's name/type overrides
            return {
              ...acc,
              balance: pAcc.balances.current ?? pAcc.balances.available ?? acc.balance
            }
          }
          return acc
        })

        // Save back to institutions table
        await supabaseAdmin
          .from('institutions')
          .update({ accounts_data: updatedAccounts, last_synced_at: new Date().toISOString(), is_disconnected: false })
          .eq('id', item.institution_id)

        // Update Cards and Loans
        const allLiabilities = [...(liabilities.credit || []), ...(liabilities.student || []), ...(liabilities.mortgage || [])]
        
        for (const pAcc of plaidAccounts) {
          const liab = allLiabilities.find(l => l.account_id === pAcc.account_id)
          const newBal = pAcc.balances.current ?? pAcc.balances.available ?? 0.0
          const mask = pAcc.mask || (pAcc.account_id ? pAcc.account_id.slice(-4) : "")
          
          let apr: number | undefined
          let minPay: number | undefined
          let nextDate: string | undefined
          
          if (liab) {
             apr = liab.aprs?.[0]?.apr_percentage ?? liab.interest_rate?.percentage ?? liab.interest_rate_percentage
             minPay = liab.minimum_payment_amount ?? liab.next_monthly_payment
             nextDate = liab.next_payment_due_date
          }
          
          if (pAcc.type === 'credit') {
             const updates: any = { balance: newBal }
             if (apr !== undefined) updates.apr = apr
             if (minPay !== undefined) updates.mo_payment = minPay
             
             await supabaseAdmin.from('cards')
                 .update(updates)
                 .eq('last4', mask)
                 .eq('institution_name', item.institutions.id) // Fallback for name matching if needed, though last4 is usually unique per institution.
          } else if (pAcc.type === 'loan') {
             const updates: any = { remaining_balance: newBal }
             if (apr !== undefined) updates.interest_rate = apr
             if (minPay !== undefined) updates.payment_amount = minPay
             if (nextDate !== undefined) updates.next_payment_date = nextDate
             
             await supabaseAdmin.from('loans')
                 .update(updates)
                 // Usually need a way to link loans, but we don't have last4 in loans. We can skip exact loan mapping or just log it for now.
          }
        }
          
        await supabaseAdmin
          .from('plaid_items')
          .update({ last_synced_at: new Date().toISOString(), status: 'active', error_code: null })
          .eq('id', item.id)

        syncedCount++
      } catch (err) {
        console.error(`Failed to sync item ${item.id}:`, err)
      }
    }

    return new Response(JSON.stringify({ success: true, synced: syncedCount }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error)
    return new Response(JSON.stringify({ error: msg }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
