/**
 * Heavy telemetry testing - all tools, all sources, trace reconstruction
 */

import { createClient } from "@supabase/supabase-js";
import { executeTool } from "../src/tools/executor.js";

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

// All sources we support
const SOURCES = ['claude_code', 'swag_manager', 'api', 'edge_function', 'test'] as const;

// All tools to test
const TOOLS_TO_TEST = [
  { name: 'locations', args: {} },
  { name: 'inventory_query', args: { action: 'summary' } },
  { name: 'inventory_query', args: { action: 'velocity', days: 7 } },
  { name: 'customers', args: { action: 'find', limit: 5 } },
  { name: 'products', args: { action: 'find', limit: 5 } },
  { name: 'orders', args: { action: 'find', limit: 5 } },
  { name: 'suppliers', args: {} },
  { name: 'analytics', args: { action: 'summary', period: 'last_7' } },
  { name: 'alerts', args: {} },
  { name: 'audit_trail', args: { limit: 5 } },
  { name: 'purchase_orders', args: { action: 'list', limit: 5 } },
  { name: 'transfers', args: { action: 'list', limit: 5 } },
];

async function runHeavyTests() {
  console.log('='.repeat(70));
  console.log('HEAVY TELEMETRY TESTING');
  console.log('='.repeat(70));

  const results = {
    total: 0,
    success: 0,
    failed: 0,
    bySource: {} as Record<string, { success: number; failed: number }>,
    byTool: {} as Record<string, { success: number; failed: number; avgMs: number; times: number[] }>,
  };

  // =========================================================================
  // TEST 1: All tools with different sources
  // =========================================================================
  console.log('\n📊 TEST 1: All tools × All sources');
  console.log('-'.repeat(70));

  for (const source of SOURCES) {
    const traceId = crypto.randomUUID();
    console.log(`\n  Source: ${source} (trace: ${traceId.slice(0, 8)}...)`);

    results.bySource[source] = { success: 0, failed: 0 };

    for (const tool of TOOLS_TO_TEST) {
      const start = Date.now();
      const result = await executeTool(supabase, tool.name, tool.args, STORE_ID, {
        source: source,
        requestId: traceId
      });
      const duration = Date.now() - start;

      results.total++;
      const toolKey = `${tool.name}${tool.args.action ? '.' + tool.args.action : ''}`;

      if (!results.byTool[toolKey]) {
        results.byTool[toolKey] = { success: 0, failed: 0, avgMs: 0, times: [] };
      }

      if (result.success) {
        results.success++;
        results.bySource[source].success++;
        results.byTool[toolKey].success++;
        process.stdout.write('✓');
      } else {
        results.failed++;
        results.bySource[source].failed++;
        results.byTool[toolKey].failed++;
        process.stdout.write('✗');
        console.log(`\n    ❌ ${toolKey}: ${result.error}`);
      }
      results.byTool[toolKey].times.push(duration);
    }
  }

  // =========================================================================
  // TEST 2: Hierarchical tracing (parent/child spans)
  // =========================================================================
  console.log('\n\n📊 TEST 2: Hierarchical tracing');
  console.log('-'.repeat(70));

  const conversationTraceId = crypto.randomUUID();
  console.log(`\n  Simulating agent conversation (trace: ${conversationTraceId.slice(0, 8)}...)`);

  // Create root span
  const { data: rootSpan } = await supabase.from("audit_logs").insert({
    action: "agent.conversation.start",
    severity: "info",
    store_id: STORE_ID,
    request_id: conversationTraceId,
    details: {
      source: "test",
      user_message: "Heavy test: get inventory, customers, and create a report"
    }
  }).select("id").single();

  const rootId = rootSpan?.id;
  console.log(`    Root span: ${rootId}`);

  // Child tool calls with parent_id
  const childTools = [
    { name: 'inventory_query', args: { action: 'summary' } },
    { name: 'customers', args: { action: 'find', query: 'test' } },
    { name: 'analytics', args: { action: 'summary' } },
    { name: 'orders', args: { action: 'find', status: 'completed', limit: 3 } },
  ];

  for (const tool of childTools) {
    const result = await executeTool(supabase, tool.name, tool.args, STORE_ID, {
      source: 'test',
      requestId: conversationTraceId,
      parentId: rootId
    });
    console.log(`    └─ ${tool.name}.${tool.args.action}: ${result.success ? '✅' : '❌'}`);
  }

  // Complete root span
  await supabase.from("audit_logs").update({
    details: {
      source: "test",
      user_message: "Heavy test: get inventory, customers, and create a report",
      completed: true,
      tool_calls: childTools.length
    }
  }).eq("id", rootId);

  // =========================================================================
  // TEST 3: Concurrent calls (stress test)
  // =========================================================================
  console.log('\n📊 TEST 3: Concurrent calls (10 parallel)');
  console.log('-'.repeat(70));

  const concurrentTraceId = crypto.randomUUID();
  const concurrentStart = Date.now();

  const promises = Array(10).fill(null).map((_, i) =>
    executeTool(supabase, 'locations', {}, STORE_ID, {
      source: 'test',
      requestId: concurrentTraceId
    })
  );

  const concurrentResults = await Promise.all(promises);
  const concurrentDuration = Date.now() - concurrentStart;
  const concurrentSuccess = concurrentResults.filter(r => r.success).length;

  console.log(`  ${concurrentSuccess}/10 succeeded in ${concurrentDuration}ms total`);
  console.log(`  Avg per call: ${Math.round(concurrentDuration / 10)}ms`);

  // =========================================================================
  // TEST 4: Error handling
  // =========================================================================
  console.log('\n📊 TEST 4: Error handling');
  console.log('-'.repeat(70));

  const errorTraceId = crypto.randomUUID();

  // Invalid tool
  const r1 = await executeTool(supabase, 'nonexistent_tool', {}, STORE_ID, {
    source: 'test', requestId: errorTraceId
  });
  console.log(`  Invalid tool: ${r1.success ? '❌ Should have failed' : '✅ Correctly failed'}`);

  // Invalid action
  const r2 = await executeTool(supabase, 'inventory', { action: 'invalid_action' }, STORE_ID, {
    source: 'test', requestId: errorTraceId
  });
  console.log(`  Invalid action: ${r2.success ? '❌ Should have failed' : '✅ Correctly failed'}`);

  // =========================================================================
  // TEST 5: Verify trace reconstruction
  // =========================================================================
  console.log('\n📊 TEST 5: Trace reconstruction');
  console.log('-'.repeat(70));

  await new Promise(r => setTimeout(r, 500)); // Wait for writes

  const { data: trace } = await supabase.rpc('get_trace', { p_request_id: conversationTraceId });

  if (trace && trace.length > 0) {
    console.log(`\n  Trace ${conversationTraceId.slice(0, 8)}...:`);
    trace.forEach((span: any) => {
      const indent = '  '.repeat(span.depth + 1);
      const status = span.severity === 'error' ? '❌' : '✅';
      const duration = span.duration_ms ? `[${span.duration_ms}ms]` : '';
      console.log(`${indent}${status} ${span.action} ${duration}`);
    });
    console.log(`\n  ✅ Trace reconstructed with ${trace.length} spans`);
  } else {
    console.log('  ❌ Failed to reconstruct trace');
  }

  // =========================================================================
  // TEST 6: Stats verification
  // =========================================================================
  console.log('\n📊 TEST 6: Stats verification');
  console.log('-'.repeat(70));

  const { data: stats } = await supabase.rpc('get_trace_stats', {
    p_store_id: STORE_ID,
    p_hours: 1
  });

  if (stats) {
    console.log(`\n  Stats for last hour:`);
    console.log(`    Total traces: ${stats.total_traces}`);
    console.log(`    Total spans: ${stats.total_spans}`);
    console.log(`    Tool calls: ${stats.tool_calls}`);
    console.log(`    Errors: ${stats.errors}`);
    console.log(`    Avg duration: ${stats.avg_duration_ms}ms`);
    console.log(`\n  Top tools:`);
    if (stats.by_action) {
      Object.entries(stats.by_action).slice(0, 5).forEach(([action, count]) => {
        console.log(`    ${action}: ${count}`);
      });
    }
  }

  // =========================================================================
  // FINAL SUMMARY
  // =========================================================================
  console.log('\n' + '='.repeat(70));
  console.log('FINAL SUMMARY');
  console.log('='.repeat(70));

  console.log(`\n  Total calls: ${results.total}`);
  console.log(`  Success: ${results.success} (${Math.round(100 * results.success / results.total)}%)`);
  console.log(`  Failed: ${results.failed}`);

  console.log('\n  By Source:');
  for (const [source, data] of Object.entries(results.bySource)) {
    console.log(`    ${source}: ${data.success}✓ ${data.failed}✗`);
  }

  console.log('\n  By Tool (avg latency):');
  for (const [tool, data] of Object.entries(results.byTool)) {
    const avg = Math.round(data.times.reduce((a, b) => a + b, 0) / data.times.length);
    console.log(`    ${tool}: ${avg}ms avg (${data.success}✓ ${data.failed}✗)`);
  }

  // Verify data in database
  const { count } = await supabase
    .from('audit_logs')
    .select('*', { count: 'exact', head: true })
    .like('action', 'tool.%')
    .gte('created_at', new Date(Date.now() - 60000).toISOString());

  console.log(`\n  Tool logs in last minute: ${count}`);

  console.log('\n' + '='.repeat(70));
  console.log('TESTING COMPLETE');
  console.log('='.repeat(70));
}

runHeavyTests().catch(console.error);
