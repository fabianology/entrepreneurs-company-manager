-- 004_plaid_reconnection.sql

-- Add is_disconnected flag to institutions table to track when a bank connection requires re-authentication (Update Mode)
ALTER TABLE public.institutions ADD COLUMN IF NOT EXISTS is_disconnected BOOLEAN DEFAULT false;
