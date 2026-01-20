#!/usr/bin/env node
// Test queue realtime by inserting/deleting a test record

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testQueueRealtime() {
    const locationId = process.argv[2];
    const cartId = process.argv[3];

    if (!locationId || !cartId) {
        console.log('Usage: node test-queue-realtime.js <location_id> <cart_id>');
        console.log('Example: node test-queue-realtime.js "123e4567-e89b-12d3-a456-426614174000" "223e4567-e89b-12d3-a456-426614174000"');
        process.exit(1);
    }

    console.log('🧪 Testing queue realtime...');
    console.log(`Location ID: ${locationId}`);
    console.log(`Cart ID: ${cartId}`);

    // Insert test record
    console.log('\n1️⃣  Inserting test queue entry...');
    const { data: insertData, error: insertError } = await supabase
        .from('location_queue')
        .insert({
            location_id: locationId,
            cart_id: cartId,
            position: 999
        })
        .select();

    if (insertError) {
        console.error('❌ Insert failed:', insertError.message);
        process.exit(1);
    }

    console.log('✅ Inserted:', insertData[0].id);
    console.log('⏰ Waiting 3 seconds for realtime to propagate...');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Delete test record
    console.log('\n2️⃣  Deleting test queue entry...');
    const { error: deleteError } = await supabase
        .from('location_queue')
        .delete()
        .eq('id', insertData[0].id);

    if (deleteError) {
        console.error('❌ Delete failed:', deleteError.message);
        process.exit(1);
    }

    console.log('✅ Deleted test entry');
    console.log('\n✨ Test complete! Check SwagManager logs for realtime events.');
}

testQueueRealtime();
