#!/usr/bin/env node
// Check Supabase realtime configuration for location_queue

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkRealtimeConfig() {
    console.log('🔍 Checking realtime configuration for location_queue...\n');

    // Check if table is in publication
    console.log('1️⃣  Checking publication tables...');
    const { data: pubTables, error: pubError } = await supabase
        .from('pg_publication_tables')
        .select('*')
        .eq('pubname', 'supabase_realtime')
        .eq('tablename', 'location_queue');

    if (pubError) {
        console.error('❌ Error:', pubError.message);
    } else if (!pubTables || pubTables.length === 0) {
        console.log('⚠️  location_queue NOT in supabase_realtime publication!');
    } else {
        console.log('✅ location_queue is in publication:', pubTables);
    }

    // Check publication settings
    console.log('\n2️⃣  Checking publication settings...');
    const { data: pubs, error: pubsError } = await supabase
        .from('pg_publication')
        .select('*')
        .eq('pubname', 'supabase_realtime');

    if (pubsError) {
        console.error('❌ Error:', pubsError.message);
    } else {
        console.log('✅ Publication settings:', pubs);
    }

    // Check replica identity
    console.log('\n3️⃣  Checking table replica identity...');
    const { data: tables, error: tablesError } = await supabase
        .from('pg_class')
        .select('relname, relreplident')
        .eq('relname', 'location_queue');

    if (tablesError) {
        console.error('❌ Error:', tablesError.message);
    } else {
        console.log('Table replica identity:', tables);
        if (tables && tables[0]) {
            const identity = tables[0].relreplident;
            console.log('  Replica identity code:', identity);
            console.log('  Meaning:', {
                'd': 'DEFAULT (only primary key)',
                'n': 'NOTHING',
                'f': 'FULL (all columns)',
                'i': 'INDEX'
            }[identity] || 'unknown');
        }
    }
}

checkRealtimeConfig();
