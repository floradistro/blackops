import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkAiLogs() {
  // Get all ai.request entries from audit_logs
  console.log('=== AI REQUEST LOGS ===');
  const { data: aiRequests, error } = await supabase
    .from('audit_logs')
    .select('*')
    .eq('action', 'ai.request')
    .order('created_at', { ascending: false })
    .limit(100);

  if (error) {
    console.log('Error:', error.message);
    return;
  }

  console.log('Total ai.request entries:', aiRequests?.length || 0);

  for (const req of aiRequests || []) {
    console.log('\n--- Entry ---');
    console.log('Created:', req.created_at);
    console.log('Details:', JSON.stringify(req.details, null, 2));
    console.log('Duration:', req.duration_ms, 'ms');
  }

  // Now get ai-related entries from events table
  console.log('\n\n=== AI EVENTS IN EVENTS TABLE ===');
  const { data: aiEvents } = await supabase
    .from('events')
    .select('*')
    .or('event_type.ilike.%ai%,event_type.ilike.%agent%,event_type.ilike.%tool%')
    .limit(50);

  if (aiEvents && aiEvents.length > 0) {
    console.log('Found', aiEvents.length, 'ai-related events');
    for (const e of aiEvents) {
      console.log('\n--- Event ---');
      console.log('Type:', e.event_type);
      console.log('Payload:', JSON.stringify(e.payload, null, 2));
    }
  } else {
    console.log('No ai-related events found');
  }

  // Check for aggregate_type = 'tool' or similar
  console.log('\n\n=== UNIQUE AGGREGATE TYPES IN EVENTS ===');
  const { data: eventTypes } = await supabase
    .from('events')
    .select('aggregate_type, event_type')
    .limit(1000);

  if (eventTypes) {
    const uniqueTypes = [...new Set(eventTypes.map(e => `${e.aggregate_type}:${e.event_type}`))];
    console.log('Unique aggregate:event types:');
    uniqueTypes.forEach(t => console.log('  ' + t));
  }
}

checkAiLogs().catch(console.error);
