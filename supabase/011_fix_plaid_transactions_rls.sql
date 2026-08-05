-- FIX: Run this in Supabase SQL Editor to fix plaid_transactions RLS
-- This ensures users can read their own transactions

-- Step 1: Drop existing policy if it exists (in case it was partially applied)
DROP POLICY IF EXISTS "Users own their transactions" ON plaid_transactions;
DROP POLICY IF EXISTS "users_own_transactions" ON plaid_transactions;
DROP POLICY IF EXISTS "Allow users to read own transactions" ON plaid_transactions;

-- Step 2: Make sure RLS is enabled
ALTER TABLE plaid_transactions ENABLE ROW LEVEL SECURITY;

-- Step 3: Create proper policies
-- SELECT: users can read their own transactions
CREATE POLICY "users_read_own_transactions"
    ON plaid_transactions FOR SELECT
    USING (auth.uid() = user_id);

-- INSERT/UPDATE/DELETE: service role handles this via edge functions
-- (no user-level write policy needed)

-- Step 4: Verify policy works - should return count when authenticated
-- SELECT count(*) FROM plaid_transactions;

-- Step 5: Check current RLS status
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'plaid_transactions';

-- Step 6: View existing policies
SELECT policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'plaid_transactions';
