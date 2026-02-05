import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

async function debug() {
  // 1. Find all stores
  console.log('=== ALL STORES ===\n');
  const { data: stores } = await supabase
    .from('stores')
    .select('id, name')
    .order('name');
  stores?.forEach(s => console.log(`  ${s.name}: ${s.id}`));

  // 2. Find Flora Distro store
  const flora = stores?.find(s => s.name.toLowerCase().includes('flora'));
  if (!flora) {
    console.log('\nNo Flora store found! Checking with broader search...');
    const { data: allStores } = await supabase.from('stores').select('id, name');
    allStores?.forEach(s => console.log(`  ${s.name}`));
    return;
  }
  console.log(`\nFlora store: ${flora.name} (${flora.id})`);

  // 3. Get Flora's categories
  console.log('\n=== FLORA CATEGORIES ===\n');
  const { data: floraCats } = await supabase
    .from('categories')
    .select('id, name, store_id')
    .eq('store_id', flora.id)
    .order('name');
  floraCats?.forEach(c => console.log(`  ${c.name}: ${c.id}`));

  // 4. Find "Disposable Vape" category for Flora
  const dispCat = floraCats?.find(c => c.name.toLowerCase().includes('disposable'));
  console.log(`\nDisposable category: ${dispCat?.name} (${dispCat?.id})`);

  // 5. Get products in that category
  if (dispCat) {
    const { data: prodCats } = await supabase
      .from('product_categories')
      .select('product_id')
      .eq('category_id', dispCat.id);

    console.log(`\nProducts in ${dispCat.name}: ${prodCats?.length}`);

    if (prodCats?.length) {
      const pids = prodCats.map(pc => pc.product_id);
      const { data: products } = await supabase
        .from('products')
        .select('id, name, status, sku, store_id, category')
        .in('id', pids);

      // Get inventory for these
      const { data: inv } = await supabase
        .from('inventory')
        .select('product_id, quantity, location_id')
        .in('product_id', pids)
        .gt('quantity', 0);

      // Get locations
      const { data: locs } = await supabase.from('locations').select('id, name');
      const locMap = Object.fromEntries(locs?.map(l => [l.id, l.name]) || []);

      console.log(`Inventory records with qty > 0: ${inv?.length}\n`);

      products?.forEach(p => {
        const pInv = inv?.filter(i => i.product_id === p.id) || [];
        const totalQty = pInv.reduce((s, i) => s + i.quantity, 0);
        console.log(`  [${p.status}] ${p.name} (store_id: ${p.store_id?.substring(0, 8)})`);
        if (pInv.length) {
          pInv.forEach(i => console.log(`      ${i.quantity}x @ ${locMap[i.location_id] || i.location_id}`));
        } else {
          console.log(`      NO STOCK`);
        }
      });
    }
  }

  // 6. Also search Flora products with "diesel" or "disposable" in name
  console.log('\n=== FLORA PRODUCTS WITH "diesel" OR "disposable" IN NAME ===\n');
  const { data: floraProds } = await supabase
    .from('products')
    .select('id, name, status, category')
    .eq('store_id', flora.id)
    .or('name.ilike.%diesel%,name.ilike.%disposable%,name.ilike.%gelato%,name.ilike.%jet fuel%')
    .order('name');

  for (const p of floraProds || []) {
    const { data: pInv } = await supabase
      .from('inventory')
      .select('quantity, location_id')
      .eq('product_id', p.id)
      .gt('quantity', 0);

    const totalQty = pInv?.reduce((s, i) => s + i.quantity, 0) || 0;
    console.log(`  [${p.status}] ${p.name} - qty: ${totalQty} ${p.category ? '(cat: ' + p.category + ')' : ''}`);
  }

  // 7. Also check products table `category` column directly
  console.log('\n=== PRODUCTS WITH category COLUMN = "Disposable Vape" or similar ===\n');
  const { data: catColProds } = await supabase
    .from('products')
    .select('id, name, status, category, store_id')
    .or('category.ilike.%disposable%,category.ilike.%vape%')
    .limit(30);

  catColProds?.forEach(p => {
    const storeName = stores?.find(s => s.id === p.store_id)?.name || 'unknown';
    console.log(`  [${p.status}] ${p.name} (cat: ${p.category}, store: ${storeName})`);
  });
}

debug();
