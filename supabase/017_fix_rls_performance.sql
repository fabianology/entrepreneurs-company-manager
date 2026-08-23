-- 017_fix_rls_performance.sql
-- Drop the slow EXISTS policies
DROP POLICY IF EXISTS "Users can view companies they own or are shared with" ON public.companies;
DROP POLICY IF EXISTS "Users can view documents for companies they have access to" ON public.company_documents;

-- Create fast IN (...) policies that utilize indexes effectively
CREATE POLICY "Users can view companies they own or are shared with"
ON public.companies FOR SELECT
USING (
    user_id = auth.uid() OR
    id IN (
        SELECT resource_id 
        FROM public.resource_shares 
        WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can view documents for companies they have access to"
ON public.company_documents FOR SELECT
USING (
    user_id = auth.uid() OR
    company_id IN (
        SELECT id 
        FROM public.companies 
        WHERE user_id = auth.uid()
    ) OR
    company_id IN (
        SELECT resource_id 
        FROM public.resource_shares 
        WHERE user_id = auth.uid()
    )
);
