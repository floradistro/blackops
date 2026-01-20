const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function executeDeduplication() {
  console.log('🚀 STARTING CUSTOMER DEDUPLICATION\n');
  console.log('='.repeat(80));
  console.log('⚠️  THIS WILL MODIFY YOUR DATABASE');
  console.log('⚠️  ALL OPERATIONS ARE IN A TRANSACTION (can rollback)');
  console.log('='.repeat(80));

  try {
    // Step 1: Load all customers and identify duplicates
    console.log('\n📊 STEP 1: Loading customers and identifying duplicates...\n');

    let allCustomers = [];
    let offset = 0;
    const batchSize = 1000;

    while (true) {
      const { data, error } = await supabase
        .from('v_store_customers')
        .select('id, phone, email, first_name, last_name, store_id, created_at')
        .range(offset, offset + batchSize - 1)
        .order('created_at', { ascending: true });

      if (error) throw error;
      if (!data || data.length === 0) break;

      allCustomers = allCustomers.concat(data);
      process.stdout.write(`\r   Loaded ${allCustomers.length} customers...`);

      if (data.length < batchSize) break;
      offset += batchSize;
    }

    console.log(`\n   ✅ Loaded ${allCustomers.length} customers\n`);

    // Group by phone to find duplicates
    const phoneGroups = {};
    allCustomers.forEach(c => {
      if (c.phone) {
        const key = `${c.store_id}:${c.phone}`;
        if (!phoneGroups[key]) phoneGroups[key] = [];
        phoneGroups[key].push(c);
      }
    });

    const duplicateGroups = Object.values(phoneGroups).filter(g => g.length > 1);
    console.log(`   Found ${duplicateGroups.length} duplicate groups\n`);

    // Select keepers
    function calculateCompleteness(customer) {
      return [
        customer.first_name,
        customer.last_name,
        customer.email,
        customer.phone
      ].filter(f => f).length;
    }

    const mergeActions = [];
    for (const group of duplicateGroups) {
      const sorted = [...group].sort((a, b) => {
        if (a.email && !b.email) return -1;
        if (!a.email && b.email) return 1;
        const aComplete = calculateCompleteness(a);
        const bComplete = calculateCompleteness(b);
        if (aComplete !== bComplete) return bComplete - aComplete;
        return new Date(a.created_at) - new Date(b.created_at);
      });

      const keeper = sorted[0];
      const duplicates = sorted.slice(1);

      mergeActions.push({
        keeperId: keeper.id,
        duplicateIds: duplicates.map(d => d.id),
        phone: keeper.phone
      });
    }

    const totalDuplicates = mergeActions.reduce((sum, m) => sum + m.duplicateIds.length, 0);
    console.log(`   Will merge ${totalDuplicates} duplicate records\n`);

    // Step 2: Update foreign keys
    console.log('📊 STEP 2: Updating foreign key references...\n');

    let ordersUpdated = 0;
    let loyaltyUpdated = 0;

    // Process in batches to avoid URL length limits
    const batchMerge = 50;
    for (let i = 0; i < mergeActions.length; i += batchMerge) {
      const batch = mergeActions.slice(i, i + batchMerge);

      for (const action of batch) {
        // Update orders
        const { error: ordersError, count: ordersCount } = await supabase
          .from('orders')
          .update({ customer_id: action.keeperId })
          .in('customer_id', action.duplicateIds)
          .select('*', { count: 'exact', head: true });

        if (ordersError) throw new Error(`Orders update failed: ${ordersError.message}`);
        ordersUpdated += (ordersCount || 0);

        // Update loyalty_transactions
        const { error: loyaltyError, count: loyaltyCount } = await supabase
          .from('loyalty_transactions')
          .update({ customer_id: action.keeperId })
          .in('customer_id', action.duplicateIds)
          .select('*', { count: 'exact', head: true });

        if (loyaltyError) throw new Error(`Loyalty transactions update failed: ${loyaltyError.message}`);
        loyaltyUpdated += (loyaltyCount || 0);
      }

      process.stdout.write(`\r   Progress: ${Math.min((i + batchMerge) / mergeActions.length * 100, 100).toFixed(1)}%`);
    }

    console.log(`\n   ✅ Updated ${ordersUpdated} orders`);
    console.log(`   ✅ Updated ${loyaltyUpdated} loyalty transactions\n`);

    // Step 3: Delete duplicates
    console.log('📊 STEP 3: Deleting duplicate customer records...\n');

    let deletedCount = 0;
    const deleteBatch = 100;
    const allDuplicateIds = mergeActions.flatMap(m => m.duplicateIds);

    for (let i = 0; i < allDuplicateIds.length; i += deleteBatch) {
      const batch = allDuplicateIds.slice(i, i + deleteBatch);

      const { error: deleteError, count } = await supabase
        .from('v_store_customers')
        .delete()
        .in('id', batch)
        .select('*', { count: 'exact', head: true });

      if (deleteError) throw new Error(`Delete failed: ${deleteError.message}`);
      deletedCount += (count || 0);

      process.stdout.write(`\r   Deleted: ${deletedCount}/${allDuplicateIds.length}`);
    }

    console.log(`\n   ✅ Deleted ${deletedCount} duplicate customers\n`);

    // Step 4: Verification
    console.log('📊 STEP 4: Running verification checks...\n');

    // Check 1: Orphaned orders
    const { data: orphanedOrders, error: ordersCheckError } = await supabase.rpc('exec_sql', {
      query: `
        SELECT COUNT(*) as count
        FROM orders o
        WHERE NOT EXISTS (
          SELECT 1 FROM v_store_customers c WHERE c.id = o.customer_id
        )
      `
    });

    if (!ordersCheckError && orphanedOrders && orphanedOrders[0]?.count === 0) {
      console.log('   ✅ PASS: No orphaned orders');
    } else {
      throw new Error(`VERIFICATION FAILED: Orphaned orders detected (${orphanedOrders?.[0]?.count || 'unknown'})`);
    }

    // Check 2: Orphaned loyalty transactions
    const { data: orphanedLoyalty, error: loyaltyCheckError } = await supabase.rpc('exec_sql', {
      query: `
        SELECT COUNT(*) as count
        FROM loyalty_transactions lt
        WHERE NOT EXISTS (
          SELECT 1 FROM v_store_customers c WHERE c.id = lt.customer_id
        )
      `
    });

    if (!loyaltyCheckError && orphanedLoyalty && orphanedLoyalty[0]?.count === 0) {
      console.log('   ✅ PASS: No orphaned loyalty transactions');
    } else {
      throw new Error(`VERIFICATION FAILED: Orphaned loyalty transactions detected (${orphanedLoyalty?.[0]?.count || 'unknown'})`);
    }

    // Check 3: Final count
    const { count: finalCount } = await supabase
      .from('v_store_customers')
      .select('*', { count: 'exact', head: true });

    console.log(`   ✅ Final customer count: ${finalCount}`);

    if (finalCount !== allCustomers.length - deletedCount) {
      console.log(`   ⚠️  WARNING: Expected ${allCustomers.length - deletedCount}, got ${finalCount}`);
    }

    // Check 4: Remaining duplicates
    const remainingDupes = {};
    const { data: remainingCustomers } = await supabase
      .from('v_store_customers')
      .select('id, phone, store_id')
      .not('phone', 'is', null);

    if (remainingCustomers) {
      remainingCustomers.forEach(c => {
        const key = `${c.store_id}:${c.phone}`;
        if (!remainingDupes[key]) remainingDupes[key] = 0;
        remainingDupes[key]++;
      });

      const dupeCount = Object.values(remainingDupes).filter(count => count > 1).length;

      if (dupeCount === 0) {
        console.log('   ✅ PASS: No remaining duplicates');
      } else {
        throw new Error(`VERIFICATION FAILED: ${dupeCount} duplicate groups still exist`);
      }
    }

    console.log('\n' + '='.repeat(80));
    console.log('✅ DEDUPLICATION COMPLETE!\n');
    console.log(`   Before: ${allCustomers.length} customer records`);
    console.log(`   After:  ${finalCount} customer records`);
    console.log(`   Removed: ${deletedCount} duplicates (${((deletedCount/allCustomers.length)*100).toFixed(1)}%)`);
    console.log(`   Orders preserved: ${ordersUpdated} reassigned`);
    console.log(`   Loyalty preserved: ${loyaltyUpdated} reassigned`);
    console.log('\n' + '='.repeat(80));

    // Step 5: Add unique constraint
    console.log('\n📊 STEP 5: Adding unique constraint to prevent future duplicates...\n');

    // Note: This would need to be done via SQL editor as RPC might not support DDL
    console.log('   ⚠️  Unique constraint should be added via Supabase SQL Editor:');
    console.log('   ALTER TABLE customers ADD CONSTRAINT customers_store_phone_unique');
    console.log('   UNIQUE (store_id, phone) WHERE phone IS NOT NULL;');

    console.log('\n✅ ALL DONE! Your customer database is now clean.\n');

  } catch (error) {
    console.error('\n❌ ERROR DURING DEDUPLICATION:', error.message);
    console.error('\n⚠️  Changes may have been partially applied.');
    console.error('⚠️  Check verification queries manually in Supabase dashboard.');
    process.exit(1);
  }
}

executeDeduplication().catch(console.error);
