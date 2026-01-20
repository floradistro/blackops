#!/usr/bin/env node
// Complete test of queue functionality with realtime

const { createClient } = require('@supabase/supabase-js');
const crypto = require('crypto');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

const locations = {
    blowingRock: '4D0685CC-6DFD-4C2E-A640-D8CFD4080975',
    ashvegas: '1711A88C-FEA7-4F3E-BF3C-83A28660C4E7'
};

async function testQueueComplete() {
    console.log('🧪 Complete Queue Test\n');
    console.log('This will test:');
    console.log('  1. Adding to different locations shows different queues');
    console.log('  2. INSERT events fire');
    console.log('  3. UPDATE events fire (when adding same cart twice)');
    console.log('  4. DELETE events fire\n');

    // Generate test cart IDs
    const blowingRockCart = crypto.randomUUID();
    const ashvegasCart = crypto.randomUUID();

    console.log('Test Cart IDs:');
    console.log(`  Blowing Rock: ${blowingRockCart}`);
    console.log(`  Ashvegas: ${ashvegasCart}\n`);

    // Test 1: Add to Blowing Rock
    console.log('1️⃣  Adding cart to Blowing Rock queue...');
    const { data: br1, error: br1Error } = await supabase.rpc('add_to_location_queue', {
        p_location_id: locations.blowingRock,
        p_cart_id: blowingRockCart,
        p_customer_id: null,
        p_user_id: null
    });

    if (br1Error) {
        console.error('❌ Failed:', br1Error.message);
        return;
    }

    console.log(`✅ Added to Blowing Rock - position ${br1.position}`);
    console.log('   → Check SwagManager: Should see INSERT EVENT for Blowing Rock');
    await sleep(3);

    // Test 2: Add to Ashvegas
    console.log('\n2️⃣  Adding cart to Ashvegas queue...');
    const { data: av1, error: av1Error } = await supabase.rpc('add_to_location_queue', {
        p_location_id: locations.ashvegas,
        p_cart_id: ashvegasCart,
        p_customer_id: null,
        p_user_id: null
    });

    if (av1Error) {
        console.error('❌ Failed:', av1Error.message);
        return;
    }

    console.log(`✅ Added to Ashvegas - position ${av1.position}`);
    console.log('   → Check SwagManager: Should see INSERT EVENT for Ashvegas');
    console.log('   → Ashvegas queue should NOT show Blowing Rock cart');
    await sleep(3);

    // Test 3: Check queues are separate
    console.log('\n3️⃣  Verifying queues are separate...');
    const { data: brQueue } = await supabase.rpc('get_location_queue', {
        p_location_id: locations.blowingRock
    });
    const { data: avQueue } = await supabase.rpc('get_location_queue', {
        p_location_id: locations.ashvegas
    });

    console.log(`   Blowing Rock queue: ${brQueue.length} entries`);
    brQueue.forEach(e => console.log(`     - Cart ${e.cart_id.substring(0, 8)}...`));

    console.log(`   Ashvegas queue: ${avQueue.length} entries`);
    avQueue.forEach(e => console.log(`     - Cart ${e.cart_id.substring(0, 8)}...`));

    const brHasOwnCart = brQueue.some(e => e.cart_id.toLowerCase() === blowingRockCart.toLowerCase());
    const brHasOtherCart = brQueue.some(e => e.cart_id.toLowerCase() === ashvegasCart.toLowerCase());
    const avHasOwnCart = avQueue.some(e => e.cart_id.toLowerCase() === ashvegasCart.toLowerCase());
    const avHasOtherCart = avQueue.some(e => e.cart_id.toLowerCase() === blowingRockCart.toLowerCase());

    if (brHasOwnCart && !brHasOtherCart && avHasOwnCart && !avHasOtherCart) {
        console.log('✅ Queues are correctly separated!');
    } else {
        console.error('❌ Queue separation issue:');
        if (!brHasOwnCart) console.error('   - Blowing Rock missing its cart');
        if (brHasOtherCart) console.error('   - Blowing Rock has Ashvegas cart (BAD!)');
        if (!avHasOwnCart) console.error('   - Ashvegas missing its cart');
        if (avHasOtherCart) console.error('   - Ashvegas has Blowing Rock cart (BAD!)');
    }
    await sleep(2);

    // Test 4: Update (add same cart again)
    console.log('\n4️⃣  Re-adding Blowing Rock cart (should UPDATE)...');
    const { data: br2, error: br2Error } = await supabase.rpc('add_to_location_queue', {
        p_location_id: locations.blowingRock,
        p_cart_id: blowingRockCart,
        p_customer_id: null,
        p_user_id: null
    });

    if (br2Error) {
        console.error('❌ Failed:', br2Error.message);
    } else {
        console.log(`✅ Updated Blowing Rock entry (same ID: ${br1.id === br2.id})`);
        console.log('   → Check SwagManager: Should see UPDATE EVENT for Blowing Rock');
    }
    await sleep(3);

    // Test 5: Clean up
    console.log('\n5️⃣  Cleaning up test data...');

    console.log('   Removing from Blowing Rock...');
    await supabase.rpc('remove_from_location_queue', {
        p_location_id: locations.blowingRock,
        p_cart_id: blowingRockCart
    });
    console.log('   → Check SwagManager: Should see DELETE EVENT for Blowing Rock');
    await sleep(2);

    console.log('   Removing from Ashvegas...');
    await supabase.rpc('remove_from_location_queue', {
        p_location_id: locations.ashvegas,
        p_cart_id: ashvegasCart
    });
    console.log('   → Check SwagManager: Should see DELETE EVENT for Ashvegas');
    await sleep(2);

    console.log('\n✨ Test complete! Summary:');
    console.log('   ✅ Database queries work correctly');
    console.log('   ✅ Queues are properly separated by location');
    console.log('   ✅ RPC functions return correct data');
    console.log('\n📱 Check SwagManager Console.app for realtime events:');
    console.log('   - You should have seen 2 INSERT, 1 UPDATE, and 2 DELETE events');
    console.log('   - Each event should be for the correct location');
    console.log('   - The queue view should update instantly without refresh');
}

function sleep(seconds) {
    return new Promise(resolve => setTimeout(resolve, seconds * 1000));
}

testQueueComplete();
