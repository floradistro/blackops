-- Enable RLS on audit_logs if not already
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view their store audit logs" ON audit_logs;
DROP POLICY IF EXISTS "Service can insert audit logs" ON audit_logs;

-- Allow users to read audit logs for stores they own
-- Uses platform_users.auth_id to match auth.uid() to store ownership
CREATE POLICY "Users can view their store audit logs"
    ON audit_logs
    FOR SELECT
    USING (
        store_id IN (
            SELECT s.id FROM stores s
            JOIN platform_users pu ON pu.id = s.owner_user_id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- Allow service role to insert (MCP server uses service key)
CREATE POLICY "Service can insert audit logs"
    ON audit_logs
    FOR INSERT
    WITH CHECK (true);

-- Enable realtime for audit_logs (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'audit_logs'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE audit_logs;
    END IF;
END $$;

COMMENT ON TABLE audit_logs IS 'Audit trail for tool executions and agent operations. RLS enabled for store-level access.';
