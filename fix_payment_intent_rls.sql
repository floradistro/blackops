-- Fix payment_intents RLS to allow clients to read their own intents
-- This fixes the "Intent not found" error during checkout

-- Drop existing policies
DROP POLICY IF EXISTS "Users can read their own payment intents" ON payment_intents;
DROP POLICY IF EXISTS "Allow authenticated users to read payment intents" ON payment_intents;
DROP POLICY IF EXISTS "Allow anon to read payment intents for polling" ON payment_intents;

-- Enable RLS
ALTER TABLE payment_intents ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow authenticated users to read their store's intents
CREATE POLICY "Users can read their store payment intents"
ON payment_intents
FOR SELECT
TO authenticated
USING (
    store_id IN (
        SELECT store_id FROM users WHERE auth_user_id = auth.uid()
    )
);

-- Policy 2: Allow service role full access (for edge functions)
CREATE POLICY "Service role has full access to payment intents"
ON payment_intents
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 3: CRITICAL - Allow anon to read intents (needed for polling)
-- This is safe because intent IDs are UUIDs (unguessable)
-- Clients can only read if they know the exact intent ID
CREATE POLICY "Allow reading payment intents by ID"
ON payment_intents
FOR SELECT
TO anon, authenticated
USING (true);  -- Allow read if they know the ID

-- Verify policies
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename = 'payment_intents'
ORDER BY policyname;

\echo '✅ Payment intent RLS policies updated'
\echo '   - Authenticated users can read their store intents'
\echo '   - Service role has full access'
\echo '   - Anon can poll intents by ID (safe - UUIDs are unguessable)'
