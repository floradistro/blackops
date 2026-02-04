/**
 * Test telemetry logging for MCP tools
 * Uses the existing audit_logs table
 */

import { createClient } from "@supabase/supabase-js";
import { executeTool } from "../src/tools/executor.js";

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function testTelemetry() {
  console.log('=' .repeat(70));
  console.log('TESTING MCP TOOL TELEMETRY (audit_logs table)');
  console.log('=' .repeat(70));

  // Test 1: locations tool (simple query)
  console.log('\n1. Testing locations tool...');
  const result1 = await executeTool(supabase, 'locations', {}, STORE_ID, {
    source: 'test'
  });
  console.log('   Result:', result1.success ? 'SUCCESS' : 'FAILED');

  // Test 2: inventory_query with action
  console.log('\n2. Testing inventory_query tool (source: claude_code)...');
  const result2 = await executeTool(supabase, 'inventory_query', { action: 'summary' }, STORE_ID, {
    source: 'claude_code'
  });
  console.log('   Result:', result2.success ? 'SUCCESS' : 'FAILED');

  // Test 3: customers tool (source: swag_manager)
  console.log('\n3. Testing customers tool (source: swag_manager)...');
  const result3 = await executeTool(supabase, 'customers', { action: 'find', limit: 5 }, STORE_ID, {
    source: 'swag_manager'
  });
  console.log('   Result:', result3.success ? 'SUCCESS' : 'FAILED');

  // Wait a moment for logs to be written
  await new Promise(r => setTimeout(r, 500));

  // Check audit_logs for tool entries
  console.log('\n' + '=' .repeat(70));
  console.log('MCP TOOL LOGS (from audit_logs)');
  console.log('=' .repeat(70));

  const { data: logs, error } = await supabase
    .from('audit_logs')
    .select('action, severity, duration_ms, details, error_message, created_at')
    .like('action', 'tool.%')
    .order('created_at', { ascending: false })
    .limit(10);

  if (error) {
    console.log('\n❌ Error querying logs:', error.message);
  } else {
    console.log(`\n✅ Found ${logs.length} MCP tool logs:\n`);
    logs.forEach(l => {
      const details = l.details as { source?: string };
      console.log(`   ${l.action}`);
      console.log(`      Source: ${details?.source} | Severity: ${l.severity} | Duration: ${l.duration_ms}ms`);
      if (l.error_message) {
        console.log(`      Error: ${l.error_message.slice(0, 60)}...`);
      }
      console.log('');
    });
  }

  // Summary stats
  console.log('=' .repeat(70));
  console.log('TOOL CALL SUMMARY');
  console.log('=' .repeat(70));

  const { data: stats } = await supabase
    .from('audit_logs')
    .select('action')
    .like('action', 'tool.%');

  const counts: Record<string, number> = {};
  stats?.forEach(s => {
    counts[s.action] = (counts[s.action] || 0) + 1;
  });

  console.log('\nTool call counts:');
  Object.entries(counts).sort((a, b) => b[1] - a[1]).forEach(([action, count]) => {
    console.log(`   ${action}: ${count}`);
  });
}

testTelemetry().catch(console.error);
