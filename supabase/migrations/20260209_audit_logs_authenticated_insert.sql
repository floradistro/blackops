-- Allow authenticated users to insert their own audit logs
-- This enables CLI telemetry when using JWT auth instead of service role

-- Drop existing insert policy
DROP POLICY IF EXISTS "Service can insert audit logs" ON audit_logs;

-- Create new policy that allows both service role AND authenticated users to insert
-- The user_id must match their auth.uid() OR be null (for system spans)
CREATE POLICY "Authenticated users can insert audit logs"
    ON audit_logs
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id IS NULL
        OR user_id::text = auth.uid()::text
    );

-- Also allow anon/service role (for MCP server mode)
CREATE POLICY "Service role can insert audit logs"
    ON audit_logs
    FOR INSERT
    TO anon, service_role
    WITH CHECK (true);

COMMENT ON POLICY "Authenticated users can insert audit logs" ON audit_logs IS
    'Allows CLI users to insert telemetry spans for their own user_id';
