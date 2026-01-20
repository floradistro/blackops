#!/usr/bin/env node
// Debug what's actually in location_queue table

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function debugQueueData() {
    console.log('🔍 Checking location_queue table...\n');

    // Get all entries
    console.log('1️⃣  All entries in location_queue:');
    const { data: allEntries, error: allError } = await supabase
        .from('location_queue')
        .select('*')
        .order('location_id', { ascending: true })
        .order('position', { ascending: true });

    if (allError) {
        console.error('❌ Error:', allError.message);
    } else {
        console.log(`Found ${allEntries.length} total entries:\n`);
        allEntries.forEach(entry => {
            console.log(`  Location: ${entry.location_id}`);
            console.log(`  Cart: ${entry.cart_id}`);
            console.log(`  Position: ${entry.position}`);
            console.log(`  Customer: ${entry.customer_id || 'null'}`);
            console.log('  ---');
        });
    }

    // Test get_location_queue RPC for specific location
    const testLocationId = '4D0685CC-6DFD-4C2E-A640-D8CFD4080975';
    console.log(`\n2️⃣  Testing get_location_queue RPC for location ${testLocationId}:`);

    const { data: queueData, error: queueError } = await supabase
        .rpc('get_location_queue', { p_location_id: testLocationId });

    if (queueError) {
        console.error('❌ Error:', queueError.message);
    } else {
        console.log(`Found ${queueData.length} entries for this location:\n`);
        queueData.forEach(entry => {
            console.log(`  Position ${entry.position}: ${entry.customer_first_name || 'Guest'} ${entry.customer_last_name || ''}`);
            console.log(`    Cart: ${entry.cart_id}`);
            console.log(`    Items: ${entry.cart_item_count}, Total: $${entry.cart_total}`);
            console.log('  ---');
        });
    }

    // Get all locations
    console.log('\n3️⃣  All locations:');
    const { data: locations, error: locError } = await supabase
        .from('locations')
        .select('id, name')
        .order('name');

    if (locError) {
        console.error('❌ Error:', locError.message);
    } else {
        locations.forEach(loc => {
            console.log(`  ${loc.name}: ${loc.id}`);
        });
    }
}

debugQueueData();
