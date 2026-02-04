-- Agent Execution Traces table
-- Stores full execution traces for developer-level observability

CREATE TABLE IF NOT EXISTS agent_execution_traces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL,
    agent_name TEXT NOT NULL,
    user_message TEXT NOT NULL,
    final_response TEXT,
    success BOOLEAN DEFAULT false,
    error_message TEXT,
    duration_ms INTEGER,
    turn_count INTEGER DEFAULT 0,
    tool_calls INTEGER DEFAULT 0,
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    events_json JSONB DEFAULT '[]'::jsonb,
    request_json JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX idx_agent_traces_store ON agent_execution_traces(store_id);
CREATE INDEX idx_agent_traces_agent ON agent_execution_traces(agent_id);
CREATE INDEX idx_agent_traces_success ON agent_execution_traces(success);
CREATE INDEX idx_agent_traces_created ON agent_execution_traces(created_at DESC);

-- Enable RLS
ALTER TABLE agent_execution_traces ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view their store's traces"
    ON agent_execution_traces
    FOR SELECT
    USING (
        store_id IN (
            SELECT store_id FROM store_staff WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert traces for their store"
    ON agent_execution_traces
    FOR INSERT
    WITH CHECK (
        store_id IN (
            SELECT store_id FROM store_staff WHERE user_id = auth.uid()
        )
    );

-- Function to get trace statistics
CREATE OR REPLACE FUNCTION get_agent_trace_stats(
    p_store_id UUID,
    p_hours_ago INTEGER DEFAULT 24
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_executions', COUNT(*),
        'success_count', COUNT(*) FILTER (WHERE success = true),
        'error_count', COUNT(*) FILTER (WHERE success = false),
        'success_rate', ROUND(
            COUNT(*) FILTER (WHERE success = true)::DECIMAL / NULLIF(COUNT(*), 0) * 100,
            1
        ),
        'avg_duration_ms', ROUND(AVG(duration_ms)),
        'total_input_tokens', SUM(COALESCE(input_tokens, 0)),
        'total_output_tokens', SUM(COALESCE(output_tokens, 0)),
        'avg_tool_calls', ROUND(AVG(tool_calls), 1),
        'agents', (
            SELECT jsonb_agg(jsonb_build_object(
                'agent_name', agent_name,
                'count', cnt,
                'success_rate', ROUND(success_cnt::DECIMAL / cnt * 100, 1)
            ))
            FROM (
                SELECT
                    agent_name,
                    COUNT(*) as cnt,
                    COUNT(*) FILTER (WHERE success = true) as success_cnt
                FROM agent_execution_traces
                WHERE store_id = p_store_id
                AND created_at > now() - (p_hours_ago || ' hours')::INTERVAL
                GROUP BY agent_name
                ORDER BY cnt DESC
                LIMIT 10
            ) sub
        )
    )
    INTO result
    FROM agent_execution_traces
    WHERE store_id = p_store_id
    AND created_at > now() - (p_hours_ago || ' hours')::INTERVAL;

    RETURN COALESCE(result, '{}'::jsonb);
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_agent_trace_stats TO authenticated;

COMMENT ON TABLE agent_execution_traces IS 'Stores execution traces for AI agents with full observability';
