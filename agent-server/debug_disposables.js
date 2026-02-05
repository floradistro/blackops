import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

async function checkDisposables() {
  // Get all disposable-related categories
  const { data: cats } = await supabase
    .from('categories')
    .select('id, name')
    .or('name.ilike.%disposable%,name.ilike.%vape%,name.eq.Vapes');

  console.log('Vape/Disposable categories:');
  cats?.forEach(c => console.log(`  ${c.name}: ${c.id}`));

  const catIds = cats?.map(c => c.id) || [];

  // Check product_categories join
  const { data: productCats } = await supabase
    .from('product_categories')
    .select('product_id, category_id')
    .in('category_id', catIds);

  console.log('\nProducts linked to vape/disposable categories:', productCats?.length);

  if (productCats?.length) {
    const pids = [...new Set(productCats.map(pc => pc.product_id))];

    // Get product details
    const { data: products } = await supabase
      .from('products')
      .select('id, name, status')
      .in('id', pids);

    // Get inventory for these products
    const { data: inv } = await supabase
      .from('inventory')
      .select('product_id, quantity, location_id')
      .in('product_id', pids)
      .gt('quantity', 0);

    const invByProd = {};
    inv?.forEach(i => {
      invByProd[i.product_id] = (invByProd[i.product_id] || 0) + i.quantity;
    });

    console.log('Products with inventory > 0:', inv?.length || 0);
    console.log('\n--- WITH STOCK ---');
    products?.filter(p => invByProd[p.id]).forEach(p => {
      console.log(`  [${p.status}] ${p.name}: ${invByProd[p.id]} in stock`);
    });

    console.log('\n--- NO STOCK (first 15) ---');
    products?.filter(p => !invByProd[p.id]).slice(0, 15).forEach(p => {
      console.log(`  [${p.status}] ${p.name}`);
    });
  }

  // Now check: are the disposable products named in a way the search tool won't find?
  console.log('\n=== NAME PATTERN CHECK ===');
  console.log('Looking for products with "disposable" or "vape" in name that DO have stock...\n');

  const { data: allInv } = await supabase
    .from('inventory')
    .select('product_id, quantity')
    .gt('quantity', 0);

  const allPids = [...new Set(allInv?.map(i => i.product_id))];

  const { data: nameCheck } = await supabase
    .from('products')
    .select('id, name, status, category')
    .in('id', allPids)
    .or('name.ilike.%disposable%,name.ilike.%vape%,name.ilike.%cart %,name.ilike.%cartridge%');

  if (nameCheck?.length) {
    nameCheck.forEach(p => {
      const qty = allInv.filter(i => i.product_id === p.id).reduce((s, i) => s + i.quantity, 0);
      console.log(`  [${p.status}] ${p.name} (cat: ${p.category || 'none'}) qty: ${qty}`);
    });
  } else {
    console.log('  NONE - products may use "Cart" naming convention instead');
  }

  // Check Sour Diesel specifically - what category is it in, what's its full data
  console.log('\n=== SOUR DIESEL DEEP CHECK ===');
  const { data: sdProducts } = await supabase
    .from('products')
    .select('id, name, status, category')
    .ilike('name', '%sour diesel%');

  for (const p of sdProducts || []) {
    const { data: pInv } = await supabase
      .from('inventory')
      .select('quantity, location_id')
      .eq('product_id', p.id)
      .gt('quantity', 0);

    const { data: pCats } = await supabase
      .from('product_categories')
      .select('category:categories(name)')
      .eq('product_id', p.id);

    console.log(`\n  ${p.name} [${p.status}] (category col: ${p.category || 'null'})`);
    console.log(`    Categories: ${pCats?.map(pc => pc.category?.name).join(', ') || 'NONE'}`);
    console.log(`    Inventory: ${pInv?.length ? pInv.map(i => `${i.quantity}x`).join(', ') : 'ZERO'}`);
  }
}

checkDisposables();
