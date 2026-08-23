-- ========================================================================================
-- 017_ultimate_rls_fix_v2.sql
-- Run this in Supabase SQL Editor. 
-- Fixes ambiguous column reference `id` -> `companies.id` that caused full table scans.
-- ========================================================================================

-- 1. Helper function for READ access (bypasses RLS recursion)
CREATE OR REPLACE FUNCTION public.has_company_access(target_company_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM companies c
    WHERE c.id = target_company_id
    AND (
      c.user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM resource_shares rs 
        WHERE rs.resource_id = target_company_id 
        AND rs.user_id = auth.uid()
      )
    )
  );
$$;

-- 2. Helper function for WRITE/INSERT access (bypasses RLS recursion)
CREATE OR REPLACE FUNCTION public.has_company_write_access(target_company_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM companies c
    WHERE c.id = target_company_id
    AND (
      c.user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM resource_shares rs 
        WHERE rs.resource_id = target_company_id 
        AND rs.user_id = auth.uid()
        AND rs.role IN ('Editor', 'Admin')
      )
    )
  );
$$;

-- 3. Reset Company Documents Policies
DROP POLICY IF EXISTS "Users can manage their own documents" ON public.company_documents;
DROP POLICY IF EXISTS "Users can view documents for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can insert documents only for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can update their own documents" ON public.company_documents;
DROP POLICY IF EXISTS "Users can update documents they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can delete their own documents" ON public.company_documents;

CREATE POLICY "Users can view documents for companies they have access to"
ON public.company_documents FOR SELECT
USING (
    auth.uid() = user_id OR
    public.has_company_access(company_id)
);

CREATE POLICY "Users can insert documents only for companies they have access to"
ON public.company_documents FOR INSERT
WITH CHECK (
    public.has_company_write_access(company_id)
);

CREATE POLICY "Users can update documents they have access to"
ON public.company_documents FOR UPDATE
USING (
    auth.uid() = user_id OR
    public.has_company_write_access(company_id)
);

CREATE POLICY "Users can delete documents they own"
ON public.company_documents FOR DELETE
USING (auth.uid() = user_id);

-- 4. Reset Companies Policies (for performance)
DROP POLICY IF EXISTS "Users can view companies they own or are shared with" ON public.companies;
DROP POLICY IF EXISTS "Users can update companies they own or are shared with as editors" ON public.companies;
DROP POLICY IF EXISTS "Users can insert companies" ON public.companies;
DROP POLICY IF EXISTS "Users can delete their own companies" ON public.companies;

CREATE POLICY "Users can view companies they own or are shared with"
ON public.companies FOR SELECT
USING (
    auth.uid() = user_id OR
    EXISTS (
        SELECT 1 FROM public.resource_shares rs 
        WHERE rs.resource_id = companies.id 
        AND rs.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY "Users can update companies they own or are shared with as editors"
ON public.companies FOR UPDATE
USING (
    auth.uid() = user_id OR
    EXISTS (
        SELECT 1 FROM public.resource_shares rs 
        WHERE rs.resource_id = companies.id 
        AND rs.user_id = (SELECT auth.uid())
        AND rs.role IN ('Editor', 'Admin')
    )
);

CREATE POLICY "Users can insert companies"
ON public.companies FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own companies"
ON public.companies FOR DELETE
USING (auth.uid() = user_id);
