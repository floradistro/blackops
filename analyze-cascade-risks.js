const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function analyzeCascadeRisks() {
  console.log('🔍 CASCADE RISK ANALYSIS - Event-Based Architecture Check\n');
  console.log('='.repeat(80));

  // 1. Check for foreign key constraints with CASCADE actions
  console.log('\n📋 STEP 1: Foreign Key Constraints on customers table\n');

  const fkQuery = `
    SELECT
      tc.table_name,
      kcu.column_name,
      rc.update_rule,
      rc.delete_rule,
      tc.constraint_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.referential_constraints rc
      ON tc.constraint_name = rc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND kcu.table_name IN (
        SELECT table_name
        FROM information_schema.key_column_usage
        WHERE constraint_name IN (
          SELECT constraint_name
          FROM information_schema.constraint_column_usage
          WHERE table_name = 'customers'
        )
      )
    ORDER BY tc.table_name;
  `;

  const { data: fkData, error: fkError } = await supabase.rpc('exec_sql', {
    query: fkQuery
  });

  if (fkError) {
    console.log('   ⚠️  Cannot query FK constraints directly (expected with RLS)');
    console.log('   → Will check manually...\n');
  } else {
    console.log('Foreign Key Constraints:');
    console.table(fkData);
  }

  // 2. Check for database triggers on customers or related tables
  console.log('\n📋 STEP 2: Database Triggers on customers table\n');

  const triggerQuery = `
    SELECT
      trigger_name,
      event_manipulation,
      event_object_table,
      action_statement,
      action_timing
    FROM information_schema.triggers
    WHERE event_object_table IN ('customers', 'v_store_customers', 'orders', 'cart_items', 'customer_loyalty', 'customer_notes')
    ORDER BY event_object_table, trigger_name;
  `;

  const { data: triggerData, error: triggerError } = await supabase.rpc('exec_sql', {
    query: triggerQuery
  });

  if (triggerError) {
    console.log('   ⚠️  Cannot query triggers directly');
    console.log('   → Checking for known trigger patterns...\n');
  } else if (triggerData && triggerData.length > 0) {
    console.log('⚠️  TRIGGERS FOUND:');
    console.table(triggerData);
  } else {
    console.log('   ✅ No triggers found on customer-related tables');
  }

  // 3. Check for Supabase Realtime subscriptions that might react to deletes
  console.log('\n📋 STEP 3: Realtime/Event Subscriptions Check\n');
  console.log('   Checking for tables with realtime enabled...\n');

  const realtimeQuery = `
    SELECT
      schemaname,
      tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename IN ('customers', 'orders', 'cart_items', 'customer_loyalty', 'customer_notes', 'order_items')
    ORDER BY tablename;
  `;

  const { data: realtimeData } = await supabase.rpc('exec_sql', {
    query: realtimeQuery
  });

  if (realtimeData) {
    console.log('Tables that may have realtime subscriptions:');
    realtimeData.forEach(t => console.log(`   - ${t.tablename}`));
    console.log('\n   ⚠️  Any DELETE operations on customers may trigger realtime events');
    console.log('   → Apps listening to these events should handle customer deletions gracefully');
  }

  // 4. Check for any stored procedures/functions that reference customers
  console.log('\n📋 STEP 4: Stored Functions Referencing customers\n');

  const functionQuery = `
    SELECT
      routine_name,
      routine_type,
      routine_definition
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND (
        routine_definition ILIKE '%customers%'
        OR routine_definition ILIKE '%customer_id%'
      )
    ORDER BY routine_name;
  `;

  const { data: functionData } = await supabase.rpc('exec_sql', {
    query: functionQuery
  });

  if (functionData && functionData.length > 0) {
    console.log(`\n   Found ${functionData.length} functions that reference customers:\n`);
    functionData.forEach(f => {
      console.log(`   📦 ${f.routine_name} (${f.routine_type})`);
      if (f.routine_definition) {
        const def = f.routine_definition.substring(0, 200);
        console.log(`      ${def}...`);
      }
      console.log('');
    });
  } else {
    console.log('   ✅ No stored functions found referencing customers');
  }

  // 5. Manual check of known tables
  console.log('\n📋 STEP 5: Manual Table Dependency Check\n');

  const tablesToCheck = [
    'orders',
    'order_items',
    'cart_items',
    'customer_loyalty',
    'customer_notes',
    'customer_addresses',
    'customer_tiers',
    'loyalty_transactions',
    'audit_logs'
  ];

  console.log('   Checking for customer_id references in known tables...\n');

  for (const table of tablesToCheck) {
    const { data, error } = await supabase
      .from(table)
      .select('id, customer_id')
      .limit(1);

    if (!error && data) {
      const { count } = await supabase
        .from(table)
        .select('*', { count: 'exact', head: true });

      console.log(`   ✅ ${table}: ${count || 0} records with customer_id FK`);
    } else if (error && error.code === 'PGRST116') {
      console.log(`   ℹ️  ${table}: Table doesn't exist`);
    } else if (error) {
      console.log(`   ⚠️  ${table}: ${error.message}`);
    }
  }

  // 6. Check migration files for CASCADE definitions
  console.log('\n📋 STEP 6: Checking Migration Files for CASCADE\n');

  const fs = require('fs');
  const path = require('path');
  const migrationsDir = '/Users/whale/Desktop/swiftwhale/supabase/migrations';

  if (fs.existsSync(migrationsDir)) {
    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    console.log(`   Scanning ${files.length} migration files...\n`);

    for (const file of files) {
      const content = fs.readFileSync(path.join(migrationsDir, file), 'utf8');

      // Check for CASCADE in customer-related foreign keys
      const cascadeMatches = content.match(/REFERENCES\s+customers.*ON\s+(DELETE|UPDATE)\s+CASCADE/gi);
      const customerFKs = content.match(/REFERENCES\s+customers/gi);

      if (cascadeMatches) {
        console.log(`   ⚠️  ${file}:`);
        console.log(`      Found CASCADE action: ${cascadeMatches.join(', ')}`);
      } else if (customerFKs) {
        console.log(`   ✅ ${file}:`);
        console.log(`      Has customer FK but NO CASCADE (safe)`);
      }
    }
  } else {
    console.log('   ℹ️  Migration directory not found at expected location');
  }

  console.log('\n' + '='.repeat(80));
  console.log('\n💡 RECOMMENDATIONS:\n');
  console.log('1. Before DELETE operations:');
  console.log('   - Update all FK references (orders, cart_items, etc.) to point to keeper');
  console.log('   - This prevents CASCADE deletes from affecting related data');
  console.log('');
  console.log('2. During transaction:');
  console.log('   - Disable triggers temporarily if any are found');
  console.log('   - Verify no rows are deleted except intended customer duplicates');
  console.log('');
  console.log('3. Realtime considerations:');
  console.log('   - DELETE events will be published to realtime subscribers');
  console.log('   - Client apps should handle customer_id changes gracefully');
  console.log('   - Consider running during low-traffic period');
  console.log('');
  console.log('4. Verification queries to run BEFORE commit:');
  console.log('   - Check no orphaned orders: SELECT COUNT(*) FROM orders WHERE customer_id NOT IN (SELECT id FROM customers)');
  console.log('   - Check no orphaned cart_items: SELECT COUNT(*) FROM cart_items WHERE customer_id NOT IN (SELECT id FROM customers)');
  console.log('   - Both should return 0');
  console.log('\n' + '='.repeat(80));
}

analyzeCascadeRisks().catch(console.error);
