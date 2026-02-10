-- Register telemetry tool in ai_tool_registry
-- Gives agents full observability: logs, conversations, traces, tool analytics, errors, tokens

INSERT INTO ai_tool_registry (
  name,
  category,
  description,
  definition,
  requires_store_id,
  requires_user_id,
  is_read_only,
  is_active,
  tool_mode,
  edge_function
) VALUES (
  'telemetry',
  'analytics',
  'Query telemetry data: audit logs, conversations, traces, tool analytics, error patterns, token usage, and full-text search. Read-only observability for agent self-awareness.',
  '{
    "name": "telemetry",
    "description": "Query telemetry data: audit logs, conversations, traces, tool analytics, error patterns, token usage, and full-text search across all observability data.",
    "input_schema": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "description": "The telemetry action to perform",
          "enum": [
            "recent_activity",
            "search",
            "conversation_detail",
            "conversations",
            "agent_performance",
            "tool_analytics",
            "tool_timeline",
            "trace",
            "span_detail",
            "error_patterns",
            "token_usage",
            "sources"
          ]
        },
        "hours_back": {
          "type": "integer",
          "description": "How many hours back to query (default 24)"
        },
        "days": {
          "type": "integer",
          "description": "Number of days for agent_performance (default 7)"
        },
        "limit": {
          "type": "integer",
          "description": "Max rows to return"
        },
        "source": {
          "type": "string",
          "description": "Filter by telemetry source (e.g. edge_function, mcp_server, whale_chat)"
        },
        "action_filter": {
          "type": "string",
          "description": "Filter audit log action names (partial match)"
        },
        "severity": {
          "type": "string",
          "description": "Filter by severity: info, warning, error",
          "enum": ["info", "warning", "error"]
        },
        "query": {
          "type": "string",
          "description": "Full-text search query for search action"
        },
        "conversation_id": {
          "type": "string",
          "description": "Conversation UUID for conversation_detail"
        },
        "agent_id": {
          "type": "string",
          "description": "Agent UUID for conversations and agent_performance"
        },
        "trace_id": {
          "type": "string",
          "description": "Trace ID for trace action"
        },
        "span_id": {
          "type": "string",
          "description": "Span UUID for span_detail action"
        },
        "tool_name": {
          "type": "string",
          "description": "Filter by tool name for tool_analytics and tool_timeline"
        },
        "bucket_minutes": {
          "type": "integer",
          "description": "Bucket size in minutes for tool_timeline (default 15)"
        }
      },
      "required": ["action"]
    }
  }'::jsonb,
  true,
  false,
  true,
  true,
  'ops',
  'agent-chat'
)
ON CONFLICT (name) DO UPDATE SET
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  definition = EXCLUDED.definition,
  requires_store_id = EXCLUDED.requires_store_id,
  is_read_only = EXCLUDED.is_read_only,
  is_active = EXCLUDED.is_active,
  tool_mode = EXCLUDED.tool_mode,
  edge_function = EXCLUDED.edge_function;
