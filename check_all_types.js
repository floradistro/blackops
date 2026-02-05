const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

const fahadId = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804';

async function checkAllTypes() {
  const { data: allTx } = await supabase
    .from('loyalty_transactions')
    .select('transaction_type, points, created_at')
    .eq('customer_id', fahadId)
    .order('created_at', { ascending: false });

  const types = {};
  let total = 0;

  allTx.forEach(tx => {
    if (!types[tx.transaction_type]) types[tx.transaction_type] = 0;
    types[tx.transaction_type] += tx.points;
    total += tx.points;
  });

  console.log('Breakdown by type:');
  for (const type in types) {
    console.log(`  ${type}: ${types[type]}`);
  }

  console.log(`\nTotal transactions: ${allTx.length}`);
  console.log(`Sum of all points: ${total}`);
  console.log(`\nCorrect balance should be: 1829 (Earned 2432 - Adjusted 603)`);
}

checkAllTypes().catch(err => console.error('Error:', err.message));
