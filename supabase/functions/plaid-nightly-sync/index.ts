import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

serve(async (req) => {
  try {
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey
    )

    const authorization = req.headers.get('Authorization') ?? ''
    const bearerToken = authorization.replace(/^Bearer\s+/i, '')
    const isServiceRequest = bearerToken === serviceRoleKey
    let callerUserId: string | null = null
    if (!isServiceRequest) {
      if (!bearerToken) {
        return new Response(JSON.stringify({ error: 'Authentication required' }), {
          headers: { 'Content-Type': 'application/json' },
          status: 401
        })
      }
      const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(bearerToken)
      if (authError || !authData.user) {
        return new Response(JSON.stringify({ error: 'Invalid or expired session' }), {
          headers: { 'Content-Type': 'application/json' },
          status: 401
        })
      }
      callerUserId = authData.user.id
    }
    const requestBody = await req.json().catch(() => ({}))
    const requestedInstitutionId = requestBody?.institution_id ?? null

    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
    const clientId = Deno.env.get('PLAID_CLIENT_ID')
    const secret = Deno.env.get('PLAID_SECRET')
    const plaidBase = `https://${plaidEnv}.plaid.com`

    const plaidRequest = async (path: string, accessToken: string) => {
      const response = await fetch(`${plaidBase}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_id: clientId,
          secret,
          access_token: accessToken
        })
      })
      return await response.json()
    }

    const normalizeIdentity = (value: any) =>
      String(value ?? '').toLowerCase().replace(/[^a-z0-9]/g, '')

    const accountTypesMatch = (left: any, right: any) => {
      const leftType = normalizeIdentity(left?.type)
      const rightType = normalizeIdentity(right?.type)
      const leftSubtype = normalizeIdentity(left?.subtype)
      const rightSubtype = normalizeIdentity(right?.subtype)
      if (leftType && rightType && leftType !== rightType) return false
      return !leftSubtype || !rightSubtype || leftSubtype === rightSubtype
    }

    const accountNames = (account: any) => new Set(
      [account?.official_name, account?.name]
        .map(normalizeIdentity)
        .filter(Boolean)
    )

    const accountSnapshot = (
      item: any,
      account: any,
      status: 'active' | 'archived'
    ) => ({
      user_id: item.user_id,
      plaid_item_id: item.id,
      account_id: account.account_id,
      persistent_account_id: account.persistent_account_id ?? null,
      institution_id: status === 'active' ? item.institution_id : null,
      company_id: item.company_id,
      name: account.name ?? null,
      official_name: account.official_name ?? null,
      mask: account.mask ?? null,
      account_type: account.type ?? null,
      subtype: account.subtype ?? null,
      status,
      ...(status === 'active' ? {
        canonical_account_id: account.account_id,
        canonical_institution_id: item.institution_id,
        canonical_company_id: item.company_id,
        match_method: 'source',
        matched_at: new Date().toISOString()
      } : {}),
      last_seen_at: new Date().toISOString()
    })

    const persistAccountSnapshots = async (
      item: any,
      accounts: any[],
      status: 'active' | 'archived'
    ) => {
      if (accounts.length === 0) return
      const { error: snapshotError } = await supabaseAdmin
        .from('plaid_accounts')
        .upsert(
          accounts.map((account: any) => accountSnapshot(item, account, status)),
          { onConflict: 'plaid_item_id,account_id' }
        )
      if (snapshotError) throw snapshotError
    }

    const matchReplacementAccount = (archivedAccount: any, currentAccounts: any[]) => {
      const persistentId = archivedAccount.persistent_account_id
      if (persistentId) {
        const persistentMatches = currentAccounts.filter((candidate: any) =>
          candidate.persistent_account_id === persistentId
        )
        if (persistentMatches.length === 1) {
          return { account: persistentMatches[0], method: 'persistent_account_id' }
        }
      }

      if (archivedAccount.mask) {
        const maskMatches = currentAccounts.filter((candidate: any) =>
          candidate.mask === archivedAccount.mask &&
          accountTypesMatch(archivedAccount, candidate)
        )
        if (maskMatches.length === 1) {
          return { account: maskMatches[0], method: 'mask_and_type' }
        }
      }

      const archivedNames = accountNames(archivedAccount)
      if (archivedNames.size > 0) {
        const nameMatches = currentAccounts.filter((candidate: any) => {
          if (!accountTypesMatch(archivedAccount, candidate)) return false
          return [...accountNames(candidate)].some(name => archivedNames.has(name))
        })
        if (nameMatches.length === 1) {
          return { account: nameMatches[0], method: 'name_and_type' }
        }
      }
      return null
    }

    const reconcileArchivedHistory = async (item: any, currentAccounts: any[]) => {
      if (!item.plaid_institution_id || currentAccounts.length === 0) return 0

      const { data: archivedItems, error: archivedError } = await supabaseAdmin
        .from('plaid_items')
        .select('id,access_token,user_id,company_id,institution_id,institution_name,plaid_institution_id')
        .eq('user_id', item.user_id)
        .eq('company_id', item.company_id)
        .eq('plaid_institution_id', item.plaid_institution_id)
        .eq('status', 'archived')
        .eq('error_code', 'SUPERSEDED_CONNECTION')
        .neq('id', item.id)
      if (archivedError) throw archivedError

      let reconciledAccounts = 0
      for (const archivedItem of (archivedItems || [])) {
        const archivedData = await plaidRequest('/accounts/get', archivedItem.access_token)
        if (archivedData.error_code) {
          console.warn(
            `Could not snapshot archived Item ${archivedItem.id}: ${archivedData.error_code}`
          )
          continue
        }

        const archivedAccounts = archivedData.accounts || []
        await persistAccountSnapshots(archivedItem, archivedAccounts, 'archived')

        for (const archivedAccount of archivedAccounts) {
          const match = matchReplacementAccount(archivedAccount, currentAccounts)
          if (!match) continue

          const matchedAt = new Date().toISOString()
          const { error: accountMatchError } = await supabaseAdmin
            .from('plaid_accounts')
            .update({
              canonical_account_id: match.account.account_id,
              canonical_institution_id: item.institution_id,
              canonical_company_id: item.company_id,
              match_method: match.method,
              matched_at: matchedAt,
              last_seen_at: matchedAt
            })
            .eq('plaid_item_id', archivedItem.id)
            .eq('account_id', archivedAccount.account_id)
          if (accountMatchError) throw accountMatchError

          const { error: transactionMatchError } = await supabaseAdmin
            .from('plaid_transactions')
            .update({
              persistent_account_id: match.account.persistent_account_id ?? null,
              canonical_account_id: match.account.account_id,
              account_match_method: match.method,
              institution_id: item.institution_id,
              company_id: item.company_id,
              is_superseded_duplicate: false,
              superseded_by_transaction_id: null
            })
            .eq('plaid_item_id', archivedItem.id)
            .eq('account_id', archivedAccount.account_id)
          if (transactionMatchError) throw transactionMatchError
          reconciledAccounts++
        }
      }
      return reconciledAccounts
    }

    // A user-triggered refresh is scoped to that user and, for an account sheet,
    // to that institution. The service-role cron still refreshes every active item.
    let itemsQuery = supabaseAdmin
      .from('plaid_items')
      .select(`
        id,
        access_token,
        user_id,
        company_id,
        institution_id,
        institution_name,
        plaid_institution_id,
        institutions (
          id,
          name,
          accounts_data
        )
      `)
      .eq('status', 'active')
      .not('institution_id', 'is', null)

    if (callerUserId) itemsQuery = itemsQuery.eq('user_id', callerUserId)
    if (requestedInstitutionId) itemsQuery = itemsQuery.eq('institution_id', requestedInstitutionId)
    const { data: plaidItems, error } = await itemsQuery

    if (error) throw error

    let syncedCount = 0
    let transactionCount = 0
    const results: any[] = []

    for (const item of (plaidItems || [])) {
      if (!item.institutions) continue

      try {
        // ── A. Fetch Balances ──────────────────────────────────────────
        const balanceData = await plaidRequest('/accounts/balance/get', item.access_token)

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
          results.push({
            item_id: item.id,
            institution_name: item.institution_name,
            success: false,
            error_code: balanceData.error_code,
            error: balanceData.error_message ?? 'Plaid balance request failed'
          })
          continue
        }

        // Liabilities enrich supported card records. Auth numbers are imported
        // during Link and encrypted by the iOS client; the sync must not replace
        // those encrypted values with raw account/routing numbers.
        const liabilityData = await plaidRequest('/liabilities/get', item.access_token).catch(() => ({}))
        if (liabilityData.error_code && !['PRODUCT_NOT_READY', 'PRODUCTS_NOT_SUPPORTED', 'ADDITIONAL_CONSENT_REQUIRED'].includes(liabilityData.error_code)) {
          console.error(`Plaid liabilities error for item ${item.id}:`, liabilityData.error_message)
        }

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

        // Merge Plaid fields back into institutions.accounts_data and restore
        // any missing non-liability account after a transient client save failure.
        // Auth numbers remain client-only because only the iOS app can encrypt them.
        const currentAccounts = item.institutions.accounts_data || []
        const plaidAccounts = balanceData.accounts || []
        await persistAccountSnapshots(item, plaidAccounts, 'active')
        const reconciledHistoryAccounts = await reconcileArchivedHistory(item, plaidAccounts)
        const updatedAccounts = currentAccounts.reduce((deduplicated: any[], account: any) => {
          const duplicateIndex = deduplicated.findIndex((candidate: any) => candidate.id === account.id)
          if (duplicateIndex >= 0) deduplicated[duplicateIndex] = { ...deduplicated[duplicateIndex], ...account }
          else deduplicated.push(account)
          return deduplicated
        }, [])
        const normalizedIdentity = (value: any) => String(value ?? '').toLowerCase().replace(/[^a-z0-9]/g, '')
        for (const pAcc of plaidAccounts.filter((account: any) => !['credit', 'loan'].includes(account.type))) {
          let existingIndex = updatedAccounts.findIndex((acc: any) =>
            pAcc.account_id === acc.id ||
            pAcc.account_id === acc.plaid_account_id ||
            (pAcc.mask && pAcc.mask === acc.last4 && pAcc.name === acc.name)
          )
          if (existingIndex < 0) {
            const plaidNames = [pAcc.official_name, pAcc.name]
              .map(normalizedIdentity)
              .filter(Boolean)
            const plaidType = normalizedIdentity(pAcc.subtype ?? pAcc.type)
            const identityMatches = updatedAccounts
              .map((acc: any, index: number) => ({ acc, index }))
              .filter(({ acc }: any) =>
                plaidNames.includes(normalizedIdentity(acc.name)) &&
                normalizedIdentity(acc.type) === plaidType
              )
            const exactMaskMatch = identityMatches.find(({ acc }: any) =>
              pAcc.mask && acc.last4 === pAcc.mask
            )
            if (exactMaskMatch) existingIndex = exactMaskMatch.index
            else if (
              identityMatches.length === 1 &&
              (!pAcc.mask || !identityMatches[0].acc.last4)
            ) existingIndex = identityMatches[0].index
          }
          const existing = existingIndex >= 0 ? updatedAccounts[existingIndex] : null
          const merged = {
            cardHolder: '',
            expiry: '',
            network: '',
            status: 'Active',
            paidFrom: '',
            paidOn: '',
            autopay: 'N/A',
            ...existing,
            id: pAcc.account_id,
            name: pAcc.official_name ?? pAcc.name ?? existing?.name ?? '',
            type: String(pAcc.subtype ?? pAcc.type ?? existing?.type ?? 'Other')
              .split(' ')
              .map((word: string) => word.charAt(0).toUpperCase() + word.slice(1))
              .join(' '),
            last4: pAcc.mask ?? existing?.last4 ?? '',
            balance: pAcc.balances.current ?? pAcc.balances.available ?? existing?.balance ?? 0,
            currency: pAcc.balances.iso_currency_code ?? pAcc.balances.unofficial_currency_code ?? existing?.currency ?? 'USD',
            limit: pAcc.balances.limit ?? existing?.limit ?? 0,
            availableBalance: pAcc.balances.available ?? existing?.availableBalance,
            apy: pAcc.apy ?? existing?.apy,
            ownershipType: pAcc.ownership_type ?? existing?.ownershipType,
            verificationStatus: pAcc.verification_status ?? existing?.verificationStatus,
            persistentAccountId: pAcc.persistent_account_id ?? existing?.persistentAccountId,
            plaid_account_id: pAcc.account_id
          }
          if (existingIndex >= 0) updatedAccounts[existingIndex] = merged
          else updatedAccounts.push(merged)
        }

        await supabaseAdmin.from('institutions')
          .update({ accounts_data: updatedAccounts, last_synced_at: new Date().toISOString(), is_disconnected: false })
          .eq('id', item.institution_id)

        // Keep Plaid-backed cards current using Balance and Liabilities fields.
        for (const pAcc of plaidAccounts.filter((account: any) => account.type === 'credit')) {
          const liability = liabilityByAccount.get(pAcc.account_id)
          const preferredAPR = liability?.aprs?.find((apr: any) => apr.apr_type === 'purchase_apr')
            ?? liability?.aprs?.[0]
          const cardUpdate: Record<string, any> = {}
          const currentBalance = pAcc.balances.current ?? pAcc.balances.available
          if (currentBalance != null) cardUpdate.balance = currentBalance
          if (pAcc.balances.limit != null) cardUpdate.limit = pAcc.balances.limit
          if (preferredAPR?.apr_percentage != null) cardUpdate.apr = preferredAPR.apr_percentage
          if (liability?.minimum_payment_amount != null) cardUpdate.mo_payment = liability.minimum_payment_amount
          if (liability?.next_payment_due_date) {
            cardUpdate.paid_on = String(Number(liability.next_payment_due_date.split('-')[2]))
          }

          const { data: existingCard } = await supabaseAdmin
            .from('financial_cards')
            .select('id')
            .eq('user_id', item.user_id)
            .eq('plaid_account_id', pAcc.account_id)
            .maybeSingle()

          const institutionName = item.institutions.name ?? item.institution_name ?? ''
          if (existingCard && Object.keys(cardUpdate).length === 0) continue
          const cardPayload = existingCard ? cardUpdate : {
            id: crypto.randomUUID(),
            user_id: item.user_id,
            company_id: item.company_id,
            name: pAcc.name ?? pAcc.official_name ?? 'Plaid Card',
            institution_name: institutionName,
            last4: pAcc.mask ?? String(pAcc.account_id).slice(-4),
            network: 'Other',
            type: 'Credit',
            status: 'Active',
            limit: pAcc.balances.limit ?? 0,
            paid_on: liability?.next_payment_due_date
              ? String(Number(liability.next_payment_due_date.split('-')[2]))
              : null,
            autopay: 'N/A',
            balance: currentBalance ?? 0,
            mo_payment: liability?.minimum_payment_amount ?? 0,
            apr: preferredAPR?.apr_percentage ?? 0,
            promo_apr: 0,
            card_holder_type: 'Mine',
            plaid_account_id: pAcc.account_id
          }
          const cardQuery = existingCard
            ? supabaseAdmin.from('financial_cards').update(cardPayload).eq('id', existingCard.id)
            : supabaseAdmin.from('financial_cards').insert(cardPayload)
          const { error: cardError } = await cardQuery
          if (cardError) console.error(`Failed to persist Plaid card ${pAcc.account_id}:`, cardError)
        }

        // Keep imported loans current when the Plaid loan identifier is present.
        for (const pAcc of plaidAccounts.filter((account: any) => account.type === 'loan')) {
          const liability = liabilityByAccount.get(pAcc.account_id)
          const loanUpdate: Record<string, any> = {}
          const remainingBalance = pAcc.balances.current ?? pAcc.balances.available
          if (remainingBalance != null) loanUpdate.remaining_balance = remainingBalance
          if (liability?.origination_principal_amount != null) {
            loanUpdate.principal_amount = liability.origination_principal_amount
          }
          const interestRate = liability?.interest_rate?.percentage ?? liability?.interest_rate_percentage
          if (interestRate != null) loanUpdate.interest_rate = interestRate
          const payment = liability?.next_monthly_payment ?? liability?.minimum_payment_amount
          if (payment != null) loanUpdate.monthly_payment = payment
          if (liability?.origination_date) loanUpdate.start_date = liability.origination_date
          if (liability?.maturity_date || liability?.expected_payoff_date) {
            loanUpdate.maturity_date = liability.maturity_date ?? liability.expected_payoff_date
          }
          if (liability?.next_payment_due_date) loanUpdate.next_payment_at = liability.next_payment_due_date
          if (liability?.loan_term) {
            loanUpdate.term = liability.loan_term
            const termValue = Number(String(liability.loan_term).split(' ')[0]) || 0
            const isYears = String(liability.loan_term).toLowerCase().includes('year')
            loanUpdate.term_years = isYears ? termValue : Math.floor(termValue / 12)
            loanUpdate.term_months = isYears ? 0 : termValue % 12
          }

          const { data: existingLoan } = await supabaseAdmin
            .from('loans')
            .select('id')
            .eq('user_id', item.user_id)
            .eq('plaid_account_id', pAcc.account_id)
            .maybeSingle()

          const institutionName = item.institutions.name ?? item.institution_name ?? ''
          if (existingLoan && Object.keys(loanUpdate).length === 0) continue
          const termValue = Number(String(liability?.loan_term ?? '').split(' ')[0]) || 0
          const termIsYears = String(liability?.loan_term ?? '').toLowerCase().includes('year')
          const loanPayload = existingLoan ? loanUpdate : {
            id: crypto.randomUUID(),
            user_id: item.user_id,
            company_id: item.company_id,
            role: 'Borrower',
            lender: institutionName,
            name: liability?.loan_name ?? pAcc.name ?? pAcc.official_name ?? 'Plaid Loan',
            principal_amount: liability?.origination_principal_amount ?? remainingBalance ?? 0,
            remaining_balance: remainingBalance ?? 0,
            interest_type: 'Percentage',
            interest_rate: liability?.interest_rate?.percentage ?? liability?.interest_rate_percentage ?? 0,
            term: liability?.loan_term ?? '0 months',
            term_years: termIsYears ? termValue : Math.floor(termValue / 12),
            term_months: termIsYears ? 0 : termValue % 12,
            schedule_frequency: 'Monthly',
            monthly_payment: liability?.next_monthly_payment ?? liability?.minimum_payment_amount ?? 0,
            start_date: liability?.origination_date ?? new Date().toISOString(),
            maturity_date: liability?.maturity_date ?? liability?.expected_payoff_date ?? null,
            next_payment_at: liability?.next_payment_due_date ?? null,
            status: 'Active',
            plaid_account_id: pAcc.account_id
          }
          const loanQuery = existingLoan
            ? supabaseAdmin.from('loans').update(loanPayload).eq('id', existingLoan.id)
            : supabaseAdmin.from('loans').insert(loanPayload)
          const { error: loanError } = await loanQuery
          if (loanError) console.error(`Failed to persist Plaid loan ${pAcc.account_id}:`, loanError)
        }

        // ── B. Fetch Transactions (up to Plaid's two-year range) ────────
        const endDate = new Date().toISOString().split('T')[0]
        const startDate = new Date(Date.now() - 730 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
        console.log(`Fetching transactions for item ${item.id}, range: ${startDate} to ${endDate}, env: ${plaidEnv}`)

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
          console.log(`Plaid /transactions/get response for item ${item.id}: status=${txRes.status}, total=${txData.total_transactions}, batch=${(txData.transactions||[]).length}, error=${txData.error_code||'none'}, msg=${txData.error_message||'none'}`)

          if (txData.error_code) {
            console.error(`Plaid transactions error for item ${item.id}: code=${txData.error_code} msg=${txData.error_message}`)
            throw new Error(`${txData.error_code}: ${txData.error_message ?? 'Plaid transaction request failed'}`)
          }

          const batch = txData.transactions || []
          allTransactions = allTransactions.concat(batch)
          const total = txData.total_transactions || 0
          hasMore = total > 0 && allTransactions.length < total
          offset += batch.length
          if (batch.length === 0) break
        }
        console.log(`Total transactions fetched for item ${item.id}: ${allTransactions.length}`)

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
            persistent_account_id: plaidAccounts.find((account: any) =>
              account.account_id === tx.account_id
            )?.persistent_account_id ?? null,
            canonical_account_id: tx.account_id,
            account_match_method: 'source',
            is_superseded_duplicate: false,
            superseded_by_transaction_id: null,
            amount: tx.amount,
            currency: tx.iso_currency_code || 'USD',
            category: tx.category || [],
            merchant_name: tx.merchant_name || tx.name,
            merchant_website: tx.website ?? null,
            merchant_logo_url: tx.logo_url ?? null,
            merchant_entity_id: tx.merchant_entity_id ?? null,
            name: tx.name || tx.merchant_name,
            date: tx.date,
            authorized_date: tx.authorized_date ?? null,
            pending: tx.pending || false,
            pending_transaction_id: tx.pending_transaction_id ?? null,
            payment_channel: tx.payment_channel ?? null,
            personal_finance_primary: tx.personal_finance_category?.primary ?? null,
            personal_finance_detailed: tx.personal_finance_category?.detailed ?? null,
            personal_finance_confidence: tx.personal_finance_category?.confidence_level ?? null,
            transaction_code: tx.transaction_code ?? null,
            location: tx.location ?? null,
            counterparties: tx.counterparties ?? [],
            is_stale_pending_duplicate: false,
            posted_transaction_id: null,
            company_id: item.company_id,
            institution_id: item.institution_id
          }))

          const { error: txErr } = await supabaseAdmin
            .from('plaid_transactions')
            .upsert(dbTxs, { onConflict: 'plaid_transaction_id' })

          if (txErr) {
            console.error(`Error saving transactions for item ${item.id}:`, txErr)
            throw txErr
          } else {
            transactionCount += dbTxs.length
            console.log(`Saved ${dbTxs.length} transactions for item ${item.id}`)
          }
        }

        // Archived access tokens can stop returning account metadata after a
        // reconnect. Once current transactions exist, recover unique account
        // matches from exact transaction overlap (or a one-to-one singleton).
        const { data: overlapReconciledAccounts, error: overlapReconcileError } = await supabaseAdmin
          .rpc('reconcile_plaid_history_by_overlap', {
            p_user_id: item.user_id,
            p_current_item_id: item.id
          })
        if (overlapReconcileError) throw overlapReconcileError

        const { data: duplicateCount, error: duplicateError } = await supabaseAdmin
          .rpc('reconcile_plaid_transaction_duplicates', { p_user_id: item.user_id })
        if (duplicateError) throw duplicateError

        const { data: stalePendingCount, error: pendingError } = await supabaseAdmin
          .rpc('reconcile_plaid_pending_transactions', { p_user_id: item.user_id })
        if (pendingError) throw pendingError

        // ── C. Update item sync timestamp ───────────────────────────────
        await supabaseAdmin.from('plaid_items')
          .update({ last_synced_at: new Date().toISOString(), status: 'active', error_code: null })
          .eq('id', item.id)

        syncedCount++
        results.push({
          item_id: item.id,
          institution_name: item.institution_name,
          success: true,
          transactions_found: allTransactions.length,
          transactions_saved: allTransactions.length,
          history_accounts_reconciled: reconciledHistoryAccounts + (overlapReconciledAccounts ?? 0),
          duplicates_suppressed: duplicateCount ?? 0,
          stale_pending_suppressed: stalePendingCount ?? 0
        })
      } catch (err) {
        console.error(`Failed to sync item ${item.id}:`, err)
        const message = err instanceof Error ? err.message : String(err)
        await supabaseAdmin.from('plaid_items')
          .update({ error_code: 'TRANSACTION_SYNC_FAILED' })
          .eq('id', item.id)
        results.push({
          item_id: item.id,
          institution_name: item.institution_name,
          success: false,
          error_code: 'TRANSACTION_SYNC_FAILED',
          error: message
        })
      }
    }

    return new Response(JSON.stringify({
      success: true,
      synced: syncedCount,
      failed: results.filter((result) => !result.success).length,
      transactions_saved: transactionCount,
      items: results
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
