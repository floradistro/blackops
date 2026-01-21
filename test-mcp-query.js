#!/usr/bin/env node
// Test if we can query rpc_function and edge_function columns using anon key

const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg'
);

(async () => {
  console.log('🔍 Testing MCP query with anon key (same as SwagManager app)...\n');

  // Test 1: Query specific columns
  console.log('Test 1: Query specific columns including rpc_function, edge_function');
  const { data: test1, error: error1 } = await supabase
    .from('ai_tool_registry')
    .select('id, name, category, rpc_function, edge_function, tool_mode')
    .eq('name', 'alerts')
    .single();

  if (error1) {
    console.error('❌ Error:', error1);
  } else {
    console.log('✅ Result:', JSON.stringify(test1, null, 2));
  }

  // Test 2: Query with * (like the app does)
  console.log('\n\nTest 2: Query with * (select all columns)');
  const { data: test2, error: error2 } = await supabase
    .from('ai_tool_registry')
    .select('*')
    .eq('name', 'alerts')
    .single();

  if (error2) {
    console.error('❌ Error:', error2);
  } else {
    console.log('✅ Columns returned:', Object.keys(test2).sort().join(', '));
    console.log('\n✅ rpc_function:', test2.rpc_function);
    console.log('✅ edge_function:', test2.edge_function);
    console.log('✅ tool_mode:', test2.tool_mode);
  }

  // Test 3: Query first 5 active tools
  console.log('\n\nTest 3: Query first 5 active tools (matching app query)');
  const { data: test3, error: error3 } = await supabase
    .from('ai_tool_registry')
    .select('*')
    .eq('is_active', true)
    .order('name')
    .limit(5);

  if (error3) {
    console.error('❌ Error:', error3);
  } else {
    console.log(`✅ Returned ${test3.length} tools:\n`);
    test3.forEach((tool, i) => {
      console.log(`${i + 1}. ${tool.name}`);
      console.log(`   rpc_function: ${tool.rpc_function || '(null)'}`);
      console.log(`   edge_function: ${tool.edge_function || '(null)'}`);
      console.log(`   tool_mode: ${tool.tool_mode || '(null)'}`);
    });
  }
})();
