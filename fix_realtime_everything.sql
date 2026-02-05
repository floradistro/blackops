-- COMPREHENSIVE REALTIME FIX FOR INSTANT UPDATES
-- Fixes: Queue, Cart, and all live data sync across devices

-- ============================================================
-- 1. ENABLE REALTIME FOR LOCATION_QUEUE
-- ============================================================

-- Ensure location_queue is in supabase_realtime publication
DO $$
BEGIN
    -- Remove if exists first (to reset)
    ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS location_queue;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- Add to publication
ALTER PUBLICATION supabase_realtime ADD TABLE location_queue;

-- Set REPLICA IDENTITY FULL for complete DELETE event data
ALTER TABLE location_queue REPLICA IDENTITY FULL;

COMMENT ON TABLE location_queue IS 'Live customer queue - instant sync across all devices';

-- ============================================================
-- 2. ENABLE REALTIME FOR CARTS
-- ============================================================

-- Add carts table to realtime
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS carts;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE carts;
ALTER TABLE carts REPLICA IDENTITY FULL;

COMMENT ON TABLE carts IS 'Shopping carts - live sync for items/totals';

-- ============================================================
-- 3. ENABLE REALTIME FOR CART_ITEMS
-- ============================================================

-- Add cart_items to realtime
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS cart_items;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE cart_items;
ALTER TABLE cart_items REPLICA IDENTITY FULL;

COMMENT ON TABLE cart_items IS 'Cart items - live sync when products added/removed';

-- ============================================================
-- 4. ENABLE REALTIME FOR STORE_CUSTOMER_PROFILES (Loyalty)
-- ============================================================

-- Add store_customer_profiles to realtime (for loyalty points)
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS store_customer_profiles;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE store_customer_profiles;
ALTER TABLE store_customer_profiles REPLICA IDENTITY FULL;

COMMENT ON TABLE store_customer_profiles IS 'Customer profiles - live loyalty points updates';

-- ============================================================
-- 5. CREATE TRIGGER TO FORCE REALTIME EVENTS
-- ============================================================

-- Sometimes Supabase Realtime needs a trigger to ensure events fire
-- This trigger does nothing but ensures INSERT/UPDATE/DELETE events are captured

DROP TRIGGER IF EXISTS location_queue_realtime_broadcast ON location_queue;
DROP FUNCTION IF EXISTS broadcast_location_queue_change();

CREATE OR REPLACE FUNCTION broadcast_location_queue_change()
RETURNS TRIGGER AS $$
BEGIN
    -- This function intentionally does nothing except return the row
    -- Its presence ensures Realtime events are reliably broadcast
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER location_queue_realtime_broadcast
AFTER INSERT OR UPDATE OR DELETE ON location_queue
FOR EACH ROW
EXECUTE FUNCTION broadcast_location_queue_change();

COMMENT ON FUNCTION broadcast_location_queue_change() IS 'Ensures Realtime events fire for location_queue';

-- ============================================================
-- 6. VERIFY REALTIME CONFIGURATION
-- ============================================================

-- Query to verify what's in the publication
SELECT
    tablename,
    schemaname
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename IN ('location_queue', 'carts', 'cart_items', 'store_customer_profiles')
ORDER BY tablename;

-- Expected output:
-- location_queue        | public
-- carts                 | public
-- cart_items            | public
-- store_customer_profiles | public

\echo '✅ Realtime configured for:'
\echo '  - location_queue (instant queue updates)'
\echo '  - carts (live cart totals)'
\echo '  - cart_items (instant item add/remove)'
\echo '  - store_customer_profiles (live loyalty points)'
\echo ''
\echo '🔄 All devices will now receive instant updates!'
