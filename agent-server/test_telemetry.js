// Test telemetry by making a real API call through the agent server
import WebSocket from 'ws';
import { createClient } from '@supabase/supabase-js';

const WS_URL = 'ws://localhost:3847';
const SUPABASE_URL = 'https://uaednwpxursknmwdeejn.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function testTelemetry() {
  console.log('=== Testing Agent Server Telemetry ===\n');

  // Step 1: Connect to WebSocket
  console.log('1. Connecting to WebSocket...');
  const ws = new WebSocket(WS_URL);

  return new Promise((resolve, reject) => {
    let conversationId = null;
    let usageData = null;

    ws.on('open', () => {
      console.log('   Connected!\n');

      // Step 2: Send a simple query (agentId must be UUID or omitted)
      console.log('2. Sending test query...');
      ws.send(JSON.stringify({
        type: 'query',
        prompt: 'Say "Hello, telemetry test!" and nothing else.',
        config: {
          agentName: 'Telemetry Test Agent',
          systemPrompt: 'You are a helpful assistant. Keep responses brief.',
          maxTurns: 1
        }
      }));
    });

    ws.on('message', (data) => {
      const msg = JSON.parse(data.toString());

      if (msg.type === 'ready') {
        console.log(`   Server ready with ${msg.tools?.length || 0} tools\n`);
      } else if (msg.type === 'started') {
        console.log(`   Started conversation: ${msg.conversationId}`);
        conversationId = msg.conversationId;
      } else if (msg.type === 'text') {
        console.log(`   Response: "${msg.text}"`);
      } else if (msg.type === 'done') {
        console.log('\n3. Received done event:');
        console.log(`   Status: ${msg.status}`);
        console.log(`   Conversation ID: ${msg.conversationId}`);
        console.log(`   Usage:`, JSON.stringify(msg.usage, null, 2));
        usageData = msg.usage;
        conversationId = msg.conversationId;
        ws.close();
      } else if (msg.type === 'error') {
        console.error(`   Error: ${msg.error}`);
        ws.close();
      }
    });

    ws.on('close', async () => {
      console.log('\n4. WebSocket closed. Checking database...\n');

      // Step 3: Query database for telemetry
      await new Promise(r => setTimeout(r, 1000)); // Wait for writes

      const { data: apiLogs, error: apiError } = await supabase
        .from('audit_logs')
        .select('*')
        .eq('action', 'claude_api_request')
        .order('created_at', { ascending: false })
        .limit(5);

      if (apiError) {
        console.error('   Database error:', apiError.message);
        resolve(false);
        return;
      }

      console.log(`   Found ${apiLogs?.length || 0} claude_api_request logs\n`);

      if (apiLogs && apiLogs.length > 0) {
        const latest = apiLogs[0];
        console.log('5. Latest telemetry record:');
        console.log('   Action:', latest.action);
        console.log('   Request ID (trace_id):', latest.request_id);
        console.log('   Duration:', latest.duration_ms, 'ms');
        console.log('   Created:', latest.created_at);

        const details = latest.details;
        if (details) {
          console.log('\n   gen_ai.* fields:');
          console.log('     system:', details['gen_ai.system']);
          console.log('     model:', details['gen_ai.request.model']);
          console.log('     input_tokens:', details['gen_ai.usage.input_tokens']);
          console.log('     output_tokens:', details['gen_ai.usage.output_tokens']);
          console.log('     cache_read_tokens:', details['gen_ai.usage.cache_read_tokens']);
          console.log('     cache_creation_tokens:', details['gen_ai.usage.cache_creation_tokens']);
          console.log('     cost (USD):', details['gen_ai.usage.cost']);

          console.log('\n   Agent context:');
          console.log('     agent_id:', details.agent_id);
          console.log('     agent_name:', details.agent_name);
          console.log('     conversation_id:', details.conversation_id);
          console.log('     turn_number:', details.turn_number);
          console.log('     stop_reason:', details.stop_reason);

          if (details.otel) {
            console.log('\n   OTEL context:');
            console.log('     trace_id:', details.otel.trace_id);
            console.log('     span_id:', details.otel.span_id);
            console.log('     span_kind:', details.otel.span_kind);
            console.log('     status_code:', details.otel.status_code);
            console.log('     service_name:', details.otel.service_name);
          }
        }

        // Verify the data matches what we got in done event
        console.log('\n6. Validation:');
        const inputMatch = details?.['gen_ai.usage.input_tokens'] === usageData?.inputTokens;
        const outputMatch = details?.['gen_ai.usage.output_tokens'] === usageData?.outputTokens;
        console.log(`   Input tokens match: ${inputMatch ? '✓' : '✗'} (DB: ${details?.['gen_ai.usage.input_tokens']}, WS: ${usageData?.inputTokens})`);
        console.log(`   Output tokens match: ${outputMatch ? '✓' : '✗'} (DB: ${details?.['gen_ai.usage.output_tokens']}, WS: ${usageData?.outputTokens})`);

        if (inputMatch && outputMatch) {
          console.log('\n=== TELEMETRY TEST PASSED ===');
          resolve(true);
        } else {
          console.log('\n=== TELEMETRY TEST FAILED (data mismatch) ===');
          resolve(false);
        }
      } else {
        console.log('=== TELEMETRY TEST FAILED (no records found) ===');
        resolve(false);
      }
    });

    ws.on('error', (err) => {
      console.error('WebSocket error:', err.message);
      reject(err);
    });

    // Timeout after 60 seconds
    setTimeout(() => {
      console.error('Test timed out');
      ws.close();
      reject(new Error('Timeout'));
    }, 60000);
  });
}

testTelemetry()
  .then(success => process.exit(success ? 0 : 1))
  .catch(err => {
    console.error('Test failed:', err);
    process.exit(1);
  });
