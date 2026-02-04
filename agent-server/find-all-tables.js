import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function listAllTables() {
  // Query pg_tables to get ALL tables in public schema
  const { data, error } = await supabase.rpc('exec_sql', {
    sql: `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      ORDER BY table_name
    `
  });

  if (error) {
    console.log('RPC failed, trying direct query...');

    // Fallback: try to query a known system view
    const { data: d2, error: e2 } = await supabase
      .from('pg_tables')
      .select('tablename')
      .eq('schemaname', 'public');

    if (e2) {
      console.log('Direct query also failed:', e2.message);
      console.log('\nTrying brute force table discovery...');

      // Brute force: try many possible table names
      const possibleTables = [
        // Telemetry/logging
        'tool_executions', 'tool_calls', 'tool_usage', 'tool_logs', 'tool_history',
        'agent_logs', 'agent_calls', 'agent_executions', 'agent_telemetry', 'agent_history',
        'execution_logs', 'execution_history', 'executions',
        'api_logs', 'api_calls', 'api_requests', 'api_history',
        'telemetry', 'telemetry_events', 'events', 'event_log',
        'analytics', 'analytics_events', 'usage_analytics',
        'audit_log', 'audit_logs', 'audit_trail', 'audits',
        'activity_log', 'activity_logs', 'activities',
        'mcp_logs', 'mcp_calls', 'mcp_executions',
        'function_calls', 'function_logs', 'function_executions',
        'rpc_logs', 'rpc_calls', 'rpc_history',
        'request_logs', 'requests', 'request_history',
        'conversation_logs', 'conversations', 'messages', 'chat_logs', 'chat_history',
        'traces', 'trace_logs', 'span_logs', 'spans',

        // Core business
        'products', 'orders', 'order_items', 'customers', 'inventory',
        'locations', 'stores', 'users', 'profiles',
        'ai_agents', 'ai_tool_registry', 'agent_execution_traces',

        // More possibilities
        'logs', 'system_logs', 'debug_logs', 'error_logs',
        'metrics', 'stats', 'statistics',
        'sessions', 'session_logs',
        'webhooks', 'webhook_logs',
        'notifications', 'notification_logs',
        'jobs', 'job_logs', 'background_jobs',
        'tasks', 'task_logs',
        'queues', 'queue_items',
        'cache', 'cache_entries'
      ];

      const foundTables = [];
      for (const table of possibleTables) {
        const { error: checkErr } = await supabase
          .from(table)
          .select('*')
          .limit(1);

        if (!checkErr) {
          foundTables.push(table);
        }
      }

      console.log('\n=== FOUND TABLES ===');
      console.log(foundTables.join('\n'));

      // Now check each found table for tool-related columns
      console.log('\n=== CHECKING FOR TOOL USAGE DATA ===');
      for (const table of foundTables) {
        const { data: sample } = await supabase.from(table).select('*').limit(1);
        if (sample && sample[0]) {
          const cols = Object.keys(sample[0]);
          const toolRelated = cols.filter(c =>
            c.includes('tool') || c.includes('execution') || c.includes('call') ||
            c.includes('function') || c.includes('operation') || c.includes('action')
          );
          if (toolRelated.length > 0) {
            console.log(`\n${table}:`);
            console.log(`  All columns: ${cols.join(', ')}`);
            console.log(`  Tool-related: ${toolRelated.join(', ')}`);
          }
        }
      }

      return;
    }

    console.log('Tables:', d2);
    return;
  }

  console.log('All tables:', data);
}

listAllTables().catch(console.error);
