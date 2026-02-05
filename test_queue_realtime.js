// Test if location_queue Realtime is working
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg';

const supabase = createClient(supabaseUrl, anonKey);

async function testRealtimeSetup() {
  console.log('🔍 Testing location_queue Realtime setup...\n');

  // 1. Check if table is in Realtime publication
  console.log('1️⃣ Checking Realtime publication status...');
  const { data: publication, error: pubError } = await supabase
    .from('location_queue')
    .select('*')
    .limit(0);

  if (pubError) {
    console.log('❌ Error querying table:', pubError.message);
  } else {
    console.log('✅ location_queue table is accessible\n');
  }

  // 2. Check RLS policies
  console.log('2️⃣ Checking RLS policies...');
  try {
    const { data: entries, error: rlsError } = await supabase
      .from('location_queue')
      .select('*')
      .limit(1);

    if (rlsError) {
      console.log('⚠️  RLS Error:', rlsError.message);
      console.log('   This might block Realtime events!\n');
    } else {
      console.log('✅ RLS allows reads\n');
    }
  } catch (e) {
    console.log('❌ Exception:', e.message, '\n');
  }

  // 3. Test Realtime subscription
  console.log('3️⃣ Testing Realtime subscription...');
  console.log('   Creating channel and subscribing...\n');

  const channel = supabase
    .channel('test-queue-channel')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'location_queue'
      },
      (payload) => {
        console.log('🎉 REALTIME EVENT RECEIVED:');
        console.log('   Event:', payload.eventType);
        console.log('   Table:', payload.table);
        console.log('   Data:', JSON.stringify(payload.new || payload.old, null, 2));
        console.log('');
      }
    )
    .subscribe((status) => {
      console.log(`   Subscription status: ${status}`);
      if (status === 'SUBSCRIBED') {
        console.log('   ✅ Successfully subscribed to location_queue changes!\n');
        console.log('📢 Listening for changes... (press Ctrl+C to stop)');
        console.log('   Try adding/removing a customer from queue in the app.\n');
      } else if (status === 'CHANNEL_ERROR') {
        console.log('   ❌ Failed to subscribe - Realtime may not be enabled!\n');
      }
    });

  // Keep alive
  await new Promise(() => {});
}

testRealtimeSetup().catch(console.error);
