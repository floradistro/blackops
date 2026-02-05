import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

async function debug() {
  // Find distinct store_ids from products
  console.log('=== DISTINCT STORE IDs FROM PRODUCTS ===\n');
  const { data: sids } = await supabase
    .from('products')
    .select('store_id')
    .not('store_id', 'is', null)
    .limit(1000);

  const unique = [...new Set(sids?.map(s => s.store_id))];
  console.log('Unique store_ids:', unique.length);

  // For each store_id, find a sample product
  for (const sid of unique) {
    const { data: sample } = await supabase
      .from('products')
      .select('name, store_id')
      .eq('store_id', sid)
      .limit(1)
      .single();

    // Also check locations for this store
    const { data: loc } = await supabase
      .from('locations')
      .select('name, store_id')
      .eq('store_id', sid)
      .limit(1);

    console.log(`\n  Store ID: ${sid}`);
    console.log(`  Sample product: ${sample?.name}`);
    console.log(`  Location: ${loc?.[0]?.name || 'none'}`);
  }

  // Search for "Flora" in locations
  console.log('\n\n=== LOCATIONS WITH "FLORA" ===\n');
  const { data: floraLocs } = await supabase
    .from('locations')
    .select('id, name, store_id')
    .ilike('name', '%flora%');
  floraLocs?.forEach(l => console.log(`  ${l.name}: ${l.id} (store: ${l.store_id})`));

  // Search catalogs for Flora
  console.log('\n=== CATALOGS ===\n');
  const { data: catalogs } = await supabase
    .from('catalogs')
    .select('id, name, store_id');
  catalogs?.forEach(c => console.log(`  ${c.name}: ${c.id} (store: ${c.store_id})`));

  // Now search: products with "disposable" in category column
  console.log('\n=== PRODUCTS category COLUMN ===\n');
  const { data: catProds } = await supabase
    .from('products')
    .select('id, name, status, category, store_id')
    .ilike('category', '%disposable%')
    .limit(20);

  if (catProds?.length) {
    catProds.forEach(p => console.log(`  [${p.status}] ${p.name} (category: ${p.category}, store: ${p.store_id?.substring(0,8)})`));
  } else {
    console.log('  None found with category column containing "disposable"');
  }

  // Get products named "Sour Diesel" with full details
  console.log('\n=== ALL SOUR DIESEL PRODUCTS (FULL) ===\n');
  const { data: sdProds } = await supabase
    .from('products')
    .select('id, name, status, category, store_id, type, primary_category_id')
    .ilike('name', '%sour diesel%');

  for (const p of sdProds || []) {
    // Get inventory
    const { data: inv } = await supabase
      .from('inventory')
      .select('quantity, location_id')
      .eq('product_id', p.id)
      .gt('quantity', 0);

    // Get categories via join
    const { data: pCats } = await supabase
      .from('product_categories')
      .select('category:categories(id, name)')
      .eq('product_id', p.id);

    const totalQty = inv?.reduce((s, i) => s + i.quantity, 0) || 0;
    console.log(`  [${p.status}] ${p.name}`);
    console.log(`    store: ${p.store_id}`);
    console.log(`    category col: ${p.category || 'null'}`);
    console.log(`    primary_category_id: ${p.primary_category_id || 'null'}`);
    console.log(`    categories: ${pCats?.map(pc => pc.category?.name).join(', ') || 'NONE'}`);
    console.log(`    type: ${p.type || 'null'}`);
    console.log(`    inventory: ${totalQty} total`);
    console.log('');
  }
}

debug();
