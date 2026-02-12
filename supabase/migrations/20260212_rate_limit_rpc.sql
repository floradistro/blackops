-- Rate limiting RPC using audit_logs as the counter table
-- Returns: allowed (bool), current_count (int), retry_after_seconds (int)

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

  SELECT COUNT(*) INTO v_count
  FROM audit_logs
  WHERE user_id = p_user_id
    AND created_at >= v_window_start
    AND action IN ('chat.user_message', 'tool_execution');

  IF v_count >= p_max_requests THEN
    -- Find oldest entry in window to calculate retry-after
    SELECT MIN(created_at) INTO v_oldest
    FROM audit_logs
    WHERE user_id = p_user_id
      AND created_at >= v_window_start
      AND action IN ('chat.user_message', 'tool_execution');

    RETURN QUERY SELECT
      FALSE,
      v_count,
      GREATEST(1, EXTRACT(EPOCH FROM (v_oldest + (p_window_seconds || ' seconds')::INTERVAL - NOW()))::INT);
  ELSE
    RETURN QUERY SELECT TRUE, v_count, 0;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
