const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

const fahadId = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804';

async function checkRecent() {
  // Get last 5 orders
  const { data: orders, error } = await supabase
    .from('orders')
    .select('id, order_number, total_amount, created_at, customer_id')
    .eq('customer_id', fahadId)
    .order('created_at', { ascending: false })
    .limit(5);

  if (error) throw error;

  console.log('Last 5 orders for Fahad:\n');

  for (const order of orders) {
    const { data: tx } = await supabase
      .from('loyalty_transactions')
      .select('points')
      .eq('reference_id', order.id);

    const txCount = tx ? tx.length : 0;
    let status;
    if (txCount === 0) status = '❌ NO TRANSACTION';
    else if (txCount === 1) status = '✅ 1 transaction';
    else status = `⚠️  ${txCount} transactions (DUPLICATES!)`;

    const date = new Date(order.created_at).toLocaleString();
    console.log(`${order.order_number} | $${order.total_amount} | ${date} | ${status}`);
  }
}

checkRecent().catch(err => console.error('Error:', err.message));
