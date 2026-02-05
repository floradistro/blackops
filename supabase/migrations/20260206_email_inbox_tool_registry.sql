-- Migration: Update email tool registry with inbox actions
-- Created: 2026-02-06
-- Purpose: Add inbox actions to the unified email tool definition

UPDATE ai_tool_registry
SET definition = '{
  "name": "email",
  "description": "Send and manage emails. Includes AI-powered inbox for inbound email handling.",
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "description": "Action to perform",
        "enum": ["send", "send_template", "list", "get", "templates", "inbox", "inbox_get", "inbox_reply", "inbox_update", "inbox_stats"]
      },
      "to": {
        "type": "string",
        "description": "Email recipient (for send/send_template)"
      },
      "subject": {
        "type": "string",
        "description": "Email subject (for send)"
      },
      "html": {
        "type": "string",
        "description": "HTML email body (for send, inbox_reply)"
      },
      "text": {
        "type": "string",
        "description": "Plain text body (for send, inbox_reply)"
      },
      "template": {
        "type": "string",
        "description": "Template slug (for send_template)"
      },
      "template_data": {
        "type": "object",
        "description": "Data for template variables"
      },
      "category": {
        "type": "string",
        "description": "Email category for tracking"
      },
      "from": {
        "type": "string",
        "description": "Sender email (optional)"
      },
      "reply_to": {
        "type": "string",
        "description": "Reply-to address"
      },
      "email_id": {
        "type": "string",
        "description": "Email ID (for get)"
      },
      "thread_id": {
        "type": "string",
        "description": "Thread ID (for inbox_get, inbox_reply, inbox_update)"
      },
      "mailbox": {
        "type": "string",
        "description": "Filter by mailbox: support, orders, returns, info, general (for inbox)"
      },
      "status": {
        "type": "string",
        "description": "Filter by status (for list, inbox)"
      },
      "priority": {
        "type": "string",
        "description": "Filter by or set priority: low, normal, high, urgent (for inbox, inbox_update)"
      },
      "intent": {
        "type": "string",
        "description": "AI-classified intent (for inbox_update)"
      },
      "ai_summary": {
        "type": "string",
        "description": "Thread summary (for inbox_update)"
      },
      "limit": {
        "type": "integer",
        "description": "Max results (default 25 for inbox, 50 for list)"
      }
    },
    "required": ["action"]
  }
}'::jsonb,
description = 'Send emails and manage AI-powered inbox. Actions: send, send_template, list, get, templates (outbound); inbox, inbox_get, inbox_reply, inbox_update, inbox_stats (inbound)'
WHERE name = 'email';
