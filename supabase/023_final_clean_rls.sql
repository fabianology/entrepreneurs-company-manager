-- ========================================================================================
-- 023_final_clean_rls.sql
-- Run this in Supabase SQL Editor. 
-- Uses the absolute gold standard IN-clause pattern for Supabase RLS.
-- Avoids PL/pgSQL completely and avoids ANY correlated subqueries.
-- ========================================================================================

-- 1. Ensure indexes exist (critical for subqueries to be O(1))
CREATE INDEX IF NOT EXISTS idx_rs_user_id ON public.resource_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_rs_resource_id ON public.resource_shares(resource_id);
CREATE INDEX IF NOT EXISTS idx_companies_user_id ON public.companies(user_id);

-- 2. Drop the procedural functions from 021 to ensure they don't block
DROP FUNCTION IF EXISTS public.can_view_company(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.can_edit_company(UUID, UUID) CASCADE;

-- 3. Drop existing policies to start fresh
DROP POLICY IF EXISTS "Users can view documents for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can insert documents only for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can update documents they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can delete documents they own" ON public.company_documents;

DROP POLICY IF EXISTS "Users can view companies they own or are shared with" ON public.companies;
DROP POLICY IF EXISTS "Users can update companies they own or are shared with as editors" ON public.companies;
DROP POLICY IF EXISTS "Users can insert companies" ON public.companies;
DROP POLICY IF EXISTS "Users can delete their own companies" ON public.companies;

-- 4. Enable RLS (in case it was left disabled by 022)
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_documents ENABLE ROW LEVEL SECURITY;

-- 5. Standard optimized IN-clause policies for Companies
CREATE POLICY "Users can view companies they own or are shared with"
ON public.companies FOR SELECT
USING (
    user_id = (SELECT auth.uid()) OR
    id IN (
        SELECT resource_id FROM public.resource_shares WHERE user_id = (SELECT auth.uid())
    )
);

CREATE POLICY "Users can update companies they own or are shared with as editors"
ON public.companies FOR UPDATE
USING (
    user_id = (SELECT auth.uid()) OR
    id IN (
        SELECT resource_id FROM public.resource_shares WHERE user_id = (SELECT auth.uid()) AND role IN ('Editor', 'Admin')
    )
);

CREATE POLICY "Users can insert companies"
ON public.companies FOR INSERT
WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can delete their own companies"
ON public.companies FOR DELETE
USING (user_id = (SELECT auth.uid()));

-- 6. Standard optimized IN-clause policies for Company Documents
CREATE POLICY "Users can view documents for companies they have access to"
ON public.company_documents FOR SELECT
USING (
    user_id = (SELECT auth.uid()) OR
    company_id IN (SELECT id FROM public.companies WHERE user_id = (SELECT auth.uid())) OR
    company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = (SELECT auth.uid()))
);

CREATE POLICY "Users can insert documents only for companies they have access to"
ON public.company_documents FOR INSERT
WITH CHECK (
    user_id = (SELECT auth.uid()) AND (
        company_id IN (SELECT id FROM public.companies WHERE user_id = (SELECT auth.uid())) OR
        company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = (SELECT auth.uid()) AND role IN ('Editor', 'Admin'))
    )
);

CREATE POLICY "Users can update documents they have access to"
ON public.company_documents FOR UPDATE
USING (
    user_id = (SELECT auth.uid()) OR
    company_id IN (SELECT id FROM public.companies WHERE user_id = (SELECT auth.uid())) OR
    company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = (SELECT auth.uid()) AND role IN ('Editor', 'Admin'))
);

CREATE POLICY "Users can delete documents they own"
ON public.company_documents FOR DELETE
USING (user_id = (SELECT auth.uid()));
