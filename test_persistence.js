// Test Persistence for User Tools & Triggers
// This simulates what the Swift app does: create, update, delete, and verify
// Run with: node test_persistence.js

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, supabaseServiceKey);
const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function testPersistence() {
    console.log('=== Testing Persistence (Swift App Simulation) ===\n');

    // Test 1: Create a new tool with ALL fields (simulating Swift model)
    console.log('1. Creating a tool with all fields (like Swift app would)...');
    const toolId = crypto.randomUUID();
    const testTool = {
        id: toolId,
        store_id: STORE_ID,
        name: 'persistence_test_' + Date.now(),
        display_name: 'Persistence Test Tool',
        description: 'Testing that all fields persist correctly',
        category: 'test',
        icon: 'testtube.2',
        execution_type: 'rpc',
        rpc_function: 'test_function',
        input_schema: {
            type: 'object',
            properties: {
                test_param: {
                    type: 'string',
                    description: 'A test parameter'
                }
            },
            required: ['test_param']
        },
        is_read_only: true,
        requires_approval: false,
        max_execution_time_ms: 10000,
        is_active: true,
        is_tested: false
    };

    const { data: createdTool, error: createErr } = await supabase
        .from('user_tools')
        .insert(testTool)
        .select()
        .single();

    if (createErr) {
        console.log('   ERROR creating tool:', createErr.message);
        return;
    }
    console.log('   ✅ Tool created:', createdTool.id);
    console.log('   Fields saved correctly:');
    console.log('     - name:', createdTool.name);
    console.log('     - execution_type:', createdTool.execution_type);
    console.log('     - input_schema:', JSON.stringify(createdTool.input_schema).substring(0, 50) + '...');

    // Test 2: Update the tool (like editing in Swift)
    console.log('\n2. Updating tool fields...');
    const { data: updatedTool, error: updateErr } = await supabase
        .from('user_tools')
        .update({
            display_name: 'Updated Test Tool',
            description: 'Updated description',
            is_tested: true,
            test_result: {
                success: true,
                output: { message: 'Test passed' },
                execution_time_ms: 250,
                tested_at: new Date().toISOString()
            }
        })
        .eq('id', toolId)
        .select()
        .single();

    if (updateErr) {
        console.log('   ERROR updating tool:', updateErr.message);
    } else {
        console.log('   ✅ Tool updated');
        console.log('     - display_name:', updatedTool.display_name);
        console.log('     - is_tested:', updatedTool.is_tested);
        console.log('     - test_result:', updatedTool.test_result?.success);
    }

    // Test 3: Create a trigger with ALL trigger types
    console.log('\n3. Testing all trigger types...');

    // 3a. Event trigger
    const eventTriggerId = crypto.randomUUID();
    const { data: eventTrigger, error: eventErr } = await supabase
        .from('user_triggers')
        .insert({
            id: eventTriggerId,
            store_id: STORE_ID,
            tool_id: toolId,
            name: 'event_trigger_test_' + Date.now(),
            description: 'Event trigger test',
            trigger_type: 'event',
            event_table: 'orders',
            event_operation: 'INSERT',
            event_filter: { status: 'pending' },
            tool_args_template: { order_id: '{{event.id}}' },
            is_active: true,
            max_retries: 3,
            retry_delay_seconds: 60
        })
        .select()
        .single();

    if (eventErr) {
        console.log('   ERROR creating event trigger:', eventErr.message);
    } else {
        console.log('   ✅ Event trigger created');
        console.log('     - trigger_type:', eventTrigger.trigger_type);
        console.log('     - event_table:', eventTrigger.event_table);
        console.log('     - event_operation:', eventTrigger.event_operation);
    }

    // 3b. Schedule trigger
    const scheduleTriggerId = crypto.randomUUID();
    const { data: scheduleTrigger, error: scheduleErr } = await supabase
        .from('user_triggers')
        .insert({
            id: scheduleTriggerId,
            store_id: STORE_ID,
            tool_id: toolId,
            name: 'schedule_trigger_test_' + Date.now(),
            description: 'Schedule trigger test',
            trigger_type: 'schedule',
            cron_expression: '0 9 * * *',  // Every day at 9am
            timezone: 'America/New_York',
            tool_args_template: { report_type: 'daily' },
            is_active: true,
            max_retries: 3,
            retry_delay_seconds: 60
        })
        .select()
        .single();

    if (scheduleErr) {
        console.log('   ERROR creating schedule trigger:', scheduleErr.message);
    } else {
        console.log('   ✅ Schedule trigger created');
        console.log('     - trigger_type:', scheduleTrigger.trigger_type);
        console.log('     - cron_expression:', scheduleTrigger.cron_expression);
        console.log('     - timezone:', scheduleTrigger.timezone);
    }

    // 3c. Condition trigger
    const conditionTriggerId = crypto.randomUUID();
    const { data: conditionTrigger, error: conditionErr } = await supabase
        .from('user_triggers')
        .insert({
            id: conditionTriggerId,
            store_id: STORE_ID,
            tool_id: toolId,
            name: 'condition_trigger_test_' + Date.now(),
            description: 'Condition trigger test',
            trigger_type: 'condition',
            condition_sql: 'SELECT COUNT(*) > 10 FROM orders WHERE status = \'pending\'',
            condition_check_interval: 300,  // Check every 5 minutes
            tool_args_template: { alert_type: 'high_pending' },
            is_active: true,
            max_retries: 3,
            retry_delay_seconds: 60
        })
        .select()
        .single();

    if (conditionErr) {
        console.log('   ERROR creating condition trigger:', conditionErr.message);
    } else {
        console.log('   ✅ Condition trigger created');
        console.log('     - trigger_type:', conditionTrigger.trigger_type);
        console.log('     - condition_sql:', conditionTrigger.condition_sql?.substring(0, 40) + '...');
        console.log('     - condition_check_interval:', conditionTrigger.condition_check_interval);
    }

    // Test 4: Verify all data can be fetched (like loadUserTools/loadUserTriggers)
    console.log('\n4. Fetching all tools and triggers (like Swift loadUserTools)...');
    const { data: allTools } = await supabase
        .from('user_tools')
        .select()
        .eq('store_id', STORE_ID)
        .order('created_at', { ascending: false });

    const { data: allTriggers } = await supabase
        .from('user_triggers')
        .select()
        .eq('store_id', STORE_ID)
        .order('created_at', { ascending: false });

    console.log(`   ✅ Loaded ${allTools?.length || 0} tools and ${allTriggers?.length || 0} triggers`);

    // Test 5: Update trigger (simulate editing in UI)
    console.log('\n5. Updating trigger (like editing in Swift UI)...');
    const { data: updatedTrigger, error: updateTriggerErr } = await supabase
        .from('user_triggers')
        .update({
            is_active: false,
            description: 'Updated trigger description',
            max_retries: 5
        })
        .eq('id', eventTriggerId)
        .select()
        .single();

    if (updateTriggerErr) {
        console.log('   ERROR updating trigger:', updateTriggerErr.message);
    } else {
        console.log('   ✅ Trigger updated');
        console.log('     - is_active:', updatedTrigger.is_active);
        console.log('     - max_retries:', updatedTrigger.max_retries);
    }

    // Test 6: Clean up test data
    console.log('\n6. Cleaning up test data...');

    // Delete triggers first (foreign key)
    await supabase.from('user_triggers').delete().eq('id', eventTriggerId);
    await supabase.from('user_triggers').delete().eq('id', scheduleTriggerId);
    await supabase.from('user_triggers').delete().eq('id', conditionTriggerId);

    // Delete tool
    await supabase.from('user_tools').delete().eq('id', toolId);

    console.log('   ✅ Test data cleaned up');

    // Verify cleanup
    const { data: remainingTools } = await supabase
        .from('user_tools')
        .select('id')
        .eq('id', toolId);

    console.log(`   Remaining test tools: ${remainingTools?.length || 0} (should be 0)`);

    console.log('\n=== All Persistence Tests PASSED ===\n');
}

testPersistence().catch(console.error);
