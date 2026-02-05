import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';
const DISP_CAT = '33f4655c-9a42-429c-b46b-ff0100d8d132';

async function check() {
  // Count ALL products in Disposable Vape category by status
  const { data: all } = await supabase
    .from('products')
    .select('id, name, status')
    .eq('primary_category_id', DISP_CAT)
    .order('name');

  const published = all?.filter(p => p.status === 'published') || [];
  const archived = all?.filter(p => p.status === 'archived') || [];
  const draft = all?.filter(p => p.status === 'draft') || [];
  const other = all?.filter(p => !['published','archived','draft'].includes(p.status)) || [];

  console.log(`=== DISPOSABLE VAPE PRODUCTS (total: ${all?.length}) ===\n`);
  console.log(`Published: ${published.length}`);
  console.log(`Archived: ${archived.length}`);
  console.log(`Draft: ${draft.length}`);
  if (other.length) console.log(`Other: ${other.length}`);

  console.log('\n--- PUBLISHED ---');
  published.forEach(p => console.log(`  ${p.name}`));

  console.log('\n--- ARCHIVED ---');
  archived.forEach(p => console.log(`  ${p.name}`));

  // Check which archived ones have stock
  if (archived.length) {
    const archIds = archived.map(a => a.id);
    const { data: inv } = await supabase
      .from('inventory')
      .select('product_id, quantity')
      .in('product_id', archIds)
      .gt('quantity', 0);

    const withStock = {};
    inv?.forEach(i => {
      withStock[i.product_id] = (withStock[i.product_id] || 0) + i.quantity;
    });

    const archivedWithStock = archived.filter(a => withStock[a.id]);
    if (archivedWithStock.length) {
      console.log(`\n--- ARCHIVED WITH STOCK (should be published?) ---`);
      archivedWithStock.forEach(p => console.log(`  ${p.name}: ${withStock[p.id]} units`));
    }
  }
}

check().catch(console.error);
