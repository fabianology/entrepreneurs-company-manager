-- ========================================================================================
-- 026_exists_rls_fix.sql
-- Replaces the IN clause with an EXISTS clause using the STABLE wrapper.
-- This is the final Postgres-native optimization available.
-- ========================================================================================

DROP POLICY IF EXISTS "Users can view companies they own or are shared with" ON public.companies;

CREATE POLICY "Users can view companies they own or are shared with"
ON public.companies FOR SELECT
USING (
    user_id = public.requesting_user_id() OR
    EXISTS (
        SELECT 1 FROM public.resource_shares rs
        WHERE rs.resource_id = companies.id
        AND rs.user_id = public.requesting_user_id()
    )
);
