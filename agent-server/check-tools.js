import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Tools implemented in executor.ts
const implemented = [
  "analytics", "inventory_velocity", "audit_trail", "employee_analytics",
  "collections_find", "create_collection", "collection_get_theme", "collection_set_theme", "collection_set_icon",
  "customers_find", "customers_create", "customers_update",
  "data_discover", "data_get",
  "email_templates_list", "email_segments_list", "email_segments_create", "email_campaign_create",
  "inventory_summary", "inventory_adjust", "inventory_set", "inventory_bulk_adjust", "inventory_bulk_set",
  "inventory_bulk_clear", "transfer_inventory", "products_at_location", "location_inventory_summary",
  "locations_find", "inventory_audit_start", "inventory_audit_count", "inventory_audit_complete", "inventory_audit_summary",
  "locations_list",
  "alerts",
  "purchase_orders_find",
  "products_find", "products_create", "products_update", "products_in_stock", "pricing_templates",
  "suppliers_find"
];

async function check() {
  const { data, error } = await supabase
    .from('ai_tool_registry')
    .select('name, category')
    .eq('is_active', true)
    .order('category');

  if (error) {
    console.log('Error:', error.message);
    return;
  }

  console.log('Database: ' + data.length + ' tools');
  console.log('Executor: ' + implemented.length + ' tools\n');

  // Group by category
  const byCategory = {};
  for (const t of data) {
    if (!byCategory[t.category]) byCategory[t.category] = [];
    byCategory[t.category].push(t.name);
  }

  console.log('=== TOOLS IN DB BY CATEGORY ===');
  for (const [cat, tools] of Object.entries(byCategory)) {
    console.log('\n' + cat + ' (' + tools.length + '):');
    for (const t of tools) {
      const hasImpl = implemented.includes(t);
      console.log('  ' + (hasImpl ? '✅' : '❌') + ' ' + t);
    }
  }

  // Find DB tools without implementation
  const dbNames = data.map(t => t.name);
  const missingImpl = dbNames.filter(n => !implemented.includes(n));
  const extraImpl = implemented.filter(n => !dbNames.includes(n));

  if (missingImpl.length > 0) {
    console.log('\n=== TOOLS IN DB WITHOUT IMPLEMENTATION ===');
    console.log(missingImpl.join(', '));
  }

  if (extraImpl.length > 0) {
    console.log('\n=== IMPLEMENTATIONS WITHOUT DB ENTRY ===');
    console.log(extraImpl.join(', '));
  }
}

check().catch(console.error);
