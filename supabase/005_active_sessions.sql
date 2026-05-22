-- ========================================================================================
-- Active Sessions and Revocation Setup Script
-- 
-- Run this script in the Supabase Studio SQL Editor to create helper functions
-- that allow users to view and revoke their own active sessions.
-- ========================================================================================

-- 1. Create a function to get active sessions for the authenticated user
CREATE OR REPLACE FUNCTION public.get_active_sessions()
RETURNS TABLE (
    id uuid,
    created_at timestamptz,
    updated_at timestamptz,
    user_agent text,
    ip_address text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT s.id, s.created_at, s.updated_at, s.user_agent, s.ip::text as ip_address
    FROM auth.sessions s
    WHERE s.user_id = auth.uid()
    ORDER BY s.updated_at DESC;
END;
$$;

-- 2. Create a function to revoke a specific session for the authenticated user
CREATE OR REPLACE FUNCTION public.revoke_session(session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    DELETE FROM auth.sessions
    WHERE id = session_id AND user_id = auth.uid();
END;
$$;
