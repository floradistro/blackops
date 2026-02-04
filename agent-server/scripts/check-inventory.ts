import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

const STORE_ID = "cd2e1122-d511-4edb-be5d-98ef274b4baf";

async function check() {
  // Check inventory without store filter
  const { data: all, error: e1, count: c1 } = await supabase.from('inventory').select('*', { count: 'exact' }).limit(5);
  console.log('Inventory (no filter):', all?.length, 'Total count:', c1, 'Error:', e1?.message);
  if (all && all.length > 0) {
    console.log('Sample:', all[0]);
  }

  // Check inventory with store_id on location
  const { data: withJoin } = await supabase
    .from('inventory')
    .select('id, product_id, quantity, location_id')
    .limit(5);
  console.log('\nInventory with location_id:', withJoin?.length);
  if (withJoin && withJoin.length > 0) {
    console.log('Sample:', withJoin[0]);
  }

  // Check if inventory has store_id column directly
  const { data: sample } = await supabase.from('inventory').select('*').limit(1);
  if (sample && sample.length > 0) {
    console.log('\nInventory columns:', Object.keys(sample[0]).join(', '));
  }
}

check().catch(console.error);
