// Fix Triggers - Full Functionality Check
// Run with: node fix_triggers_full.js

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, supabaseServiceKey);
const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function fixAndAudit() {
    console.log('=== Fix Triggers & Full Functionality Audit ===\n');

    // 1. Clear broken queue items
    console.log('1. Clearing broken queue items...');
    const { data: deleted, error: delErr } = await supabase
        .from('trigger_queue')
        .delete()
        .eq('store_id', STORE_ID)
        .neq('status', 'success')
        .select();

    console.log(`   Deleted ${deleted?.length || 0} broken items`);

    // 2. Create the missing count_store_orders function via RPC
    console.log('\n2. Creating count_store_orders RPC function...');
    const createFunctionSQL = `
        CREATE OR REPLACE FUNCTION count_store_orders(p_store_id UUID, p_args JSONB)
        RETURNS JSONB
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $$
        DECLARE
            v_count INTEGER;
            v_status TEXT;
        BEGIN
            v_status := p_args->>'status';

            IF v_status IS NOT NULL THEN
                SELECT COUNT(*) INTO v_count
                FROM orders
                WHERE store_id = p_store_id AND status = v_status;
            ELSE
                SELECT COUNT(*) INTO v_count
                FROM orders
                WHERE store_id = p_store_id;
            END IF;

            RETURN jsonb_build_object(
                'count', v_count,
                'status_filter', v_status,
                'store_id', p_store_id
            );
        END;
        $$;
    `;

    const { error: funcErr } = await supabase.rpc('exec_sql', { sql: createFunctionSQL });
    if (funcErr) {
        // Try direct execution if exec_sql doesn't exist
        console.log('   exec_sql not available, will need manual migration');
    } else {
        console.log('   ✅ Function created');
    }

    // 3. Check what Postgres triggers exist
    console.log('\n3. Checking Postgres triggers on orders table...');
    const { data: triggers, error: trigErr } = await supabase
        .rpc('get_triggers_info')
        .maybeSingle();

    if (trigErr) {
        console.log('   Cannot check via RPC, this is expected');
    }

    // 4. List all user_tools
    console.log('\n4. Current user_tools:');
    const { data: tools } = await supabase
        .from('user_tools')
        .select('id, name, display_name, execution_type, rpc_function, sql_template, is_active')
        .eq('store_id', STORE_ID);

    tools?.forEach(t => {
        console.log(`   - ${t.name} (${t.execution_type})`);
        if (t.execution_type === 'rpc') console.log(`     rpc_function: ${t.rpc_function}`);
        if (t.execution_type === 'sql') console.log(`     sql_template: ${t.sql_template?.substring(0, 50)}...`);
    });

    // 5. List all user_triggers
    console.log('\n5. Current user_triggers:');
    const { data: userTriggers } = await supabase
        .from('user_triggers')
        .select('id, name, trigger_type, event_table, event_operation, tool_id, is_active')
        .eq('store_id', STORE_ID);

    userTriggers?.forEach(t => {
        console.log(`   - ${t.name} (${t.trigger_type}: ${t.event_table}/${t.event_operation}) active=${t.is_active}`);
    });

    // 6. Check what's MISSING for full functionality
    console.log('\n\n=== MISSING FUNCTIONALITY AUDIT ===\n');

    // 6a. Check if Postgres trigger exists on orders
    console.log('6a. Postgres Trigger on orders table:');
    console.log('    ISSUE: The migration calls setup_event_trigger() but pg_cron may not be enabled');
    console.log('    FIX NEEDED: Run setup_event_trigger(\'orders\', \'ALL\') manually in Supabase SQL Editor');

    // 6b. Check if pg_cron jobs exist
    console.log('\n6b. pg_cron for queue processing:');
    console.log('    ISSUE: cron.schedule() requires pg_cron extension');
    console.log('    FIX OPTIONS:');
    console.log('    - Enable pg_cron in Supabase dashboard (if available)');
    console.log('    - OR use Supabase Edge Function with cron trigger');
    console.log('    - OR call process_trigger_queue() from your server on interval');

    // 6c. Check RPC functions
    console.log('\n6c. Required RPC functions:');
    const requiredFunctions = [
        'execute_user_tool',
        'enqueue_trigger',
        'process_trigger_queue',
        'resolve_trigger_args',
        'setup_event_trigger',
        'trigger_on_table_event'
    ];

    for (const fn of requiredFunctions) {
        const { error } = await supabase.rpc(fn, {}).catch(e => ({ error: e }));
        // If error is about wrong arguments, function exists
        const exists = !error || error.message?.includes('argument') || error.message?.includes('parameter');
        console.log(`    - ${fn}: ${exists ? '✅ exists' : '❌ MISSING'}`);
    }

    // 7. Test the SQL tool (should work without RPC)
    console.log('\n7. Testing SQL tool execution (low_stock_products)...');
    const { data: sqlTool } = await supabase
        .from('user_tools')
        .select('id')
        .eq('store_id', STORE_ID)
        .eq('name', 'low_stock_products')
        .single();

    if (sqlTool) {
        const { data: sqlResult, error: sqlErr } = await supabase
            .rpc('execute_user_tool', {
                p_tool_id: sqlTool.id,
                p_store_id: STORE_ID,
                p_args: {}
            });

        if (sqlErr) {
            console.log('   ERROR:', sqlErr.message);
        } else {
            console.log('   ✅ SQL tool works:', sqlResult?.success);
        }
    }

    // 8. Fix: Switch trigger to use SQL tool
    console.log('\n8. Switching test_order_trigger to use SQL tool...');
    if (sqlTool && userTriggers?.length > 0) {
        const { error: updateErr } = await supabase
            .from('user_triggers')
            .update({ tool_id: sqlTool.id })
            .eq('name', 'test_order_trigger')
            .eq('store_id', STORE_ID);

        if (updateErr) {
            console.log('   ERROR:', updateErr.message);
        } else {
            console.log('   ✅ Trigger updated to use SQL tool');
        }
    }

    // 9. Test full flow manually
    console.log('\n9. Testing full flow (manual enqueue + process)...');

    // Get the trigger
    const { data: trigger } = await supabase
        .from('user_triggers')
        .select('id')
        .eq('store_id', STORE_ID)
        .eq('is_active', true)
        .limit(1)
        .single();

    if (trigger) {
        // Enqueue
        const { data: queueId, error: enqErr } = await supabase
            .rpc('enqueue_trigger', {
                p_trigger_id: trigger.id,
                p_event_payload: {
                    table: 'orders',
                    operation: 'INSERT',
                    new: { id: 'test-123', status: 'pending' }
                }
            });

        if (enqErr) {
            console.log('   Enqueue ERROR:', enqErr.message);
        } else {
            console.log('   Enqueued:', queueId);

            // Process
            const { data: processResult, error: procErr } = await supabase
                .rpc('process_trigger_queue', { p_batch_size: 5 });

            if (procErr) {
                console.log('   Process ERROR:', procErr.message);
            } else {
                console.log('   Process result:', processResult);
            }

            // Check result
            const { data: queueItem } = await supabase
                .from('trigger_queue')
                .select('status, result, last_error')
                .eq('id', queueId)
                .single();

            console.log('   Queue item status:', queueItem?.status);
            if (queueItem?.last_error) {
                console.log('   Last error:', queueItem.last_error);
            }
            if (queueItem?.result) {
                console.log('   Result:', JSON.stringify(queueItem.result).substring(0, 100));
            }
        }
    }

    console.log('\n\n=== SUMMARY OF FIXES NEEDED ===\n');
    console.log('1. Run this SQL in Supabase SQL Editor to create missing function:');
    console.log('   ' + createFunctionSQL.split('\n').slice(0, 3).join('\n   ') + '...');
    console.log('\n2. Ensure Postgres triggers are set up on orders table:');
    console.log('   SELECT setup_event_trigger(\'orders\', \'ALL\');');
    console.log('\n3. Set up queue processing (one of these):');
    console.log('   a) Enable pg_cron and run: SELECT cron.schedule(\'process-queue\', \'*/10 * * * * *\', $$SELECT process_trigger_queue(20)$$);');
    console.log('   b) Create Supabase Edge Function with cron trigger');
    console.log('   c) Call process_trigger_queue from your server every 10 seconds');

    console.log('\n=== Done ===\n');
}

fixAndAudit().catch(console.error);
