#!/usr/bin/env node
// Test the RPC function to see if it returns rpc_function and edge_function

const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg'
);

(async () => {
  console.log('🔍 Testing RPC function get_mcp_tool...\n');

  const { data, error } = await supabase.rpc('get_mcp_tool', {
    tool_name: 'locations_list'
  });

  if (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }

  console.log('✅ RPC function returned:');
  console.log(JSON.stringify(data, null, 2));

  if (data && data.length > 0) {
    const tool = data[0];
    console.log('\n📊 Key fields:');
    console.log('  name:', tool.name);
    console.log('  rpc_function:', tool.rpc_function);
    console.log('  edge_function:', tool.edge_function);
    console.log('  tool_mode:', tool.tool_mode);
  }
})();
