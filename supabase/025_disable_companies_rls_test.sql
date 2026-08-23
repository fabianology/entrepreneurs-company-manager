-- ========================================================================================
-- 025_disable_companies_rls_test.sql
-- TEMPORARILY disable companies RLS to conclusively prove if the 9s delay is the database.
-- ========================================================================================

ALTER TABLE public.companies DISABLE ROW LEVEL SECURITY;
