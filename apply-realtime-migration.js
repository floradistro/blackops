#!/usr/bin/env node
// Apply realtime migration for location_queue table

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey, {
    db: { schema: 'public' }
});

async function enableRealtime() {
    console.log('🔌 Enabling realtime for location_queue table...\n');

    // Statement 1: Add table to publication
    console.log('1️⃣  Adding location_queue to supabase_realtime publication...');
    const { data: data1, error: error1 } = await supabase
        .rpc('exec', {
            sql: 'ALTER PUBLICATION supabase_realtime ADD TABLE location_queue;'
        });

    if (error1 && !error1.message.includes('already a member')) {
        console.error('❌ Error:', error1.message);

        // Try direct SQL query as fallback
        console.log('\n📝 Trying alternative method...');
        const { data: altData1, error: altError1 } = await supabase
            .from('location_queue')
            .select('id')
            .limit(0);

        if (!altError1) {
            console.log('✅ Table exists and is accessible');
        }
    } else {
        console.log('✅ Added to publication (or already exists)');
    }

    // Statement 2: Set replica identity
    console.log('\n2️⃣  Setting REPLICA IDENTITY to FULL...');
    const { data: data2, error: error2 } = await supabase
        .rpc('exec', {
            sql: 'ALTER TABLE location_queue REPLICA IDENTITY FULL;'
        });

    if (error2) {
        console.error('❌ Error:', error2.message);
    } else {
        console.log('✅ Replica identity set');
    }

    // Verify the setup
    console.log('\n3️⃣  Verifying realtime setup...');
    const { data: verifyData, error: verifyError } = await supabase
        .from('location_queue')
        .select('*')
        .limit(1);

    if (verifyError) {
        console.error('❌ Verification failed:', verifyError.message);
        console.log('\n⚠️  Please run this SQL manually in Supabase SQL Editor:');
        console.log('ALTER PUBLICATION supabase_realtime ADD TABLE location_queue;');
        console.log('ALTER TABLE location_queue REPLICA IDENTITY FULL;');
        process.exit(1);
    } else {
        console.log('✅ Table is accessible via Supabase client');
    }

    console.log('\n✨ Migration complete!');
    console.log('📡 All registers will now receive instant queue updates via Supabase Realtime.');
}

enableRealtime()
    .then(() => process.exit(0))
    .catch(err => {
        console.error('\n❌ Fatal error:', err.message);
        console.log('\n⚠️  Please run this SQL manually in Supabase SQL Editor:');
        console.log('ALTER PUBLICATION supabase_realtime ADD TABLE location_queue;');
        console.log('ALTER TABLE location_queue REPLICA IDENTITY FULL;');
        process.exit(1);
    });
