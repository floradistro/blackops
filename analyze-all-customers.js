const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function analyzeAllCustomers() {
  console.log('🔍 Comprehensive Customer Database Analysis\n');
  console.log('='.repeat(60));

  // Get ALL customers - no limit
  let allCustomers = [];
  let offset = 0;
  const batchSize = 1000;

  console.log('\n📥 Fetching ALL customers from database...\n');

  while (true) {
    const { data, error } = await supabase
      .from('v_store_customers')
      .select('id, phone, email, first_name, last_name, store_id, created_at')
      .range(offset, offset + batchSize - 1)
      .order('created_at', { ascending: true });

    if (error) {
      console.error('❌ Error:', error);
      break;
    }

    if (!data || data.length === 0) break;

    allCustomers = allCustomers.concat(data);
    console.log(`   Loaded ${allCustomers.length} customers...`);

    if (data.length < batchSize) break;
    offset += batchSize;
  }

  console.log(`\n✅ Total customers loaded: ${allCustomers.length}`);
  console.log('='.repeat(60));

  // Analyze by store
  const byStore = {};
  allCustomers.forEach(c => {
    if (!byStore[c.store_id]) byStore[c.store_id] = [];
    byStore[c.store_id].push(c);
  });

  console.log(`\n📊 Customers by Store:\n`);
  Object.entries(byStore).forEach(([storeId, customers]) => {
    console.log(`Store ${storeId}: ${customers.length} customers`);
  });

  // Analyze duplicates
  console.log('\n🔄 Duplicate Analysis:\n');

  const phoneGroups = {};
  const emailGroups = {};

  allCustomers.forEach(c => {
    if (c.phone) {
      const key = `${c.store_id}:${c.phone}`;
      if (!phoneGroups[key]) phoneGroups[key] = [];
      phoneGroups[key].push(c);
    }
    if (c.email) {
      const key = `${c.store_id}:${c.email}`;
      if (!emailGroups[key]) emailGroups[key] = [];
      emailGroups[key].push(c);
    }
  });

  const phoneDupes = Object.entries(phoneGroups).filter(([_, arr]) => arr.length > 1);
  const emailDupes = Object.entries(emailGroups).filter(([_, arr]) => arr.length > 1);

  console.log(`📞 Phone duplicates: ${phoneDupes.length} unique phones with duplicates`);
  console.log(`📧 Email duplicates: ${emailDupes.length} unique emails with duplicates`);

  // Count total duplicate records
  const totalDupePhoneRecords = phoneDupes.reduce((sum, [_, arr]) => sum + (arr.length - 1), 0);
  const totalDupeEmailRecords = emailDupes.reduce((sum, [_, arr]) => sum + (arr.length - 1), 0);

  console.log(`\n   Total duplicate phone RECORDS: ${totalDupePhoneRecords}`);
  console.log(`   Total duplicate email RECORDS: ${totalDupeEmailRecords}`);

  // Worst offenders
  console.log('\n🏆 Top 20 Most Duplicated Phones:\n');
  phoneDupes
    .sort((a, b) => b[1].length - a[1].length)
    .slice(0, 20)
    .forEach(([key, customers]) => {
      const [storeId, phone] = key.split(':');
      console.log(`   ${phone}: ${customers.length} duplicate records`);
      customers.slice(0, 3).forEach(c => {
        const name = `${c.first_name || ''} ${c.last_name || ''}`.trim() || 'N/A';
        console.log(`      - ${name} (${c.email || 'no email'}) - ID: ${c.id}`);
      });
      if (customers.length > 3) {
        console.log(`      ... and ${customers.length - 3} more`);
      }
      console.log('');
    });

  // Statistics
  const customersWithPhone = allCustomers.filter(c => c.phone).length;
  const customersWithEmail = allCustomers.filter(c => c.email).length;
  const customersWithBoth = allCustomers.filter(c => c.phone && c.email).length;
  const customersWithNeither = allCustomers.filter(c => !c.phone && !c.email).length;

  console.log('\n📈 Customer Data Quality:\n');
  console.log(`   Customers with phone: ${customersWithPhone} (${(customersWithPhone/allCustomers.length*100).toFixed(1)}%)`);
  console.log(`   Customers with email: ${customersWithEmail} (${(customersWithEmail/allCustomers.length*100).toFixed(1)}%)`);
  console.log(`   Customers with both: ${customersWithBoth} (${(customersWithBoth/allCustomers.length*100).toFixed(1)}%)`);
  console.log(`   Customers with neither: ${customersWithNeither} (${(customersWithNeither/allCustomers.length*100).toFixed(1)}%)`);

  // Unique customer estimate
  const uniquePhones = new Set(allCustomers.filter(c => c.phone).map(c => `${c.store_id}:${c.phone}`)).size;
  const uniqueEmails = new Set(allCustomers.filter(c => c.email).map(c => `${c.store_id}:${c.email}`)).size;

  console.log('\n🎯 Estimated Unique Customers:\n');
  console.log(`   By phone: ${uniquePhones}`);
  console.log(`   By email: ${uniqueEmails}`);
  console.log(`   Total records: ${allCustomers.length}`);
  console.log(`   Waste from duplicates: ${allCustomers.length - uniquePhones} records (${((allCustomers.length - uniquePhones)/allCustomers.length*100).toFixed(1)}%)`);

  console.log('\n' + '='.repeat(60));
  console.log('\n💡 RECOMMENDATION:\n');
  console.log(`   You have ${allCustomers.length} customer records`);
  console.log(`   But only ~${uniquePhones} unique customers (by phone)`);
  console.log(`   That's ${allCustomers.length - uniquePhones} duplicate records to clean up!`);
  console.log('\n' + '='.repeat(60));
}

analyzeAllCustomers();
