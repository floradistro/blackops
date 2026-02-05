const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

const fahadId = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804';

async function checkSpent() {
  const { data: spent } = await supabase
    .from('loyalty_transactions')
    .select('*')
    .eq('customer_id', fahadId)
    .eq('transaction_type', 'spent')
    .order('created_at', { ascending: false })
    .limit(20);

  console.log(`Found ${spent ? spent.length : 0} "spent" transactions (showing latest 20):\n`);

  if (spent) {
    spent.forEach(tx => {
      const date = new Date(tx.created_at).toLocaleString();
      const desc = tx.description || 'No description';
      console.log(`${date} | ${tx.points} pts | ${desc}`);
    });
  }
}

checkSpent().catch(err => console.error('Error:', err.message));
