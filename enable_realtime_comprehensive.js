// Enable Realtime for ALL tables - instant sync across devices
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function enableRealtimeForAll() {
  console.log('🔧 Enabling Realtime for all critical tables...\n');

  const sql = `
-- COMPREHENSIVE REALTIME SETUP
-- Enable Realtime for: queue, carts, cart_items, loyalty

-- 1. location_queue
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS location_queue;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
ALTER PUBLICATION supabase_realtime ADD TABLE location_queue;
ALTER TABLE location_queue REPLICA IDENTITY FULL;

-- 2. carts
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS carts;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
ALTER PUBLICATION supabase_realtime ADD TABLE carts;
ALTER TABLE carts REPLICA IDENTITY FULL;

-- 3. cart_items
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS cart_items;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
ALTER PUBLICATION supabase_realtime ADD TABLE cart_items;
ALTER TABLE cart_items REPLICA IDENTITY FULL;

-- 4. store_customer_profiles (loyalty points)
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS store_customer_profiles;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
ALTER PUBLICATION supabase_realtime ADD TABLE store_customer_profiles;
ALTER TABLE store_customer_profiles REPLICA IDENTITY FULL;

-- Create broadcast trigger for location_queue
DROP TRIGGER IF EXISTS location_queue_realtime_broadcast ON location_queue;
DROP FUNCTION IF EXISTS broadcast_location_queue_change();

CREATE OR REPLACE FUNCTION broadcast_location_queue_change()
RETURNS TRIGGER AS $func$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$func$ LANGUAGE plpgsql;

CREATE TRIGGER location_queue_realtime_broadcast
AFTER INSERT OR UPDATE OR DELETE ON location_queue
FOR EACH ROW
EXECUTE FUNCTION broadcast_location_queue_change();

-- Verify
SELECT
    tablename,
    schemaname
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename IN ('location_queue', 'carts', 'cart_items', 'store_customer_profiles')
ORDER BY tablename;
  `;

  try {
    const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql });

    if (error) {
      console.log('❌ Error applying SQL:', error.message);
      console.log('\n📝 Manual steps required:');
      console.log('1. Go to Supabase Dashboard → Database → Replication');
      console.log('2. Add these tables to supabase_realtime publication:');
      console.log('   - location_queue');
      console.log('   - carts');
      console.log('   - cart_items');
      console.log('   - store_customer_profiles');
      console.log('\n3. For each table, set "Row Identity" to "Full"');
      return;
    }

    console.log('✅ Realtime enabled successfully!\n');
    console.log('📊 Tables now broadcasting live:');
    console.log('  ✅ location_queue - Queue updates across devices');
    console.log('  ✅ carts - Cart totals live sync');
    console.log('  ✅ cart_items - Items add/remove instant');
    console.log('  ✅ store_customer_profiles - Loyalty points live\n');
  } catch (e) {
    console.error('❌ Exception:', e.message);
    console.log('\n📝 Fallback: Apply SQL manually via Supabase SQL Editor');
  }
}

enableRealtimeForAll().catch(console.error);
