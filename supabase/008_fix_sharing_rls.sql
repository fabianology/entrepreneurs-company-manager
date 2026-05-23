-- ========================================================================================
-- Fix Infinite Recursion in RLS Policies
--
-- This script replaces the direct table queries in the RLS policies with
-- SECURITY DEFINER functions. This breaks the infinite loop caused by
-- foreign key checks and circular policy references between `companies`
-- and `resource_invitations`.
-- ========================================================================================

-- 1. Drop the previous policies that caused the infinite loop
DROP POLICY IF EXISTS "Users can view shared companies" ON companies;
DROP POLICY IF EXISTS "Users can view subscriptions of shared companies" ON subscriptions;
DROP POLICY IF EXISTS "Users can view institutions of shared companies" ON institutions;
DROP POLICY IF EXISTS "Users can view cards of shared companies" ON financial_cards;
DROP POLICY IF EXISTS "Users can view loans of shared companies" ON loans;
DROP POLICY IF EXISTS "Users can view documents of shared companies" ON company_documents;

-- 2. Create a SECURITY DEFINER function to safely check for invitations without triggering RLS recursively
CREATE OR REPLACE FUNCTION check_has_company_invitation(check_company_id UUID, check_email TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER -- This bypasses RLS so it doesn't trigger an infinite loop
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM resource_invitations 
    WHERE resource_id = check_company_id 
    AND resource_type = 'company' 
    AND email = check_email
  );
$$;

-- 3. Re-create the policies using the safe function
CREATE POLICY "Users can view shared companies" 
ON companies FOR SELECT USING (
  check_has_company_invitation(id, auth.jwt()->>'email')
);

CREATE POLICY "Users can view subscriptions of shared companies" 
ON subscriptions FOR SELECT USING (
  check_has_company_invitation(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Users can view institutions of shared companies" 
ON institutions FOR SELECT USING (
  check_has_company_invitation(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Users can view cards of shared companies" 
ON financial_cards FOR SELECT USING (
  check_has_company_invitation(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Users can view loans of shared companies" 
ON loans FOR SELECT USING (
  check_has_company_invitation(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Users can view documents of shared companies" 
ON company_documents FOR SELECT USING (
  check_has_company_invitation(company_id, auth.jwt()->>'email')
);
