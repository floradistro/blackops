const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

const fahadId = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804';

async function checkLoyalty() {
  // Get loyalty transactions summary
  const { data: transactions, error: txError } = await supabase
    .from('loyalty_transactions')
    .select('transaction_type, points, created_at')
    .eq('customer_id', fahadId)
    .order('created_at', { ascending: false })
    .limit(20);

  if (txError) throw txError;

  console.log(`\nRecent loyalty transactions (latest 20):\n`);

  transactions.forEach(tx => {
    const date = new Date(tx.created_at).toLocaleString();
    const type = tx.transaction_type.padEnd(10);
    const points = tx.points > 0 ? `+${tx.points}` : `${tx.points}`;
    console.log(`${date} | ${type} | ${points}`);
  });

  // Get totals across all transactions
  const { data: allTx, error: allError } = await supabase
    .from('loyalty_transactions')
    .select('transaction_type, points')
    .eq('customer_id', fahadId);

  if (allError) throw allError;

  let totalEarned = 0;
  let totalRedeemed = 0;
  let totalExpired = 0;

  allTx.forEach(tx => {
    if (tx.transaction_type === 'earned') totalEarned += tx.points;
    else if (tx.transaction_type === 'redeemed') totalRedeemed += Math.abs(tx.points);
    else if (tx.transaction_type === 'expired') totalExpired += Math.abs(tx.points);
  });

  console.log(`\n=== Loyalty Summary (${allTx.length} total transactions) ===`);
  console.log(`Earned:   +${totalEarned}`);
  console.log(`Redeemed: -${totalRedeemed}`);
  console.log(`Expired:  -${totalExpired}`);
  console.log(`Net:      ${totalEarned - totalRedeemed - totalExpired}`);

  // Check store_customer_profiles
  const { data: profile, error: profError } = await supabase
    .from('store_customer_profiles')
    .select('loyalty_points')
    .eq('relationship_id', fahadId);

  if (profError) throw profError;

  console.log(`\nstore_customer_profiles.loyalty_points: ${profile[0]?.loyalty_points || 'NULL'}`);

  // Count orders
  const { count: orderCount, error: orderError } = await supabase
    .from('orders')
    .select('*', { count: 'exact', head: true })
    .eq('customer_id', fahadId);

  if (orderError) throw orderError;

  console.log(`\n=== Order Stats ===`);
  console.log(`Total orders: ${orderCount}`);
  console.log(`Should have ~${orderCount} loyalty transactions (1 per order)`);
  console.log(`Actually have: ${allTx.length} transactions`);
}

checkLoyalty().catch(err => console.error('Error:', err.message));
