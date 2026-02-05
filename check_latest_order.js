const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

const fahadId = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804';

async function checkLatestOrder() {
  // Get the absolute latest order
  const { data: order, error } = await supabase
    .from('orders')
    .select('id, order_number, total_amount, created_at, customer_id')
    .eq('customer_id', fahadId)
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  if (error) throw error;

  const time = new Date(order.created_at).toLocaleTimeString();

  console.log('Latest Order:');
  console.log(`  Order: ${order.order_number}`);
  console.log(`  Total: $${order.total_amount}`);
  console.log(`  Time: ${time}`);
  console.log(`  ID: ${order.id}`);

  // Check for loyalty transaction
  const { data: tx, error: txError } = await supabase
    .from('loyalty_transactions')
    .select('*')
    .eq('reference_id', order.id)
    .eq('customer_id', fahadId)
    .eq('transaction_type', 'earned');

  if (txError) throw txError;

  if (tx.length > 0) {
    console.log(`\n✅ Loyalty transaction found!`);
    tx.forEach(t => console.log(`  Points: ${t.points}, Created: ${t.created_at}`));
  } else {
    console.log(`\n❌ NO loyalty transaction for this order`);

    // Check the RPC function definition
    console.log('\nLet me check if the award_loyalty_points RPC exists...');
  }

  // Check balance
  const { data: profile } = await supabase
    .from('store_customer_profiles')
    .select('loyalty_points')
    .eq('relationship_id', fahadId)
    .single();

  console.log(`\nCurrent balance: ${profile?.loyalty_points || 0}`);
}

checkLatestOrder().catch(err => console.error('Error:', err.message));
