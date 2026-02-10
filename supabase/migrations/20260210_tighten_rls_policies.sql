-- Tighten RLS policies for client-side access (no more service role key in client)
-- All queries now go through the authenticated client, so RLS must allow proper access.

-- ============================================================================
-- audit_logs: allow authenticated users to SELECT their store's logs
-- ============================================================================

-- Allow authenticated users to read audit logs for their stores
CREATE POLICY IF NOT EXISTS "Users can read own store audit logs"
  ON audit_logs FOR SELECT
  TO authenticated
  USING (
    store_id IS NULL
    OR store_id IN (SELECT get_user_store_ids())
  );

-- Allow authenticated users to insert audit logs (for telemetry)
CREATE POLICY IF NOT EXISTS "Users can insert audit logs"
  ON audit_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ============================================================================
-- ai_agent_config: allow authenticated users to manage their store's agents
-- ============================================================================

CREATE POLICY IF NOT EXISTS "Users can read own store agents"
  ON ai_agent_config FOR SELECT
  TO authenticated
  USING (
    store_id IS NULL
    OR store_id IN (SELECT get_user_store_ids())
  );

CREATE POLICY IF NOT EXISTS "Users can insert own store agents"
  ON ai_agent_config FOR INSERT
  TO authenticated
  WITH CHECK (
    store_id IN (SELECT get_user_store_ids())
  );

CREATE POLICY IF NOT EXISTS "Users can update own store agents"
  ON ai_agent_config FOR UPDATE
  TO authenticated
  USING (
    store_id IN (SELECT get_user_store_ids())
  );

CREATE POLICY IF NOT EXISTS "Users can delete own store agents"
  ON ai_agent_config FOR DELETE
  TO authenticated
  USING (
    store_id IN (SELECT get_user_store_ids())
  );

-- ============================================================================
-- user_tools: allow authenticated users to manage their store's tools
-- ============================================================================

CREATE POLICY IF NOT EXISTS "Users can read own store tools"
  ON user_tools FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY IF NOT EXISTS "Users can insert own store tools"
  ON user_tools FOR INSERT
  TO authenticated
  WITH CHECK (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY IF NOT EXISTS "Users can update own store tools"
  ON user_tools FOR UPDATE
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY IF NOT EXISTS "Users can delete own store tools"
  ON user_tools FOR DELETE
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- ============================================================================
-- user_tool_secrets: allow authenticated users to manage their store's secrets
-- ============================================================================

CREATE POLICY IF NOT EXISTS "Users can read own store secrets"
  ON user_tool_secrets FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY IF NOT EXISTS "Users can insert own store secrets"
  ON user_tool_secrets FOR INSERT
  TO authenticated
  WITH CHECK (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY IF NOT EXISTS "Users can delete own store secrets"
  ON user_tool_secrets FOR DELETE
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- ============================================================================
-- user_triggers: allow authenticated users to manage their store's triggers
-- ============================================================================

CREATE POLICY IF NOT EXISTS "Users can read own store triggers"
  ON user_triggers FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY IF NOT EXISTS "Users can insert own store triggers"
  ON user_triggers FOR INSERT
  TO authenticated
  WITH CHECK (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY IF NOT EXISTS "Users can update own store triggers"
  ON user_triggers FOR UPDATE
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY IF NOT EXISTS "Users can delete own store triggers"
  ON user_triggers FOR DELETE
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));
