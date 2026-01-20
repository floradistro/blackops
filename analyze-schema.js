const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function analyzeSchema() {
  console.log('🔍 DATABASE SCHEMA ANALYSIS FOR CUSTOMER DEDUPLICATION\n');
  console.log('='.repeat(80));

  // Query to find all tables that reference customers
  const schemaQuery = `
    SELECT
      tc.table_name,
      kcu.column_name,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name,
      tc.constraint_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND ccu.table_name = 'customers'
      AND tc.table_schema = 'public'
    ORDER BY tc.table_name;
  `;

  console.log('\n📊 TABLES THAT REFERENCE CUSTOMERS:\n');

  // Manually check known tables
  const tablesToCheck = [
    'orders',
    'customer_loyalty',
    'customer_notes',
    'cart_items',
    'order_items',
    'customer_addresses'
  ];

  for (const table of tablesToCheck) {
    const { count, error } = await supabase
      .from(table)
      .select('*', { count: 'exact', head: true })
      .limit(0);

    if (!error) {
      console.log(`✓ ${table}: ${count || 0} records`);
    } else {
      console.log(`✗ ${table}: Table not found or error`);
    }
  }

  console.log('\n📋 CUSTOMER TABLE STRUCTURE:\n');

  // Get sample customer to see structure
  const { data: sampleCustomers } = await supabase
    .from('customers')
    .select('*')
    .limit(1);

  if (sampleCustomers && sampleCustomers.length > 0) {
    const columns = Object.keys(sampleCustomers[0]);
    console.log('Columns:', columns.join(', '));
  }

  console.log('\n🔄 DUPLICATE PATTERNS ANALYSIS:\n');

  // Find examples of each duplicate pattern
  const { data: phoneDupeExample } = await supabase
    .from('customers')
    .select('*')
    .eq('phone', '2019058727')
    .order('created_at');

  if (phoneDupeExample && phoneDupeExample.length > 1) {
    console.log(`Example: Phone ${phoneDupeExample[0].phone} has ${phoneDupeExample.length} records:`);
    phoneDupeExample.forEach((c, i) => {
      console.log(`  ${i+1}. ID: ${c.id}`);
      console.log(`     Created: ${c.created_at}`);
      console.log(`     Email: ${c.email || 'N/A'}`);
      console.log(`     Name: ${c.first_name} ${c.last_name}`);
      console.log(`     Has orders: checking...`);
    });
  }

  console.log('\n🔗 CHECKING FOREIGN KEY RELATIONSHIPS:\n');

  // Check if duplicates have associated data
  if (phoneDupeExample && phoneDupeExample.length > 1) {
    for (const customer of phoneDupeExample) {
      const { count: orderCount } = await supabase
        .from('orders')
        .select('*', { count: 'exact', head: true })
        .eq('customer_id', customer.id);

      const { count: loyaltyCount } = await supabase
        .from('customer_loyalty')
        .select('*', { count: 'exact', head: true })
        .eq('customer_id', customer.id);

      const { count: notesCount } = await supabase
        .from('customer_notes')
        .select('*', { count: 'exact', head: true })
        .eq('customer_id', customer.id);

      console.log(`Customer ${customer.id}:`);
      console.log(`  Orders: ${orderCount || 0}`);
      console.log(`  Loyalty records: ${loyaltyCount || 0}`);
      console.log(`  Notes: ${notesCount || 0}`);
    }
  }

  console.log('\n💾 DATA COMPLETENESS ANALYSIS:\n');

  // Check which duplicate has most complete data
  if (phoneDupeExample && phoneDupeExample.length > 1) {
    phoneDupeExample.forEach((c, i) => {
      const completeness = [
        c.first_name ? 1 : 0,
        c.last_name ? 1 : 0,
        c.email ? 1 : 0,
        c.phone ? 1 : 0,
        c.street_address ? 1 : 0,
        c.city ? 1 : 0,
        c.state ? 1 : 0,
        c.postal_code ? 1 : 0,
        c.date_of_birth ? 1 : 0,
        c.drivers_license_number ? 1 : 0
      ].reduce((a, b) => a + b, 0);

      console.log(`Record ${i+1} (${c.id}): ${completeness}/10 fields filled`);
    });
  }

  console.log('\n' + '='.repeat(80));
}

analyzeSchema().catch(console.error);
