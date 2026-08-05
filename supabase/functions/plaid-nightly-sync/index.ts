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
      // Ignore parse errors, just means no body or invalid json
    }

    const debugErrors: any[] = []

    // 1. Fetch active Plaid items with their institution references
    let query = supabaseAdmin
      .from('plaid_items')
      .select(`
        id,
        access_token,
        institution_id,
        company_id,
        user_id,
        institutions (
          id,
          accounts_data
        )
      `)
      .eq('status', 'active')
      .not('institution_id', 'is', null)

    if (body.institution_id) {
        query = query.eq('institution_id', body.institution_id)
    }

    const { data: plaidItems, error } = await query

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

        const plaidAccounts = balanceData.accounts || []

        // Fallback: Fetch last 90 days of transactions to manually detect subscriptions
        const d = new Date()
        const endDate = d.toISOString().split('T')[0]
        d.setDate(d.getDate() - 90)
        const startDate = d.toISOString().split('T')[0]

        const txRes = await fetch(`https://${plaidEnv}.plaid.com/transactions/get`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              client_id: clientId,
              secret: secret,
              access_token: item.access_token,
              start_date: startDate,
              end_date: endDate,
              options: {
                count: 500
              }
            })
        })
        const txData = await txRes.json()
        
        const outflow_streams: any[] = []
        if (txData.transactions && txData.transactions.length > 0) {
            const dbTxs = txData.transactions.map((tx: any) => ({
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

            const { error: txErr } = await supabaseAdmin.from('plaid_transactions').upsert(dbTxs, { onConflict: 'plaid_transaction_id' })
            if (txErr) console.error(`Error saving plaid_transactions for item ${item.id}:`, txErr)

            const normalizeMerchantName = (rawName: string): string => {
                if (!rawName) return ""
                let clean = rawName.toUpperCase()
                clean = clean.replace(/^(SQ \*|TST\*|PAYPAL \*|AMZN MKT|SP \*)/g, '')
                clean = clean.replace(/(\.COM|DIG SERVICES|DIGITAL|SERVICE|INC|LLC|CORP|LTD|CO|PAYMENT|AUTOPAY|BILLING|RECURRING|\#\d+)/g, ' ')
                clean = clean.replace(/[^A-Z0-9\s]/g, '')
                clean = clean.replace(/\s+/g, ' ').trim()
                return clean || rawName.toUpperCase()
            }

            const txByName: Record<string, any[]> = {}
            for (const tx of txData.transactions) {
                if (tx.amount <= 0) continue // only expenses
                const rawName = tx.merchant_name || tx.name
                if (!rawName) continue
                const key = normalizeMerchantName(rawName)
                if (!txByName[key]) txByName[key] = []
                txByName[key].push(tx)
            }
            
            for (const [key, txs] of Object.entries(txByName)) {
                if (txs.length >= 2) {
                    const amounts = txs.map(t => t.amount)
                    const avg = amounts.reduce((a, b) => a + b, 0) / amounts.length
                    const isSimilar = amounts.every(a => Math.abs(a - avg) / avg < 0.25) // within 25%
                    
                    if (isSimilar) {
                        txs.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
                        const latest = txs[0]
                        const oldest = txs[txs.length - 1]
                        const daysDiff = (new Date(latest.date).getTime() - new Date(oldest.date).getTime()) / (1000 * 60 * 60 * 24)
                        
                        let frequency = 'UNKNOWN'
                        if (txs.length >= 2 && daysDiff >= 15) {
                            frequency = 'MONTHLY'
                        } else if (txs.length >= 2 && daysDiff >= 300) {
                            frequency = 'ANNUALLY'
                        }
                        
                        if (frequency !== 'UNKNOWN') {
                            const displayName = latest.merchant_name || latest.name || key
                            outflow_streams.push({
                                stream_id: `custom_stream_${encodeURIComponent(key).replace(/%/g, '')}_${latest.account_id}`.substring(0, 64),
                                account_id: latest.account_id,
                                frequency: frequency,
                                merchant_name: displayName,
                                last_amount: {
                                    value: avg,
                                    iso_currency_code: latest.iso_currency_code || 'USD'
                                },
                                is_active: true
                            })
                        }
                    }
                }
            }
        }
        
        const recurringData = { outflow_streams }
        
        if (!balanceRes.ok || balanceData.error_code) {
          const errMsg = balanceData.error_message || `HTTP ${balanceRes.status}`
          console.error(`Plaid error for item ${item.id}:`, errMsg)
          debugErrors.push({ type: 'balance', item: item.id, error: errMsg, code: balanceData.error_code })
          // Update item status if auth revoked
          if (balanceData.error_code === 'ITEM_LOGIN_REQUIRED') {
            await supabaseAdmin.from('plaid_items').update({ status: 'requires_reauth', error_code: balanceData.error_code }).eq('id', item.id)
            await supabaseAdmin.from('institutions').update({ is_disconnected: true }).eq('id', item.institution_id)
          }
          continue
        }

        // Update balances in 'institutions' JSONB array
        const currentAccounts = item.institutions.accounts_data || []
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
        const { error: updateInstError } = await supabaseAdmin.from('institutions')
          .update({ accounts_data: updatedAccounts, last_synced_at: new Date().toISOString(), is_disconnected: false })
          .eq('id', item.institution_id)
        if (updateInstError) debugErrors.push({ type: 'update_inst', item: item.id, error: updateInstError })
        
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
             const updates: any = { balance: newBal, plaid_account_id: pAcc.account_id }
             if (apr !== undefined) updates.apr = apr
             if (minPay !== undefined) updates.mo_payment = minPay
             if (pAcc.mask) updates.last4 = pAcc.mask
             
             const { data: cardsToUpdate } = await supabaseAdmin.from('financial_cards')
                 .select('id')
                 .eq('company_id', item.company_id)
                 .or(`plaid_account_id.eq.${pAcc.account_id},last4.eq.${mask},last4.eq.${pAcc.account_id.slice(-4)}`)

             if (cardsToUpdate && cardsToUpdate.length > 0) {
                 for (const c of cardsToUpdate) {
                     await supabaseAdmin.from('financial_cards')
                         .update(updates)
                         .eq('id', c.id)
                 }
             }
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

        // Process Subscriptions (Outflow Streams)
        if (recurringData.outflow_streams) {
            for (const stream of recurringData.outflow_streams) {
                if (!stream.is_active) continue
                
                // Only capture things that look like subscriptions (monthly/yearly)
                const isMonthly = stream.frequency === 'MONTHLY' || stream.frequency === 'SEMI_MONTHLY'
                const isYearly = stream.frequency === 'ANNUALLY'
                if (!isMonthly && !isYearly) continue

                const streamId = stream.stream_id
                const accountId = stream.account_id
                const amount = stream.last_amount?.value ? Math.abs(stream.last_amount.value) : 0
                const currency = stream.last_amount?.iso_currency_code || 'USD'
                const merchantName = stream.merchant_name || stream.description || "Unknown Subscription"

                // Check if we already have this stream
                const { data: existing } = await supabaseAdmin.from('subscriptions')
                    .select('id').eq('plaid_stream_id', streamId).single()
                
                if (existing) {
                    // Update existing
                    await supabaseAdmin.from('subscriptions').update({
                        cost: amount,
                        last_updated: new Date().toISOString()
                    }).eq('id', existing.id)
                } else {
                    // Create new
                    await supabaseAdmin.from('subscriptions').insert({
                        id: crypto.randomUUID(),
                        user_id: item.user_id,
                        company_id: item.company_id,
                        name: merchantName,
                        cost: amount,
                        currency: currency,
                        billing_cycle: isMonthly ? 'Monthly' : 'Yearly',
                        status: 'Active',
                        pricing_model: amount > 0 ? 'paid' : 'free',
                        renew: 'Auto',
                        plaid_stream_id: streamId,
                        plaid_account_id: accountId,
                        last_updated: new Date().toISOString()
                    })
                }
            }
        }

        syncedCount++
      } catch (err) {
        console.error(`Failed to sync item ${item.id}:`, err)
      }
    }

    return new Response(JSON.stringify({ success: true, synced: syncedCount, itemsFound: plaidItems?.length, debugErrors }), {
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
