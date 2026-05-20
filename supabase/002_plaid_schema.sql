-- 002_plaid_schema.sql
-- Run this in the Supabase Dashboard SQL Editor to set up the Plaid database schema

-- 1. Create the plaid_items table
CREATE TABLE IF NOT EXISTS plaid_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    institution_id  UUID REFERENCES institutions(id) ON DELETE SET NULL,
    
    -- Plaid-specific fields
    access_token    TEXT NOT NULL,          -- 🔴 CRITICAL: encrypted at rest
    item_id         TEXT NOT NULL UNIQUE,   -- Plaid's identifier for this connection
    plaid_institution_id TEXT,              -- e.g. "ins_3" for Chase
    institution_name     TEXT,              -- Human-readable, e.g. "Chase"
    
    -- Sync state
    cursor          TEXT,                   -- For /transactions/sync pagination
    last_synced_at  TIMESTAMPTZ,
    status          TEXT DEFAULT 'active',  -- active | requires_reauth | error
    error_code      TEXT,                   -- Last Plaid error code if any
    
    -- Metadata
    products        TEXT[] DEFAULT '{}',    -- Which products are active: {'transactions','auth','balance'}
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE plaid_items ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS Policies
-- Users can only read and manage their own plaid items
CREATE POLICY "Users can manage their own plaid items"
    ON plaid_items FOR ALL USING (auth.uid() = user_id);

-- 4. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_plaid_items_status ON plaid_items(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_plaid_items_user_id ON plaid_items(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_items_company_id ON plaid_items(company_id);
