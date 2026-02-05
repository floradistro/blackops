// Test User Tools & Triggers System
// Run with: node test_user_tools.js

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://uaednwpxursknmwdeejn.supabase.co';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function runTests() {
    console.log('=== User Tools & Triggers Test Suite ===\n');

    // Test 1: Check if tables exist
    console.log('1. Checking if tables exist...');
    try {
        const { data: tools, error: toolsErr } = await supabase
            .from('user_tools')
            .select('id')
            .limit(1);

        if (toolsErr) {
            console.log('   ERROR: user_tools table not found or not accessible');
            console.log('   Details:', toolsErr.message);
            console.log('\n   You need to run the migrations first:');
            console.log('   - supabase/migrations/20260126_user_tools.sql');
            console.log('   - supabase/migrations/20260126_user_triggers.sql');
            return;
        }
        console.log('   user_tools table: OK');

        const { data: triggers, error: triggersErr } = await supabase
            .from('user_triggers')
            .select('id')
            .limit(1);

        if (triggersErr) {
            console.log('   ERROR: user_triggers table not found');
            console.log('   Details:', triggersErr.message);
            return;
        }
        console.log('   user_triggers table: OK');
    } catch (err) {
        console.log('   ERROR:', err.message);
        return;
    }

    // Test 2: Create a test RPC tool
    console.log('\n2. Creating a test RPC tool...');
    let testToolId;
    try {
        const { data: tool, error } = await supabase
            .from('user_tools')
            .insert({
                store_id: STORE_ID,
                name: 'test_order_count',
                display_name: 'Test Order Count',
                description: 'Test tool that counts orders',
                category: 'test',
                icon: 'number.circle',
                execution_type: 'rpc',
                rpc_function: 'count_store_orders', // We'll create this
                input_schema: {
                    type: 'object',
                    properties: {
                        status: {
                            type: 'string',
                            description: 'Filter by status'
                        }
                    },
                    required: []
                },
                is_read_only: true,
                requires_approval: false,
                is_active: true
            })
            .select()
            .single();

        if (error) {
            if (error.code === '23505') {
                console.log('   Tool already exists, fetching...');
                const { data: existingTool } = await supabase
                    .from('user_tools')
                    .select()
                    .eq('store_id', STORE_ID)
                    .eq('name', 'test_order_count')
                    .single();
                testToolId = existingTool?.id;
            } else {
                throw error;
            }
        } else {
            testToolId = tool.id;
            console.log('   Created tool:', tool.id);
        }
    } catch (err) {
        console.log('   ERROR:', err.message);
    }

    // Test 3: Create a test SQL tool
    console.log('\n3. Creating a test SQL tool...');
    let sqlToolId;
    try {
        const { data: sqlTool, error } = await supabase
            .from('user_tools')
            .insert({
                store_id: STORE_ID,
                name: 'low_stock_products',
                display_name: 'Low Stock Products',
                description: 'Get products with low stock',
                category: 'inventory',
                icon: 'exclamationmark.triangle',
                execution_type: 'sql',
                sql_template: 'SELECT id, name, sku FROM products WHERE store_id = $store_id LIMIT 10',
                allowed_tables: ['products'],
                is_read_only: true,
                requires_approval: false,
                is_active: true,
                input_schema: {
                    type: 'object',
                    properties: {},
                    required: []
                }
            })
            .select()
            .single();

        if (error) {
            if (error.code === '23505') {
                console.log('   Tool already exists, fetching...');
                const { data: existingTool } = await supabase
                    .from('user_tools')
                    .select()
                    .eq('store_id', STORE_ID)
                    .eq('name', 'low_stock_products')
                    .single();
                sqlToolId = existingTool?.id;
            } else {
                throw error;
            }
        } else {
            sqlToolId = sqlTool.id;
            console.log('   Created SQL tool:', sqlTool.id);
        }
    } catch (err) {
        console.log('   ERROR:', err.message);
    }

    // Test 4: List all tools for the store
    console.log('\n4. Listing all tools for store...');
    try {
        const { data: tools, error } = await supabase
            .from('user_tools')
            .select('id, name, display_name, execution_type, is_active')
            .eq('store_id', STORE_ID);

        if (error) throw error;
        console.log(`   Found ${tools.length} tools:`);
        tools.forEach(t => {
            console.log(`   - ${t.display_name} (${t.execution_type}) ${t.is_active ? '' : '[inactive]'}`);
        });
    } catch (err) {
        console.log('   ERROR:', err.message);
    }

    // Test 5: Test get_user_tools RPC
    console.log('\n5. Testing get_user_tools RPC...');
    try {
        const { data, error } = await supabase
            .rpc('get_user_tools', { p_store_id: STORE_ID });

        if (error) throw error;
        console.log(`   RPC returned ${data?.length || 0} tools`);
        if (data && data.length > 0) {
            console.log('   First tool schema:', JSON.stringify(data[0], null, 2).substring(0, 200) + '...');
        }
    } catch (err) {
        console.log('   ERROR:', err.message);
        console.log('   (RPC might not exist yet - run migration)');
    }

    // Test 6: Create a trigger (if we have a tool)
    if (testToolId || sqlToolId) {
        console.log('\n6. Creating a test trigger...');
        const toolId = testToolId || sqlToolId;
        try {
            const { data: trigger, error } = await supabase
                .from('user_triggers')
                .insert({
                    store_id: STORE_ID,
                    name: 'test_order_trigger',
                    description: 'Test trigger for orders',
                    trigger_type: 'event',
                    event_table: 'orders',
                    event_operation: 'INSERT',
                    tool_id: toolId,
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

            if (error) {
                if (error.code === '23505') {
                    console.log('   Trigger already exists');
                } else {
                    throw error;
                }
            } else {
                console.log('   Created trigger:', trigger.id);
            }
        } catch (err) {
            console.log('   ERROR:', err.message);
        }
    }

    // Test 7: List triggers
    console.log('\n7. Listing triggers for store...');
    try {
        const { data: triggers, error } = await supabase
            .from('user_triggers')
            .select('id, name, trigger_type, event_table, event_operation, is_active')
            .eq('store_id', STORE_ID);

        if (error) throw error;
        console.log(`   Found ${triggers.length} triggers:`);
        triggers.forEach(t => {
            console.log(`   - ${t.name} (${t.trigger_type}: ${t.event_table}/${t.event_operation}) ${t.is_active ? '' : '[inactive]'}`);
        });
    } catch (err) {
        console.log('   ERROR:', err.message);
    }

    // Test 8: Test tool execution (if execute_user_tool exists)
    if (sqlToolId) {
        console.log('\n8. Testing tool execution...');
        try {
            const { data, error } = await supabase
                .rpc('execute_user_tool', {
                    p_tool_id: sqlToolId,
                    p_store_id: STORE_ID,
                    p_args: {}
                });

            if (error) throw error;
            console.log('   Execution result:', JSON.stringify(data, null, 2));
        } catch (err) {
            console.log('   ERROR:', err.message);
            console.log('   (execute_user_tool RPC might not exist - run migration)');
        }
    }

    // Test 9: Check execution log
    console.log('\n9. Checking execution log...');
    try {
        const { data: logs, error } = await supabase
            .from('user_tool_executions')
            .select('id, tool_id, status, created_at')
            .eq('store_id', STORE_ID)
            .order('created_at', { ascending: false })
            .limit(5);

        if (error) throw error;
        console.log(`   Found ${logs.length} execution logs`);
        logs.forEach(l => {
            console.log(`   - ${l.id}: ${l.status} at ${l.created_at}`);
        });
    } catch (err) {
        console.log('   ERROR:', err.message);
    }

    console.log('\n=== Tests Complete ===\n');
}

runTests().catch(console.error);
