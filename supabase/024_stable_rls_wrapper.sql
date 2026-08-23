-- ========================================================================================
-- 024_stable_rls_wrapper.sql
-- Fixes the catastrophic 7.6s query planner bug by using a STABLE wrapper around auth.uid()
-- ========================================================================================

-- 1. Create a STABLE wrapper function to prevent Postgres from evaluating auth.uid() per row
CREATE OR REPLACE FUNCTION public.requesting_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

-- 2. Drop the old unoptimized policies
DROP POLICY IF EXISTS "Users can view companies they own or are shared with" ON public.companies;
DROP POLICY IF EXISTS "Users can update companies they own or are shared with as editors" ON public.companies;
DROP POLICY IF EXISTS "Users can insert companies" ON public.companies;
DROP POLICY IF EXISTS "Users can delete their own companies" ON public.companies;

DROP POLICY IF EXISTS "Users can view documents for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can insert documents only for companies they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can update documents they have access to" ON public.company_documents;
DROP POLICY IF EXISTS "Users can delete documents they own" ON public.company_documents;

-- 3. Recreate policies using the STABLE function instead of auth.uid()
CREATE POLICY "Users can view companies they own or are shared with"
ON public.companies FOR SELECT
USING (
    user_id = public.requesting_user_id() OR
    id IN (
        SELECT resource_id FROM public.resource_shares WHERE user_id = public.requesting_user_id()
    )
);

CREATE POLICY "Users can update companies they own or are shared with as editors"
ON public.companies FOR UPDATE
USING (
    user_id = public.requesting_user_id() OR
    id IN (
        SELECT resource_id FROM public.resource_shares WHERE user_id = public.requesting_user_id() AND role IN ('Editor', 'Admin')
    )
);

CREATE POLICY "Users can insert companies"
ON public.companies FOR INSERT
WITH CHECK (user_id = public.requesting_user_id());

CREATE POLICY "Users can delete their own companies"
ON public.companies FOR DELETE
USING (user_id = public.requesting_user_id());

-- 4. Recreate Document policies using the STABLE function
CREATE POLICY "Users can view documents for companies they have access to"
ON public.company_documents FOR SELECT
USING (
    user_id = public.requesting_user_id() OR
    company_id IN (SELECT id FROM public.companies WHERE user_id = public.requesting_user_id()) OR
    company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = public.requesting_user_id())
);

CREATE POLICY "Users can insert documents only for companies they have access to"
ON public.company_documents FOR INSERT
WITH CHECK (
    user_id = public.requesting_user_id() AND (
        company_id IN (SELECT id FROM public.companies WHERE user_id = public.requesting_user_id()) OR
        company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = public.requesting_user_id() AND role IN ('Editor', 'Admin'))
    )
);

CREATE POLICY "Users can update documents they have access to"
ON public.company_documents FOR UPDATE
USING (
    user_id = public.requesting_user_id() OR
    company_id IN (SELECT id FROM public.companies WHERE user_id = public.requesting_user_id()) OR
    company_id IN (SELECT resource_id FROM public.resource_shares WHERE user_id = public.requesting_user_id() AND role IN ('Editor', 'Admin'))
);

CREATE POLICY "Users can delete documents they own"
ON public.company_documents FOR DELETE
USING (user_id = public.requesting_user_id());
