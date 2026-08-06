-- 012_create_plaid_transactions_table.sql
-- Run this in Supabase Dashboard → SQL Editor

-- 1. Create table (with all columns the edge function writes)
CREATE TABLE IF NOT EXISTS plaid_transactions (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plaid_item_id        UUID NOT NULL REFERENCES plaid_items(id) ON DELETE CASCADE,
    plaid_transaction_id TEXT NOT NULL UNIQUE,
    account_id           TEXT,
    amount               DOUBLE PRECISION,
    currency             TEXT DEFAULT 'USD',
    category             TEXT[],
    merchant_name        TEXT,
    name                 TEXT,
    date                 DATE,
    pending              BOOLEAN DEFAULT false,
    company_id           UUID REFERENCES companies(id) ON DELETE SET NULL,
    institution_id       UUID REFERENCES institutions(id) ON DELETE SET NULL,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE plaid_transactions ENABLE ROW LEVEL SECURITY;

-- 3. Drop any old conflicting policies
DROP POLICY IF EXISTS "Users own their transactions" ON plaid_transactions;
DROP POLICY IF EXISTS "users_read_own_transactions" ON plaid_transactions;
DROP POLICY IF EXISTS "users_write_own_transactions" ON plaid_transactions;

-- 4. Clean simple policies: users can read their own rows
CREATE POLICY "users_read_own_transactions"
    ON plaid_transactions FOR SELECT
    USING (auth.uid() = user_id);

-- Service role (edge function) can write — no RLS restriction for service_role
-- (service role bypasses RLS by default)

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_plaid_tx_user    ON plaid_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_tx_item    ON plaid_transactions(plaid_item_id);
CREATE INDEX IF NOT EXISTS idx_plaid_tx_account ON plaid_transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_plaid_tx_date    ON plaid_transactions(date DESC);
