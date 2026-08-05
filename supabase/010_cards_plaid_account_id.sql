-- 010_cards_plaid_account_id.sql
-- Add plaid_account_id to financial_cards table to enable direct mapping with Plaid credit card accounts

ALTER TABLE financial_cards ADD COLUMN IF NOT EXISTS plaid_account_id TEXT;
CREATE INDEX IF NOT EXISTS idx_financial_cards_plaid_account_id ON financial_cards(plaid_account_id);
