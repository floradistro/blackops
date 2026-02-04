import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function check() {
  // Check ai_conversations structure
  console.log('=== AI_CONVERSATIONS TABLE ===');
  const { data: convs, error } = await supabase
    .from('ai_conversations')
    .select('*')
    .limit(20);

  if (error) {
    console.log('Error:', error.message);
    return;
  }

  if (convs && convs.length > 0) {
    console.log('Columns:', Object.keys(convs[0]).join(', '));
    console.log('Total found:', convs.length);

    for (const c of convs) {
      console.log('\n---');
      console.log('ID:', c.id);
      console.log('Created:', c.created_at);
      // Print all fields
      for (const [k, v] of Object.entries(c)) {
        if (k !== 'id' && k !== 'created_at') {
          const val = typeof v === 'string' ? v.slice(0, 100) : JSON.stringify(v)?.slice(0, 200);
          console.log(`  ${k}:`, val);
        }
      }
    }
  }

  // Now search EVERYTHING for tool-related data
  console.log('\n\n=== EXHAUSTIVE TOOL SEARCH ===');

  // Get every table that exists
  const allPossible = [
    'ai_conversations', 'ai_messages', 'ai_tool_calls', 'ai_tool_executions',
    'ai_chat_history', 'ai_requests', 'ai_responses', 'ai_sessions',
    'chat_sessions', 'chat_messages', 'conversations', 'messages',
    'tool_calls', 'tool_executions', 'tool_logs', 'tool_results',
    'agent_sessions', 'agent_messages', 'agent_tool_calls',
    'mcp_calls', 'mcp_tool_calls', 'mcp_executions',
    'gateway_logs', 'gateway_tool_calls', 'gateway_executions',
    'execution_history', 'execution_traces', 'api_tool_calls'
  ];

  for (const table of allPossible) {
    const { data, error: err } = await supabase.from(table).select('*').limit(3);
    if (!err && data && data.length > 0) {
      console.log(`\n✅ ${table}:`);
      console.log('   Columns:', Object.keys(data[0]).join(', '));

      // Look for tool-related columns
      const cols = Object.keys(data[0]);
      const toolCols = cols.filter(c =>
        c.includes('tool') || c.includes('function') || c.includes('call') ||
        c.includes('action') || c.includes('operation')
      );
      if (toolCols.length > 0) {
        console.log('   Tool columns:', toolCols.join(', '));
        // Print sample values
        for (const col of toolCols) {
          console.log(`   Sample ${col}:`, JSON.stringify(data[0][col])?.slice(0, 100));
        }
      }
    }
  }
}

check().catch(console.error);
