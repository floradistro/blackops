-- EMERGENCY DIAGNOSTIC: Nothing is realtime
-- Date: 2026-01-22 19:35 EST

\echo '=========================================='
\echo 'CHECKING WHAT BROKE'
\echo '=========================================='
\echo ''

-- ============================================
-- 1. CHECK IF DATA IS BEING WRITTEN AT ALL
-- ============================================
\echo '1️⃣ RECENT DATABASE ACTIVITY (Last 10 minutes):'
\echo ''

SELECT
    'location_queue' as table_name,
    COUNT(*) as recent_records,
    MAX(created_at) as most_recent
FROM location_queue
WHERE created_at > NOW() - INTERVAL '10 minutes'
UNION ALL
SELECT
    'carts' as table_name,
    COUNT(*) as recent_records,
    MAX(created_at) as most_recent
FROM carts
WHERE created_at > NOW() - INTERVAL '10 minutes'
UNION ALL
SELECT
    'cart_items' as table_name,
    COUNT(*) as recent_records,
    MAX(created_at) as most_recent
FROM cart_items
WHERE created_at > NOW() - INTERVAL '10 minutes'
ORDER BY table_name;

\echo ''
\echo '=========================================='

-- ============================================
-- 2. TEST ANON USER PERMISSIONS
-- ============================================
\echo '2️⃣ TESTING AS ANON USER (what clients see):'
\echo ''

SET ROLE anon;

-- Test location_queue
\echo 'Can anon SELECT location_queue?'
SELECT COUNT(*) as visible_queue_entries FROM location_queue;

-- Test carts
\echo 'Can anon SELECT carts?'
SELECT COUNT(*) as visible_carts FROM carts;

-- Test cart_items
\echo 'Can anon SELECT cart_items?'
SELECT COUNT(*) as visible_cart_items FROM cart_items;

RESET ROLE;

\echo ''
\echo '=========================================='

-- ============================================
-- 3. CHECK REALTIME PUBLICATION
-- ============================================
\echo '3️⃣ REALTIME PUBLICATION STATUS:'
\echo ''

SELECT
    schemaname || '.' || tablename as table_name,
    'IN PUBLICATION' as status
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename IN ('location_queue', 'carts', 'cart_items')
ORDER BY tablename;

\echo ''
\echo '=========================================='

-- ============================================
-- 4. CHECK REPLICA IDENTITY
-- ============================================
\echo '4️⃣ REPLICA IDENTITY:'
\echo ''

SELECT
    c.relname as table_name,
    CASE c.relreplident
        WHEN 'f' THEN 'FULL ✅'
        WHEN 'd' THEN 'DEFAULT ⚠️'
        ELSE c.relreplident::text
    END as replica_identity
FROM pg_class c
WHERE c.relname IN ('location_queue', 'carts', 'cart_items')
ORDER BY c.relname;

\echo ''
\echo '=========================================='

-- ============================================
-- 5. CHECK FUNCTION PERMISSIONS
-- ============================================
\echo '5️⃣ FUNCTION PERMISSIONS:'
\echo ''

SELECT
    routine_name,
    grantee,
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'get_user_store_id'
ORDER BY grantee;

\echo ''
\echo '=========================================='

-- ============================================
-- 6. CHECK RLS POLICIES
-- ============================================
\echo '6️⃣ RLS POLICIES (SELECT only):'
\echo ''

SELECT
    tablename,
    policyname,
    cmd
FROM pg_policies
WHERE tablename IN ('location_queue', 'carts', 'cart_items')
AND cmd IN ('SELECT', 'ALL')
ORDER BY tablename, cmd, policyname;

\echo ''
\echo '=========================================='

-- ============================================
-- 7. SAMPLE RECENT DATA
-- ============================================
\echo '7️⃣ SAMPLE RECENT DATA:'
\echo ''

\echo 'Recent queue entries:'
SELECT
    id,
    customer_name,
    location_id,
    status,
    created_at
FROM location_queue
ORDER BY created_at DESC
LIMIT 3;

\echo ''
\echo 'Recent carts:'
SELECT
    id,
    store_id,
    location_id,
    customer_id,
    status,
    created_at
FROM carts
ORDER BY created_at DESC
LIMIT 3;

\echo ''
\echo '=========================================='
\echo 'DIAGNOSIS COMPLETE'
\echo '=========================================='
