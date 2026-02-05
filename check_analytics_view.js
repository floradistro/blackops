import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
dotenv.config({ path: 'agent-server/.env' });

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkView() {
  // Check what columns exist in v_daily_sales
  const { data, error } = await supabase
    .from('v_daily_sales')
    .select('*')
    .limit(1);
    
  if (error) {
    console.log('Error:', error.message);
    return;
  }
  
  console.log('v_daily_sales columns:', Object.keys(data[0] || {}));
  console.log('Sample row:', JSON.stringify(data[0], null, 2));
  
  // Also check last 90 days totals
  const ninety = new Date();
  ninety.setDate(ninety.getDate() - 90);
  
  const { data: sales, error: e2 } = await supabase
    .from('v_daily_sales')
    .select('*')
    .gte('sale_date', ninety.toISOString().split('T')[0]);
    
  if (e2) {
    console.log('Error:', e2.message);
    return;
  }
  
  const totals = (sales || []).reduce((acc, day) => ({
    grossSales: acc.grossSales + parseFloat(day.gross_sales || 0),
    netSales: acc.netSales + parseFloat(day.net_sales || 0),
    totalCogs: acc.totalCogs + parseFloat(day.total_cogs || 0),
    totalProfit: acc.totalProfit + parseFloat(day.total_profit || 0),
    totalOrders: acc.totalOrders + parseInt(day.order_count || 0),
  }), { grossSales: 0, netSales: 0, totalCogs: 0, totalProfit: 0, totalOrders: 0 });
  
  console.log('\nLast 90 days totals:');
  console.log(JSON.stringify(totals, null, 2));
}

checkView();
