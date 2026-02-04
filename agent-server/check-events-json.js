import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function check() {
  // Get full column info for agent_execution_traces
  console.log('=== CHECKING AGENT_EXECUTION_TRACES COLUMNS ===\n');

  const { data } = await supabase
    .from('agent_execution_traces')
    .select('*')
    .limit(1);

  if (data && data[0]) {
    console.log('Current columns:', Object.keys(data[0]).sort().join(', '));

    // Check for events_json specifically
    if ('events_json' in data[0]) {
      console.log('\n✅ events_json EXISTS!');
      console.log('Value:', JSON.stringify(data[0].events_json, null, 2));
    } else if ('request_json' in data[0]) {
      console.log('\n✅ request_json EXISTS!');
      console.log('Value:', JSON.stringify(data[0].request_json, null, 2));
    }

    // Check for agent_name
    if ('agent_name' in data[0]) {
      console.log('\n✅ agent_name EXISTS!');
      console.log('Value:', data[0].agent_name);
    }
  }

  // Try to select events_json explicitly
  console.log('\n=== TRYING TO SELECT EVENTS_JSON ===');
  const { data: d2, error: e2 } = await supabase
    .from('agent_execution_traces')
    .select('id, events_json, request_json, agent_name')
    .limit(5);

  if (e2) {
    console.log('Error:', e2.message);
  } else {
    console.log('Data with events_json:', JSON.stringify(d2, null, 2));
  }

  // Also check if there's a different traces table
  console.log('\n=== CHECKING FOR OTHER TRACE TABLES ===');
  const otherTables = [
    'execution_traces', 'ai_traces', 'agent_traces', 'tool_traces',
    'mcp_traces', 'function_traces', 'call_traces'
  ];

  for (const table of otherTables) {
    const { data: d3, error: e3 } = await supabase.from(table).select('*').limit(1);
    if (!e3 && d3) {
      console.log(`✅ Found ${table}:`, Object.keys(d3[0] || {}).join(', '));
    }
  }
}

check().catch(console.error);
