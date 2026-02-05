const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testRPC() {
  // Test with a mock order
  console.log('Testing award_loyalty_points RPC...\n');

  const { data, error } = await supabase.rpc('award_loyalty_points', {
    p_customer_id: 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804',
    p_order_id: '3db2b746-ee35-4e9a-8aff-1b002441038f', // the order we checked
    p_order_total: 16,
    p_store_id: 'cd2e1122-d511-4edb-be5d-98ef274b4baf'
  });

  console.log('RPC Result:');
  console.log('  data:', data);
  console.log('  error:', error);

  // Check if transaction was created
  const { data: tx, error: txError } = await supabase
    .from('loyalty_transactions')
    .select('*')
    .eq('reference_id', '3db2b746-ee35-4e9a-8aff-1b002441038f')
    .eq('customer_id', 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804');

  if (txError) {
    console.error('\nTransaction check error:', txError.message);
  } else {
    console.log(`\nTransactions for this order: ${tx.length}`);
    if (tx.length > 0) {
      tx.forEach(t => {
        console.log(`  ${t.transaction_type}: ${t.points} points`);
      });
    }
  }

  // Check balance
  const { data: profile } = await supabase
    .from('store_customer_profiles')
    .select('loyalty_points')
    .eq('relationship_id', 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804')
    .single();

  console.log(`\nCurrent balance: ${profile?.loyalty_points}`);
}

testRPC().catch(err => console.error('Error:', err.message));
