#!/usr/bin/env node
// Test add_to_location_queue RPC function to see if it triggers realtime events

const { createClient } = require('@supabase/supabase-js');
const crypto = require('crypto');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testRpcRealtime() {
    const locationId = '4D0685CC-6DFD-4C2E-A640-D8CFD4080975';
    const cartId = crypto.randomUUID();

    console.log('🧪 Testing add_to_location_queue RPC function...');
    console.log(`Location ID: ${locationId}`);
    console.log(`Cart ID: ${cartId}\n`);

    // First call - should INSERT
    console.log('1️⃣  First call via RPC (should INSERT)...');
    const { data: insert1, error: error1 } = await supabase.rpc('add_to_location_queue', {
        p_location_id: locationId,
        p_cart_id: cartId,
        p_customer_id: null,
        p_user_id: null
    });

    if (error1) {
        console.error('❌ RPC call failed:', error1.message);
        console.error('   Details:', error1);
        return;
    }

    console.log('✅ RPC returned:', insert1);
    console.log('⏰ Waiting 3 seconds for realtime INSERT event...\n');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Second call - should UPDATE (conflict on unique constraint)
    console.log('2️⃣  Second call via RPC (should UPDATE on conflict)...');
    const { data: insert2, error: error2 } = await supabase.rpc('add_to_location_queue', {
        p_location_id: locationId,
        p_cart_id: cartId,
        p_customer_id: null,
        p_user_id: null
    });

    if (error2) {
        console.error('❌ RPC call failed:', error2.message);
    } else {
        console.log('✅ RPC returned:', insert2);
    }

    console.log('⏰ Waiting 3 seconds for realtime UPDATE event...\n');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Clean up via RPC
    console.log('3️⃣  Cleaning up via remove RPC...');
    const { data: removed, error: removeError } = await supabase.rpc('remove_from_location_queue', {
        p_location_id: locationId,
        p_cart_id: cartId
    });

    if (removeError) {
        console.error('❌ Remove failed:', removeError.message);
    } else {
        console.log('✅ Removed:', removed);
    }

    console.log('⏰ Waiting 3 seconds for realtime DELETE event...\n');
    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log('✨ Test complete! Check SwagManager Console.app for:');
    console.log('   1. "📡 INSERT EVENT DETECTED!" after step 1');
    console.log('   2. "📡 UPDATE EVENT DETECTED!" after step 2');
    console.log('   3. "📡 DELETE EVENT DETECTED!" after step 3');
    console.log('\nIf you only see DELETE, then the issue is with the RPC function not triggering INSERT/UPDATE events.');
}

testRpcRealtime();
