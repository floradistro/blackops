import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function debug() {
  // 1. Get the stores table columns
  const { data: storeRow } = await supabase
    .from('stores')
    .select('*')
    .eq('id', STORE_ID)
    .single();
  console.log('=== STORE RECORD ===\n');
  console.log(JSON.stringify(storeRow, null, 2));

  // 2. Get categories for this store
  console.log('\n=== CATEGORIES FOR THIS STORE ===\n');
  const { data: cats } = await supabase
    .from('categories')
    .select('id, name, store_id, catalog_id, parent_id')
    .eq('store_id', STORE_ID)
    .order('name');

  console.log(`Found ${cats?.length} categories`);
  cats?.forEach(c => {
    const parent = c.parent_id ? cats.find(p => p.id === c.parent_id)?.name : null;
    console.log(`  ${parent ? '  └ ' : ''}${c.name} (${c.id.substring(0, 8)}) ${c.catalog_id ? '[catalog: ' + c.catalog_id.substring(0, 8) + ']' : ''}`);
  });

  // 3. Find disposable vape category
  const dispCats = cats?.filter(c =>
    c.name.toLowerCase().includes('disposable') ||
    c.name.toLowerCase().includes('vape')
  );
  console.log('\n=== VAPE/DISPOSABLE CATEGORIES ===');
  dispCats?.forEach(c => console.log(`  ${c.name}: ${c.id}`));

  // 4. For each vape/disposable category, get products with inventory
  for (const cat of dispCats || []) {
    console.log(`\n=== PRODUCTS IN "${cat.name}" ===\n`);

    const { data: prodCats } = await supabase
      .from('product_categories')
      .select('product_id')
      .eq('category_id', cat.id);

    // Also check primary_category_id
    const { data: primaryProds } = await supabase
      .from('products')
      .select('id')
      .eq('primary_category_id', cat.id);

    const allPids = [...new Set([
      ...(prodCats?.map(pc => pc.product_id) || []),
      ...(primaryProds?.map(p => p.id) || [])
    ])];

    console.log(`  via product_categories: ${prodCats?.length}`);
    console.log(`  via primary_category_id: ${primaryProds?.length}`);
    console.log(`  total unique: ${allPids.length}`);

    if (allPids.length) {
      const { data: products } = await supabase
        .from('products')
        .select('id, name, status')
        .in('id', allPids)
        .order('name');

      const { data: inv } = await supabase
        .from('inventory')
        .select('product_id, quantity, location_id')
        .in('product_id', allPids)
        .gt('quantity', 0);

      const { data: locs } = await supabase.from('locations').select('id, name');
      const locMap = Object.fromEntries(locs?.map(l => [l.id, l.name]) || []);

      for (const p of products || []) {
        const pInv = inv?.filter(i => i.product_id === p.id) || [];
        const totalQty = pInv.reduce((s, i) => s + i.quantity, 0);
        console.log(`\n  [${p.status}] ${p.name} - ${totalQty} total`);
        pInv.forEach(i => console.log(`      ${i.quantity}x @ ${locMap[i.location_id] || i.location_id}`));
        if (!pInv.length) console.log('      NO STOCK');
      }
    }
  }

  // 5. Also: "Sour Diesel" products for this store
  console.log('\n\n=== SOUR DIESEL FOR THIS STORE ===\n');
  const { data: sdProds } = await supabase
    .from('products')
    .select('id, name, status, primary_category_id')
    .eq('store_id', STORE_ID)
    .ilike('name', '%sour diesel%');

  for (const p of sdProds || []) {
    const catName = cats?.find(c => c.id === p.primary_category_id)?.name;
    const { data: inv } = await supabase
      .from('inventory')
      .select('quantity, location_id')
      .eq('product_id', p.id)
      .gt('quantity', 0);

    const totalQty = inv?.reduce((s, i) => s + i.quantity, 0) || 0;
    console.log(`  [${p.status}] ${p.name} (primary cat: ${catName || 'none'}) - qty: ${totalQty}`);
  }
}

debug();
