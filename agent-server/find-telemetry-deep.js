import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function deepSearch() {
  // Try to list ALL tables via SQL
  console.log('=== ATTEMPTING TO LIST ALL TABLES VIA SQL ===\n');

  // Try different RPC functions that might exist
  const rpcFunctions = [
    'list_tables', 'get_tables', 'get_all_tables', 'schema_info',
    'exec_sql', 'run_sql', 'execute_sql', 'raw_query'
  ];

  for (const fn of rpcFunctions) {
    const { data, error } = await supabase.rpc(fn, { sql: "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'" });
    if (!error && data) {
      console.log(`RPC ${fn} worked:`, data);
    }
  }

  // Brute force with MANY more table names
  console.log('\n=== BRUTE FORCE TABLE DISCOVERY ===\n');

  const moreNames = [
    // Tool/MCP related
    'mcp_tool_calls', 'mcp_tool_executions', 'mcp_tool_logs', 'mcp_tool_results',
    'mcp_requests', 'mcp_responses', 'mcp_sessions', 'mcp_history',
    'tool_call_logs', 'tool_call_history', 'tool_execution_logs', 'tool_execution_history',
    'tool_invocation_logs', 'tool_invocations', 'tool_requests', 'tool_responses',

    // AI/Agent related
    'ai_tool_calls', 'ai_tool_executions', 'ai_tool_logs', 'ai_tool_history',
    'ai_agent_logs', 'ai_agent_calls', 'ai_agent_history', 'ai_agent_sessions',
    'ai_chat_logs', 'ai_chat_history', 'ai_chat_messages', 'ai_chat_sessions',
    'agent_tool_calls', 'agent_tool_logs', 'agent_calls', 'agent_history',
    'agent_actions', 'agent_events', 'agent_activity', 'agent_usage',

    // Execution/Gateway
    'execution_logs', 'execution_history', 'execution_records', 'executions',
    'gateway_logs', 'gateway_calls', 'gateway_history', 'gateway_requests',
    'function_calls', 'function_logs', 'function_executions', 'function_history',
    'edge_function_logs', 'edge_function_calls', 'edge_logs',
    'rpc_calls', 'rpc_logs', 'rpc_history', 'rpc_executions',

    // Usage/Analytics
    'usage_logs', 'usage_history', 'usage_analytics', 'usage_metrics',
    'api_usage', 'api_calls', 'api_logs', 'api_history', 'api_requests',
    'request_logs', 'request_history', 'http_logs', 'http_requests',

    // Telemetry
    'telemetry', 'telemetry_logs', 'telemetry_events', 'telemetry_data',
    'metrics', 'metric_logs', 'stats', 'statistics',

    // Chat/Conversation
    'chat_logs', 'chat_history', 'chat_messages', 'chat_sessions', 'chats',
    'conversation_logs', 'conversation_history', 'conversation_messages',
    'message_logs', 'message_history',

    // Other
    'activity_logs', 'activity_history', 'activities',
    'action_logs', 'action_history', 'actions',
    'event_logs', 'event_history',
    'system_logs', 'debug_logs', 'error_logs', 'app_logs',
    'traces', 'trace_logs', 'spans', 'span_logs',

    // With underscores and variations
    'toolcalls', 'toolexecutions', 'toollogs',
    'agentcalls', 'agentlogs', 'agentexecutions',
    'mcpcalls', 'mcplogs', 'mcpexecutions',

    // Possibly in different naming conventions
    'ToolCalls', 'ToolExecutions', 'AgentCalls', 'MCPCalls',
    'tool-calls', 'tool-executions', 'agent-calls', 'mcp-calls'
  ];

  const found = [];
  for (const table of moreNames) {
    const { data, error } = await supabase.from(table).select('*').limit(1);
    if (!error) {
      found.push(table);
      console.log(`✅ ${table}`);
      if (data && data[0]) {
        console.log(`   Columns: ${Object.keys(data[0]).join(', ')}`);
        // Check for tool-related data
        const str = JSON.stringify(data[0]);
        if (str.includes('tool') || str.includes('mcp') || str.includes('function')) {
          console.log(`   CONTAINS TOOL DATA!`);
          console.log(`   Sample: ${str.slice(0, 300)}`);
        }
      }
    }
  }

  console.log('\n=== FOUND TABLES ===');
  console.log(found.join('\n'));

  // Also check if there's data in Supabase storage or edge function logs
  console.log('\n=== CHECKING FOR LOGS IN KNOWN TABLES ===');

  // Check if audit_logs has more tool data we missed
  const { data: auditWithTool } = await supabase
    .from('audit_logs')
    .select('*')
    .limit(500);

  if (auditWithTool) {
    // Search through details for tool mentions
    const toolAudits = auditWithTool.filter(a => {
      const str = JSON.stringify(a).toLowerCase();
      return str.includes('tool') || str.includes('mcp') || str.includes('function_name') || str.includes('rpc');
    });
    if (toolAudits.length > 0) {
      console.log('Found tool-related audit entries:', toolAudits.length);
      toolAudits.slice(0, 5).forEach(a => console.log(JSON.stringify(a, null, 2)));
    }
  }

  // Check if agent_execution_traces has tool data in other columns
  console.log('\n=== FULL AGENT_EXECUTION_TRACES INSPECTION ===');
  const { data: fullTraces } = await supabase
    .from('agent_execution_traces')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(10);

  if (fullTraces) {
    for (const t of fullTraces) {
      console.log('\n--- Full trace ---');
      console.log(JSON.stringify(t, null, 2));
    }
  }
}

deepSearch().catch(console.error);
