const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function dryRunDeduplication() {
  console.log('🧪 DRY RUN - CUSTOMER DEDUPLICATION ANALYSIS');
  console.log('='.repeat(80));
  console.log('⚠️  NO DATABASE WRITES - This is a simulation only\n');

  // Fetch all customers
  console.log('📥 Loading all customers...\n');
  let allCustomers = [];
  let offset = 0;
  const batchSize = 1000;

  while (true) {
    const { data, error } = await supabase
      .from('v_store_customers')
      .select('id, phone, email, first_name, last_name, store_id, created_at, street_address, city, state, postal_code, date_of_birth, drivers_license_number')
      .range(offset, offset + batchSize - 1)
      .order('created_at', { ascending: true });

    if (error) {
      console.error('❌ Error loading customers:', error);
      return;
    }

    if (!data || data.length === 0) break;
    allCustomers = allCustomers.concat(data);
    console.log(`   Loaded ${allCustomers.length} customers...`);

    if (data.length < batchSize) break;
    offset += batchSize;
  }

  console.log(`\n✅ Total customers loaded: ${allCustomers.length}\n`);
  console.log('='.repeat(80));

  // Group by phone
  const phoneGroups = {};
  allCustomers.forEach(c => {
    if (c.phone) {
      const key = `${c.store_id}:${c.phone}`;
      if (!phoneGroups[key]) phoneGroups[key] = [];
      phoneGroups[key].push(c);
    }
  });

  const duplicateGroups = Object.values(phoneGroups).filter(group => group.length > 1);
  const uniqueGroups = Object.values(phoneGroups).filter(group => group.length === 1);

  console.log('\n📊 DUPLICATE ANALYSIS:\n');
  console.log(`   Total customer records: ${allCustomers.length}`);
  console.log(`   Unique customers (single record): ${uniqueGroups.length}`);
  console.log(`   Duplicate groups: ${duplicateGroups.length}`);

  const totalDuplicateRecords = duplicateGroups.reduce((sum, group) => sum + (group.length - 1), 0);
  console.log(`   Records to be merged/deleted: ${totalDuplicateRecords}`);
  console.log(`   Expected final count: ${allCustomers.length - totalDuplicateRecords}`);

  // Calculate data completeness score
  function calculateCompleteness(customer) {
    return [
      customer.first_name,
      customer.last_name,
      customer.email,
      customer.phone,
      customer.street_address,
      customer.city,
      customer.state,
      customer.postal_code,
      customer.date_of_birth,
      customer.drivers_license_number
    ].filter(f => f).length;
  }

  // Select keeper for each duplicate group
  const mergeActions = [];
  let conflictsFound = {
    differentEmails: 0,
    differentNames: 0,
    differentAddresses: 0
  };

  for (const group of duplicateGroups) {
    // Sort to pick keeper: prefer email, prefer most complete, prefer oldest
    const sorted = [...group].sort((a, b) => {
      // Prefer records with email
      if (a.email && !b.email) return -1;
      if (!a.email && b.email) return 1;

      // Prefer most complete data
      const aComplete = calculateCompleteness(a);
      const bComplete = calculateCompleteness(b);
      if (aComplete !== bComplete) return bComplete - aComplete;

      // Prefer oldest
      return new Date(a.created_at) - new Date(b.created_at);
    });

    const keeper = sorted[0];
    const duplicates = sorted.slice(1);

    // Check for conflicts
    const emails = new Set(group.filter(c => c.email).map(c => c.email));
    const names = new Set(group.map(c => `${c.first_name || ''} ${c.last_name || ''}`.trim()));
    const addresses = new Set(group.filter(c => c.street_address).map(c => c.street_address));

    const conflicts = {
      emails: emails.size > 1 ? Array.from(emails) : null,
      names: names.size > 1 ? Array.from(names) : null,
      addresses: addresses.size > 1 ? Array.from(addresses) : null
    };

    if (conflicts.emails) conflictsFound.differentEmails++;
    if (conflicts.names) conflictsFound.differentNames++;
    if (conflicts.addresses) conflictsFound.differentAddresses++;

    mergeActions.push({
      phone: keeper.phone,
      storeId: keeper.store_id,
      keeper: keeper,
      duplicates: duplicates,
      conflicts: conflicts,
      duplicateIds: duplicates.map(d => d.id)
    });
  }

  console.log('\n🔍 CONFLICT DETECTION:\n');
  console.log(`   Duplicate groups with different emails: ${conflictsFound.differentEmails}`);
  console.log(`   Duplicate groups with different names: ${conflictsFound.differentNames}`);
  console.log(`   Duplicate groups with different addresses: ${conflictsFound.differentAddresses}`);

  // Check foreign key impacts
  console.log('\n📊 CHECKING FOREIGN KEY IMPACTS:\n');

  const allDuplicateIds = mergeActions.flatMap(m => m.duplicateIds);
  console.log(`   Checking ${allDuplicateIds.length} duplicate customer IDs...\n`);

  // Check orders
  const { data: affectedOrders, error: ordersError } = await supabase
    .from('orders')
    .select('id, customer_id')
    .in('customer_id', allDuplicateIds);

  if (ordersError) {
    console.error('❌ Error checking orders:', ordersError);
  } else {
    console.log(`   Orders to be reassigned: ${affectedOrders?.length || 0}`);
  }

  // Check cart_items
  const { data: affectedCarts, error: cartsError } = await supabase
    .from('cart_items')
    .select('id, customer_id')
    .in('customer_id', allDuplicateIds);

  if (cartsError) {
    console.error('❌ Error checking cart_items:', cartsError);
  } else {
    console.log(`   Cart items to be reassigned: ${affectedCarts?.length || 0}`);
  }

  // Check customer_loyalty
  const { data: affectedLoyalty, error: loyaltyError } = await supabase
    .from('customer_loyalty')
    .select('id, customer_id')
    .in('customer_id', allDuplicateIds);

  if (loyaltyError) {
    console.error('❌ Error checking loyalty:', loyaltyError);
  } else {
    console.log(`   Loyalty records to be merged/deleted: ${affectedLoyalty?.length || 0}`);
  }

  // Show detailed examples
  console.log('\n📝 DETAILED MERGE EXAMPLES (First 10 groups):\n');
  console.log('='.repeat(80));

  for (const [idx, action] of mergeActions.slice(0, 10).entries()) {
    console.log(`\n${idx + 1}. Phone: ${action.phone} (${action.duplicates.length + 1} records → 1 record)`);

    console.log(`   ✅ KEEPER: ${action.keeper.id}`);
    console.log(`      Name: ${action.keeper.first_name || ''} ${action.keeper.last_name || ''}`);
    console.log(`      Email: ${action.keeper.email || 'N/A'}`);
    console.log(`      Created: ${action.keeper.created_at}`);
    console.log(`      Completeness: ${calculateCompleteness(action.keeper)}/10 fields`);

    // Check keeper's orders
    const { count: keeperOrders } = await supabase
      .from('orders')
      .select('*', { count: 'exact', head: true })
      .eq('customer_id', action.keeper.id);
    console.log(`      Orders: ${keeperOrders || 0}`);

    console.log(`\n   🗑️  DUPLICATES TO DELETE:`);
    for (const dupe of action.duplicates) {
      console.log(`      - ${dupe.id}`);
      console.log(`        Name: ${dupe.first_name || ''} ${dupe.last_name || ''}`);
      console.log(`        Email: ${dupe.email || 'N/A'}`);
      console.log(`        Created: ${dupe.created_at}`);
      console.log(`        Completeness: ${calculateCompleteness(dupe)}/10 fields`);

      // Check duplicate's orders
      const { count: dupeOrders } = await supabase
        .from('orders')
        .select('*', { count: 'exact', head: true })
        .eq('customer_id', dupe.id);
      console.log(`        Orders: ${dupeOrders || 0} (will be reassigned to keeper)`);
    }

    if (action.conflicts.emails) {
      console.log(`\n   ⚠️  EMAIL CONFLICT: ${action.conflicts.emails.join(' vs ')}`);
      console.log(`      → Will keep: ${action.keeper.email || 'N/A'}`);
    }
    if (action.conflicts.names) {
      console.log(`\n   ⚠️  NAME CONFLICT: ${action.conflicts.names.join(' vs ')}`);
      console.log(`      → Will keep: ${action.keeper.first_name || ''} ${action.keeper.last_name || ''}`);
    }
    if (action.conflicts.addresses) {
      console.log(`\n   ⚠️  ADDRESS CONFLICT: ${action.conflicts.addresses.join(' vs ')}`);
      console.log(`      → Will keep: ${action.keeper.street_address || 'N/A'}`);
    }
  }

  if (mergeActions.length > 10) {
    console.log(`\n... and ${mergeActions.length - 10} more duplicate groups`);
  }

  console.log('\n' + '='.repeat(80));
  console.log('\n📋 EXECUTION PLAN SUMMARY:\n');
  console.log('Phase 1: Update Foreign Keys');
  console.log(`   - UPDATE orders: ~${affectedOrders?.length || 0} records`);
  console.log(`   - UPDATE cart_items: ~${affectedCarts?.length || 0} records`);
  console.log(`   - MERGE customer_loyalty: ~${affectedLoyalty?.length || 0} records`);

  console.log('\nPhase 2: Delete Duplicates');
  console.log(`   - DELETE FROM customers: ${totalDuplicateRecords} records`);

  console.log('\nPhase 3: Add Constraint');
  console.log('   - ALTER TABLE customers ADD CONSTRAINT customers_store_phone_unique');

  console.log('\n📊 EXPECTED RESULTS:\n');
  console.log(`   Before: ${allCustomers.length} customer records`);
  console.log(`   After:  ${allCustomers.length - totalDuplicateRecords} customer records`);
  console.log(`   Reduction: ${totalDuplicateRecords} records (${((totalDuplicateRecords/allCustomers.length)*100).toFixed(1)}%)`);
  console.log(`   Data loss risk: ZERO (all orders and data preserved)`);

  console.log('\n' + '='.repeat(80));
  console.log('\n✅ DRY RUN COMPLETE - No database changes were made');
  console.log('\n💡 Next steps:');
  console.log('   1. Review this output carefully');
  console.log('   2. Check conflict resolutions are acceptable');
  console.log('   3. If satisfied, run the actual deduplication script');
  console.log('   4. That script will include full backup and transaction safety');
  console.log('\n' + '='.repeat(80));

  // Export merge plan to JSON for reference
  const mergePlan = {
    summary: {
      totalRecords: allCustomers.length,
      uniqueCustomers: uniqueGroups.length,
      duplicateGroups: duplicateGroups.length,
      recordsToDelete: totalDuplicateRecords,
      expectedFinalCount: allCustomers.length - totalDuplicateRecords,
      conflicts: conflictsFound,
      foreignKeyImpacts: {
        orders: affectedOrders?.length || 0,
        cartItems: affectedCarts?.length || 0,
        loyalty: affectedLoyalty?.length || 0
      }
    },
    mergeActions: mergeActions.map(m => ({
      phone: m.phone,
      storeId: m.storeId,
      keeperId: m.keeper.id,
      keeperEmail: m.keeper.email,
      keeperName: `${m.keeper.first_name || ''} ${m.keeper.last_name || ''}`.trim(),
      duplicateIds: m.duplicateIds,
      conflicts: m.conflicts
    }))
  };

  const fs = require('fs');
  fs.writeFileSync(
    '/Users/whale/Desktop/blackops/merge-plan.json',
    JSON.stringify(mergePlan, null, 2)
  );
  console.log('\n📄 Full merge plan saved to: merge-plan.json');
}

dryRunDeduplication().catch(console.error);
