import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

async function debug() {
  // Just dump every table that might hold "Flora"
  const tables = ['stores', 'locations', 'catalogs', 'categories', 'products'];

  for (const table of tables) {
    const { data, error } = await supabase
      .from(table)
      .select('*')
      .ilike('name', '%flora%')
      .limit(10);

    if (error) {
      console.log(`${table}: ERROR - ${error.message}`);
    } else if (data?.length) {
      console.log(`\n=== ${table.toUpperCase()} matching "flora" (${data.length}) ===`);
      data.forEach(row => console.log(JSON.stringify(row, null, 2)));
    } else {
      console.log(`${table}: no matches for "flora"`);
    }
  }

  // Also check: what store does the user's session use?
  // The agent chat likely comes in with a store context
  // Let's check the latest conversation's audit log to see the store_id
  console.log('\n\n=== LATEST AGENT CONVERSATIONS (store context) ===\n');
  const { data: recent } = await supabase
    .from('audit_logs')
    .select('action, store_id, details')
    .eq('action', 'claude_api_request')
    .order('created_at', { ascending: false })
    .limit(5);

  recent?.forEach(r => {
    console.log(`  store_id: ${r.store_id}`);
    console.log(`  agent_name: ${r.details?.agent_name}`);
    console.log(`  conversation_id: ${r.details?.conversation_id}`);
    console.log('');
  });

  // Get the store_id from the real user conversations
  const storeIds = [...new Set(recent?.map(r => r.store_id).filter(Boolean))];
  console.log('Active store IDs from conversations:', storeIds);

  for (const sid of storeIds) {
    // What is this store?
    const { data: store } = await supabase
      .from('stores')
      .select('*')
      .eq('id', sid)
      .single();

    if (store) {
      console.log(`\nStore: ${store.name} (${store.id})`);
    } else {
      // Maybe it's not in "stores" table - check locations
      const { data: loc } = await supabase
        .from('locations')
        .select('name, store_id')
        .eq('store_id', sid)
        .limit(3);
      console.log(`\nNo store record for ${sid}, but locations:`, loc?.map(l => l.name));
    }
  }
}

debug();
