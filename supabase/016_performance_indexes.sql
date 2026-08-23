-- 016_performance_indexes.sql
CREATE INDEX IF NOT EXISTS idx_resource_shares_user_id ON public.resource_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_resource_shares_resource_id ON public.resource_shares(resource_id);
CREATE INDEX IF NOT EXISTS idx_company_documents_company_id ON public.company_documents(company_id);
CREATE INDEX IF NOT EXISTS idx_companies_user_id ON public.companies(user_id);

CREATE INDEX IF NOT EXISTS idx_resource_invitations_invited_by ON public.resource_invitations(invited_by);
CREATE INDEX IF NOT EXISTS idx_resource_invitations_email ON public.resource_invitations(email);
