import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkMoreTables() {
  // Try to find any additional tables we might have missed
  const moreTables = [
    'rpc_logs', 'function_logs', 'edge_function_logs', 'supabase_logs',
    'mcp_tool_calls', 'mcp_executions', 'mcp_logs',
    'agent_tool_calls', 'agent_tool_logs', 'agent_actions',
    'tool_executions', 'tool_invocations', 'tool_results',
    'ai_conversations', 'ai_messages', 'ai_tool_executions', 'ai_tool_calls',
    'chat_messages', 'chat_history', 'conversations', 'messages',
    'api_requests', 'request_logs', 'http_logs',
    'gateway_logs', 'gateway_calls', 'gateway_requests',
    'function_invocations', 'invocation_logs'
  ];

  console.log('=== SEARCHING FOR MORE TABLES ===\n');

  for (const table of moreTables) {
    const { data, error } = await supabase.from(table).select('*').limit(1);
    if (!error) {
      console.log(`✅ ${table}`);
      if (data && data[0]) {
        console.log(`   Columns: ${Object.keys(data[0]).join(', ')}`);
      }
    }
  }

  // Check if there's more in agent_execution_traces that we missed
  console.log('\n\n=== ALL AGENT_EXECUTION_TRACES ===');
  const { data: traces } = await supabase
    .from('agent_execution_traces')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(20);

  if (traces) {
    console.log('Total traces:', traces.length);
    for (const t of traces) {
      console.log('\n---');
      console.log('Agent ID:', t.agent_id);
      console.log('Message:', t.user_message?.slice(0, 60));
      console.log('Success:', t.success);
      console.log('tool_calls:', t.tool_calls, '(type:', typeof t.tool_calls + ')');
      console.log('turn_count:', t.turn_count);
      console.log('Final response:', t.final_response?.slice(0, 100));
    }
  }

  // Check what agents exist
  console.log('\n\n=== AI_AGENTS TABLE ===');
  const { data: agents, error: agentErr } = await supabase
    .from('ai_agents')
    .select('*')
    .limit(10);

  if (agents) {
    console.log('Agents found:', agents.length);
    for (const a of agents) {
      console.log(`\n  ${a.name || a.id}:`);
      console.log(`    System prompt: ${a.system_prompt?.slice(0, 80)}...`);
      console.log(`    Model: ${a.model}`);
      console.log(`    Enabled tools: ${a.enabled_tools?.length || 'all'}`);
    }
  }
}

checkMoreTables().catch(console.error);
