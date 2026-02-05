-- Comprehensive diagnostic for cart realtime
-- Run this to see what's happening

-- 1. Check if realtime is enabled for cart tables
SELECT
  schemaname,
  tablename,
  CASE WHEN schemaname || '.' || tablename IN (
    SELECT schemaname || '.' || tablename
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
  ) THEN '✅ IN PUBLICATION'
  ELSE '❌ NOT IN PUBLICATION'
  END as publication_status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('carts', 'cart_items', 'location_queue')
ORDER BY tablename;

-- 2. Check replica identity
SELECT
  c.relname as table_name,
  CASE c.relreplident
    WHEN 'd' THEN '❌ DEFAULT (only primary key)'
    WHEN 'f' THEN '✅ FULL (all columns)'
    WHEN 'i' THEN '⚠️ INDEX'
    WHEN 'n' THEN '❌ NOTHING'
  END as replica_identity
FROM pg_class c
WHERE c.relname IN ('carts', 'cart_items', 'location_queue')
ORDER BY c.relname;

-- 3. Check RLS policies that affect SELECT (what clients can see)
SELECT
  tablename,
  policyname,
  cmd,
  CASE
    WHEN cmd = 'SELECT' THEN '✅ Affects realtime visibility'
    WHEN cmd = 'ALL' THEN '⚠️ Affects all operations'
    ELSE 'ℹ️ Other'
  END as impact
FROM pg_policies
WHERE tablename IN ('carts', 'cart_items')
  AND (cmd = 'SELECT' OR cmd = 'ALL')
ORDER BY tablename, cmd, policyname;

-- 4. Get a sample cart to test with
SELECT
  id,
  store_id,
  location_id,
  customer_id,
  status,
  created_at,
  (SELECT COUNT(*) FROM cart_items WHERE cart_id = carts.id) as item_count
FROM carts
ORDER BY created_at DESC
LIMIT 5;

-- 5. Check if there are any recent cart_items inserts (last 10 minutes)
SELECT
  ci.id,
  ci.cart_id,
  ci.product_name,
  ci.quantity,
  ci.created_at,
  ci.updated_at,
  EXTRACT(EPOCH FROM (NOW() - ci.created_at)) as seconds_ago
FROM cart_items ci
WHERE ci.created_at > NOW() - INTERVAL '10 minutes'
ORDER BY ci.created_at DESC
LIMIT 10;

-- 6. Test if we can select carts as anon user (simulating client)
-- This is what determines if realtime events are delivered!
SET ROLE anon;
SELECT
  COUNT(*) as visible_carts,
  'These are carts an anon client can see (and receive realtime for)' as note
FROM carts;
RESET ROLE;

-- 7. Test if we can select cart_items as anon user
SET ROLE anon;
SELECT
  COUNT(*) as visible_cart_items,
  'These are cart_items an anon client can see (and receive realtime for)' as note
FROM cart_items;
RESET ROLE;
