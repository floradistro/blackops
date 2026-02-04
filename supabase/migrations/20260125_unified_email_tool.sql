-- Migration: Replace 4 basic email tools with unified email tool
-- Calls platform send-email edge function with templates support

-- Deactivate old email tools
UPDATE ai_tool_registry
SET is_active = false
WHERE name IN (
  'email_templates_list',
  'email_segments_list',
  'email_segments_create',
  'email_campaign_create'
);

-- Insert unified email tool (uses platform edge function)
INSERT INTO ai_tool_registry (
  name,
  category,
  description,
  definition,
  requires_store_id,
  requires_user_id,
  is_read_only,
  is_active,
  tool_mode
) VALUES (
  'email',
  'email',
  'Send emails via platform edge function with template support. Actions: send (raw email), send_template (use predefined template), list (view sent emails), get (email details), templates (list available templates).',
  '{
    "name": "email",
    "description": "Send and manage emails via platform edge function. Supports templates.",
    "input_schema": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "description": "Action: send, send_template, list, get, templates",
          "enum": ["send", "send_template", "list", "get", "templates"]
        },
        "to": {
          "type": "string",
          "description": "Email recipient (for send/send_template)"
        },
        "subject": {
          "type": "string",
          "description": "Email subject (for send action)"
        },
        "html": {
          "type": "string",
          "description": "HTML email body (for send action)"
        },
        "text": {
          "type": "string",
          "description": "Plain text email body (for send action)"
        },
        "template": {
          "type": "string",
          "description": "Template slug (for send_template action)"
        },
        "template_data": {
          "type": "object",
          "description": "Data to populate template variables"
        },
        "category": {
          "type": "string",
          "description": "Email category for tracking (e.g., order_confirmation, marketing)"
        },
        "from": {
          "type": "string",
          "description": "Sender email (optional)"
        },
        "reply_to": {
          "type": "string",
          "description": "Reply-to email address"
        },
        "email_id": {
          "type": "string",
          "description": "Email ID (for get action)"
        },
        "limit": {
          "type": "integer",
          "description": "Max results for list action (default 50)"
        },
        "status": {
          "type": "string",
          "description": "Filter by status for list action"
        }
      },
      "required": ["action"]
    }
  }'::jsonb,
  true,
  false,
  false,
  true,
  'local'
)
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  definition = EXCLUDED.definition,
  is_active = true,
  tool_mode = 'local';

-- Migrate agent enabled_tools: Replace old email tool references with unified 'email' tool
-- This updates the enabled_tools JSONB array in ai_agent_config
UPDATE ai_agent_config
SET enabled_tools = (
  SELECT jsonb_agg(DISTINCT tool)
  FROM (
    -- Keep non-email tools as-is
    SELECT tool
    FROM jsonb_array_elements_text(enabled_tools) AS tool
    WHERE tool NOT IN (
      'email_templates_list',
      'email_segments_list',
      'email_segments_create',
      'email_campaign_create'
    )
    UNION
    -- Add unified 'email' tool if any old email tool was present
    SELECT 'email'
    WHERE EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(enabled_tools) AS t
      WHERE t IN (
        'email_templates_list',
        'email_segments_list',
        'email_segments_create',
        'email_campaign_create'
      )
    )
  ) AS tools
)
WHERE enabled_tools IS NOT NULL
  AND enabled_tools @> '["email_templates_list"]'::jsonb
     OR enabled_tools @> '["email_segments_list"]'::jsonb
     OR enabled_tools @> '["email_segments_create"]'::jsonb
     OR enabled_tools @> '["email_campaign_create"]'::jsonb;