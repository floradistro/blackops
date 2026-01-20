#!/usr/bin/env node
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkEmails() {
    console.log('Checking email_sends table...\n');
    
    const { data, error, count } = await supabase
        .from('email_sends')
        .select('*', { count: 'exact' })
        .limit(3);
    
    if (error) {
        console.log('❌ Error:', error.message);
        console.log('Full error:', JSON.stringify(error, null, 2));
    } else {
        console.log(`✅ Found ${count} total emails`);
        if (data && data.length > 0) {
            console.log('\n📧 Sample email:');
            console.log(JSON.stringify(data[0], null, 2));
            console.log('\n📋 Column types:');
            Object.entries(data[0]).forEach(([key, value]) => {
                console.log(`  ${key}: ${typeof value} = ${value}`);
            });
        } else {
            console.log('⚠️  No emails in table');
        }
    }
}

checkEmails().catch(console.error);
