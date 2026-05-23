-- ========================================================================================
-- Supabase Security & RLS Setup Script for Sharing
-- 
-- Run this script in the Supabase Studio SQL Editor to allow users to view resources
-- that have been shared with them via their email address.
-- ========================================================================================

-- Companies
CREATE POLICY "Users can view shared companies" 
ON companies FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM resource_invitations 
    WHERE resource_invitations.resource_id = companies.id 
    AND resource_invitations.resource_type = 'company' 
    AND resource_invitations.email = auth.jwt()->>'email'
  )
);

-- Subscriptions
CREATE POLICY "Users can view subscriptions of shared companies" 
ON subscriptions FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM resource_invitations 
    WHERE resource_invitations.resource_id = subscriptions.company_id 
    AND resource_invitations.resource_type = 'company' 
    AND resource_invitations.email = auth.jwt()->>'email'
  )
);

-- Institutions
CREATE POLICY "Users can view institutions of shared companies" 
ON institutions FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM resource_invitations 
    WHERE resource_invitations.resource_id = institutions.company_id 
    AND resource_invitations.resource_type = 'company' 
    AND resource_invitations.email = auth.jwt()->>'email'
  )
);

-- Financial Cards
CREATE POLICY "Users can view cards of shared companies" 
ON financial_cards FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM resource_invitations 
    WHERE resource_invitations.resource_id = financial_cards.company_id 
    AND resource_invitations.resource_type = 'company' 
    AND resource_invitations.email = auth.jwt()->>'email'
  )
);

-- Loans
CREATE POLICY "Users can view loans of shared companies" 
ON loans FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM resource_invitations 
    WHERE resource_invitations.resource_id = loans.company_id 
    AND resource_invitations.resource_type = 'company' 
    AND resource_invitations.email = auth.jwt()->>'email'
  )
);

-- Company Documents
CREATE POLICY "Users can view documents of shared companies" 
ON company_documents FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM resource_invitations 
    WHERE resource_invitations.resource_id = company_documents.company_id 
    AND resource_invitations.resource_type = 'company' 
    AND resource_invitations.email = auth.jwt()->>'email'
  )
);

-- To allow full editing (INSERT/UPDATE/DELETE) for Editors/Admins, 
-- additional policies with `FOR ALL` checking `role IN ('Editor', 'Admin')` would be added.
