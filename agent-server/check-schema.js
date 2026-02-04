import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function check() {
  // Check locations table structure
  console.log('=== LOCATIONS TABLE ===');
  const { data: loc, error: locErr } = await supabase.from('locations').select('*').limit(1);
  if (locErr) {
    console.log('Error:', locErr.message);
  } else if (loc && loc[0]) {
    console.log('Columns:', Object.keys(loc[0]).sort().join(', '));
    console.log('Sample:', JSON.stringify(loc[0], null, 2));
  }

  // Check orders table structure  
  console.log('\n=== ORDERS TABLE ===');
  const { data: ord, error: ordErr } = await supabase.from('orders').select('*').limit(1);
  if (ordErr) {
    console.log('Error:', ordErr.message);
  } else if (ord && ord[0]) {
    console.log('Columns:', Object.keys(ord[0]).sort().join(', '));
  }

  // Test analytics query directly
  console.log('\n=== TESTING ANALYTICS QUERY ===');
  const { data: analytics, error: analyticsErr } = await supabase
    .from('orders')
    .select('total_amount, status, created_at')
    .in('status', ['completed', 'paid'])
    .limit(5);
  
  if (analyticsErr) {
    console.log('Analytics Error:', analyticsErr.message);
  } else {
    console.log('Analytics OK, found', analytics?.length || 0, 'orders');
    if (analytics && analytics[0]) {
      console.log('Sample:', analytics[0]);
    }
  }
}

check().catch(console.error);
