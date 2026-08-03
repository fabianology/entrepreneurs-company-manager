-- ========================================================================================
-- RLS Edit Policies for Shared Resources
--
-- This script adds INSERT, UPDATE, and DELETE policies for users who hold an
-- 'Admin' or 'Editor' role in a shared company.
-- ========================================================================================

-- 1. Create a SECURITY DEFINER function to securely check editing permissions
CREATE OR REPLACE FUNCTION check_company_edit_permission(check_company_id UUID, check_email TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM resource_invitations 
    WHERE resource_id = check_company_id 
    AND resource_type = 'company' 
    AND email = check_email
    AND role IN ('Admin', 'Editor')
  );
$$;

-- 2. Add INSERT, UPDATE, and DELETE policies for 'financial_cards'
CREATE POLICY "Invited editors can insert cards" 
ON financial_cards FOR INSERT WITH CHECK (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can update cards" 
ON financial_cards FOR UPDATE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can delete cards" 
ON financial_cards FOR DELETE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

-- 3. Add INSERT, UPDATE, and DELETE policies for 'subscriptions'
CREATE POLICY "Invited editors can insert subscriptions" 
ON subscriptions FOR INSERT WITH CHECK (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can update subscriptions" 
ON subscriptions FOR UPDATE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can delete subscriptions" 
ON subscriptions FOR DELETE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

-- 4. Add INSERT, UPDATE, and DELETE policies for 'institutions'
CREATE POLICY "Invited editors can insert institutions" 
ON institutions FOR INSERT WITH CHECK (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can update institutions" 
ON institutions FOR UPDATE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can delete institutions" 
ON institutions FOR DELETE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

-- 5. Add INSERT, UPDATE, and DELETE policies for 'loans'
CREATE POLICY "Invited editors can insert loans" 
ON loans FOR INSERT WITH CHECK (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can update loans" 
ON loans FOR UPDATE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can delete loans" 
ON loans FOR DELETE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

-- 6. Add INSERT, UPDATE, and DELETE policies for 'company_documents'
CREATE POLICY "Invited editors can insert documents" 
ON company_documents FOR INSERT WITH CHECK (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can update documents" 
ON company_documents FOR UPDATE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

CREATE POLICY "Invited editors can delete documents" 
ON company_documents FOR DELETE USING (
  check_company_edit_permission(company_id, auth.jwt()->>'email')
);

-- 7. Add UPDATE policies for 'companies' (Admins/Editors can edit the company info, but typically only owner deletes)
CREATE POLICY "Invited editors can update companies" 
ON companies FOR UPDATE USING (
  check_company_edit_permission(id, auth.jwt()->>'email')
);
