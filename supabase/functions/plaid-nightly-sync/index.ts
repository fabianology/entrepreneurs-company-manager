import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
    const clientId = Deno.env.get('PLAID_CLIENT_ID')
    const secret = Deno.env.get('PLAID_SECRET')
    const plaidBase = `https://${plaidEnv}.plaid.com`

    // 1. Fetch all active Plaid items
    const { data: plaidItems, error } = await supabaseAdmin
      .from('plaid_items')
      .select(`
        id,
        access_token,
        user_id,
        company_id,
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
    let transactionCount = 0

    for (const item of (plaidItems || [])) {
      if (!item.institutions) continue

      try {
        // ── A. Fetch Balances ──────────────────────────────────────────
        const balanceRes = await fetch(`${plaidBase}/accounts/balance/get`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            client_id: clientId,
            secret: secret,
            access_token: item.access_token
          })
        })
        const balanceData = await balanceRes.json()

        if (balanceData.error_code) {
          console.error(`Plaid balance error for item ${item.id}:`, balanceData.error_message)
          if (balanceData.error_code === 'ITEM_LOGIN_REQUIRED') {
            await supabaseAdmin.from('plaid_items')
              .update({ status: 'requires_reauth', error_code: balanceData.error_code })
              .eq('id', item.id)
            await supabaseAdmin.from('institutions')
              .update({ is_disconnected: true })
              .eq('id', item.institution_id)
          }
          continue
        }

        // Merge balances back into institutions.accounts_data
        const currentAccounts = item.institutions.accounts_data || []
        const plaidAccounts = balanceData.accounts || []
        const updatedAccounts = currentAccounts.map((acc: any) => {
          const pAcc = plaidAccounts.find((p: any) =>
            p.mask === acc.last4 || (p.account_id && p.account_id.endsWith(acc.last4))
          )
          return pAcc
            ? { ...acc, balance: pAcc.balances.current ?? pAcc.balances.available ?? acc.balance, plaid_account_id: pAcc.account_id }
            : acc
        })

        await supabaseAdmin.from('institutions')
          .update({ accounts_data: updatedAccounts, last_synced_at: new Date().toISOString(), is_disconnected: false })
          .eq('id', item.institution_id)

        // ── B. Fetch Transactions (last 90 days) ────────────────────────
        const endDate = new Date().toISOString().split('T')[0]
        const startDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]

        let allTransactions: any[] = []
        let hasMore = true
        let offset = 0

        while (hasMore) {
          const txRes = await fetch(`${plaidBase}/transactions/get`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              client_id: clientId,
              secret: secret,
              access_token: item.access_token,
              start_date: startDate,
              end_date: endDate,
              options: { count: 500, offset }
            })
          })
          const txData = await txRes.json()

          if (txData.error_code) {
            console.error(`Plaid transactions error for item ${item.id}:`, txData.error_message)
            break
          }

          const batch = txData.transactions || []
          allTransactions = allTransactions.concat(batch)
          hasMore = allTransactions.length < (txData.total_transactions || 0)
          offset += batch.length
          if (batch.length === 0) break
        }

        if (allTransactions.length > 0) {
          // Map Plaid account_id to our institution account
          const accountIdMap: Record<string, string> = {}
          for (const acc of updatedAccounts) {
            if (acc.plaid_account_id) accountIdMap[acc.plaid_account_id] = acc.id
          }
          // Also try matching by last4 from balanceData
          for (const pAcc of plaidAccounts) {
            if (pAcc.account_id && pAcc.mask) {
              const matched = updatedAccounts.find((a: any) => a.last4 === pAcc.mask)
              if (matched) accountIdMap[pAcc.account_id] = matched.id
            }
          }

          const dbTxs = allTransactions.map((tx: any) => ({
            user_id: item.user_id,
            plaid_item_id: item.id,
            plaid_transaction_id: tx.transaction_id,
            account_id: tx.account_id,
            amount: tx.amount,
            currency: tx.iso_currency_code || 'USD',
            category: tx.category || [],
            merchant_name: tx.merchant_name || tx.name,
            name: tx.name || tx.merchant_name,
            date: tx.date,
            pending: tx.pending || false,
            company_id: item.company_id,
            institution_id: item.institution_id
          }))

          const { error: txErr } = await supabaseAdmin
            .from('plaid_transactions')
            .upsert(dbTxs, { onConflict: 'plaid_transaction_id' })

          if (txErr) {
            console.error(`Error saving transactions for item ${item.id}:`, txErr)
          } else {
            transactionCount += dbTxs.length
            console.log(`Saved ${dbTxs.length} transactions for item ${item.id}`)
          }
        }

        // ── C. Update item sync timestamp ───────────────────────────────
        await supabaseAdmin.from('plaid_items')
          .update({ last_synced_at: new Date().toISOString(), status: 'active', error_code: null })
          .eq('id', item.id)

        syncedCount++
      } catch (err) {
        console.error(`Failed to sync item ${item.id}:`, err)
      }
    }

    return new Response(JSON.stringify({
      success: true,
      synced: syncedCount,
      transactions_saved: transactionCount
    }), {
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
