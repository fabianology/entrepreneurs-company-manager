-- 003_plaid_transactions.sql
-- Run this in the Supabase Dashboard SQL Editor to set up the Plaid transactions schema and nightly sync cron job

-- 1. Create the plaid_transactions table
CREATE TABLE IF NOT EXISTS plaid_transactions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plaid_item_id       UUID NOT NULL REFERENCES plaid_items(id) ON DELETE CASCADE,
    plaid_transaction_id TEXT NOT NULL UNIQUE,
    
    account_id          TEXT,
    amount              DOUBLE PRECISION,
    currency            TEXT DEFAULT 'USD',
    category            TEXT[],
    merchant_name       TEXT,
    name                TEXT,
    date                DATE,
    pending             BOOLEAN DEFAULT false,
    
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE plaid_transactions ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies
CREATE POLICY "Users own their transactions"
    ON plaid_transactions FOR ALL USING (auth.uid() = user_id);

-- 4. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_plaid_tx_user ON plaid_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_tx_item ON plaid_transactions(plaid_item_id);
CREATE INDEX IF NOT EXISTS idx_plaid_tx_date ON plaid_transactions(date);

-- 5. pg_cron Setup for Nightly Sync
-- This calls the Edge Function every night at 2:00 AM UTC
-- Make sure pg_net and pg_cron extensions are enabled in Database -> Extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- NOTE: You will need to replace the URL below with your actual project URL and anon key, 
-- or rely on a webhook. For now, this is a placeholder you can edit before running.
/*
SELECT cron.schedule(
    'invoke-plaid-sync-nightly',
    '0 2 * * *', -- Every day at 2:00 AM
    $$
    SELECT net.http_post(
        url:='https://YOUR_PROJECT_REF.supabase.co/functions/v1/plaid-nightly-sync',
        headers:='{"Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb,
        body:='{}'::jsonb
    )
    $$
);
*/
