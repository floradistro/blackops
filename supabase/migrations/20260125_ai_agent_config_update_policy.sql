-- Migration: Add UPDATE, INSERT, DELETE policies for ai_agent_config
-- Allows store owners to manage their AI agents

-- Drop existing policies if any (for clean slate)
DROP POLICY IF EXISTS "ai_agent_config_update_policy" ON ai_agent_config;
DROP POLICY IF EXISTS "ai_agent_config_insert_policy" ON ai_agent_config;
DROP POLICY IF EXISTS "ai_agent_config_delete_policy" ON ai_agent_config;

-- Create policy: Users can update agents for their stores
CREATE POLICY "ai_agent_config_update_policy" ON ai_agent_config
    FOR UPDATE
    TO authenticated
    USING (
        store_id IN (SELECT get_user_store_ids())
    )
    WITH CHECK (
        store_id IN (SELECT get_user_store_ids())
    );

-- Create policy: Users can insert agents for their stores
CREATE POLICY "ai_agent_config_insert_policy" ON ai_agent_config
    FOR INSERT
    TO authenticated
    WITH CHECK (
        store_id IN (SELECT get_user_store_ids())
    );

-- Create policy: Users can delete agents for their stores
CREATE POLICY "ai_agent_config_delete_policy" ON ai_agent_config
    FOR DELETE
    TO authenticated
    USING (
        store_id IN (SELECT get_user_store_ids())
    );

-- Grant necessary permissions
GRANT UPDATE, INSERT, DELETE ON ai_agent_config TO authenticated;
