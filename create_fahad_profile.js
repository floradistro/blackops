const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

const fahadId = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804';

async function createProfile() {
  // Calculate correct balance
  const { data: transactions, error: txError } = await supabase
    .from('loyalty_transactions')
    .select('points')
    .eq('customer_id', fahadId);

  if (txError) throw txError;

  const balance = transactions.reduce((sum, tx) => sum + tx.points, 0);

  console.log(`Calculated loyalty balance: ${balance}`);

  // Create minimal profile record
  const { data: created, error: createError } = await supabase
    .from('store_customer_profiles')
    .insert({
      relationship_id: fahadId,
      loyalty_points: balance,
      loyalty_tier: 'bronze',
      lifetime_points_earned: 0,
      total_spent: 0,
      total_orders: 0,
      average_order_value: 0,
      lifetime_value: 0,
      is_wholesale_approved: false,
      billing_address: {
        city: '',
        email: '',
        phone: '',
        state: '',
        company: '',
        country: 'US',
        postcode: '',
        address_1: '',
        address_2: '',
        last_name: '',
        first_name: ''
      },
      shipping_addresses: [],
      default_shipping_address_index: 0,
      id_verified: false
    })
    .select();

  if (createError) {
    console.error('Failed to create profile:', createError.message);
    throw createError;
  }

  console.log(`✅ Created store_customer_profiles record`);
  console.log(`   loyalty_points: ${created[0].loyalty_points}`);
  console.log(`   id: ${created[0].id}`);
}

createProfile().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
