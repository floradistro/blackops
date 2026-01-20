const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testOrders() {
  try {
    // Get total count of orders
    const { data, error, count } = await supabase
      .from('orders')
      .select('id, order_number, store_id, location_id, created_at', { count: 'exact', head: false })
      .limit(10);

    if (error) {
      console.log('Error fetching orders:', error.message);
      return;
    }

    console.log('Total orders in database:', count);
    console.log('Sample orders:');
    if (data) {
      data.forEach(order => {
        console.log(`  - Order #${order.order_number} (Store: ${order.store_id?.substring(0,8)}, Location: ${order.location_id?.substring(0,8) || 'none'})`);
      });
    }
  } catch (err) {
    console.log('Exception:', err.message);
  }
}

testOrders();
