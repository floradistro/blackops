/**
 * Test hierarchical tracing - our own OTEL-like system
 * No third party needed!
 */

import { createClient } from "@supabase/supabase-js";
import { executeTool } from "../src/tools/executor.js";

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function simulateAgentConversation() {
  console.log('=' .repeat(70));
  console.log('SIMULATING AGENT CONVERSATION WITH TRACING');
  console.log('=' .repeat(70));

  // This is the trace ID - one per conversation/request
  const traceId = crypto.randomUUID();
  console.log(`\nTrace ID: ${traceId}`);
  console.log('\nUser: "Show me inventory and find customers named John"');

  // Create root span for the agent conversation
  const { data: rootSpan } = await supabase.from("audit_logs").insert({
    action: "agent.conversation",
    severity: "info",
    store_id: STORE_ID,
    request_id: traceId,
    details: {
      source: "swag_manager",
      user_message: "Show me inventory and find customers named John"
    }
  }).select("id").single();

  const rootSpanId = rootSpan?.id;
  console.log(`Root Span: ${rootSpanId}\n`);

  // Agent decides to call inventory_query tool
  console.log('Agent thinking... calling inventory_query');
  const result1 = await executeTool(
    supabase,
    'inventory_query',
    { action: 'summary' },
    STORE_ID,
    { source: 'swag_manager', requestId: traceId, parentId: rootSpanId }
  );
  console.log(`  └─ inventory_query.summary: ${result1.success ? 'SUCCESS' : 'FAILED'}`);

  // Agent decides to call customers tool
  console.log('Agent thinking... calling customers');
  const result2 = await executeTool(
    supabase,
    'customers',
    { action: 'find', query: 'John' },
    STORE_ID,
    { source: 'swag_manager', requestId: traceId, parentId: rootSpanId }
  );
  console.log(`  └─ customers.find: ${result2.success ? 'SUCCESS' : 'FAILED'}`);

  // Update root span with completion
  await supabase.from("audit_logs")
    .update({
      details: {
        source: "swag_manager",
        user_message: "Show me inventory and find customers named John",
        completed: true,
        tool_calls: 2
      }
    })
    .eq("id", rootSpanId);

  // Wait for writes
  await new Promise(r => setTimeout(r, 500));

  // Now reconstruct the trace!
  console.log('\n' + '=' .repeat(70));
  console.log('RECONSTRUCTED TRACE');
  console.log('=' .repeat(70));

  const { data: trace } = await supabase.rpc('get_trace', { p_request_id: traceId });

  if (trace && trace.length > 0) {
    console.log(`\nTrace ${traceId}:`);
    trace.forEach((span: any) => {
      const indent = '  '.repeat(span.depth);
      const status = span.severity === 'error' ? '❌' : '✅';
      console.log(`${indent}${status} ${span.action} [${span.duration_ms || 0}ms]`);
      if (span.error_message) {
        console.log(`${indent}   Error: ${span.error_message}`);
      }
    });
  }

  // Get overall stats
  console.log('\n' + '=' .repeat(70));
  console.log('TRACE STATS (last 24h)');
  console.log('=' .repeat(70));

  const { data: stats } = await supabase.rpc('get_trace_stats', {
    p_store_id: STORE_ID,
    p_hours: 24
  });

  if (stats) {
    console.log('\n' + JSON.stringify(stats, null, 2));
  }
}

simulateAgentConversation().catch(console.error);
