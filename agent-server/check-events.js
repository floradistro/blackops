import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkEvents() {
  // Check events table structure and content
  console.log('=== EVENTS TABLE ===');
  const { data: eventsSample, error: e1 } = await supabase
    .from('events')
    .select('*')
    .limit(5);

  if (eventsSample && eventsSample[0]) {
    console.log('Columns:', Object.keys(eventsSample[0]).join(', '));
    console.log('Sample events:');
    for (const e of eventsSample) {
      console.log(JSON.stringify(e, null, 2));
    }
  }

  // Check analytics_events table
  console.log('\n=== ANALYTICS_EVENTS TABLE ===');
  const { data: analyticsSample, error: e2 } = await supabase
    .from('analytics_events')
    .select('*')
    .limit(5);

  if (analyticsSample && analyticsSample[0]) {
    console.log('Columns:', Object.keys(analyticsSample[0]).join(', '));
    console.log('Sample analytics events:');
    for (const e of analyticsSample) {
      console.log(JSON.stringify(e, null, 2));
    }
  }

  // Check audit_logs for tool calls
  console.log('\n=== AUDIT_LOGS TABLE ===');
  const { data: auditSample, error: e3 } = await supabase
    .from('audit_logs')
    .select('*')
    .limit(10);

  if (auditSample && auditSample[0]) {
    console.log('Columns:', Object.keys(auditSample[0]).join(', '));
    console.log('Sample audit logs:');
    for (const e of auditSample) {
      console.log(`  ${e.action} | ${e.resource_type} | ${e.created_at}`);
    }
  }

  // Now look for any tool-related entries
  console.log('\n=== SEARCHING FOR TOOL CALLS IN AUDIT_LOGS ===');
  const { data: toolAudits } = await supabase
    .from('audit_logs')
    .select('*')
    .or('action.ilike.%tool%,resource_type.ilike.%tool%,action.ilike.%mcp%,action.ilike.%agent%')
    .limit(50);

  if (toolAudits && toolAudits.length > 0) {
    console.log('Found tool-related audit entries:', toolAudits.length);
    for (const e of toolAudits) {
      console.log(`  ${e.action} | ${e.resource_type} | ${JSON.stringify(e.details)?.slice(0, 100)}`);
    }
  } else {
    console.log('No tool-related entries found');
  }

  // Check all unique actions in audit_logs
  console.log('\n=== ALL UNIQUE ACTIONS IN AUDIT_LOGS ===');
  const { data: allAudits } = await supabase
    .from('audit_logs')
    .select('action, resource_type')
    .limit(1000);

  if (allAudits) {
    const uniqueActions = [...new Set(allAudits.map(a => `${a.action}|${a.resource_type}`))];
    console.log('Unique action|resource combinations:');
    uniqueActions.forEach(a => console.log('  ' + a));
  }

  // Check events for tool-related events
  console.log('\n=== SEARCHING FOR TOOL EVENTS ===');
  const { data: allEvents } = await supabase
    .from('events')
    .select('*')
    .limit(100);

  if (allEvents && allEvents.length > 0) {
    // Get unique event types
    const eventTypes = [...new Set(allEvents.map(e => e.event_type || e.type || e.name || 'unknown'))];
    console.log('Event types found:', eventTypes.join(', '));

    // Look for tool-related ones
    const toolEvents = allEvents.filter(e => {
      const str = JSON.stringify(e).toLowerCase();
      return str.includes('tool') || str.includes('mcp') || str.includes('agent');
    });
    console.log('Tool-related events:', toolEvents.length);
    for (const e of toolEvents.slice(0, 5)) {
      console.log(JSON.stringify(e, null, 2));
    }
  }
}

checkEvents().catch(console.error);
