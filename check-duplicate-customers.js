const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function checkDuplicates() {
  console.log('🔍 Checking for duplicate customers...\n');

  // Get all customers from the view
  const { data: customers, error } = await supabase
    .from('v_store_customers')
    .select('id, phone, email, first_name, last_name, store_id')
    .order('phone');

  if (error) {
    console.error('❌ Error fetching customers:', error);
    return;
  }

  console.log(`📊 Total customers: ${customers.length}\n`);

  // Check for duplicate phones
  const phoneGroups = {};
  const emailGroups = {};

  customers.forEach(c => {
    if (c.phone) {
      if (!phoneGroups[c.phone]) phoneGroups[c.phone] = [];
      phoneGroups[c.phone].push(c);
    }
    if (c.email) {
      if (!emailGroups[c.email]) emailGroups[c.email] = [];
      emailGroups[c.email].push(c);
    }
  });

  // Find duplicates
  const phoneDupes = Object.entries(phoneGroups).filter(([_, arr]) => arr.length > 1);
  const emailDupes = Object.entries(emailGroups).filter(([_, arr]) => arr.length > 1);

  console.log(`📞 Duplicate phone numbers: ${phoneDupes.length}`);
  console.log(`📧 Duplicate emails: ${emailDupes.length}\n`);

  if (phoneDupes.length > 0) {
    console.log('Top 10 duplicate phone numbers:\n');
    phoneDupes.slice(0, 10).forEach(([phone, customers]) => {
      console.log(`Phone: ${phone} (${customers.length} customers)`);
      customers.forEach(c => {
        const name = `${c.first_name || ''} ${c.last_name || ''}`.trim() || 'N/A';
        const email = c.email || 'N/A';
        console.log(`  - ID: ${c.id}, Name: ${name}, Email: ${email}, Store: ${c.store_id}`);
      });
      console.log('');
    });
  }

  if (emailDupes.length > 0) {
    console.log('\nTop 10 duplicate emails:\n');
    emailDupes.slice(0, 10).forEach(([email, customers]) => {
      console.log(`Email: ${email} (${customers.length} customers)`);
      customers.forEach(c => {
        const name = `${c.first_name || ''} ${c.last_name || ''}`.trim() || 'N/A';
        const phone = c.phone || 'N/A';
        console.log(`  - ID: ${c.id}, Name: ${name}, Phone: ${phone}, Store: ${c.store_id}`);
      });
      console.log('');
    });
  }

  // Summary
  const totalDupePhones = phoneDupes.reduce((sum, [_, arr]) => sum + arr.length - 1, 0);
  const totalDupeEmails = emailDupes.reduce((sum, [_, arr]) => sum + arr.length - 1, 0);

  console.log('\n📊 SUMMARY:');
  console.log(`Total duplicate phone records: ${totalDupePhones}`);
  console.log(`Total duplicate email records: ${totalDupeEmails}`);
  console.log(`Unique customers (by phone): ${customers.filter(c => c.phone).length - totalDupePhones}`);
}

checkDuplicates();
