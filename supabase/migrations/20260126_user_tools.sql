-- Migration: User-Created Custom Tools
-- Allows users to create their own tools that the AI agent can use
-- Execution types: rpc (call existing function), http (call external API), sql (run sandboxed query)

-- ============================================================================
-- 1. USER TOOLS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_tools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,

    -- Tool identity
    name VARCHAR(100) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(100) DEFAULT 'custom',
    icon VARCHAR(50) DEFAULT 'wrench.fill', -- SF Symbol name

    -- Tool definition (MCP-compatible schema)
    input_schema JSONB NOT NULL DEFAULT '{
        "type": "object",
        "properties": {},
        "required": []
    }',

    -- Execution configuration
    execution_type VARCHAR(20) NOT NULL CHECK (execution_type IN ('rpc', 'http', 'sql')),

    -- For RPC: name of the Postgres function to call
    rpc_function VARCHAR(255),

    -- For HTTP: endpoint configuration
    http_config JSONB DEFAULT NULL,
    -- Example: {
    --   "url": "https://api.example.com/endpoint",
    --   "method": "POST",
    --   "headers": {"Authorization": "Bearer {{secret:api_key}}"},
    --   "body_template": {"sku": "{{sku}}", "quantity": "{{quantity}}"}
    -- }

    -- For SQL: parameterized query template (SAFE - parameters are bound, not interpolated)
    sql_template TEXT,
    -- Example: SELECT * FROM products WHERE store_id = $store_id AND sku = $sku

    -- Permissions & Safety
    allowed_tables TEXT[] DEFAULT '{}', -- For SQL type: which tables can be accessed
    is_read_only BOOLEAN DEFAULT true,
    requires_approval BOOLEAN DEFAULT false, -- If true, requires human approval before execution
    max_execution_time_ms INTEGER DEFAULT 5000, -- Timeout

    -- Status
    is_active BOOLEAN DEFAULT true,
    is_tested BOOLEAN DEFAULT false, -- Has the user tested this tool?
    test_result JSONB, -- Last test result

    -- Audit
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    -- Unique tool name per store
    UNIQUE(store_id, name)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_tools_store ON user_tools(store_id);
CREATE INDEX IF NOT EXISTS idx_user_tools_active ON user_tools(store_id, is_active);
CREATE INDEX IF NOT EXISTS idx_user_tools_category ON user_tools(category);

-- ============================================================================
-- 2. USER TOOL SECRETS (for HTTP tools that need API keys)
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_tool_secrets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    tool_id UUID REFERENCES user_tools(id) ON DELETE CASCADE,

    name VARCHAR(100) NOT NULL, -- e.g., "api_key", "webhook_secret"
    encrypted_value TEXT NOT NULL, -- Encrypted with pgcrypto

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(store_id, name)
);

CREATE INDEX IF NOT EXISTS idx_user_tool_secrets_store ON user_tool_secrets(store_id);

-- ============================================================================
-- 3. USER TOOL EXECUTION LOG
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_tool_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tool_id UUID NOT NULL REFERENCES user_tools(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,

    -- Execution context
    agent_id UUID REFERENCES ai_agent_config(id),
    conversation_id UUID,

    -- Input/Output
    input_args JSONB NOT NULL,
    output_result JSONB,

    -- Status
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'running', 'success', 'error', 'timeout', 'rejected')),
    error_message TEXT,
    execution_time_ms INTEGER,

    -- Approval (if requires_approval = true)
    approved_by UUID,
    approved_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_tool_executions_tool ON user_tool_executions(tool_id);
CREATE INDEX IF NOT EXISTS idx_user_tool_executions_store ON user_tool_executions(store_id);
CREATE INDEX IF NOT EXISTS idx_user_tool_executions_created ON user_tool_executions(created_at DESC);

-- ============================================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE user_tools ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_tool_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_tool_executions ENABLE ROW LEVEL SECURITY;

-- Users can only see their store's tools
CREATE POLICY "Users can view their store tools" ON user_tools
    FOR SELECT USING (store_id IN (SELECT id FROM stores));

CREATE POLICY "Users can manage their store tools" ON user_tools
    FOR ALL USING (store_id IN (SELECT id FROM stores));

-- Secrets - only accessible via RPC (not direct select)
CREATE POLICY "Secrets are not directly readable" ON user_tool_secrets
    FOR SELECT USING (false); -- Block all direct reads

CREATE POLICY "Users can manage their store secrets" ON user_tool_secrets
    FOR INSERT WITH CHECK (store_id IN (SELECT id FROM stores));

CREATE POLICY "Users can delete their store secrets" ON user_tool_secrets
    FOR DELETE USING (store_id IN (SELECT id FROM stores));

-- Executions
CREATE POLICY "Users can view their store executions" ON user_tool_executions
    FOR SELECT USING (store_id IN (SELECT id FROM stores));

-- ============================================================================
-- 5. HELPER FUNCTIONS
-- ============================================================================

-- Execute a user tool (called by the agent server)
CREATE OR REPLACE FUNCTION execute_user_tool(
    p_tool_id UUID,
    p_store_id UUID,
    p_args JSONB,
    p_agent_id UUID DEFAULT NULL,
    p_conversation_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tool user_tools%ROWTYPE;
    v_result JSONB;
    v_start_time TIMESTAMPTZ;
    v_execution_id UUID;
    v_error TEXT;
BEGIN
    v_start_time := clock_timestamp();

    -- Get tool config
    SELECT * INTO v_tool
    FROM user_tools
    WHERE id = p_tool_id AND store_id = p_store_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tool not found or inactive');
    END IF;

    -- Check if approval required
    IF v_tool.requires_approval THEN
        -- Create pending execution for approval
        INSERT INTO user_tool_executions (tool_id, store_id, agent_id, conversation_id, input_args, status)
        VALUES (p_tool_id, p_store_id, p_agent_id, p_conversation_id, p_args, 'pending')
        RETURNING id INTO v_execution_id;

        RETURN jsonb_build_object(
            'success', false,
            'pending_approval', true,
            'execution_id', v_execution_id,
            'message', 'This tool requires human approval before execution'
        );
    END IF;

    -- Create execution record
    INSERT INTO user_tool_executions (tool_id, store_id, agent_id, conversation_id, input_args, status)
    VALUES (p_tool_id, p_store_id, p_agent_id, p_conversation_id, p_args, 'running')
    RETURNING id INTO v_execution_id;

    BEGIN
        -- Execute based on type
        CASE v_tool.execution_type
            WHEN 'rpc' THEN
                -- Call the RPC function
                IF v_tool.rpc_function IS NOT NULL THEN
                    EXECUTE format('SELECT %I($1, $2)', v_tool.rpc_function)
                    INTO v_result
                    USING p_store_id, p_args;
                ELSE
                    v_result := jsonb_build_object('error', 'No RPC function configured');
                END IF;

            WHEN 'sql' THEN
                -- Execute parameterized SQL (handled by agent-server for safety)
                v_result := jsonb_build_object(
                    'execute_sql', true,
                    'template', v_tool.sql_template,
                    'allowed_tables', v_tool.allowed_tables,
                    'is_read_only', v_tool.is_read_only
                );

            WHEN 'http' THEN
                -- HTTP calls are handled by the agent-server
                v_result := jsonb_build_object(
                    'execute_http', true,
                    'config', v_tool.http_config
                );

            ELSE
                v_result := jsonb_build_object('error', 'Unknown execution type');
        END CASE;

        -- Update execution record
        UPDATE user_tool_executions
        SET status = 'success',
            output_result = v_result,
            execution_time_ms = EXTRACT(MILLISECONDS FROM (clock_timestamp() - v_start_time))::INTEGER
        WHERE id = v_execution_id;

        RETURN jsonb_build_object('success', true, 'data', v_result);

    EXCEPTION WHEN OTHERS THEN
        v_error := SQLERRM;

        UPDATE user_tool_executions
        SET status = 'error',
            error_message = v_error,
            execution_time_ms = EXTRACT(MILLISECONDS FROM (clock_timestamp() - v_start_time))::INTEGER
        WHERE id = v_execution_id;

        RETURN jsonb_build_object('success', false, 'error', v_error);
    END;
END;
$$;

-- Get user tools for a store (returns MCP-compatible format)
CREATE OR REPLACE FUNCTION get_user_tools(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', id,
                'name', name,
                'display_name', display_name,
                'description', description,
                'category', category,
                'icon', icon,
                'input_schema', input_schema,
                'execution_type', execution_type,
                'is_read_only', is_read_only,
                'requires_approval', requires_approval
            )
        ), '[]'::jsonb)
        FROM user_tools
        WHERE store_id = p_store_id AND is_active = true
    );
END;
$$;

-- ============================================================================
-- 6. EXAMPLE USER TOOLS (commented out - for reference)
-- ============================================================================

-- Example: Check external inventory API
-- INSERT INTO user_tools (store_id, name, display_name, description, execution_type, http_config, input_schema)
-- VALUES (
--     'your-store-id',
--     'check_shopify_inventory',
--     'Check Shopify Inventory',
--     'Check current stock level for a product in Shopify',
--     'http',
--     '{
--         "url": "https://{{shop}}.myshopify.com/admin/api/2024-01/inventory_levels.json",
--         "method": "GET",
--         "headers": {"X-Shopify-Access-Token": "{{secret:shopify_token}}"},
--         "query_params": {"inventory_item_ids": "{{inventory_item_id}}"}
--     }',
--     '{
--         "type": "object",
--         "properties": {
--             "inventory_item_id": {"type": "string", "description": "Shopify inventory item ID"}
--         },
--         "required": ["inventory_item_id"]
--     }'
-- );

-- Example: Custom SQL query
-- INSERT INTO user_tools (store_id, name, display_name, description, execution_type, sql_template, allowed_tables, is_read_only, input_schema)
-- VALUES (
--     'your-store-id',
--     'low_stock_report',
--     'Low Stock Report',
--     'Get products with stock below threshold',
--     'sql',
--     'SELECT name, sku, stock_quantity FROM products WHERE store_id = $store_id AND stock_quantity < $threshold ORDER BY stock_quantity ASC LIMIT 50',
--     ARRAY['products'],
--     true,
--     '{
--         "type": "object",
--         "properties": {
--             "threshold": {"type": "integer", "description": "Stock threshold", "default": 10}
--         },
--         "required": []
--     }'
-- );
