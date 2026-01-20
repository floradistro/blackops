#!/usr/bin/env node
// Verify the add_to_location_queue function implementation

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function verifyQueueFunction() {
    console.log('🔍 Checking add_to_location_queue function definition...\n');

    // Query pg_proc to get the function source
    const { data, error } = await supabase.rpc('exec_sql', {
        query: `
            SELECT
                p.proname as function_name,
                pg_get_functiondef(p.oid) as function_def
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public'
            AND p.proname = 'add_to_location_queue';
        `
    });

    if (error) {
        console.error('❌ Error querying function:', error.message);
        console.log('\n💡 Trying alternate method...\n');

        // Try direct query
        const { data: funcData, error: funcError } = await supabase
            .from('pg_proc')
            .select('*')
            .eq('proname', 'add_to_location_queue')
            .limit(1);

        if (funcError) {
            console.error('❌ Also failed:', funcError.message);
            console.log('\n⚠️  Cannot verify function - trying manual test instead...\n');
            await manualTest();
        } else {
            console.log('Function exists:', funcData);
        }
    } else {
        console.log('Function definition:');
        console.log(data);
    }
}

async function manualTest() {
    console.log('🧪 Testing add_to_location_queue behavior...\n');

    const locationId = '4D0685CC-6DFD-4C2E-A640-D8CFD4080975';
    const testCartId = 'TEST-CART-' + Date.now();

    console.log(`Location ID: ${locationId}`);
    console.log(`Test Cart ID: ${testCartId}\n`);

    // First call - should INSERT
    console.log('1️⃣  First call (should INSERT)...');
    const { data: insert1, error: error1 } = await supabase.rpc('add_to_location_queue', {
        p_location_id: locationId,
        p_cart_id: testCartId,
        p_customer_id: null,
        p_user_id: null
    });

    if (error1) {
        console.error('❌ Failed:', error1.message);
        return;
    }

    console.log('✅ Success:', insert1);
    console.log('⏰ Waiting 2 seconds for realtime...\n');
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Second call - should UPDATE (conflict on unique constraint)
    console.log('2️⃣  Second call (should UPDATE on conflict)...');
    const { data: insert2, error: error2 } = await supabase.rpc('add_to_location_queue', {
        p_location_id: locationId,
        p_cart_id: testCartId,
        p_customer_id: null,
        p_user_id: null
    });

    if (error2) {
        console.error('❌ Failed:', error2.message);
    } else {
        console.log('✅ Success:', insert2);
    }

    console.log('⏰ Waiting 2 seconds for realtime...\n');
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Clean up
    console.log('🧹 Cleaning up test data...');
    const { error: deleteError } = await supabase
        .from('location_queue')
        .delete()
        .eq('cart_id', testCartId);

    if (deleteError) {
        console.error('❌ Cleanup failed:', deleteError.message);
    } else {
        console.log('✅ Test data cleaned up');
    }

    console.log('\n✨ Test complete! Check SwagManager Console.app for realtime events:');
    console.log('   - Should see "📡 INSERT EVENT DETECTED!" after step 1');
    console.log('   - Should see "📡 UPDATE EVENT DETECTED!" after step 2');
    console.log('   - Should see "📡 DELETE EVENT DETECTED!" after cleanup');
}

verifyQueueFunction();
