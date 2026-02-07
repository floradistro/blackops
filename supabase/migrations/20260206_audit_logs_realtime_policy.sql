-- Add permissive read policy for realtime telemetry
-- The existing RLS policy requires auth.uid() which may not be available in all realtime contexts

-- Add policy that allows reading tool execution logs (non-sensitive operational data)
-- Filter by action prefix to only allow telemetry-related reads
CREATE POLICY "Allow reading tool telemetry"
    ON audit_logs
    FOR SELECT
    USING (
        action LIKE 'tool.%'
        OR action = 'claude_api_request'
    );

-- Ensure realtime is enabled (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'audit_logs'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE audit_logs;
    END IF;
END $$;
