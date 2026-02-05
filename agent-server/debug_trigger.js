import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://uaednwpxursknmwdeejn.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI');

const PRODUCT_ID = '826ce46c-6692-477c-ba26-4e49b6f08914';

async function debug() {
  // 1. Get the product
  const { data: product, error: pErr } = await supabase
    .from('products')
    .select('*')
    .eq('id', PRODUCT_ID)
    .single();

  if (pErr) {
    console.log('Error fetching product:', pErr.message);
    return;
  }

  console.log('=== SOUR DIESEL 2.5g PRODUCT ===\n');
  console.log('Name:', product.name);
  console.log('Status:', product.status);
  console.log('Store ID:', product.store_id);

  // Check which columns contain objects/arrays that might cause trigger issues
  console.log('\n=== COLUMN TYPES ===\n');
  for (const [key, val] of Object.entries(product)) {
    const type = val === null ? 'null' : Array.isArray(val) ? 'array' : typeof val;
    if (type === 'object' || type === 'array') {
      console.log(`  ${key}: ${type} =>`, JSON.stringify(val).substring(0, 200));
    }
  }

  // 2. Try updating just the status
  console.log('\n=== ATTEMPTING UPDATE (status only) ===\n');
  const { data: updated, error: uErr } = await supabase
    .from('products')
    .update({ status: 'published' })
    .eq('id', PRODUCT_ID)
    .select('id, name, status');

  if (uErr) {
    console.log('UPDATE ERROR:', uErr.message);
    console.log('Full error:', JSON.stringify(uErr, null, 2));
  } else {
    console.log('Updated successfully:', updated);
  }

  // 3. Check inventory
  const { data: inv } = await supabase
    .from('inventory')
    .select('quantity, location_id')
    .eq('product_id', PRODUCT_ID)
    .gt('quantity', 0);

  console.log('\n=== INVENTORY ===');
  console.log('Stock:', inv?.reduce((s, i) => s + i.quantity, 0) || 0);
  inv?.forEach(i => console.log(`  ${i.quantity}x @ ${i.location_id}`));
}

debug().catch(console.error);
