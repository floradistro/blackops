-- Migration: User Triggers with Retry Queue System
-- Automated triggers for user tools with built-in retry and queue support

-- ============================================================================
-- 1. USER TRIGGERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_triggers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,

    -- Trigger identity
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,

    -- Trigger type: event, schedule, condition
    trigger_type VARCHAR(20) NOT NULL CHECK (trigger_type IN ('event', 'schedule', 'condition')),

    -- For event triggers: which table/event to watch
    event_table VARCHAR(100),      -- e.g., 'orders', 'customers'
    event_operation VARCHAR(20),   -- 'INSERT', 'UPDATE', 'DELETE'
    event_filter JSONB,            -- Optional filter: {"status": "paid"}

    -- For schedule triggers: cron expression
    cron_expression VARCHAR(100),  -- e.g., '0 9 * * *' (daily at 9am)
    timezone VARCHAR(50) DEFAULT 'UTC',

    -- For condition triggers: SQL that returns true/false
    condition_sql TEXT,            -- e.g., 'SELECT COUNT(*) > 10 FROM orders WHERE status = ''pending'''
    condition_check_interval INTEGER DEFAULT 300, -- Check every N seconds

    -- What to execute
    tool_id UUID REFERENCES user_tools(id) ON DELETE CASCADE,
    tool_args_template JSONB,      -- Args with {{variable}} placeholders

    -- Retry configuration
    max_retries INTEGER DEFAULT 3,
    retry_delay_seconds INTEGER DEFAULT 60,        -- Base delay (doubles each retry)
    retry_backoff_multiplier NUMERIC DEFAULT 2.0,  -- Exponential backoff
    timeout_seconds INTEGER DEFAULT 30,

    -- Rate limiting
    max_executions_per_hour INTEGER DEFAULT 100,
    cooldown_seconds INTEGER DEFAULT 0,            -- Min time between executions

    -- Audit
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_triggered_at TIMESTAMPTZ,

    UNIQUE(store_id, name)
);

CREATE INDEX IF NOT EXISTS idx_user_triggers_store ON user_triggers(store_id);
CREATE INDEX IF NOT EXISTS idx_user_triggers_active ON user_triggers(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_user_triggers_type ON user_triggers(trigger_type);
CREATE INDEX IF NOT EXISTS idx_user_triggers_event ON user_triggers(event_table, event_operation) WHERE trigger_type = 'event';

-- ============================================================================
-- 2. TRIGGER EXECUTION QUEUE
-- ============================================================================

CREATE TABLE IF NOT EXISTS trigger_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trigger_id UUID NOT NULL REFERENCES user_triggers(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,

    -- Execution context
    event_payload JSONB,           -- The triggering event data (for event triggers)
    resolved_args JSONB,           -- Tool args with variables replaced

    -- Queue status
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'success', 'failed', 'dead')),
    priority INTEGER DEFAULT 0,    -- Higher = more urgent

    -- Retry tracking
    attempt_count INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    next_attempt_at TIMESTAMPTZ DEFAULT now(),
    last_error TEXT,

    -- Timing
    created_at TIMESTAMPTZ DEFAULT now(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    execution_time_ms INTEGER,

    -- Result
    result JSONB
);

CREATE INDEX IF NOT EXISTS idx_trigger_queue_pending ON trigger_queue(next_attempt_at)
    WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_trigger_queue_store ON trigger_queue(store_id, status);
CREATE INDEX IF NOT EXISTS idx_trigger_queue_trigger ON trigger_queue(trigger_id);

-- ============================================================================
-- 3. DEAD LETTER QUEUE (failed after all retries)
-- ============================================================================

CREATE TABLE IF NOT EXISTS trigger_dead_letter (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_queue_id UUID NOT NULL,
    trigger_id UUID REFERENCES user_triggers(id) ON DELETE SET NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,

    -- Original execution data
    event_payload JSONB,
    resolved_args JSONB,

    -- Failure info
    attempt_count INTEGER,
    errors JSONB,                  -- Array of all error messages
    final_error TEXT,

    -- For manual retry
    can_retry BOOLEAN DEFAULT true,
    retried_at TIMESTAMPTZ,
    retried_by UUID,

    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trigger_dlq_store ON trigger_dead_letter(store_id);
CREATE INDEX IF NOT EXISTS idx_trigger_dlq_retry ON trigger_dead_letter(can_retry) WHERE can_retry = true;

-- ============================================================================
-- 4. TRIGGER EXECUTION STATS (for rate limiting)
-- ============================================================================

CREATE TABLE IF NOT EXISTS trigger_execution_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trigger_id UUID NOT NULL REFERENCES user_triggers(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,

    -- Hourly bucket for rate limiting
    hour_bucket TIMESTAMPTZ NOT NULL,  -- Truncated to hour
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,

    UNIQUE(trigger_id, hour_bucket)
);

CREATE INDEX IF NOT EXISTS idx_trigger_stats_bucket ON trigger_execution_stats(trigger_id, hour_bucket);

-- ============================================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE user_triggers ENABLE ROW LEVEL SECURITY;
ALTER TABLE trigger_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE trigger_dead_letter ENABLE ROW LEVEL SECURITY;
ALTER TABLE trigger_execution_stats ENABLE ROW LEVEL SECURITY;

-- Users can manage their store's triggers
CREATE POLICY "Users can view their store triggers" ON user_triggers
    FOR SELECT USING (store_id IN (SELECT id FROM stores));

CREATE POLICY "Users can manage their store triggers" ON user_triggers
    FOR ALL USING (store_id IN (SELECT id FROM stores));

-- Queue is viewable but managed by system
CREATE POLICY "Users can view their store queue" ON trigger_queue
    FOR SELECT USING (store_id IN (SELECT id FROM stores));

CREATE POLICY "Users can view their store DLQ" ON trigger_dead_letter
    FOR SELECT USING (store_id IN (SELECT id FROM stores));

CREATE POLICY "Users can view their store stats" ON trigger_execution_stats
    FOR SELECT USING (store_id IN (SELECT id FROM stores));

-- ============================================================================
-- 6. QUEUE MANAGEMENT FUNCTIONS
-- ============================================================================

-- Enqueue a trigger execution
CREATE OR REPLACE FUNCTION enqueue_trigger(
    p_trigger_id UUID,
    p_event_payload JSONB DEFAULT NULL,
    p_priority INTEGER DEFAULT 0
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trigger user_triggers%ROWTYPE;
    v_queue_id UUID;
    v_resolved_args JSONB;
    v_hourly_count INTEGER;
BEGIN
    -- Get trigger config
    SELECT * INTO v_trigger FROM user_triggers WHERE id = p_trigger_id AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trigger not found or inactive';
    END IF;

    -- Check rate limit
    SELECT COALESCE(SUM(execution_count), 0) INTO v_hourly_count
    FROM trigger_execution_stats
    WHERE trigger_id = p_trigger_id
      AND hour_bucket = date_trunc('hour', now());

    IF v_hourly_count >= v_trigger.max_executions_per_hour THEN
        RAISE EXCEPTION 'Rate limit exceeded: % executions this hour (max: %)',
            v_hourly_count, v_trigger.max_executions_per_hour;
    END IF;

    -- Check cooldown
    IF v_trigger.cooldown_seconds > 0 AND v_trigger.last_triggered_at IS NOT NULL THEN
        IF now() < v_trigger.last_triggered_at + (v_trigger.cooldown_seconds || ' seconds')::interval THEN
            RAISE EXCEPTION 'Cooldown active: wait % seconds',
                EXTRACT(EPOCH FROM (v_trigger.last_triggered_at + (v_trigger.cooldown_seconds || ' seconds')::interval - now()))::integer;
        END IF;
    END IF;

    -- Resolve template variables in args
    v_resolved_args := resolve_trigger_args(v_trigger.tool_args_template, p_event_payload);

    -- Insert into queue
    INSERT INTO trigger_queue (
        trigger_id, store_id, event_payload, resolved_args,
        priority, max_attempts, next_attempt_at
    ) VALUES (
        p_trigger_id, v_trigger.store_id, p_event_payload, v_resolved_args,
        p_priority, v_trigger.max_retries, now()
    )
    RETURNING id INTO v_queue_id;

    -- Update last triggered
    UPDATE user_triggers SET last_triggered_at = now() WHERE id = p_trigger_id;

    RETURN v_queue_id;
END;
$$;

-- Resolve template variables in trigger args
CREATE OR REPLACE FUNCTION resolve_trigger_args(
    p_template JSONB,
    p_event_payload JSONB
) RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result TEXT;
    v_key TEXT;
    v_value TEXT;
BEGIN
    IF p_template IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    v_result := p_template::text;

    -- Replace {{event.field}} with values from event payload
    IF p_event_payload IS NOT NULL THEN
        FOR v_key, v_value IN
            SELECT key, value::text FROM jsonb_each(p_event_payload)
        LOOP
            v_result := replace(v_result, '{{event.' || v_key || '}}', COALESCE(v_value, ''));
            v_result := replace(v_result, '{{' || v_key || '}}', COALESCE(v_value, ''));
        END LOOP;
    END IF;

    -- Replace {{now}} with current timestamp
    v_result := replace(v_result, '{{now}}', now()::text);
    v_result := replace(v_result, '{{today}}', current_date::text);

    RETURN v_result::jsonb;
EXCEPTION WHEN OTHERS THEN
    -- If JSON parsing fails, return original template
    RETURN p_template;
END;
$$;

-- Process pending queue items (called by pg_cron)
CREATE OR REPLACE FUNCTION process_trigger_queue(p_batch_size INTEGER DEFAULT 10)
RETURNS TABLE(processed INTEGER, succeeded INTEGER, failed INTEGER, requeued INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
    v_result JSONB;
    v_processed INTEGER := 0;
    v_succeeded INTEGER := 0;
    v_failed INTEGER := 0;
    v_requeued INTEGER := 0;
    v_trigger user_triggers%ROWTYPE;
    v_tool user_tools%ROWTYPE;
    v_next_delay INTEGER;
BEGIN
    -- Lock and fetch pending items
    FOR v_item IN
        SELECT q.*, t.retry_delay_seconds, t.retry_backoff_multiplier, t.tool_id
        FROM trigger_queue q
        JOIN user_triggers t ON q.trigger_id = t.id
        WHERE q.status = 'pending'
          AND q.next_attempt_at <= now()
        ORDER BY q.priority DESC, q.next_attempt_at ASC
        LIMIT p_batch_size
        FOR UPDATE OF q SKIP LOCKED
    LOOP
        v_processed := v_processed + 1;

        -- Mark as processing
        UPDATE trigger_queue
        SET status = 'processing',
            started_at = now(),
            attempt_count = attempt_count + 1
        WHERE id = v_item.id;

        BEGIN
            -- Execute the tool
            SELECT * INTO v_tool FROM user_tools WHERE id = v_item.tool_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Tool not found: %', v_item.tool_id;
            END IF;

            -- Call execute_user_tool
            v_result := execute_user_tool(
                v_item.tool_id,
                v_item.store_id,
                v_item.resolved_args
            );

            IF (v_result->>'success')::boolean THEN
                -- Success!
                UPDATE trigger_queue
                SET status = 'success',
                    completed_at = now(),
                    execution_time_ms = EXTRACT(MILLISECONDS FROM (now() - started_at))::integer,
                    result = v_result
                WHERE id = v_item.id;

                v_succeeded := v_succeeded + 1;

                -- Update stats
                INSERT INTO trigger_execution_stats (trigger_id, store_id, hour_bucket, execution_count, success_count)
                VALUES (v_item.trigger_id, v_item.store_id, date_trunc('hour', now()), 1, 1)
                ON CONFLICT (trigger_id, hour_bucket) DO UPDATE
                SET execution_count = trigger_execution_stats.execution_count + 1,
                    success_count = trigger_execution_stats.success_count + 1;
            ELSE
                RAISE EXCEPTION '%', COALESCE(v_result->>'error', 'Unknown error');
            END IF;

        EXCEPTION WHEN OTHERS THEN
            -- Execution failed
            IF v_item.attempt_count >= v_item.max_attempts THEN
                -- Move to dead letter queue
                INSERT INTO trigger_dead_letter (
                    original_queue_id, trigger_id, store_id,
                    event_payload, resolved_args,
                    attempt_count, final_error
                ) VALUES (
                    v_item.id, v_item.trigger_id, v_item.store_id,
                    v_item.event_payload, v_item.resolved_args,
                    v_item.attempt_count, SQLERRM
                );

                UPDATE trigger_queue
                SET status = 'dead',
                    completed_at = now(),
                    last_error = SQLERRM
                WHERE id = v_item.id;

                v_failed := v_failed + 1;
            ELSE
                -- Requeue with exponential backoff
                v_next_delay := v_item.retry_delay_seconds *
                    power(v_item.retry_backoff_multiplier, v_item.attempt_count - 1);

                UPDATE trigger_queue
                SET status = 'pending',
                    next_attempt_at = now() + (v_next_delay || ' seconds')::interval,
                    last_error = SQLERRM
                WHERE id = v_item.id;

                v_requeued := v_requeued + 1;
            END IF;

            -- Update failure stats
            INSERT INTO trigger_execution_stats (trigger_id, store_id, hour_bucket, execution_count, failure_count)
            VALUES (v_item.trigger_id, v_item.store_id, date_trunc('hour', now()), 1, 1)
            ON CONFLICT (trigger_id, hour_bucket) DO UPDATE
            SET execution_count = trigger_execution_stats.execution_count + 1,
                failure_count = trigger_execution_stats.failure_count + 1;
        END;
    END LOOP;

    RETURN QUERY SELECT v_processed, v_succeeded, v_failed, v_requeued;
END;
$$;

-- Manually retry a dead letter item
CREATE OR REPLACE FUNCTION retry_dead_letter(
    p_dlq_id UUID,
    p_user_id UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dlq trigger_dead_letter%ROWTYPE;
    v_new_queue_id UUID;
BEGIN
    SELECT * INTO v_dlq FROM trigger_dead_letter WHERE id = p_dlq_id AND can_retry = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dead letter item not found or cannot be retried';
    END IF;

    -- Re-enqueue
    INSERT INTO trigger_queue (
        trigger_id, store_id, event_payload, resolved_args,
        status, priority, max_attempts, next_attempt_at
    ) VALUES (
        v_dlq.trigger_id, v_dlq.store_id, v_dlq.event_payload, v_dlq.resolved_args,
        'pending', 10, 1, now()  -- High priority, single attempt
    )
    RETURNING id INTO v_new_queue_id;

    -- Mark DLQ item as retried
    UPDATE trigger_dead_letter
    SET can_retry = false,
        retried_at = now(),
        retried_by = p_user_id
    WHERE id = p_dlq_id;

    RETURN v_new_queue_id;
END;
$$;

-- ============================================================================
-- 7. EVENT TRIGGER FUNCTION (called by table triggers)
-- ============================================================================

CREATE OR REPLACE FUNCTION trigger_on_table_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trigger RECORD;
    v_event_payload JSONB;
    v_matches BOOLEAN;
BEGIN
    -- Build event payload
    v_event_payload := jsonb_build_object(
        'table', TG_TABLE_NAME,
        'operation', TG_OP,
        'old', CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD)::jsonb ELSE NULL END,
        'new', CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW)::jsonb ELSE NULL END
    );

    -- Find matching triggers
    FOR v_trigger IN
        SELECT * FROM user_triggers
        WHERE trigger_type = 'event'
          AND is_active = true
          AND event_table = TG_TABLE_NAME
          AND event_operation = TG_OP
    LOOP
        -- Check filter if present
        v_matches := true;
        IF v_trigger.event_filter IS NOT NULL AND v_trigger.event_filter != '{}'::jsonb THEN
            -- Simple filter: all keys must match in NEW record
            v_matches := (
                SELECT bool_and(
                    COALESCE((v_event_payload->'new'->>key), '') = value
                )
                FROM jsonb_each_text(v_trigger.event_filter)
            );
        END IF;

        IF v_matches THEN
            -- Enqueue trigger execution
            PERFORM enqueue_trigger(v_trigger.id, v_event_payload);
        END IF;
    END LOOP;

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- ============================================================================
-- 8. HELPER TO CREATE TABLE TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION setup_event_trigger(
    p_table_name TEXT,
    p_operation TEXT  -- 'INSERT', 'UPDATE', 'DELETE', or 'ALL'
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trigger_name TEXT;
    v_ops TEXT[];
    v_op TEXT;
BEGIN
    IF p_operation = 'ALL' THEN
        v_ops := ARRAY['INSERT', 'UPDATE', 'DELETE'];
    ELSE
        v_ops := ARRAY[p_operation];
    END IF;

    FOREACH v_op IN ARRAY v_ops LOOP
        v_trigger_name := 'user_trigger_' || p_table_name || '_' || lower(v_op);

        -- Drop if exists
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I', v_trigger_name, p_table_name);

        -- Create trigger
        EXECUTE format(
            'CREATE TRIGGER %I AFTER %s ON %I FOR EACH ROW EXECUTE FUNCTION trigger_on_table_event()',
            v_trigger_name, v_op, p_table_name
        );
    END LOOP;
END;
$$;

-- ============================================================================
-- 9. PG_CRON JOBS FOR QUEUE PROCESSING
-- ============================================================================

-- Process queue every 10 seconds
SELECT cron.schedule(
    'process-trigger-queue',
    '10 seconds',
    $$SELECT process_trigger_queue(20)$$
);

-- Cleanup old completed queue items (keep 7 days)
SELECT cron.schedule(
    'cleanup-trigger-queue',
    '0 3 * * *',  -- Daily at 3am
    $$DELETE FROM trigger_queue WHERE status IN ('success', 'dead') AND completed_at < now() - interval '7 days'$$
);

-- Cleanup old stats (keep 30 days)
SELECT cron.schedule(
    'cleanup-trigger-stats',
    '0 4 * * *',  -- Daily at 4am
    $$DELETE FROM trigger_execution_stats WHERE hour_bucket < now() - interval '30 days'$$
);

-- ============================================================================
-- 10. SETUP EVENT TRIGGERS ON COMMON TABLES
-- ============================================================================

-- These will fire user triggers when rows change
SELECT setup_event_trigger('orders', 'ALL');
SELECT setup_event_trigger('customers', 'ALL');
SELECT setup_event_trigger('products', 'ALL');
SELECT setup_event_trigger('inventory', 'ALL');
