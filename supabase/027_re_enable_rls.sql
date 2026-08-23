-- ========================================================================================
-- 027_re_enable_rls.sql
-- Re-enables Row Level Security on the companies table.
-- ========================================================================================

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
