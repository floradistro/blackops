-- Add rpc_function and edge_function columns to ai_tool_registry
-- These columns specify which backend function to call for each MCP server

ALTER TABLE ai_tool_registry
ADD COLUMN IF NOT EXISTS rpc_function text,
ADD COLUMN IF NOT EXISTS edge_function text,
ADD COLUMN IF NOT EXISTS tool_mode text,
ADD COLUMN IF NOT EXISTS requires_user_id boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS requires_store_id boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_read_only boolean DEFAULT false;

-- Add check constraint to ensure at least one execution method is specified
ALTER TABLE ai_tool_registry
ADD CONSTRAINT execution_method_required
CHECK (rpc_function IS NOT NULL OR edge_function IS NOT NULL);

-- Update existing tools with their RPC functions
-- (these can be updated based on your actual tool implementations)
UPDATE ai_tool_registry SET rpc_function = name || '_query' WHERE rpc_function IS NULL AND edge_function IS NULL;

COMMENT ON COLUMN ai_tool_registry.rpc_function IS 'Name of the Supabase RPC function to call for this tool';
COMMENT ON COLUMN ai_tool_registry.edge_function IS 'Name of the Supabase Edge Function to call for this tool';
COMMENT ON COLUMN ai_tool_registry.tool_mode IS 'Tool mode: ops, analytics, browser, etc.';
