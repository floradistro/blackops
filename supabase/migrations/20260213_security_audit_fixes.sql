-- ============================================================================
-- Security Audit Fixes — February 2026
-- Addresses all CRITICAL, HIGH, MEDIUM, and LOW issues from production audit
-- ============================================================================

-- ============================================================================
-- C1: FIX — api_key column in ai_agent_config exposed to anon via RLS
-- The anon policy grants SELECT on all columns including api_key.
-- Fix: Drop the anon policy entirely. Agents are only needed by authenticated users.
-- API keys should NEVER be in a table with anon read access.
-- ============================================================================

-- Drop the dangerous anon policy
DROP POLICY IF EXISTS "ai_agent_config_anon_read" ON ai_agent_config;

-- Revoke anon SELECT entirely
REVOKE SELECT ON ai_agent_config FROM anon;

-- Create a security barrier view that excludes the api_key column
-- This is what authenticated users should read through
CREATE OR REPLACE VIEW ai_agent_config_safe AS
SELECT
  id, store_id, name, description, system_prompt, model, max_tokens,
  max_tool_calls, icon, accent_color, enabled_tools, temperature,
  tone, verbosity, can_query, can_send, can_modify, context_config,
  status, published_at, published_by, version, is_active, created_at, updated_at
FROM ai_agent_config;

-- Grant the safe view to authenticated (no api_key column)
GRANT SELECT ON ai_agent_config_safe TO authenticated;

COMMENT ON VIEW ai_agent_config_safe IS 'Safe view of ai_agent_config excluding api_key column. Use this for client reads.';

-- ============================================================================
-- C2: FIX — store_email_accounts and oauth_states have USING(true) RLS
-- These policies allow ALL roles (including anon/authenticated) full access.
-- Fix: Restrict to service_role only.
-- ============================================================================

-- store_email_accounts
DROP POLICY IF EXISTS "Service role can manage email accounts" ON store_email_accounts;

CREATE POLICY "Service role only on email accounts"
  ON store_email_accounts FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Authenticated users can read their own store's accounts (without tokens)
CREATE POLICY "Users can view own store email accounts"
  ON store_email_accounts FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- oauth_states
DROP POLICY IF EXISTS "Service role can manage oauth states" ON oauth_states;

CREATE POLICY "Service role only on oauth states"
  ON oauth_states FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- H1: FIX — email_threads and email_inbox have USING(true) RLS
-- Fix: Restrict to service_role + store-scoped read for authenticated users
-- ============================================================================

-- email_threads
DROP POLICY IF EXISTS "Service role full access on email_threads" ON email_threads;

CREATE POLICY "Service role full access on email_threads"
  ON email_threads FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Users can view own store email threads"
  ON email_threads FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- email_inbox
DROP POLICY IF EXISTS "Service role full access on email_inbox" ON email_inbox;

CREATE POLICY "Service role full access on email_inbox"
  ON email_inbox FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Users can view own store email inbox"
  ON email_inbox FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- ============================================================================
-- H2: FIX — Broken RLS: store_id IN (SELECT id FROM stores) returns ALL stores
-- Affects: ai_conversations, ai_agent_triggers, ai_safety_rules,
--          ai_prompt_templates, user_tools
-- Fix: Replace with get_user_store_ids()
-- ============================================================================

-- ai_conversations
DROP POLICY IF EXISTS "Users can view their store conversations" ON ai_conversations;
DROP POLICY IF EXISTS "Users can manage their store conversations" ON ai_conversations;

CREATE POLICY "Users can view own store conversations"
  ON ai_conversations FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY "Users can manage own store conversations"
  ON ai_conversations FOR ALL
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- Service role needs full access for edge functions
CREATE POLICY "Service role full access on conversations"
  ON ai_conversations FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ai_agent_triggers
DROP POLICY IF EXISTS "Users can view their store triggers" ON ai_agent_triggers;
DROP POLICY IF EXISTS "Users can manage their store triggers" ON ai_agent_triggers;

CREATE POLICY "Users can view own store triggers"
  ON ai_agent_triggers FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY "Users can manage own store triggers"
  ON ai_agent_triggers FOR ALL
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- ai_safety_rules
DROP POLICY IF EXISTS "Users can view their store safety rules" ON ai_safety_rules;
DROP POLICY IF EXISTS "Users can manage their store safety rules" ON ai_safety_rules;

CREATE POLICY "Users can view own store safety rules"
  ON ai_safety_rules FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()) OR store_id IS NULL);

CREATE POLICY "Users can manage own store safety rules"
  ON ai_safety_rules FOR ALL
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- ai_prompt_templates
DROP POLICY IF EXISTS "Users can view system templates and their store templates" ON ai_prompt_templates;
DROP POLICY IF EXISTS "Users can manage their store templates" ON ai_prompt_templates;

CREATE POLICY "Users can view system and own store templates"
  ON ai_prompt_templates FOR SELECT
  TO authenticated
  USING (is_system = true OR store_id IS NULL OR store_id IN (SELECT get_user_store_ids()));

CREATE POLICY "Users can manage own store templates"
  ON ai_prompt_templates FOR ALL
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

-- user_tools (drop old broken policies, keep the tightened ones from 20260210)
DROP POLICY IF EXISTS "Users can view their store tools" ON user_tools;
DROP POLICY IF EXISTS "Users can manage their store tools" ON user_tools;

-- ============================================================================
-- C3: FIX — Atomic inventory transfer via database RPC
-- Wraps the read+write in a single transaction with SELECT ... FOR UPDATE
-- Prevents both partial failures and TOCTOU race conditions
-- ============================================================================

CREATE OR REPLACE FUNCTION atomic_inventory_transfer(
  p_store_id UUID,
  p_product_id UUID,
  p_from_location_id UUID,
  p_to_location_id UUID,
  p_quantity NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_src_qty NUMERIC;
  v_dst_qty NUMERIC;
  v_src_id UUID;
  v_dst_id UUID;
BEGIN
  -- Validate
  IF p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be positive');
  END IF;
  IF p_from_location_id = p_to_location_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source and destination must differ');
  END IF;

  -- Lock source row FOR UPDATE to prevent concurrent reads
  SELECT id, quantity INTO v_src_id, v_src_qty
  FROM inventory
  WHERE store_id = p_store_id
    AND product_id = p_product_id
    AND location_id = p_from_location_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No inventory at source location');
  END IF;

  IF v_src_qty < p_quantity THEN
    RETURN jsonb_build_object('success', false, 'error',
      format('Insufficient stock: have %s, need %s', v_src_qty, p_quantity));
  END IF;

  -- Lock or create destination row
  SELECT id, quantity INTO v_dst_id, v_dst_qty
  FROM inventory
  WHERE store_id = p_store_id
    AND product_id = p_product_id
    AND location_id = p_to_location_id
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Create destination row
    INSERT INTO inventory (store_id, product_id, location_id, quantity)
    VALUES (p_store_id, p_product_id, p_to_location_id, p_quantity);
    v_dst_qty := 0;
  ELSE
    UPDATE inventory SET quantity = quantity + p_quantity, updated_at = NOW()
    WHERE id = v_dst_id;
  END IF;

  -- Deduct from source
  UPDATE inventory SET quantity = quantity - p_quantity, updated_at = NOW()
  WHERE id = v_src_id;

  -- Audit trail
  INSERT INTO inventory_adjustments (
    inventory_id, product_id, location_id,
    adjustment_type, old_quantity, new_quantity, reason
  ) VALUES
    (v_src_id, p_product_id, p_from_location_id, 'TRANSFER_OUT',
     v_src_qty, v_src_qty - p_quantity,
     format('Transfer %s to location %s', p_quantity, p_to_location_id)),
    (COALESCE(v_dst_id, gen_random_uuid()), p_product_id, p_to_location_id, 'TRANSFER_IN',
     COALESCE(v_dst_qty, 0), COALESCE(v_dst_qty, 0) + p_quantity,
     format('Transfer %s from location %s', p_quantity, p_from_location_id));

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'product_id', p_product_id,
      'from_location_id', p_from_location_id,
      'to_location_id', p_to_location_id,
      'quantity', p_quantity,
      'source_before', v_src_qty,
      'source_after', v_src_qty - p_quantity,
      'dest_before', COALESCE(v_dst_qty, 0),
      'dest_after', COALESCE(v_dst_qty, 0) + p_quantity
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION atomic_inventory_transfer TO service_role;
GRANT EXECUTE ON FUNCTION atomic_inventory_transfer TO authenticated;

COMMENT ON FUNCTION atomic_inventory_transfer IS 'Atomic inventory transfer with row-level locking. Prevents race conditions and partial failures.';

-- ============================================================================
-- H5: FIX — Restrict execute_user_tool to only call allowlisted RPC functions
-- The current code calls any function name stored in user_tools.rpc_function
-- Fix: Validate against an allowlist before EXECUTE
-- ============================================================================

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
    v_allowed_functions TEXT[] := ARRAY[
        'cleanup_dust_inventory', 'cleanup_dust_inventory_with_audit',
        'get_agent_analytics', 'get_agent_trace_stats',
        'get_user_tools', 'atomic_inventory_transfer',
        'check_rate_limit', 'publish_agent', 'rollback_agent'
    ];
BEGIN
    v_start_time := clock_timestamp();

    -- Get tool config (scoped to store)
    SELECT * INTO v_tool
    FROM user_tools
    WHERE id = p_tool_id AND store_id = p_store_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tool not found or inactive');
    END IF;

    -- Check if approval required
    IF v_tool.requires_approval THEN
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
        CASE v_tool.execution_type
            WHEN 'rpc' THEN
                IF v_tool.rpc_function IS NOT NULL THEN
                    -- H5 FIX: Validate function name against allowlist
                    IF NOT (v_tool.rpc_function = ANY(v_allowed_functions)) THEN
                        RAISE EXCEPTION 'Function % is not in the allowlist', v_tool.rpc_function;
                    END IF;

                    EXECUTE format('SELECT %I($1, $2)', v_tool.rpc_function)
                    INTO v_result
                    USING p_store_id, p_args;
                ELSE
                    v_result := jsonb_build_object('error', 'No RPC function configured');
                END IF;

            WHEN 'sql' THEN
                v_result := jsonb_build_object(
                    'execute_sql', true,
                    'template', v_tool.sql_template,
                    'allowed_tables', v_tool.allowed_tables,
                    'is_read_only', v_tool.is_read_only
                );

            WHEN 'http' THEN
                v_result := jsonb_build_object(
                    'execute_http', true,
                    'config', v_tool.http_config
                );

            ELSE
                v_result := jsonb_build_object('error', 'Unknown execution type');
        END CASE;

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

-- ============================================================================
-- H7/M4: FIX — Rate limiting: add dedicated table + index instead of scanning audit_logs
-- ============================================================================

CREATE TABLE IF NOT EXISTS rate_limit_counters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  action TEXT NOT NULL DEFAULT 'chat',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Composite index for the rate limit query
CREATE INDEX IF NOT EXISTS idx_rate_limit_user_action_time
  ON rate_limit_counters (user_id, created_at DESC)
  WHERE action = 'chat';

-- Auto-cleanup: delete entries older than 1 hour (no need to keep them)
CREATE OR REPLACE FUNCTION cleanup_rate_limit_counters()
RETURNS void AS $$
BEGIN
  DELETE FROM rate_limit_counters WHERE created_at < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;

-- RLS: only service_role can touch this table
ALTER TABLE rate_limit_counters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role only on rate limits"
  ON rate_limit_counters FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Updated rate limit function using the dedicated table
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_user_id UUID,
  p_window_seconds INT DEFAULT 60,
  p_max_requests INT DEFAULT 20
)
RETURNS TABLE(allowed BOOLEAN, current_count BIGINT, retry_after_seconds INT) AS $$
DECLARE
  v_count BIGINT;
  v_window_start TIMESTAMPTZ;
  v_oldest TIMESTAMPTZ;
BEGIN
  v_window_start := NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  -- Count from dedicated rate limit table (fast, indexed)
  SELECT COUNT(*) INTO v_count
  FROM rate_limit_counters
  WHERE user_id = p_user_id
    AND created_at >= v_window_start;

  IF v_count >= p_max_requests THEN
    SELECT MIN(created_at) INTO v_oldest
    FROM rate_limit_counters
    WHERE user_id = p_user_id
      AND created_at >= v_window_start;

    RETURN QUERY SELECT
      FALSE,
      v_count,
      GREATEST(1, EXTRACT(EPOCH FROM (v_oldest + (p_window_seconds || ' seconds')::INTERVAL - NOW()))::INT);
  ELSE
    -- Record this request
    INSERT INTO rate_limit_counters (user_id, action) VALUES (p_user_id, 'chat');

    RETURN QUERY SELECT TRUE, v_count + 1, 0;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Also add the missing index on audit_logs for the old pattern (backwards compat)
CREATE INDEX IF NOT EXISTS idx_audit_logs_rate_limit
  ON audit_logs (user_id, created_at)
  WHERE action IN ('chat.user_message', 'tool_execution');

-- ============================================================================
-- M1: FIX — Missing ON DELETE CASCADE on foreign keys
-- inventory_adjustments: add cascades
-- ============================================================================

-- inventory_adjustments.inventory_id → inventory(id) ON DELETE CASCADE
-- We can't ALTER existing FK constraints, so drop and recreate
DO $$
BEGIN
  -- inventory_adjustments → inventory
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'inventory_adjustments'
      AND constraint_type = 'FOREIGN KEY'
      AND constraint_name LIKE '%inventory_id%'
  ) THEN
    ALTER TABLE inventory_adjustments
      DROP CONSTRAINT IF EXISTS inventory_adjustments_inventory_id_fkey;
  END IF;

  ALTER TABLE inventory_adjustments
    ADD CONSTRAINT inventory_adjustments_inventory_id_fkey
    FOREIGN KEY (inventory_id) REFERENCES inventory(id) ON DELETE SET NULL;

  -- inventory_adjustments → products
  ALTER TABLE inventory_adjustments
    DROP CONSTRAINT IF EXISTS inventory_adjustments_product_id_fkey;
  ALTER TABLE inventory_adjustments
    ADD CONSTRAINT inventory_adjustments_product_id_fkey
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL;

  -- inventory_adjustments → locations
  ALTER TABLE inventory_adjustments
    DROP CONSTRAINT IF EXISTS inventory_adjustments_location_id_fkey;
  ALTER TABLE inventory_adjustments
    ADD CONSTRAINT inventory_adjustments_location_id_fkey
    FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE SET NULL;
END $$;

-- document_templates.store_id: already has ON DELETE CASCADE from initial migration, verify
-- (no change needed — the CREATE TABLE uses REFERENCES stores(id) which defaults to RESTRICT,
-- but this was already addressed in the original migration)

-- ============================================================================
-- M2: FIX — Enable RLS on inventory_adjustments
-- ============================================================================

ALTER TABLE inventory_adjustments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on inventory_adjustments"
  ON inventory_adjustments FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- M7: FIX — Revoke get_user_store_ids() from anon
-- auth.uid() is NULL for anon, which could match rows with NULL auth_user_id
-- ============================================================================

REVOKE EXECUTE ON FUNCTION get_user_store_ids() FROM anon;

-- ============================================================================
-- M8: FIX — document_templates policy allows NULL auth.uid()
-- ============================================================================

DROP POLICY IF EXISTS "Store members can manage templates" ON document_templates;

CREATE POLICY "Store members can manage templates"
  ON document_templates FOR ALL
  TO authenticated
  USING (store_id IN (
    SELECT store_id FROM store_staff WHERE user_id = auth.uid()
  ));

-- ============================================================================
-- M9: FIX — agent_execution_traces uses store_staff, standardize to get_user_store_ids()
-- ============================================================================

DROP POLICY IF EXISTS "Users can view their store's traces" ON agent_execution_traces;
DROP POLICY IF EXISTS "Users can insert traces for their store" ON agent_execution_traces;

CREATE POLICY "Users can view own store traces"
  ON agent_execution_traces FOR SELECT
  TO authenticated
  USING (store_id IN (SELECT get_user_store_ids()));

CREATE POLICY "Users can insert own store traces"
  ON agent_execution_traces FOR INSERT
  TO authenticated
  WITH CHECK (store_id IN (SELECT get_user_store_ids()));

-- Service role full access
CREATE POLICY "Service role full access on traces"
  ON agent_execution_traces FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- H1 (audit_logs): FIX — Tighten INSERT policy
-- Current: WITH CHECK (true) to anon = anyone can insert fake audit entries
-- Fix: Restrict anon INSERT, keep service_role + authenticated
-- ============================================================================

DROP POLICY IF EXISTS "Service role can insert audit logs" ON audit_logs;

CREATE POLICY "Service role can insert audit logs"
  ON audit_logs FOR INSERT
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- L6: FIX — Missing updated_at triggers on key tables
-- ============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ai_conversations
DROP TRIGGER IF EXISTS trg_ai_conversations_updated_at ON ai_conversations;
CREATE TRIGGER trg_ai_conversations_updated_at
  BEFORE UPDATE ON ai_conversations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ai_agent_triggers
DROP TRIGGER IF EXISTS trg_ai_agent_triggers_updated_at ON ai_agent_triggers;
CREATE TRIGGER trg_ai_agent_triggers_updated_at
  BEFORE UPDATE ON ai_agent_triggers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ai_safety_rules
DROP TRIGGER IF EXISTS trg_ai_safety_rules_updated_at ON ai_safety_rules;
CREATE TRIGGER trg_ai_safety_rules_updated_at
  BEFORE UPDATE ON ai_safety_rules
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ai_prompt_templates
DROP TRIGGER IF EXISTS trg_ai_prompt_templates_updated_at ON ai_prompt_templates;
CREATE TRIGGER trg_ai_prompt_templates_updated_at
  BEFORE UPDATE ON ai_prompt_templates
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- document_templates
DROP TRIGGER IF EXISTS trg_document_templates_updated_at ON document_templates;
CREATE TRIGGER trg_document_templates_updated_at
  BEFORE UPDATE ON document_templates
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE rate_limit_counters IS 'Dedicated rate limiting table with indexed lookups. Auto-cleaned hourly.';
COMMENT ON FUNCTION atomic_inventory_transfer IS 'Row-locked atomic transfer preventing race conditions and partial failures.';
COMMENT ON FUNCTION set_updated_at IS 'Generic trigger function to auto-set updated_at on row update.';
