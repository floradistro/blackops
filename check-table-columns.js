#!/usr/bin/env node
// Check ai_tool_registry table structure

const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://bpuvsuavqntwkzbklkev.supabase.co',
  process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwdXZzdWF2cW50d2t6Ymtsa2V2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ3NTM2MjEsImV4cCI6MjA1MDMyOTYyMX0.hss-7lci8C8RHwks8nSfKI8W9uE2v7OVz-TzN0_hEfg'
);

(async () => {
  console.log('Fetching one record to see structure...\n');

  const { data, error } = await supabase
    .from('ai_tool_registry')
    .select('*')
    .eq('name', 'audit_trail')
    .single();

  if (error) {
    console.error('Error:', error);
    process.exit(1);
  }

  console.log('Columns in ai_tool_registry:');
  console.log(Object.keys(data).sort().join('\n'));
  console.log('\n=== Full audit_trail record ===');
  console.log(JSON.stringify(data, null, 2));
})();
