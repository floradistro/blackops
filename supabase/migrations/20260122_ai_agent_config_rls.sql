-- Migration: Enable RLS and create policies for ai_agent_config table
-- This allows authenticated users to read AI agents for their stores

-- Enable RLS on the table (if not already enabled)
ALTER TABLE ai_agent_config ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (to ensure clean slate)
DROP POLICY IF EXISTS "ai_agent_config_select_policy" ON ai_agent_config;
DROP POLICY IF EXISTS "ai_agent_config_read_active" ON ai_agent_config;
DROP POLICY IF EXISTS "ai_agent_config_anon_read" ON ai_agent_config;
DROP POLICY IF EXISTS "ai_agent_config_select_via_store" ON ai_agent_config;

-- Create policy: Authenticated users can read active agents for their stores
-- Uses the existing get_user_store_ids() helper function
CREATE POLICY "ai_agent_config_select_via_store" ON ai_agent_config
    FOR SELECT
    TO authenticated
    USING (
        is_active = true
        AND (
            store_id IS NULL  -- Global agents (available to all)
            OR store_id IN (SELECT get_user_store_ids())  -- Store-specific agents
        )
    );

-- Create policy: Allow anon users to read active agents
-- Agents are not sensitive data - they're publicly visible AI assistants
CREATE POLICY "ai_agent_config_anon_read" ON ai_agent_config
    FOR SELECT
    TO anon
    USING (is_active = true);

-- Grant necessary permissions
GRANT SELECT ON ai_agent_config TO authenticated;
GRANT SELECT ON ai_agent_config TO anon;
