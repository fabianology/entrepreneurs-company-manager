-- ========================================================================================
-- 020_fast_rls_fix_cascade.sql
-- Run this in Supabase SQL Editor. 
-- Fixes statement timeout by replacing correlated EXISTS subqueries with 
-- non-correlated IN clauses. Includes CASCADE to properly remove previous dependencies.
-- ========================================================================================

-- 1. Ensure indexes exist (critical for IN clauses)
CREATE INDEX IF NOT EXISTS idx_resource_shares_user_id ON public.resource_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_resource_shares_resource_id ON public.resource_shares(resource_id);

-- 2. Drop all previous functions and policies (using CASCADE to handle dependencies)
DROP FUNCTION IF EXISTS public.has_company_access(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.has_company_write_access(UUID) CASCADE;

-- (The CASCADE above automatically dropped the dependent policies, but we'll include these to be safe)
DROP POLICY IF EXISTS "Users can view documents for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can insert documents only for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can update documents they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can delete documents they own" ON public.company_documents;

DROP POLICY IF EXISTS "Users can view companies they own or are shared with" ON public.companies;
DROP POLICY IF EXISTS "Users can update companies they own or are shared with as editors" ON public.companies;
DROP POLICY IF EXISTS "Users can insert companies" ON public.companies;
DROP POLICY IF EXISTS "Users can delete their own companies" ON public.companies;


-- 3. High-Performance Non-Correlated Policies for Companies
CREATE POLICY "Users can view companies they own or are shared with"
ON public.companies FOR SELECT
USING (
    auth.uid() = user_id OR
    id IN (
        SELECT resource_id FROM public.resource_shares WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can update companies they own or are shared with as editors"
ON public.companies FOR UPDATE
USING (
    auth.uid() = user_id OR
    id IN (
        SELECT resource_id FROM public.resource_shares WHERE user_id = auth.uid() AND role IN ('Editor', 'Admin')
    )
);

CREATE POLICY "Users can insert companies"
ON public.companies FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own companies"
ON public.companies FOR DELETE
USING (auth.uid() = user_id);


-- 4. High-Performance Non-Correlated Policies for Company Documents
CREATE POLICY "Users can view documents for companies they have access to"
ON public.company_documents FOR SELECT
USING (
    auth.uid() = user_id OR
    company_id IN (SELECT id FROM public.companies WHERE user_id = auth.uid()) OR
    company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = auth.uid())
);

CREATE POLICY "Users can insert documents only for companies they have access to"
ON public.company_documents FOR INSERT
WITH CHECK (
    auth.uid() = user_id AND (
        company_id IN (SELECT id FROM public.companies WHERE user_id = auth.uid()) OR
        company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = auth.uid() AND role IN ('Editor', 'Admin'))
    )
);

CREATE POLICY "Users can update documents they have access to"
ON public.company_documents FOR UPDATE
USING (
    auth.uid() = user_id OR
    company_id IN (SELECT id FROM public.companies WHERE user_id = auth.uid()) OR
    company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = auth.uid() AND role IN ('Editor', 'Admin'))
);

CREATE POLICY "Users can delete documents they own"
ON public.company_documents FOR DELETE
USING (auth.uid() = user_id);
