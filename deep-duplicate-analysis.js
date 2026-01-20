const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function deepAnalysis() {
  console.log('🔍 DEEP DUPLICATE ANALYSIS - EDGE CASES & DATA LOSS PREVENTION\n');
  console.log('='.repeat(80));

  // Find duplicate groups
  const { data: allCustomers, error } = await supabase
    .from('customers')
    .select('id, phone, email, first_name, last_name, store_id, created_at')
    .order('phone');

  if (error || !allCustomers) {
    console.error('Error fetching customers:', error);
    return;
  }

  const phoneGroups = {};
  allCustomers.forEach(c => {
    if (c.phone) {
      const key = `${c.store_id}:${c.phone}`;
      if (!phoneGroups[key]) phoneGroups[key] = [];
      phoneGroups[key].push(c);
    }
  });

  const duplicateGroups = Object.values(phoneGroups).filter(group => group.length > 1);

  console.log(`\n📊 Found ${duplicateGroups.length} duplicate groups to analyze\n`);

  // Sample 50 duplicate groups for detailed analysis
  const sampleGroups = duplicateGroups.slice(0, 50);

  const edgeCases = {
    conflictingData: [],
    hasOrders: [],
    hasLoyalty: [],
    hasNotes: [],
    differentEmails: [],
    differentNames: [],
    sameIdDuplicates: []
  };

  for (const group of sampleGroups) {
    const customerIds = group.map(c => c.id);

    // Check if same ID appears multiple times (true duplicate rows)
    const uniqueIds = new Set(customerIds);
    if (uniqueIds.size < customerIds.length) {
      edgeCases.sameIdDuplicates.push(group);
    }

    // Check orders
    const { data: orders } = await supabase
      .from('orders')
      .select('id, customer_id')
      .in('customer_id', customerIds);

    if (orders && orders.length > 0) {
      edgeCases.hasOrders.push({ group, orderCount: orders.length });
    }

    // Check loyalty
    const { data: loyalty } = await supabase
      .from('customer_loyalty')
      .select('id, customer_id')
      .in('customer_id', customerIds);

    if (loyalty && loyalty.length > 0) {
      edgeCases.hasLoyalty.push({ group, loyaltyCount: loyalty.length });
    }

    // Check notes
    const { data: notes } = await supabase
      .from('customer_notes')
      .select('id, customer_id')
      .in('customer_id', customerIds);

    if (notes && notes.length > 0) {
      edgeCases.hasNotes.push({ group, notesCount: notes.length });
    }

    // Check for conflicting emails
    const emails = new Set(group.filter(c => c.email).map(c => c.email));
    if (emails.size > 1) {
      edgeCases.differentEmails.push({ group, emails: Array.from(emails) });
    }

    // Check for conflicting names
    const names = new Set(group.map(c => `${c.first_name} ${c.last_name}`));
    if (names.size > 1) {
      edgeCases.differentNames.push({ group, names: Array.from(names) });
    }
  }

  console.log('\n🚨 EDGE CASES IDENTIFIED:\n');
  console.log(`1. Same ID duplicates (literal duplicate rows): ${edgeCases.sameIdDuplicates.length}`);
  console.log(`2. Duplicates with orders: ${edgeCases.hasOrders.length}`);
  console.log(`3. Duplicates with loyalty data: ${edgeCases.hasLoyalty.length}`);
  console.log(`4. Duplicates with notes: ${edgeCases.hasNotes.length}`);
  console.log(`5. Duplicates with different emails: ${edgeCases.differentEmails.length}`);
  console.log(`6. Duplicates with different names: ${edgeCases.differentNames.length}`);

  console.log('\n📝 DETAILED EXAMPLES:\n');

  if (edgeCases.sameIdDuplicates.length > 0) {
    console.log('SAME ID DUPLICATES (True duplicate rows):');
    const example = edgeCases.sameIdDuplicates[0];
    console.log(`  Phone: ${example[0].phone}`);
    console.log(`  IDs: ${example.map(c => c.id).join(', ')}`);
    console.log(`  → These are literal duplicate rows, can safely delete extras\n`);
  }

  if (edgeCases.hasOrders.length > 0) {
    console.log('DUPLICATES WITH ORDERS:');
    const example = edgeCases.hasOrders[0];
    console.log(`  Phone: ${example.group[0].phone}`);
    console.log(`  Customer IDs: ${example.group.map(c => c.id).join(', ')}`);
    console.log(`  Total orders: ${example.orderCount}`);
    console.log(`  → Must merge orders to keep customer ID\n`);
  }

  if (edgeCases.differentEmails.length > 0) {
    console.log('DUPLICATES WITH DIFFERENT EMAILS (CONFLICT):');
    const example = edgeCases.differentEmails[0];
    console.log(`  Phone: ${example.group[0].phone}`);
    console.log(`  Emails: ${example.emails.join(' vs ')}`);
    console.log(`  → Strategy: Keep most recent email or most complete record\n`);
  }

  if (edgeCases.differentNames.length > 0) {
    console.log('DUPLICATES WITH DIFFERENT NAMES (CONFLICT):');
    const example = edgeCases.differentNames[0];
    console.log(`  Phone: ${example.group[0].phone}`);
    console.log(`  Names: ${example.names.join(' vs ')}`);
    console.log(`  → Strategy: Keep most recent name or most complete record\n`);
  }

  console.log('\n' + '='.repeat(80));
  console.log('\n💡 MERGE STRATEGY RECOMMENDATIONS:\n');
  console.log('1. For SAME ID duplicates: Delete extra rows (safe)');
  console.log('2. For different IDs with same phone:');
  console.log('   - Select keeper: Oldest record OR most complete data');
  console.log('   - Merge orders: UPDATE orders SET customer_id = keeper_id');
  console.log('   - Merge loyalty: UPDATE customer_loyalty SET customer_id = keeper_id');
  console.log('   - Merge notes: UPDATE customer_notes SET customer_id = keeper_id');
  console.log('   - Handle conflicts: Use keeper\'s data, log conflicts');
  console.log('   - Delete duplicates after merge');
  console.log('\n' + '='.repeat(80));

  return edgeCases;
}

deepAnalysis().catch(console.error);
