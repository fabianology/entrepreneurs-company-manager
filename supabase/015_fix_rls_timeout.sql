-- ========================================================================================
-- 015_fix_rls_timeout.sql
-- Run this in Supabase SQL Editor to fix the "canceling statement due to statement timeout"
-- ========================================================================================

-- 1. Add missing indexes to prevent Full Table Scans (which cause the timeout)
CREATE INDEX IF NOT EXISTS idx_resource_shares_resource_id ON public.resource_shares(resource_id);
CREATE INDEX IF NOT EXISTS idx_resource_shares_user_id ON public.resource_shares(user_id);

-- 2. Simplify the overly-nested RLS policies for documents
DROP POLICY IF EXISTS "Users can view documents for companies they have access to" ON public.company_documents;

CREATE POLICY "Users can view documents for companies they have access to"
ON public.company_documents FOR SELECT
USING (
    auth.uid() = user_id OR
    EXISTS (
        -- We only need to check if the company exists for this user.
        -- Postgres automatically applies the `companies` RLS policy to this subquery!
        SELECT 1 FROM public.companies c
        WHERE c.id = company_documents.company_id
    )
);

DROP POLICY IF EXISTS "Users can insert documents only for companies they have access to" ON public.company_documents;

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
