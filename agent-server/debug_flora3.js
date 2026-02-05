import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

const FLORA_CATALOG_ID = '76287db6-07fe-4e36-81c2-d4e39ccde130';

async function debug() {
  // 1. Get Flora catalog details
  console.log('=== FLORA DISTRO CATALOG ===\n');
  const { data: catalog } = await supabase
    .from('catalogs')
    .select('*')
    .eq('id', FLORA_CATALOG_ID)
    .single();
  console.log('Name:', catalog?.name);
  console.log('Store ID:', catalog?.store_id);

  // 2. Get categories linked to this catalog
  console.log('\n=== CATEGORIES IN FLORA CATALOG ===\n');
  const { data: catLinks } = await supabase
    .from('catalog_categories')
    .select('category_id')
    .eq('catalog_id', FLORA_CATALOG_ID);

  if (!catLinks?.length) {
    console.log('No catalog_categories links found. Checking categories directly...');

    // Maybe categories reference catalog directly
    const { data: cats } = await supabase
      .from('categories')
      .select('id, name, catalog_id, store_id, parent_id')
      .eq('catalog_id', FLORA_CATALOG_ID)
      .order('name');

    console.log(`\nCategories with catalog_id = Flora: ${cats?.length}\n`);
    cats?.forEach(c => console.log(`  ${c.name} (${c.id})`));

    // Find disposable vape category
    const dispCat = cats?.find(c => c.name.toLowerCase().includes('disposable'));
    if (dispCat) {
      console.log(`\n=== DISPOSABLE VAPE CATEGORY: ${dispCat.name} (${dispCat.id}) ===\n`);

      // Get products in this category
      const { data: prodCats } = await supabase
        .from('product_categories')
        .select('product_id')
        .eq('category_id', dispCat.id);

      console.log(`Products in this category: ${prodCats?.length}`);

      if (prodCats?.length) {
        const pids = prodCats.map(pc => pc.product_id);
        const { data: products } = await supabase
          .from('products')
          .select('id, name, status')
          .in('id', pids)
          .order('name');

        for (const p of products || []) {
          const { data: inv } = await supabase
            .from('inventory')
            .select('quantity, location_id')
            .eq('product_id', p.id)
            .gt('quantity', 0);

          const { data: locs } = await supabase
            .from('locations')
            .select('id, name')
            .in('id', inv?.map(i => i.location_id) || ['00000000-0000-0000-0000-000000000000']);

          const locMap = Object.fromEntries(locs?.map(l => [l.id, l.name]) || []);
          const totalQty = inv?.reduce((s, i) => s + i.quantity, 0) || 0;

          console.log(`\n  [${p.status}] ${p.name} - ${totalQty} total`);
          inv?.forEach(i => console.log(`      ${i.quantity}x @ ${locMap[i.location_id] || i.location_id}`));
          if (!inv?.length) console.log('      NO STOCK');
        }
      }
    }

    // Also check products with primary_category_id pointing to a Flora category
    if (cats?.length) {
      const catIds = cats.map(c => c.id);
      console.log('\n\n=== PRODUCTS WITH primary_category_id IN FLORA CATEGORIES ===\n');
      const { data: primProds } = await supabase
        .from('products')
        .select('id, name, status, primary_category_id')
        .in('primary_category_id', catIds)
        .limit(30);

      primProds?.forEach(p => {
        const catName = cats.find(c => c.id === p.primary_category_id)?.name;
        console.log(`  [${p.status}] ${p.name} (primary_cat: ${catName})`);
      });
    }
  } else {
    console.log(`Found ${catLinks.length} catalog_categories links`);
    const catIds = catLinks.map(cl => cl.category_id);
    const { data: cats } = await supabase
      .from('categories')
      .select('id, name')
      .in('id', catIds)
      .order('name');
    cats?.forEach(c => console.log(`  ${c.name} (${c.id})`));
  }
}

debug();
