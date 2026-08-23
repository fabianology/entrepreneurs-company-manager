-- ========================================================================================
-- 021_bulletproof_rls.sql
-- Run this in Supabase SQL Editor. 
-- 100% eliminates Postgres Query Planner loops by wrapping ALL complex checks 
-- inside isolated Security Definer functions.
-- ========================================================================================

-- 1. Helper function for READ access (bypasses planner recursion completely)
CREATE OR REPLACE FUNCTION public.can_view_company(c_id UUID, c_owner UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- If the user owns it, fast return
  IF c_owner = auth.uid() THEN
    RETURN TRUE;
  END IF;
  
  -- Otherwise, check if they have a resource share (bypassing RLS entirely)
  RETURN EXISTS (
    SELECT 1 FROM resource_shares rs 
    WHERE rs.resource_id = c_id 
    AND rs.user_id = auth.uid()
  );
END;
$$;

-- 2. Helper function for WRITE/INSERT access
CREATE OR REPLACE FUNCTION public.can_edit_company(c_id UUID, c_owner UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF c_owner = auth.uid() THEN
    RETURN TRUE;
  END IF;
  
  RETURN EXISTS (
    SELECT 1 FROM resource_shares rs 
    WHERE rs.resource_id = c_id 
    AND rs.user_id = auth.uid()
    AND rs.role IN ('Editor', 'Admin')
  );
END;
$$;

-- 3. Drop existing policies
DROP POLICY IF EXISTS "Users can view documents for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can insert documents only for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can update documents they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can delete documents they own" ON public.company_documents;

DROP POLICY IF EXISTS "Users can view companies they own or are shared with" ON public.companies;
DROP POLICY IF EXISTS "Users can update companies they own or are shared with as editors" ON public.companies;
DROP POLICY IF EXISTS "Users can insert companies" ON public.companies;
DROP POLICY IF EXISTS "Users can delete their own companies" ON public.companies;

-- 4. Bulletproof Policies for Companies
CREATE POLICY "Users can view companies they own or are shared with"
ON public.companies FOR SELECT
USING ( public.can_view_company(id, user_id) );

CREATE POLICY "Users can update companies they own or are shared with as editors"
ON public.companies FOR UPDATE
USING ( public.can_edit_company(id, user_id) );

CREATE POLICY "Users can insert companies"
ON public.companies FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own companies"
ON public.companies FOR DELETE
USING (auth.uid() = user_id);

-- 5. Bulletproof Policies for Company Documents
CREATE POLICY "Users can view documents for companies they have access to"
ON public.company_documents FOR SELECT
USING ( public.can_view_company(company_id, user_id) );

CREATE POLICY "Users can insert documents only for companies they have access to"
ON public.company_documents FOR INSERT
WITH CHECK ( public.can_edit_company(company_id, user_id) );

CREATE POLICY "Users can update documents they have access to"
ON public.company_documents FOR UPDATE
USING ( public.can_edit_company(company_id, user_id) );

CREATE POLICY "Users can delete documents they own"
ON public.company_documents FOR DELETE
USING (auth.uid() = user_id);
