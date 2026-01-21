#!/bin/bash
# Check MCP execution monitoring

echo "🔍 Checking MCP execution logs..."
echo ""

PGPASSWORD='holyfuckingshitfuck' psql "host=db.uaednwpxursknmwdeejn.supabase.co port=5432 user=postgres dbname=postgres sslmode=require" << 'EOF'
-- Show recent executions
SELECT
  tool_name,
  result_status,
  execution_time_ms,
  LEFT(request::text, 50) as request_preview,
  created_at
FROM lisa_tool_execution_log
ORDER BY created_at DESC
LIMIT 10;

-- Show stats by tool
SELECT
  tool_name,
  COUNT(*) as total_executions,
  AVG(execution_time_ms)::int as avg_ms,
  COUNT(*) FILTER (WHERE result_status = 'success') as successes,
  COUNT(*) FILTER (WHERE result_status = 'error') as errors
FROM lisa_tool_execution_log
GROUP BY tool_name
ORDER BY total_executions DESC
LIMIT 10;
EOF
