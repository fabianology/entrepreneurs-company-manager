-- Add plaid_stream_id to subscriptions table
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS plaid_stream_id UUID;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS plaid_account_id TEXT;
