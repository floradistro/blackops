const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

const fahadId = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804';

async function analyzeLoyalty() {
  const { data: allTx, error } = await supabase
    .from('loyalty_transactions')
    .select('transaction_type, points')
    .eq('customer_id', fahadId);

  if (error) throw error;

  let earned = 0;
  let redeemed = 0;
  let adjusted = 0;
  let expired = 0;

  allTx.forEach(tx => {
    switch(tx.transaction_type) {
      case 'earned':
        earned += tx.points;
        break;
      case 'redeemed':
        redeemed += tx.points; // already negative
        break;
      case 'adjusted':
        adjusted += tx.points; // can be positive or negative
        break;
      case 'expired':
        expired += tx.points; // already negative
        break;
    }
  });

  const total = earned + redeemed + adjusted + expired;

  console.log('=== Loyalty Breakdown ===');
  console.log(`Earned:    ${earned > 0 ? '+' : ''}${earned}`);
  console.log(`Redeemed:  ${redeemed}`);
  console.log(`Adjusted:  ${adjusted}`);
  console.log(`Expired:   ${expired}`);
  console.log(`---------`);
  console.log(`Balance:   ${total}`);
}

analyzeLoyalty().catch(err => console.error('Error:', err.message));
