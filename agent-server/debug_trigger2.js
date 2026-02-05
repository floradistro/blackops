import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function debug() {
  // 1. Check user_triggers for products table
  console.log('=== USER_TRIGGERS FOR PRODUCTS ===\n');
  const { data: triggers, error: tErr } = await supabase
    .from('user_triggers')
    .select('*')
    .eq('event_table', 'products');

  if (tErr) {
    console.log('Error:', tErr.message);
    // Maybe table doesn't exist
    const { data: t2, error: t2Err } = await supabase
      .from('user_triggers')
      .select('*')
      .limit(5);
    console.log('All triggers:', t2?.length, t2Err?.message);
    return;
  }

  console.log(`Found ${triggers?.length} triggers for products table\n`);
  triggers?.forEach(t => {
    console.log(`  ID: ${t.id}`);
    console.log(`  Name: ${t.name}`);
    console.log(`  Active: ${t.is_active}`);
    console.log(`  Store: ${t.store_id}`);
    console.log(`  Operation: ${t.event_operation}`);
    console.log(`  Filter type: ${typeof t.event_filter}`);
    console.log(`  Filter value: ${JSON.stringify(t.event_filter)}`);
    console.log(`  Filter is array: ${Array.isArray(t.event_filter)}`);
    console.log('');
  });

  // 2. Also check ALL active triggers for this store
  console.log('=== ALL ACTIVE TRIGGERS FOR STORE ===\n');
  const { data: storeTriggers } = await supabase
    .from('user_triggers')
    .select('*')
    .eq('store_id', STORE_ID)
    .eq('is_active', true);

  storeTriggers?.forEach(t => {
    console.log(`  ${t.name} | table: ${t.event_table} | op: ${t.event_operation} | filter: ${JSON.stringify(t.event_filter)}`);
  });
  console.log(`\nTotal: ${storeTriggers?.length}`);

  // 3. Check for null store_id triggers that would match all stores
  console.log('\n=== TRIGGERS WITH NULL STORE_ID ===\n');
  const { data: nullTriggers } = await supabase
    .from('user_triggers')
    .select('*')
    .is('store_id', null)
    .eq('is_active', true);

  nullTriggers?.forEach(t => {
    console.log(`  ${t.name} | table: ${t.event_table} | op: ${t.event_operation} | filter: ${JSON.stringify(t.event_filter)}`);
  });
  console.log(`\nTotal: ${nullTriggers?.length}`);
}

debug().catch(console.error);
