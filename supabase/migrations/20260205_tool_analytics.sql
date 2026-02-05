-- =============================================================================
-- TOOL-LEVEL ANALYTICS: Next-Gen OTEL Observability (2026)
-- =============================================================================
-- Provides comprehensive tool performance metrics, time-series analytics,
-- error breakdowns, and reliability scoring following OpenTelemetry
-- Gen AI Semantic Conventions and Anthropic best practices.
-- =============================================================================

-- =============================================================================
-- 1. INDEXES: Fast tool-level queries
-- =============================================================================

-- Composite index for tool analytics queries (resource_type + action + time)
CREATE INDEX IF NOT EXISTS idx_audit_logs_tool_analytics
  ON audit_logs (resource_type, created_at DESC)
  WHERE resource_type = 'mcp_tool';

-- Index for tool name + action pattern matching
CREATE INDEX IF NOT EXISTS idx_audit_logs_tool_action
  ON audit_logs (resource_id, action, created_at DESC)
  WHERE resource_type = 'mcp_tool';

-- Index for error analysis
CREATE INDEX IF NOT EXISTS idx_audit_logs_tool_errors
  ON audit_logs (resource_id, error_type, created_at DESC)
  WHERE resource_type = 'mcp_tool' AND status_code = 'ERROR';

-- Index for cost attribution queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_tool_cost
  ON audit_logs (conversation_id, resource_type, created_at)
  WHERE resource_type = 'mcp_tool' AND total_cost IS NOT NULL;

-- =============================================================================
-- 2. get_tool_analytics() - Comprehensive per-tool performance metrics
-- =============================================================================

CREATE OR REPLACE FUNCTION get_tool_analytics(
  p_store_id UUID DEFAULT NULL,
  p_hours_back INT DEFAULT 24,
  p_tool_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff TIMESTAMPTZ;
  v_result JSONB;
BEGIN
  v_cutoff := NOW() - (p_hours_back || ' hours')::INTERVAL;

  WITH tool_spans AS (
    SELECT
      resource_id AS tool_name,
      -- Extract sub-action: tool.inventory.adjust -> adjust
      CASE
        WHEN action LIKE 'tool.%.%' THEN split_part(action, '.', 3)
        ELSE NULL
      END AS tool_action,
      duration_ms,
      status_code,
      error_type,
      (details->>'timed_out')::BOOLEAN AS timed_out,
      total_cost,
      -- Extract marginal cost from details JSONB
      (details->>'marginal_cost')::NUMERIC AS marginal_cost,
      -- Input/output sizes for payload analysis
      COALESCE(octet_length(details->>'tool_input'), 0) AS input_bytes,
      COALESCE(octet_length(details->>'tool_result'), 0) AS output_bytes,
      created_at
    FROM audit_logs
    WHERE resource_type = 'mcp_tool'
      AND created_at >= v_cutoff
      AND (p_store_id IS NULL OR store_id = p_store_id)
      AND (p_tool_name IS NULL OR resource_id = p_tool_name)
  ),

  -- Per-tool aggregations
  tool_metrics AS (
    SELECT
      tool_name,
      COUNT(*) AS total_calls,
      COUNT(*) FILTER (WHERE status_code = 'OK') AS success_count,
      COUNT(*) FILTER (WHERE status_code = 'ERROR') AS error_count,
      COUNT(*) FILTER (WHERE timed_out = TRUE) AS timeout_count,

      -- Latency percentiles
      ROUND(AVG(duration_ms)::NUMERIC, 1) AS avg_ms,
      ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms)::NUMERIC, 1) AS p50_ms,
      ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY duration_ms)::NUMERIC, 1) AS p90_ms,
      ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)::NUMERIC, 1) AS p95_ms,
      ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms)::NUMERIC, 1) AS p99_ms,
      MIN(duration_ms) AS min_ms,
      MAX(duration_ms) AS max_ms,

      -- Error rate
      ROUND(100.0 * COUNT(*) FILTER (WHERE status_code = 'ERROR') / NULLIF(COUNT(*), 0), 2) AS error_rate,

      -- Payload stats
      ROUND(AVG(input_bytes)::NUMERIC, 0) AS avg_input_bytes,
      ROUND(AVG(output_bytes)::NUMERIC, 0) AS avg_output_bytes,

      -- Cost attribution (marginal cost extracted in tool_spans)
      COALESCE(SUM(marginal_cost), 0) AS total_marginal_cost,

      -- Time range
      MIN(created_at) AS first_call,
      MAX(created_at) AS last_call,

      -- Throughput (calls per minute)
      ROUND(
        COUNT(*)::NUMERIC / GREATEST(
          EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) / 60.0,
          1
        ), 2
      ) AS calls_per_minute
    FROM tool_spans
    GROUP BY tool_name
  ),

  -- Per-tool action breakdown
  action_metrics AS (
    SELECT
      tool_name,
      JSONB_OBJECT_AGG(
        COALESCE(tool_action, '_default'),
        JSONB_BUILD_OBJECT(
          'count', cnt,
          'avg_ms', avg_dur,
          'p50_ms', p50_dur,
          'p95_ms', p95_dur,
          'error_count', errs,
          'error_rate', ROUND(100.0 * errs / NULLIF(cnt, 0), 2)
        )
      ) AS actions
    FROM (
      SELECT
        tool_name,
        tool_action,
        COUNT(*) AS cnt,
        ROUND(AVG(duration_ms)::NUMERIC, 1) AS avg_dur,
        ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms)::NUMERIC, 1) AS p50_dur,
        ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)::NUMERIC, 1) AS p95_dur,
        COUNT(*) FILTER (WHERE status_code = 'ERROR') AS errs
      FROM tool_spans
      GROUP BY tool_name, tool_action
    ) sub
    GROUP BY tool_name
  ),

  -- Per-tool error type breakdown
  error_breakdown AS (
    SELECT
      tool_name,
      JSONB_OBJECT_AGG(
        COALESCE(error_type, 'unknown'),
        type_count
      ) AS error_types
    FROM (
      SELECT
        tool_name,
        error_type,
        COUNT(*) AS type_count
      FROM tool_spans
      WHERE status_code = 'ERROR'
      GROUP BY tool_name, error_type
    ) sub
    GROUP BY tool_name
  ),

  -- Build per-tool result
  tool_results AS (
    SELECT JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'tool_name', tm.tool_name,
        'total_calls', tm.total_calls,
        'success_count', tm.success_count,
        'error_count', tm.error_count,
        'timeout_count', tm.timeout_count,
        'error_rate', tm.error_rate,
        'avg_ms', tm.avg_ms,
        'p50_ms', tm.p50_ms,
        'p90_ms', tm.p90_ms,
        'p95_ms', tm.p95_ms,
        'p99_ms', tm.p99_ms,
        'min_ms', tm.min_ms,
        'max_ms', tm.max_ms,
        'avg_input_bytes', tm.avg_input_bytes,
        'avg_output_bytes', tm.avg_output_bytes,
        'total_marginal_cost', tm.total_marginal_cost,
        'calls_per_minute', tm.calls_per_minute,
        'first_call', tm.first_call,
        'last_call', tm.last_call,
        'reliability_score', ROUND(
          GREATEST(0, 100.0 - tm.error_rate - (tm.timeout_count::NUMERIC / NULLIF(tm.total_calls, 0) * 100)),
          1
        ),
        'actions', COALESCE(am.actions, '{}'::JSONB),
        'error_types', COALESCE(eb.error_types, '{}'::JSONB)
      )
      ORDER BY tm.total_calls DESC
    ) AS tools
    FROM tool_metrics tm
    LEFT JOIN action_metrics am ON am.tool_name = tm.tool_name
    LEFT JOIN error_breakdown eb ON eb.tool_name = tm.tool_name
  ),

  -- Global summary
  summary AS (
    SELECT JSONB_BUILD_OBJECT(
      'total_calls', COALESCE(SUM(total_calls), 0),
      'total_errors', COALESCE(SUM(error_count), 0),
      'total_timeouts', COALESCE(SUM(timeout_count), 0),
      'overall_error_rate', ROUND(
        100.0 * COALESCE(SUM(error_count), 0) / NULLIF(COALESCE(SUM(total_calls), 0), 0), 2
      ),
      'overall_avg_ms', ROUND(AVG(avg_ms)::NUMERIC, 1),
      'overall_p50_ms', ROUND(AVG(p50_ms)::NUMERIC, 1),
      'overall_p95_ms', ROUND(AVG(p95_ms)::NUMERIC, 1),
      'unique_tools', COUNT(DISTINCT tool_name),
      'total_marginal_cost', ROUND(COALESCE(SUM(total_marginal_cost), 0)::NUMERIC, 6),
      'slowest_tool', (SELECT tool_name FROM tool_metrics ORDER BY p95_ms DESC NULLS LAST LIMIT 1),
      'most_used_tool', (SELECT tool_name FROM tool_metrics ORDER BY total_calls DESC LIMIT 1),
      'most_errors_tool', (SELECT tool_name FROM tool_metrics WHERE error_count > 0 ORDER BY error_rate DESC LIMIT 1),
      'hours_analyzed', p_hours_back
    ) AS summary
    FROM tool_metrics
  )

  SELECT JSONB_BUILD_OBJECT(
    'tools', COALESCE(tr.tools, '[]'::JSONB),
    'summary', s.summary
  ) INTO v_result
  FROM tool_results tr, summary s;

  RETURN v_result;
END;
$$;

-- =============================================================================
-- 3. get_tool_timeline() - Time-bucketed metrics for charts
-- =============================================================================

CREATE OR REPLACE FUNCTION get_tool_timeline(
  p_store_id UUID DEFAULT NULL,
  p_hours_back INT DEFAULT 24,
  p_bucket_minutes INT DEFAULT 15,
  p_tool_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff TIMESTAMPTZ;
  v_result JSONB;
BEGIN
  v_cutoff := NOW() - (p_hours_back || ' hours')::INTERVAL;

  WITH buckets AS (
    SELECT
      DATE_TRUNC('minute', created_at) - (
        (EXTRACT(MINUTE FROM created_at)::INT % p_bucket_minutes) || ' minutes'
      )::INTERVAL AS bucket,
      resource_id AS tool_name,
      duration_ms,
      status_code,
      error_type,
      (details->>'timed_out')::BOOLEAN AS timed_out
    FROM audit_logs
    WHERE resource_type = 'mcp_tool'
      AND created_at >= v_cutoff
      AND (p_store_id IS NULL OR store_id = p_store_id)
      AND (p_tool_name IS NULL OR resource_id = p_tool_name)
  ),

  bucketed AS (
    SELECT
      bucket,
      tool_name,
      COUNT(*) AS calls,
      COUNT(*) FILTER (WHERE status_code = 'ERROR') AS errors,
      COUNT(*) FILTER (WHERE timed_out = TRUE) AS timeouts,
      ROUND(AVG(duration_ms)::NUMERIC, 1) AS avg_ms,
      ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)::NUMERIC, 1) AS p95_ms,
      MAX(duration_ms) AS max_ms
    FROM buckets
    GROUP BY bucket, tool_name
  ),

  -- Also aggregate across all tools per bucket
  bucketed_total AS (
    SELECT
      bucket,
      '_all' AS tool_name,
      SUM(calls)::INT AS calls,
      SUM(errors)::INT AS errors,
      SUM(timeouts)::INT AS timeouts,
      ROUND(AVG(avg_ms)::NUMERIC, 1) AS avg_ms,
      ROUND(AVG(p95_ms)::NUMERIC, 1) AS p95_ms,
      MAX(max_ms) AS max_ms
    FROM bucketed
    GROUP BY bucket
  ),

  combined AS (
    SELECT * FROM bucketed
    UNION ALL
    SELECT * FROM bucketed_total
  )

  SELECT JSONB_BUILD_OBJECT(
    'bucket_minutes', p_bucket_minutes,
    'hours_back', p_hours_back,
    'buckets', COALESCE(
      (SELECT JSONB_AGG(
        JSONB_BUILD_OBJECT(
          'time', bucket,
          'tool', tool_name,
          'calls', calls,
          'errors', errors,
          'timeouts', timeouts,
          'avg_ms', avg_ms,
          'p95_ms', p95_ms,
          'max_ms', max_ms
        )
        ORDER BY bucket ASC, tool_name
      ) FROM combined),
      '[]'::JSONB
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- =============================================================================
-- 4. get_tool_trace_detail() - Full tool execution detail for span inspector
-- =============================================================================

CREATE OR REPLACE FUNCTION get_tool_trace_detail(
  p_span_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_span RECORD;
  v_avg_duration NUMERIC;
  v_p95_duration NUMERIC;
  v_tool_error_rate NUMERIC;
  v_tool_total_calls BIGINT;
BEGIN
  -- Get the span
  SELECT * INTO v_span
  FROM audit_logs
  WHERE id = p_span_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('error', 'Span not found');
  END IF;

  -- Get comparison metrics for this tool (last 24h)
  SELECT
    ROUND(AVG(duration_ms)::NUMERIC, 1),
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)::NUMERIC, 1),
    ROUND(100.0 * COUNT(*) FILTER (WHERE status_code = 'ERROR') / NULLIF(COUNT(*), 0), 2),
    COUNT(*)
  INTO v_avg_duration, v_p95_duration, v_tool_error_rate, v_tool_total_calls
  FROM audit_logs
  WHERE resource_type = 'mcp_tool'
    AND resource_id = v_span.resource_id
    AND created_at >= NOW() - INTERVAL '24 hours';

  SELECT JSONB_BUILD_OBJECT(
    'span', JSONB_BUILD_OBJECT(
      'id', v_span.id,
      'action', v_span.action,
      'tool_name', v_span.resource_id,
      'severity', v_span.severity,
      'duration_ms', v_span.duration_ms,
      'status_code', v_span.status_code,
      'error_type', v_span.error_type,
      'error_message', v_span.error_message,
      'retryable', v_span.retryable,
      'created_at', v_span.created_at,
      'trace_id', v_span.trace_id,
      'span_id', v_span.span_id,
      'span_kind', v_span.span_kind,
      'service_name', v_span.service_name,
      'service_version', v_span.service_version,
      'model', v_span.model,
      'turn_number', v_span.turn_number,
      'conversation_id', v_span.conversation_id,
      'start_time', v_span.start_time,
      'end_time', v_span.end_time,
      'details', v_span.details
    ),
    'comparison', JSONB_BUILD_OBJECT(
      'avg_ms', v_avg_duration,
      'p95_ms', v_p95_duration,
      'error_rate', v_tool_error_rate,
      'total_calls_24h', v_tool_total_calls,
      'is_slow', v_span.duration_ms > COALESCE(v_p95_duration, 999999),
      'percentile_rank', (
        SELECT ROUND(
          100.0 * COUNT(*) FILTER (WHERE duration_ms <= v_span.duration_ms) / NULLIF(COUNT(*), 0),
          1
        )
        FROM audit_logs
        WHERE resource_type = 'mcp_tool'
          AND resource_id = v_span.resource_id
          AND created_at >= NOW() - INTERVAL '24 hours'
      )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- =============================================================================
-- 5. get_tool_error_patterns() - Error correlation analysis
-- =============================================================================

CREATE OR REPLACE FUNCTION get_tool_error_patterns(
  p_store_id UUID DEFAULT NULL,
  p_hours_back INT DEFAULT 24
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff TIMESTAMPTZ;
  v_result JSONB;
BEGIN
  v_cutoff := NOW() - (p_hours_back || ' hours')::INTERVAL;

  WITH error_spans AS (
    SELECT
      resource_id AS tool_name,
      CASE
        WHEN action LIKE 'tool.%.%' THEN split_part(action, '.', 3)
        ELSE NULL
      END AS tool_action,
      error_type,
      error_message,
      (details->>'timed_out')::BOOLEAN AS timed_out,
      retryable,
      duration_ms,
      conversation_id,
      trace_id,
      created_at
    FROM audit_logs
    WHERE resource_type = 'mcp_tool'
      AND status_code = 'ERROR'
      AND created_at >= v_cutoff
      AND (p_store_id IS NULL OR store_id = p_store_id)
  ),

  -- Error type distribution
  error_distribution AS (
    SELECT JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'error_type', COALESCE(error_type, 'unknown'),
        'count', cnt,
        'pct', ROUND(100.0 * cnt / NULLIF((SELECT COUNT(*) FROM error_spans), 0), 1),
        'retryable_count', retry_cnt,
        'avg_duration_ms', avg_dur,
        'affected_tools', tools
      )
      ORDER BY cnt DESC
    )
    FROM (
      SELECT
        error_type,
        COUNT(*) AS cnt,
        COUNT(*) FILTER (WHERE retryable = TRUE) AS retry_cnt,
        ROUND(AVG(duration_ms)::NUMERIC, 1) AS avg_dur,
        ARRAY_AGG(DISTINCT tool_name) AS tools
      FROM error_spans
      GROUP BY error_type
    ) sub
  ),

  -- Recent errors (last 10)
  recent_errors AS (
    SELECT JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'tool_name', tool_name,
        'action', tool_action,
        'error_type', error_type,
        'error_message', LEFT(error_message, 200),
        'timed_out', timed_out,
        'retryable', retryable,
        'duration_ms', duration_ms,
        'conversation_id', conversation_id,
        'created_at', created_at
      )
      ORDER BY created_at DESC
    )
    FROM (SELECT * FROM error_spans ORDER BY created_at DESC LIMIT 10) sub
  ),

  -- Error bursts (>3 errors within 5 min window)
  error_bursts AS (
    SELECT JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'tool_name', tool_name,
        'window_start', window_start,
        'error_count', error_count,
        'primary_error_type', primary_type
      )
    )
    FROM (
      SELECT
        tool_name,
        DATE_TRUNC('minute', created_at) - (
          (EXTRACT(MINUTE FROM created_at)::INT % 5) || ' minutes'
        )::INTERVAL AS window_start,
        COUNT(*) AS error_count,
        MODE() WITHIN GROUP (ORDER BY error_type) AS primary_type
      FROM error_spans
      GROUP BY tool_name, window_start
      HAVING COUNT(*) >= 3
      ORDER BY window_start DESC
      LIMIT 10
    ) sub
  )

  SELECT JSONB_BUILD_OBJECT(
    'total_errors', (SELECT COUNT(*) FROM error_spans),
    'unique_tools_affected', (SELECT COUNT(DISTINCT tool_name) FROM error_spans),
    'distribution', COALESCE((SELECT * FROM error_distribution), '[]'::JSONB),
    'recent', COALESCE((SELECT * FROM recent_errors), '[]'::JSONB),
    'bursts', COALESCE((SELECT * FROM error_bursts), '[]'::JSONB),
    'hours_analyzed', p_hours_back
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- =============================================================================
-- 6. GRANTS
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_tool_analytics TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_tool_timeline TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_tool_trace_detail TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_tool_error_patterns TO authenticated, service_role, anon;
