const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
const supabase = createClient(supabaseUrl, serviceRoleKey);

async function deactivateEmptyFahadAccounts() {
  try {
    // Main account to keep active
    const mainAccountId = 'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804';

    // Find all Fahad Khan accounts (excluding main account)
    const { data: fahadAccounts, error: searchError } = await supabase
      .from('v_store_customers')
      .select('id, first_name, last_name, email, phone, loyalty_points')
      .ilike('first_name', '%fahad%')
      .ilike('last_name', '%khan%')
      .neq('id', mainAccountId);

    if (searchError) throw searchError;

    console.log(`\nFound ${fahadAccounts.length} Fahad Khan accounts (excluding main account)`);

    // Check each account for orders
    const emptyAccounts = [];

    for (const account of fahadAccounts) {
      const { count, error: countError } = await supabase
        .from('orders')
        .select('*', { count: 'exact', head: true })
        .eq('customer_id', account.id);

      if (countError) throw countError;

      if (count === 0) {
        emptyAccounts.push({ ...account, order_count: 0 });
      }
    }

    console.log(`\n${emptyAccounts.length} accounts have 0 orders:\n`);
    emptyAccounts.forEach(acc => {
      const contact = acc.email || acc.phone || 'no contact';
      const points = acc.loyalty_points || 0;
      console.log(`- ${acc.id} | ${acc.first_name} ${acc.last_name} | ${contact} | Orders: 0 | Points: ${points}`);
    });

    if (emptyAccounts.length === 0) {
      console.log('\nNo empty accounts to deactivate.');
      return;
    }

    // Deactivate all empty accounts
    const idsToDeactivate = emptyAccounts.map(acc => acc.id);

    const { data: updateResult, error: updateError } = await supabase
      .from('user_creation_relationships')
      .update({ status: 'inactive' })
      .in('id', idsToDeactivate)
      .select();

    if (updateError) throw updateError;

    console.log(`\n✅ Deactivated ${updateResult.length} empty Fahad Khan accounts`);

    // Verify main account is still active and get order count
    const { data: mainAccount, error: verifyError } = await supabase
      .from('v_store_customers')
      .select('id, first_name, last_name, email, phone, loyalty_points')
      .eq('id', mainAccountId)
      .single();

    if (verifyError) throw verifyError;

    const { count: mainOrderCount, error: mainCountError } = await supabase
      .from('orders')
      .select('*', { count: 'exact', head: true })
      .eq('customer_id', mainAccountId);

    if (mainCountError) throw mainCountError;

    console.log(`\n✅ Main account still active:`);
    console.log(`   ID: ${mainAccount.id}`);
    console.log(`   Name: ${mainAccount.first_name} ${mainAccount.last_name}`);
    console.log(`   Email: ${mainAccount.email}`);
    console.log(`   Phone: ${mainAccount.phone}`);
    console.log(`   Orders: ${mainOrderCount}`);
    console.log(`   Points: ${mainAccount.loyalty_points}`);

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

deactivateEmptyFahadAccounts();
