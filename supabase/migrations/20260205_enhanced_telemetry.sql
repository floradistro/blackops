-- Enhanced Telemetry for W3C Trace Context / OpenTelemetry Compliance
--
-- W3C Trace Context: https://www.w3.org/TR/trace-context/
-- OpenTelemetry Semantic Conventions: https://opentelemetry.io/docs/specs/semconv/
--
-- This upgrade adds missing OTEL fields while maintaining backward compatibility

-- Add new columns for full OTEL compliance
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS span_id text;  -- W3C span-id (16 hex chars)
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS trace_id text; -- W3C trace-id (32 hex chars) - more explicit than request_id
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS trace_flags smallint DEFAULT 1; -- 01 = sampled
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS span_kind text DEFAULT 'INTERNAL'; -- CLIENT, SERVER, INTERNAL, PRODUCER, CONSUMER
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS service_name text DEFAULT 'agent-server';
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS service_version text;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS status_code text DEFAULT 'OK'; -- OK, ERROR, UNSET
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS start_time timestamptz;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS end_time timestamptz;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS events jsonb DEFAULT '[]'::jsonb; -- Array of {name, timestamp, attributes}
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS links jsonb DEFAULT '[]'::jsonb; -- Array of {trace_id, span_id}

-- AI-specific telemetry (Anthropic Agent SDK 2026)
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS model text; -- claude-sonnet-4-20250514
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS input_tokens integer;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS output_tokens integer;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS total_cost numeric(10,6);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS turn_number integer;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS conversation_id uuid;

-- Error classification (matches your ToolErrorType enum)
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS error_type text; -- recoverable, permanent, rate_limit, auth, validation, not_found
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS retryable boolean DEFAULT false;

-- Resource attributes (OTEL semantic conventions)
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS resource_attributes jsonb DEFAULT '{}'::jsonb;
-- Example: {"db.system": "postgresql", "db.name": "supabase", "http.method": "POST"}

-- Create index for W3C trace lookup
CREATE INDEX IF NOT EXISTS idx_audit_logs_trace_id ON audit_logs(trace_id) WHERE trace_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_span_id ON audit_logs(span_id) WHERE span_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_conversation ON audit_logs(conversation_id) WHERE conversation_id IS NOT NULL;

-- Add constraint for span_kind
ALTER TABLE audit_logs DROP CONSTRAINT IF EXISTS audit_logs_span_kind_check;
ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_span_kind_check
  CHECK (span_kind IS NULL OR span_kind IN ('CLIENT', 'SERVER', 'INTERNAL', 'PRODUCER', 'CONSUMER'));

-- Add constraint for status_code (OTEL standard)
ALTER TABLE audit_logs DROP CONSTRAINT IF EXISTS audit_logs_status_code_check;
ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_status_code_check
  CHECK (status_code IS NULL OR status_code IN ('OK', 'ERROR', 'UNSET'));

-- Backfill trace_id from request_id for existing records
UPDATE audit_logs SET trace_id = request_id WHERE trace_id IS NULL AND request_id IS NOT NULL;

-- Comment for documentation
COMMENT ON TABLE audit_logs IS 'OpenTelemetry-compliant distributed tracing with AI agent extensions. W3C Trace Context compatible.';
COMMENT ON COLUMN audit_logs.trace_id IS 'W3C trace-id: 32 lowercase hex chars identifying the whole trace';
COMMENT ON COLUMN audit_logs.span_id IS 'W3C span-id: 16 lowercase hex chars identifying this span';
COMMENT ON COLUMN audit_logs.parent_id IS 'Parent span UUID for hierarchical traces';
COMMENT ON COLUMN audit_logs.span_kind IS 'OTEL span kind: CLIENT (outgoing), SERVER (incoming), INTERNAL (in-process), PRODUCER/CONSUMER (async)';
COMMENT ON COLUMN audit_logs.events IS 'Array of timestamped events within span: [{name, timestamp, attributes}]';
COMMENT ON COLUMN audit_logs.links IS 'Links to related spans in other traces: [{trace_id, span_id}]';
COMMENT ON COLUMN audit_logs.input_tokens IS 'Claude API input tokens (AI telemetry)';
COMMENT ON COLUMN audit_logs.output_tokens IS 'Claude API output tokens (AI telemetry)';
COMMENT ON COLUMN audit_logs.turn_number IS 'Agent conversation turn number';

-- Create view for trace reconstruction
CREATE OR REPLACE VIEW v_traces AS
SELECT
  COALESCE(trace_id, request_id) as trace_id,
  MIN(start_time) as trace_start,
  MAX(end_time) as trace_end,
  MAX(end_time) - MIN(start_time) as total_duration,
  COUNT(*) as span_count,
  COUNT(*) FILTER (WHERE status_code = 'ERROR' OR severity = 'error') as error_count,
  SUM(input_tokens) as total_input_tokens,
  SUM(output_tokens) as total_output_tokens,
  SUM(total_cost) as total_cost,
  MAX(turn_number) as max_turns,
  array_agg(DISTINCT service_name) FILTER (WHERE service_name IS NOT NULL) as services,
  array_agg(DISTINCT action) as operations,
  MIN(store_id) as store_id,
  MIN(conversation_id) as conversation_id
FROM audit_logs
WHERE trace_id IS NOT NULL OR request_id IS NOT NULL
GROUP BY COALESCE(trace_id, request_id);

-- Create view for span details with parent info
CREATE OR REPLACE VIEW v_spans AS
SELECT
  a.id,
  a.trace_id,
  a.span_id,
  a.parent_id,
  p.action as parent_operation,
  a.action as operation,
  a.span_kind,
  a.service_name,
  a.start_time,
  a.end_time,
  a.duration_ms,
  a.status_code,
  a.error_message,
  a.error_type,
  a.retryable,
  a.model,
  a.input_tokens,
  a.output_tokens,
  a.turn_number,
  a.details,
  a.events,
  a.resource_attributes,
  a.created_at
FROM audit_logs a
LEFT JOIN audit_logs p ON a.parent_id = p.id
ORDER BY a.created_at DESC;

GRANT SELECT ON v_traces TO authenticated;
GRANT SELECT ON v_traces TO service_role;
GRANT SELECT ON v_spans TO authenticated;
GRANT SELECT ON v_spans TO service_role;

-- RPC for getting a full trace with all spans in hierarchy
CREATE OR REPLACE FUNCTION get_trace(p_trace_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  WITH RECURSIVE span_tree AS (
    -- Root spans (no parent)
    SELECT
      id, trace_id, span_id, parent_id, action, span_kind, service_name,
      start_time, end_time, duration_ms, status_code, error_message,
      model, input_tokens, output_tokens, turn_number, details, events,
      0 as depth,
      ARRAY[id] as path
    FROM audit_logs
    WHERE (trace_id = p_trace_id OR request_id = p_trace_id)
      AND parent_id IS NULL

    UNION ALL

    -- Child spans
    SELECT
      a.id, a.trace_id, a.span_id, a.parent_id, a.action, a.span_kind, a.service_name,
      a.start_time, a.end_time, a.duration_ms, a.status_code, a.error_message,
      a.model, a.input_tokens, a.output_tokens, a.turn_number, a.details, a.events,
      st.depth + 1,
      st.path || a.id
    FROM audit_logs a
    JOIN span_tree st ON a.parent_id = st.id
    WHERE a.trace_id = p_trace_id OR a.request_id = p_trace_id
  )
  SELECT jsonb_build_object(
    'trace_id', p_trace_id,
    'span_count', COUNT(*),
    'total_duration_ms', SUM(duration_ms),
    'total_input_tokens', SUM(input_tokens),
    'total_output_tokens', SUM(output_tokens),
    'max_depth', MAX(depth),
    'error_count', COUNT(*) FILTER (WHERE status_code = 'ERROR'),
    'spans', jsonb_agg(
      jsonb_build_object(
        'id', id,
        'span_id', span_id,
        'parent_id', parent_id,
        'operation', action,
        'span_kind', span_kind,
        'service', service_name,
        'duration_ms', duration_ms,
        'status', status_code,
        'error', error_message,
        'model', model,
        'tokens', jsonb_build_object('input', input_tokens, 'output', output_tokens),
        'turn', turn_number,
        'depth', depth,
        'events', events,
        'details', details
      ) ORDER BY depth, start_time
    )
  ) INTO result
  FROM span_tree;

  RETURN COALESCE(result, '{"error": "Trace not found"}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION get_trace TO authenticated;
GRANT EXECUTE ON FUNCTION get_trace TO service_role;
