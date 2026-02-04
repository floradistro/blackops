import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function check() {
  // Check customers WITHOUT store_id filter
  const { data: all, error: e1 } = await supabase.from('customers').select('id, email, first_name, last_name, store_id').limit(5);
  console.log('Customers (no filter):', all?.length, 'Error:', e1?.message);
  if (all && all.length > 0) {
    console.log('Sample:', all[0]);
  }

  // Check WITH store_id filter
  const STORE_ID = "cd2e1122-d511-4edb-be5d-98ef274b4baf";
  const { data: filtered, error: e2 } = await supabase.from('customers').select('id, email, first_name, last_name, store_id').eq('store_id', STORE_ID).limit(5);
  console.log('\nCustomers (with store_id filter):', filtered?.length, 'Error:', e2?.message);

  // Check table structure - does store_id exist?
  const { data: sample } = await supabase.from('customers').select('*').limit(1);
  if (sample && sample.length > 0) {
    console.log('\nCustomer columns:', Object.keys(sample[0]).join(', '));
  }
}

check().catch(console.error);
