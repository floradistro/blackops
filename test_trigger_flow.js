// Test Full Trigger Flow
// Run with: node test_trigger_flow.js

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, supabaseServiceKey);
const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function testTriggerFlow() {
    console.log('=== Full Trigger Flow Test ===\n');

    // 1. Check if database trigger exists on orders table
    console.log('1. Checking if database trigger exists on orders table...');
    const { data: triggers, error: triggerErr } = await supabase.rpc('get_table_triggers', {
        p_table_name: 'orders'
    }).maybeSingle();

    // If RPC doesn't exist, check directly
    if (triggerErr) {
        console.log('   Cannot check triggers via RPC, trying direct query...');
        const { data: rawTriggers, error: rawErr } = await supabase
            .from('pg_trigger')
            .select('*')
            .limit(1);

        if (rawErr) {
            console.log('   Cannot access pg_trigger directly (expected)');
        }
    } else {
        console.log('   Triggers:', triggers);
    }

    // 2. Check current queue status
    console.log('\n2. Checking trigger_queue for pending items...');
    const { data: queueBefore, error: queueErr } = await supabase
        .from('trigger_queue')
        .select('id, trigger_id, status, created_at')
        .eq('store_id', STORE_ID)
        .order('created_at', { ascending: false })
        .limit(5);

    if (queueErr) {
        console.log('   ERROR:', queueErr.message);
    } else {
        console.log(`   Found ${queueBefore?.length || 0} items in queue`);
        queueBefore?.forEach(q => console.log(`   - ${q.id}: ${q.status}`));
    }

    // 3. Get the test_order_trigger
    console.log('\n3. Checking test_order_trigger configuration...');
    const { data: testTrigger, error: testTriggerErr } = await supabase
        .from('user_triggers')
        .select('*')
        .eq('store_id', STORE_ID)
        .eq('name', 'test_order_trigger')
        .single();

    if (testTriggerErr) {
        console.log('   ERROR:', testTriggerErr.message);
        console.log('   Creating test_order_trigger...');

        // Get any tool first
        const { data: tool } = await supabase
            .from('user_tools')
            .select('id')
            .eq('store_id', STORE_ID)
            .limit(1)
            .single();

        if (tool) {
            const { data: newTrigger, error: createErr } = await supabase
                .from('user_triggers')
                .insert({
                    store_id: STORE_ID,
                    name: 'test_order_trigger',
                    description: 'Test trigger for orders',
                    trigger_type: 'event',
                    event_table: 'orders',
                    event_operation: 'INSERT',
                    tool_id: tool.id,
                    tool_args_template: {
                        order_id: '{{event.id}}',
                        status: '{{event.status}}'
                    },
                    is_active: true,
                    max_retries: 3,
                    retry_delay_seconds: 60
                })
                .select()
                .single();

            if (createErr) {
                console.log('   Failed to create trigger:', createErr.message);
                return;
            }
            console.log('   Created trigger:', newTrigger.id);
        }
    } else {
        console.log('   Trigger found:', testTrigger.id);
        console.log('   - event_table:', testTrigger.event_table);
        console.log('   - event_operation:', testTrigger.event_operation);
        console.log('   - is_active:', testTrigger.is_active);
        console.log('   - tool_id:', testTrigger.tool_id);
    }

    // 4. Manually enqueue a trigger (bypass the DB trigger)
    console.log('\n4. Manually calling enqueue_trigger RPC...');
    const { data: enqueueTrigger } = await supabase
        .from('user_triggers')
        .select('id')
        .eq('store_id', STORE_ID)
        .eq('event_table', 'orders')
        .eq('event_operation', 'INSERT')
        .eq('is_active', true)
        .single();

    if (enqueueTrigger) {
        const { data: queueId, error: enqueueErr } = await supabase
            .rpc('enqueue_trigger', {
                p_trigger_id: enqueueTrigger.id,
                p_event_payload: {
                    table: 'orders',
                    operation: 'INSERT',
                    new: { id: 'test-order-123', status: 'pending', store_id: STORE_ID }
                }
            });

        if (enqueueErr) {
            console.log('   ERROR:', enqueueErr.message);
        } else {
            console.log('   Enqueued! Queue ID:', queueId);
        }
    } else {
        console.log('   No active trigger found for orders INSERT');
    }

    // 5. Check queue after enqueue
    console.log('\n5. Checking queue after enqueue...');
    const { data: queueAfter } = await supabase
        .from('trigger_queue')
        .select('id, trigger_id, status, resolved_args, created_at')
        .eq('store_id', STORE_ID)
        .order('created_at', { ascending: false })
        .limit(5);

    console.log(`   Found ${queueAfter?.length || 0} items`);
    queueAfter?.forEach(q => {
        console.log(`   - ${q.id}: ${q.status}`);
        console.log(`     resolved_args: ${JSON.stringify(q.resolved_args)}`);
    });

    // 6. Try to process the queue
    console.log('\n6. Calling process_trigger_queue...');
    const { data: processResult, error: processErr } = await supabase
        .rpc('process_trigger_queue', { p_batch_size: 10 });

    if (processErr) {
        console.log('   ERROR:', processErr.message);
    } else {
        console.log('   Result:', processResult);
    }

    // 7. Check final queue status
    console.log('\n7. Final queue status...');
    const { data: queueFinal } = await supabase
        .from('trigger_queue')
        .select('id, status, last_error, result, completed_at')
        .eq('store_id', STORE_ID)
        .order('created_at', { ascending: false })
        .limit(5);

    queueFinal?.forEach(q => {
        console.log(`   - ${q.id}: ${q.status}`);
        if (q.last_error) console.log(`     error: ${q.last_error}`);
        if (q.result) console.log(`     result: ${JSON.stringify(q.result)}`);
    });

    // 8. Check if the Postgres trigger actually fires
    console.log('\n8. Testing if Postgres trigger fires on order INSERT...');
    console.log('   (This requires creating an actual order)');

    // Get a customer and location for the order
    const { data: customer } = await supabase
        .from('customers')
        .select('id')
        .eq('store_id', STORE_ID)
        .limit(1)
        .single();

    const { data: location } = await supabase
        .from('locations')
        .select('id')
        .eq('store_id', STORE_ID)
        .limit(1)
        .single();

    if (customer && location) {
        // Count queue items before
        const { count: beforeCount } = await supabase
            .from('trigger_queue')
            .select('*', { count: 'exact', head: true })
            .eq('store_id', STORE_ID);

        // Create a test order
        const testOrderId = crypto.randomUUID();
        const { data: order, error: orderErr } = await supabase
            .from('orders')
            .insert({
                id: testOrderId,
                store_id: STORE_ID,
                customer_id: customer.id,
                location_id: location.id,
                status: 'pending',
                order_number: 'TEST-' + Date.now(),
                subtotal: 0,
                total: 0,
                payment_method: 'cash',
                items_json: []
            })
            .select()
            .single();

        if (orderErr) {
            console.log('   ERROR creating order:', orderErr.message);
        } else {
            console.log('   Created test order:', order.id);

            // Wait a moment for trigger to fire
            await new Promise(r => setTimeout(r, 500));

            // Count queue items after
            const { count: afterCount } = await supabase
                .from('trigger_queue')
                .select('*', { count: 'exact', head: true })
                .eq('store_id', STORE_ID);

            if (afterCount > beforeCount) {
                console.log('   ✅ TRIGGER FIRED! Queue increased from', beforeCount, 'to', afterCount);
            } else {
                console.log('   ❌ TRIGGER DID NOT FIRE! Queue still at', afterCount);
                console.log('   This means the Postgres trigger is not set up correctly.');
            }

            // Cleanup test order
            await supabase.from('orders').delete().eq('id', testOrderId);
            console.log('   Cleaned up test order');
        }
    } else {
        console.log('   Skipping (need customer and location)');
    }

    console.log('\n=== Test Complete ===\n');
}

testTriggerFlow().catch(console.error);
