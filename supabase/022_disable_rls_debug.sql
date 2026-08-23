-- ========================================================================================
-- 022_disable_rls_debug.sql
-- Run this in Supabase SQL Editor. 
-- Temporarily disables RLS on all tables to definitively prove if RLS is the bottleneck.
-- ========================================================================================

ALTER TABLE public.companies DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.resource_shares DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.institutions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_cards DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.resource_invitations DISABLE ROW LEVEL SECURITY;
