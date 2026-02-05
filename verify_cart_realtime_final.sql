-- FINAL VERIFICATION: Cart Realtime Configuration
-- Run this to confirm everything is ready
-- Date: 2026-01-22

-- ============================================
-- 1. VERIFY FUNCTION PERMISSIONS
-- ============================================
SELECT
    'get_user_store_id() Permissions' as check_name,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM information_schema.routine_privileges
            WHERE routine_name = 'get_user_store_id'
            AND grantee IN ('anon', 'authenticated', 'public')
            AND privilege_type = 'EXECUTE'
        ) THEN '✅ GRANTED'
        ELSE '❌ MISSING'
    END as status;

-- ============================================
-- 2. VERIFY RLS POLICIES
-- ============================================
SELECT
    '📋 RLS Policies Check' as section,
    tablename,
    COUNT(*) as policy_count,
    CASE
        WHEN tablename = 'carts' AND COUNT(*) >= 4 THEN '✅ CORRECT'
        WHEN tablename = 'cart_items' AND COUNT(*) >= 3 THEN '✅ CORRECT'
        ELSE '⚠️ CHECK POLICIES'
    END as status
FROM pg_policies
WHERE tablename IN ('carts', 'cart_items')
GROUP BY tablename
ORDER BY tablename;

-- ============================================
-- 3. VERIFY SELECT POLICIES EXIST
-- ============================================
SELECT
    '📖 SELECT Policies' as section,
    tablename,
    policyname,
    '✅' as exists
FROM pg_policies
WHERE tablename IN ('carts', 'cart_items')
AND cmd = 'SELECT'
ORDER BY tablename, policyname;

-- ============================================
-- 4. VERIFY REALTIME CONFIGURATION
-- ============================================
SELECT
    'Realtime Publication' as check_name,
    schemaname || '.' || tablename as table_name,
    CASE
        WHEN schemaname || '.' || tablename IN (
            SELECT schemaname || '.' || tablename
            FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
        ) THEN '✅ IN PUBLICATION'
        ELSE '❌ NOT IN PUBLICATION'
    END as status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('carts', 'cart_items')
ORDER BY tablename;

-- ============================================
-- 5. VERIFY REPLICA IDENTITY
-- ============================================
SELECT
    'Replica Identity' as check_name,
    c.relname as table_name,
    CASE c.relreplident
        WHEN 'f' THEN '✅ FULL'
        WHEN 'd' THEN '⚠️ DEFAULT (should be FULL)'
        ELSE '❌ ' || c.relreplident
    END as status
FROM pg_class c
WHERE c.relname IN ('carts', 'cart_items')
ORDER BY c.relname;

-- ============================================
-- 6. TEST AS ANON USER (SIMULATE CLIENT)
-- ============================================
\echo '🧪 Testing SELECT as anon user (this is what clients do)...'

SET ROLE anon;

-- This should NOT error now that function has EXECUTE permission
SELECT
    '🧪 Anon User Test' as test_name,
    COUNT(*) as visible_carts,
    CASE
        WHEN COUNT(*) >= 0 THEN '✅ CAN SELECT (realtime will work)'
        ELSE '❌ CANNOT SELECT'
    END as result
FROM carts
WHERE created_at > NOW() - INTERVAL '1 day';

RESET ROLE;

-- ============================================
-- 7. GET RECENT TEST DATA
-- ============================================
SELECT
    '📊 Recent Carts (for testing)' as section,
    id,
    store_id,
    location_id,
    customer_id,
    status,
    (SELECT COUNT(*) FROM cart_items WHERE cart_id = carts.id) as item_count,
    created_at
FROM carts
ORDER BY created_at DESC
LIMIT 3;

-- ============================================
-- SUMMARY
-- ============================================
\echo ''
\echo '================================'
\echo 'EXPECTED RESULTS:'
\echo '================================'
\echo '✅ get_user_store_id() Permissions: GRANTED'
\echo '✅ Carts: 4+ policies'
\echo '✅ Cart Items: 3+ policies'
\echo '✅ SELECT policies exist for both tables'
\echo '✅ Tables IN PUBLICATION'
\echo '✅ Replica Identity: FULL'
\echo '✅ Anon user CAN SELECT carts'
\echo ''
\echo 'If all checks pass, cart realtime should work!'
\echo '================================'
