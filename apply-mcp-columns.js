#!/usr/bin/env node
// Apply migration to add rpc_function and edge_function columns

const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

const sql = fs.readFileSync('supabase/migrations/20260120_add_rpc_edge_function_columns.sql', 'utf8');

const supabase = createClient(
  'https://bpuvsuavqntwkzbklkev.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwdXZzdWF2cW50d2t6Ymtsa2V2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNDc1MzYyMSwiZXhwIjoyMDUwMzI5NjIxfQ.FGW6u_qlcL3QQmB1Y0h7hSs8aXdVOGEO8sdkMTMDKa4'  // service_role key for migrations
);

(async () => {
  console.log('Applying migration: add rpc_function and edge_function columns...\n');

  const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql });

  if (error) {
    console.error('Error:', error);
    process.exit(1);
  }

  console.log('✅ Migration applied successfully!');
  console.log('\nNow restart the SwagManager app to see the data load properly.');
})();
