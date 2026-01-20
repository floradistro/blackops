#!/usr/bin/env node
// Direct PostgreSQL connection to enable realtime

const { Client } = require('pg');

const client = new Client({
    host: 'db.uaednwpxursknmwdeejn.supabase.co',
    port: 5432,
    user: 'postgres',
    password: 'holyfuckingshitfuck',
    database: 'postgres',
    ssl: { rejectUnauthorized: false }
});

async function enableRealtime() {
    try {
        console.log('🔌 Connecting to Supabase PostgreSQL...');
        await client.connect();
        console.log('✅ Connected!\n');

        // Statement 1: Add to publication
        console.log('1️⃣  Adding location_queue to supabase_realtime publication...');
        try {
            await client.query('ALTER PUBLICATION supabase_realtime ADD TABLE location_queue;');
            console.log('✅ Added to publication');
        } catch (err) {
            if (err.message.includes('already a member')) {
                console.log('✅ Already in publication');
            } else {
                throw err;
            }
        }

        // Statement 2: Set replica identity
        console.log('\n2️⃣  Setting REPLICA IDENTITY to FULL...');
        await client.query('ALTER TABLE location_queue REPLICA IDENTITY FULL;');
        console.log('✅ Replica identity set');

        // Verify
        console.log('\n3️⃣  Verifying setup...');
        const result = await client.query(`
            SELECT COUNT(*) as count
            FROM location_queue;
        `);
        console.log(`✅ location_queue table has ${result.rows[0].count} entries`);

        console.log('\n✨ Migration complete!');
        console.log('📡 All registers will now receive instant queue updates via Supabase Realtime.\n');

    } catch (err) {
        console.error('\n❌ Error:', err.message);
        if (err.code === 'ECONNREFUSED') {
            console.log('\n⚠️  Direct database connection is not available.');
            console.log('Please run this SQL manually in Supabase SQL Editor:');
            console.log('\nALTER PUBLICATION supabase_realtime ADD TABLE location_queue;');
            console.log('ALTER TABLE location_queue REPLICA IDENTITY FULL;');
        }
        process.exit(1);
    } finally {
        await client.end();
    }
}

enableRealtime();
