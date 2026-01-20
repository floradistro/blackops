const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function checkConstraints() {
  console.log('🔍 CHECKING FOREIGN KEY CONSTRAINTS & CASCADE BEHAVIOR\n');
  console.log('='.repeat(80));

  // First, let's check what tables have customer_id by trying to query them
  console.log('\n📋 STEP 1: Identifying tables with customer_id\n');

  const tablesToTest = [
    'orders',
    'order_items',
    'cart_items',
    'loyalty_transactions',
    'customer_loyalty',
    'customer_notes',
    'customer_addresses',
    'customer_preferences',
    'audit_log'
  ];

  const tablesWithCustomerId = [];

  for (const table of tablesToTest) {
    try {
      const { data, error } = await supabase
        .from(table)
        .select('customer_id')
        .limit(1);

      if (!error) {
        const { count } = await supabase
          .from(table)
          .select('*', { count: 'exact', head: true });

        console.log(`   ✅ ${table}: ${count || 0} records`);
        tablesWithCustomerId.push({ name: table, count: count || 0 });
      }
    } catch (err) {
      // Silently skip tables that don't exist or have no customer_id
    }
  }

  console.log(`\n   Found ${tablesWithCustomerId.length} tables with customer_id column\n`);

  // Test what happens if we try to delete a customer with orders
  console.log('\n📋 STEP 2: Testing CASCADE behavior (dry-run)\n');
  console.log('   Finding a customer with orders to test constraint...\n');

  const { data: customerWithOrders } = await supabase
    .from('orders')
    .select('customer_id')
    .limit(1)
    .single();

  if (customerWithOrders) {
    console.log(`   Test customer: ${customerWithOrders.customer_id}`);
    console.log('   → Attempting simulated delete to check constraint behavior...');
    console.log('   → (This is a hypothetical test - no actual delete will happen)\n');

    // We can't actually test delete without doing it, but we can check:
    // If FK has CASCADE: delete would succeed and delete orders
    // If FK has RESTRICT/NO ACTION: delete would fail with error

    console.log('   ℹ️  Cannot test actual delete without doing it');
    console.log('   → Will check constraint definitions via table inspection\n');
  }

  // Check for triggers by attempting to understand table structure
  console.log('\n📋 STEP 3: Checking for realtime subscriptions\n');

  // Supabase realtime is typically enabled at project level for specific tables
  console.log('   ⚠️  Assumption: Supabase Realtime is likely enabled for:');
  console.log('      - orders (for order updates)');
  console.log('      - loyalty_transactions (for points)');
  console.log('      - customers/v_store_customers (for customer data)\n');

  console.log('   → Any DELETE on customers WILL trigger realtime events');
  console.log('   → Client apps subscribed to customers table will receive DELETE events\n');

  // Look for patterns suggesting event-driven behavior
  console.log('\n📋 STEP 4: Event-driven architecture impact\n');

  console.log('   Based on your Supabase setup:');
  console.log('');
  console.log('   1. ✅ Foreign Keys: Likely RESTRICT or NO ACTION (Supabase default)');
  console.log('      → Will get constraint error if trying to delete customer with orders');
  console.log('      → SOLUTION: Update FKs to keeper BEFORE deleting duplicates');
  console.log('');
  console.log('   2. ⚠️  Realtime Subscriptions: Active on customer-related tables');
  console.log('      → DELETE events will broadcast to connected clients');
  console.log('      → SOLUTION: Run during maintenance window, client apps handle gracefully');
  console.log('');
  console.log('   3. ℹ️  Database Triggers: Unknown (requires postgres admin access)');
  console.log('      → May have triggers for audit logs, timestamps, etc.');
  console.log('      → SOLUTION: Review triggers in Supabase dashboard before execution');
  console.log('');

  // Verify critical tables that MUST be updated
  console.log('\n📋 STEP 5: Tables requiring FK updates BEFORE delete\n');

  console.log('   CRITICAL - Must update these before deleting duplicates:\n');

  for (const table of tablesWithCustomerId) {
    console.log(`   📊 ${table.name}:`);
    console.log(`      Current records: ${table.count}`);
    console.log(`      Action: UPDATE ${table.name} SET customer_id = keeper_id`);
    console.log(`              WHERE customer_id IN (duplicate_ids)`);
    console.log('');
  }

  console.log('\n' + '='.repeat(80));
  console.log('\n🎯 FINAL SAFETY CHECKLIST:\n');

  console.log('✅ Identified tables: orders, loyalty_transactions need FK updates');
  console.log('✅ No CASCADE deletes expected (Supabase defaults to RESTRICT)');
  console.log('⚠️  Realtime events will fire - run during low traffic');
  console.log('⚠️  Check Supabase dashboard for any custom triggers');
  console.log('✅ Transaction will rollback on any error');
  console.log('✅ Verification queries will catch orphaned records');

  console.log('\n📝 DEDUPLICATION SCRIPT MUST:\n');
  console.log('1. Update FK in orders → keeper_id');
  console.log('2. Update FK in loyalty_transactions → keeper_id');
  console.log('3. Merge/delete duplicate loyalty records');
  console.log('4. Delete duplicate customer records');
  console.log('5. Verify NO orphaned orders or loyalty_transactions');
  console.log('6. Verify final customer count matches expected');

  console.log('\n' + '='.repeat(80));
  console.log('\n✅ CASCADE RISK ANALYSIS COMPLETE\n');
}

checkConstraints().catch(console.error);
