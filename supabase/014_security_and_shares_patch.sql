-- ========================================================================================
-- 014_security_and_shares_patch.sql
-- Run this script in the Supabase Studio SQL Editor
-- ========================================================================================

-- 1. CREATE RESOURCE SHARES TABLE
CREATE TABLE IF NOT EXISTS public.resource_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id UUID NOT NULL,
    resource_type TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'Viewer',
    sender_email TEXT,
    sender_display_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on resource_shares
ALTER TABLE public.resource_shares ENABLE ROW LEVEL SECURITY;

-- Users can view and manage shares sent to them
CREATE POLICY "Users can access their own shares"
ON public.resource_shares FOR ALL
USING (auth.uid() = user_id);

-- 2. FIX COMPANIES RLS POLICIES
DROP POLICY IF EXISTS "Users can manage their own companies" ON public.companies;

CREATE POLICY "Users can view companies they own or are shared with"
ON public.companies FOR SELECT
USING (
    auth.uid() = user_id OR
    EXISTS (
        SELECT 1 FROM public.resource_shares rs 
        WHERE rs.resource_id = companies.id 
        AND rs.user_id = auth.uid()
    )
);

CREATE POLICY "Users can update companies they own or are shared with as editors"
ON public.companies FOR UPDATE
USING (
    auth.uid() = user_id OR
    EXISTS (
        SELECT 1 FROM public.resource_shares rs 
        WHERE rs.resource_id = companies.id 
        AND rs.user_id = auth.uid()
        AND rs.role IN ('Editor', 'Admin')
    )
);

CREATE POLICY "Users can insert companies"
ON public.companies FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own companies"
ON public.companies FOR DELETE
USING (auth.uid() = user_id);


-- 3. SECURE COMPANY DOCUMENTS UPLOADS
DROP POLICY IF EXISTS "Users can manage their own documents" ON public.company_documents;

CREATE POLICY "Users can view documents for companies they have access to"
ON public.company_documents FOR SELECT
USING (
    auth.uid() = user_id OR
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = company_documents.company_id
        AND (
            c.user_id = auth.uid() OR
            EXISTS (
                SELECT 1 FROM public.resource_shares rs 
                WHERE rs.resource_id = c.id 
                AND rs.user_id = auth.uid()
            )
        )
    )
);

CREATE POLICY "Users can insert documents only for companies they have access to"
ON public.company_documents FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = company_documents.company_id
        AND (
            c.user_id = auth.uid() OR
            EXISTS (
                SELECT 1 FROM public.resource_shares rs 
                WHERE rs.resource_id = c.id 
                AND rs.user_id = auth.uid()
                AND rs.role IN ('Editor', 'Admin')
            )
        )
    )
);

CREATE POLICY "Users can update their own documents"
ON public.company_documents FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own documents"
ON public.company_documents FOR DELETE
USING (auth.uid() = user_id);
