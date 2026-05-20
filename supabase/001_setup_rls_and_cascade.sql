-- ========================================================================================
-- Supabase Security & RLS Setup Script
-- 
-- Run this script in the Supabase Studio SQL Editor to enforce Row Level Security (RLS)
-- and setup ON DELETE CASCADE so user data is wiped when an account is deleted.
-- ========================================================================================

-- 1. ENABLE ROW LEVEL SECURITY
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE institutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_invitations ENABLE ROW LEVEL SECURITY;

-- 2. CREATE STANDARD RLS POLICIES (Users can only see/edit their own data)
-- Companies
CREATE POLICY "Users can manage their own companies" 
ON companies FOR ALL USING (auth.uid() = user_id);

-- Subscriptions
CREATE POLICY "Users can manage their own subscriptions" 
ON subscriptions FOR ALL USING (auth.uid() = user_id);

-- Institutions
CREATE POLICY "Users can manage their own institutions" 
ON institutions FOR ALL USING (auth.uid() = user_id);

-- Financial Cards
CREATE POLICY "Users can manage their own cards" 
ON financial_cards FOR ALL USING (auth.uid() = user_id);

-- Loans
CREATE POLICY "Users can manage their own loans" 
ON loans FOR ALL USING (auth.uid() = user_id);

-- Company Documents
CREATE POLICY "Users can manage their own documents" 
ON company_documents FOR ALL USING (auth.uid() = user_id);

-- Resource Invitations
CREATE POLICY "Users can see invitations they sent or received" 
ON resource_invitations FOR ALL 
USING (auth.uid() = invited_by OR auth.jwt()->>'email' = email);

-- 3. ENFORCE ON DELETE CASCADE FOR ALL FOREIGN KEYS TO auth.users
-- Note: Replace 'companies_user_id_fkey' with your actual constraint names if they differ.
-- This ensures that if a user deletes their account, all their data is hard deleted immediately.

DO $$ 
DECLARE 
    tbl TEXT;
BEGIN 
    FOR tbl IN SELECT unnest(ARRAY['companies', 'subscriptions', 'institutions', 'financial_cards', 'loans', 'company_documents']) 
    LOOP
        EXECUTE format('
            ALTER TABLE IF EXISTS %I 
            DROP CONSTRAINT IF EXISTS %I_user_id_fkey;
            
            ALTER TABLE IF EXISTS %I 
            ADD CONSTRAINT %I_user_id_fkey 
            FOREIGN KEY (user_id) 
            REFERENCES auth.users(id) 
            ON DELETE CASCADE;
        ', tbl, tbl, tbl, tbl);
    END LOOP;
END $$;

-- Handle resource_invitations separately since its foreign key is 'invited_by' instead of 'user_id'
ALTER TABLE IF EXISTS resource_invitations 
DROP CONSTRAINT IF EXISTS resource_invitations_invited_by_fkey;

ALTER TABLE IF EXISTS resource_invitations 
ADD CONSTRAINT resource_invitations_invited_by_fkey 
FOREIGN KEY (invited_by) 
REFERENCES auth.users(id) 
ON DELETE CASCADE;

-- 4. STORAGE BUCKET SECURITY
-- Assuming your bucket is named 'CompanyDocuments'
-- INSERT policy for Storage
CREATE POLICY "Users can upload their own documents"
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'CompanyDocuments' AND auth.uid() = owner);

-- SELECT policy for Storage
CREATE POLICY "Users can view their own documents"
ON storage.objects FOR SELECT TO authenticated 
USING (bucket_id = 'CompanyDocuments' AND auth.uid() = owner);

-- DELETE policy for Storage
CREATE POLICY "Users can delete their own documents"
ON storage.objects FOR DELETE TO authenticated 
USING (bucket_id = 'CompanyDocuments' AND auth.uid() = owner);
