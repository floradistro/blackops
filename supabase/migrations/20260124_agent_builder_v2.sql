-- Agent Builder V2: Versioning, Templates, Conversations, Triggers, Safety
-- This migration adds production-grade features for the agent builder

-- ============================================================================
-- 1. AGENT VERSIONING & DEPLOYMENT
-- ============================================================================

-- Add deployment status to agents
ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived'));

ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;

ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS published_by UUID;

-- Version history table
CREATE TABLE IF NOT EXISTS ai_agent_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES ai_agent_config(id) ON DELETE CASCADE,
    version INT NOT NULL,
    config_snapshot JSONB NOT NULL,
    change_notes TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(agent_id, version)
);

-- Index for version lookups
CREATE INDEX IF NOT EXISTS idx_agent_versions_agent_id ON ai_agent_versions(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_versions_created_at ON ai_agent_versions(created_at DESC);

-- RLS for versions
ALTER TABLE ai_agent_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view versions for their store's agents" ON ai_agent_versions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM ai_agent_config a
            WHERE a.id = ai_agent_versions.agent_id
        )
    );

-- ============================================================================
-- 2. PROMPT TEMPLATES LIBRARY
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_prompt_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL, -- customer_service, sales, support, operations, custom
    industry VARCHAR(100), -- retail, restaurant, ecommerce, general
    content TEXT NOT NULL,
    variables JSONB DEFAULT '[]', -- [{name: "customer_name", type: "string", description: "Customer's first name"}]
    example_values JSONB DEFAULT '{}', -- {customer_name: "John"}
    is_system BOOLEAN DEFAULT false, -- true for built-in templates
    is_public BOOLEAN DEFAULT false, -- shareable across stores
    usage_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prompt_templates_store ON ai_prompt_templates(store_id);
CREATE INDEX IF NOT EXISTS idx_prompt_templates_category ON ai_prompt_templates(category);
CREATE INDEX IF NOT EXISTS idx_prompt_templates_system ON ai_prompt_templates(is_system);

-- RLS
ALTER TABLE ai_prompt_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view system templates and their store templates" ON ai_prompt_templates
    FOR SELECT USING (is_system = true OR store_id IS NULL OR store_id IN (
        SELECT id FROM stores -- Simplified, adjust based on your auth
    ));

CREATE POLICY "Users can manage their store templates" ON ai_prompt_templates
    FOR ALL USING (store_id IN (SELECT id FROM stores));

-- Insert default system templates
INSERT INTO ai_prompt_templates (id, name, description, category, industry, content, variables, is_system, is_public) VALUES
-- Customer Service
(gen_random_uuid(), 'Customer Service Agent', 'Friendly customer service representative', 'customer_service', 'general',
'You are {{agent_name}}, a helpful customer service representative for {{store_name}}.

Your role is to:
- Answer customer questions accurately and helpfully
- Help resolve issues with empathy and patience
- Provide product information and recommendations
- Process returns and exchanges when appropriate

Guidelines:
- Always be polite and professional
- If you don''t know something, admit it and offer to find out
- Never make promises you can''t keep
- Escalate to a human when necessary

Customer context:
{{#if customer}}
- Name: {{customer.name}}
- Loyalty tier: {{customer.tier}}
- Total orders: {{customer.order_count}}
{{/if}}',
'[{"name": "agent_name", "type": "string", "description": "Name of the AI agent", "default": "Alex"},
  {"name": "store_name", "type": "string", "description": "Name of the store"},
  {"name": "customer", "type": "object", "description": "Customer context object"}]',
true, true),

-- Sales Assistant
(gen_random_uuid(), 'Sales Assistant', 'Product expert focused on helping customers find what they need', 'sales', 'retail',
'You are {{agent_name}}, a knowledgeable sales assistant for {{store_name}}.

Your expertise:
- Deep knowledge of our product catalog
- Understanding of customer needs and preferences
- Ability to make personalized recommendations

Your approach:
- Ask clarifying questions to understand needs
- Suggest products that match requirements
- Highlight relevant features and benefits
- Mention current promotions when applicable
- Be honest about product limitations

{{#if products}}
Available products in context:
{{#each products}}
- {{this.name}}: ${{this.price}} - {{this.description}}
{{/each}}
{{/if}}',
'[{"name": "agent_name", "type": "string", "description": "Name of the AI agent", "default": "Sam"},
  {"name": "store_name", "type": "string", "description": "Name of the store"},
  {"name": "products", "type": "array", "description": "Array of product objects"}]',
true, true),

-- Order Support
(gen_random_uuid(), 'Order Support Specialist', 'Handles order inquiries, tracking, and issues', 'support', 'ecommerce',
'You are {{agent_name}}, an order support specialist for {{store_name}}.

Your responsibilities:
- Help customers track their orders
- Explain order status and estimated delivery
- Process order modifications when possible
- Handle shipping issues and delays
- Coordinate returns and refunds

Important policies:
- Orders can be modified within 1 hour of placement
- Refunds are processed within 5-7 business days
- Free shipping on orders over $50

{{#if order}}
Current order context:
- Order #: {{order.number}}
- Status: {{order.status}}
- Items: {{order.item_count}}
- Total: ${{order.total}}
{{/if}}',
'[{"name": "agent_name", "type": "string", "description": "Name of the AI agent", "default": "Jordan"},
  {"name": "store_name", "type": "string", "description": "Name of the store"},
  {"name": "order", "type": "object", "description": "Order context object"}]',
true, true),

-- Operations Assistant
(gen_random_uuid(), 'Operations Assistant', 'Internal assistant for inventory and operations tasks', 'operations', 'general',
'You are {{agent_name}}, an operations assistant for {{store_name}}.

Your capabilities:
- Check inventory levels across locations
- Generate reports on sales and performance
- Help with scheduling and logistics
- Answer questions about operational metrics

Guidelines:
- Provide accurate data from the system
- Highlight any concerning trends or issues
- Suggest optimizations when appropriate
- Keep responses concise and actionable

{{#if location}}
Current location: {{location.name}}
{{/if}}',
'[{"name": "agent_name", "type": "string", "description": "Name of the AI agent", "default": "Morgan"},
  {"name": "store_name", "type": "string", "description": "Name of the store"},
  {"name": "location", "type": "object", "description": "Location context object"}]',
true, true),

-- Concierge
(gen_random_uuid(), 'Personal Concierge', 'High-touch personalized service for VIP customers', 'customer_service', 'retail',
'You are {{agent_name}}, a personal concierge for {{store_name}}''s most valued customers.

Your mission:
- Provide exceptional, personalized service
- Anticipate needs before they''re expressed
- Offer exclusive access and early notifications
- Remember preferences and past interactions

VIP benefits you can offer:
- Priority shipping
- Early access to new products
- Personal shopping assistance
- Special event invitations

{{#if customer}}
VIP Customer Profile:
- Name: {{customer.name}}
- Member since: {{customer.member_since}}
- Preferences: {{customer.preferences}}
- Total lifetime value: ${{customer.ltv}}
{{/if}}',
'[{"name": "agent_name", "type": "string", "description": "Name of the AI agent", "default": "Victoria"},
  {"name": "store_name", "type": "string", "description": "Name of the store"},
  {"name": "customer", "type": "object", "description": "VIP customer context object"}]',
true, true)

ON CONFLICT DO NOTHING;

-- ============================================================================
-- 3. CONVERSATION SESSIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES ai_agent_config(id) ON DELETE CASCADE,
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    customer_id UUID,

    -- Conversation state
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'escalated', 'archived')),
    title VARCHAR(255),

    -- Messages stored as JSONB array
    -- [{role: "user", content: "...", timestamp: "..."}, {role: "assistant", content: "...", timestamp: "..."}]
    messages JSONB NOT NULL DEFAULT '[]',

    -- Metadata
    metadata JSONB DEFAULT '{}', -- {source: "test_panel", resolution: "answered", tags: []}

    -- Metrics
    turn_count INT DEFAULT 0,
    total_tokens INT DEFAULT 0,
    duration_ms INT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_conversations_agent ON ai_conversations(agent_id);
CREATE INDEX IF NOT EXISTS idx_conversations_store ON ai_conversations(store_id);
CREATE INDEX IF NOT EXISTS idx_conversations_customer ON ai_conversations(customer_id);
CREATE INDEX IF NOT EXISTS idx_conversations_status ON ai_conversations(status);
CREATE INDEX IF NOT EXISTS idx_conversations_created ON ai_conversations(created_at DESC);

-- RLS
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their store conversations" ON ai_conversations
    FOR SELECT USING (store_id IN (SELECT id FROM stores));

CREATE POLICY "Users can manage their store conversations" ON ai_conversations
    FOR ALL USING (store_id IN (SELECT id FROM stores));

-- ============================================================================
-- 4. EVENT TRIGGERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_agent_triggers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES ai_agent_config(id) ON DELETE CASCADE,
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,

    name VARCHAR(255) NOT NULL,
    description TEXT,

    -- Trigger type and configuration
    trigger_type VARCHAR(50) NOT NULL CHECK (trigger_type IN ('event', 'schedule', 'webhook', 'queue')),
    trigger_config JSONB NOT NULL,
    -- event: {event_name: "order.created", filters: {status: "pending"}}
    -- schedule: {cron: "0 9 * * *", timezone: "America/New_York"}
    -- webhook: {path: "/agents/xyz/trigger", method: "POST", auth_required: true}
    -- queue: {queue_id: "...", auto_process: true}

    -- Input template (what context to pass to agent)
    input_template TEXT,

    -- Execution settings
    is_active BOOLEAN DEFAULT true,
    max_executions_per_hour INT DEFAULT 100,
    last_triggered_at TIMESTAMPTZ,
    execution_count INT DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_triggers_agent ON ai_agent_triggers(agent_id);
CREATE INDEX IF NOT EXISTS idx_triggers_store ON ai_agent_triggers(store_id);
CREATE INDEX IF NOT EXISTS idx_triggers_type ON ai_agent_triggers(trigger_type);
CREATE INDEX IF NOT EXISTS idx_triggers_active ON ai_agent_triggers(is_active) WHERE is_active = true;

-- RLS
ALTER TABLE ai_agent_triggers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their store triggers" ON ai_agent_triggers
    FOR SELECT USING (store_id IN (SELECT id FROM stores));

CREATE POLICY "Users can manage their store triggers" ON ai_agent_triggers
    FOR ALL USING (store_id IN (SELECT id FROM stores));

-- ============================================================================
-- 5. SAFETY RULES & GUARDRAILS
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_safety_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID REFERENCES ai_agent_config(id) ON DELETE CASCADE, -- NULL = global rule
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,

    name VARCHAR(255) NOT NULL,
    description TEXT,

    -- Rule type and configuration
    rule_type VARCHAR(50) NOT NULL CHECK (rule_type IN (
        'content_filter',      -- Block certain content
        'rate_limit',          -- Limit executions
        'approval_required',   -- Human approval for actions
        'data_scope',          -- Limit data access
        'output_validation',   -- Validate response format
        'pii_masking',         -- Mask sensitive data
        'escalation'           -- When to escalate to human
    )),

    rule_config JSONB NOT NULL,
    -- content_filter: {blocked_words: [], blocked_topics: [], severity: "block"|"warn"}
    -- rate_limit: {max_per_minute: 10, max_per_hour: 100, per: "user"|"agent"|"store"}
    -- approval_required: {actions: ["modify_order", "issue_refund"], approvers: ["admin"]}
    -- data_scope: {allowed_tables: [], denied_columns: [], max_records: 100}
    -- output_validation: {max_length: 1000, required_fields: [], format: "json"|"text"}
    -- pii_masking: {fields: ["email", "phone", "ssn"], replacement: "***"}
    -- escalation: {triggers: ["sentiment_negative", "request_human"], target: "support_queue"}

    -- Rule behavior
    is_active BOOLEAN DEFAULT true,
    is_blocking BOOLEAN DEFAULT true, -- false = just log, don't block
    priority INT DEFAULT 0, -- Higher priority rules evaluated first

    -- Metrics
    trigger_count INT DEFAULT 0,
    last_triggered_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_safety_rules_agent ON ai_safety_rules(agent_id);
CREATE INDEX IF NOT EXISTS idx_safety_rules_store ON ai_safety_rules(store_id);
CREATE INDEX IF NOT EXISTS idx_safety_rules_type ON ai_safety_rules(rule_type);
CREATE INDEX IF NOT EXISTS idx_safety_rules_active ON ai_safety_rules(is_active) WHERE is_active = true;

-- RLS
ALTER TABLE ai_safety_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their store safety rules" ON ai_safety_rules
    FOR SELECT USING (store_id IN (SELECT id FROM stores) OR store_id IS NULL);

CREATE POLICY "Users can manage their store safety rules" ON ai_safety_rules
    FOR ALL USING (store_id IN (SELECT id FROM stores));

-- Insert default global safety rules
INSERT INTO ai_safety_rules (id, name, description, rule_type, rule_config, is_active, is_blocking, priority) VALUES
(gen_random_uuid(), 'Default Rate Limit', 'Prevent abuse with basic rate limiting', 'rate_limit',
 '{"max_per_minute": 20, "max_per_hour": 200, "per": "user"}', true, true, 100),

(gen_random_uuid(), 'Basic Content Filter', 'Block obviously harmful content', 'content_filter',
 '{"blocked_topics": ["violence", "illegal_activities", "hate_speech"], "severity": "block"}', true, true, 90),

(gen_random_uuid(), 'PII Protection', 'Mask sensitive personal information in logs', 'pii_masking',
 '{"fields": ["email", "phone", "credit_card", "ssn"], "replacement": "[REDACTED]"}', true, false, 80),

(gen_random_uuid(), 'Human Escalation', 'Escalate when customer requests human', 'escalation',
 '{"triggers": ["request_human", "frustrated_customer", "legal_mention"], "target": "support_queue"}', true, false, 70)

ON CONFLICT DO NOTHING;

-- ============================================================================
-- 6. ANALYTICS AGGREGATIONS
-- ============================================================================

-- Function to get agent analytics
CREATE OR REPLACE FUNCTION get_agent_analytics(
    p_agent_id UUID,
    p_days INT DEFAULT 7
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'summary', (
            SELECT jsonb_build_object(
                'total_conversations', COUNT(*),
                'total_messages', SUM(turn_count),
                'total_tokens', SUM(total_tokens),
                'avg_turns_per_conversation', ROUND(AVG(turn_count)::numeric, 1),
                'resolution_rate', ROUND(
                    (COUNT(*) FILTER (WHERE status = 'resolved')::numeric / NULLIF(COUNT(*), 0) * 100)::numeric, 1
                )
            )
            FROM ai_conversations
            WHERE agent_id = p_agent_id
            AND created_at > now() - (p_days || ' days')::interval
        ),
        'by_day', (
            SELECT jsonb_agg(day_stats ORDER BY day)
            FROM (
                SELECT
                    date_trunc('day', created_at)::date as day,
                    COUNT(*) as conversations,
                    SUM(turn_count) as messages,
                    SUM(total_tokens) as tokens
                FROM ai_conversations
                WHERE agent_id = p_agent_id
                AND created_at > now() - (p_days || ' days')::interval
                GROUP BY date_trunc('day', created_at)::date
            ) day_stats
        ),
        'by_status', (
            SELECT jsonb_object_agg(status, count)
            FROM (
                SELECT status, COUNT(*) as count
                FROM ai_conversations
                WHERE agent_id = p_agent_id
                AND created_at > now() - (p_days || ' days')::interval
                GROUP BY status
            ) status_stats
        ),
        'execution_traces', (
            SELECT jsonb_build_object(
                'total', COUNT(*),
                'success_rate', ROUND(
                    (COUNT(*) FILTER (WHERE success = true)::numeric / NULLIF(COUNT(*), 0) * 100)::numeric, 1
                ),
                'avg_duration_ms', ROUND(AVG(duration_ms)::numeric, 0),
                'avg_tool_calls', ROUND(AVG(tool_calls)::numeric, 1),
                'total_input_tokens', SUM(input_tokens),
                'total_output_tokens', SUM(output_tokens)
            )
            FROM agent_execution_traces
            WHERE agent_id = p_agent_id
            AND created_at > now() - (p_days || ' days')::interval
        )
    ) INTO result;

    RETURN result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_agent_analytics TO authenticated;

-- ============================================================================
-- 7. HELPER FUNCTIONS
-- ============================================================================

-- Function to publish an agent (creates version snapshot)
CREATE OR REPLACE FUNCTION publish_agent(
    p_agent_id UUID,
    p_change_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_version INT;
    v_config JSONB;
    v_result JSONB;
BEGIN
    -- Get next version number
    SELECT COALESCE(MAX(version), 0) + 1 INTO v_version
    FROM ai_agent_versions
    WHERE agent_id = p_agent_id;

    -- Get current config as snapshot
    SELECT to_jsonb(a.*) INTO v_config
    FROM ai_agent_config a
    WHERE a.id = p_agent_id;

    IF v_config IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Agent not found');
    END IF;

    -- Create version record
    INSERT INTO ai_agent_versions (agent_id, version, config_snapshot, change_notes)
    VALUES (p_agent_id, v_version, v_config, p_change_notes);

    -- Update agent status
    UPDATE ai_agent_config
    SET status = 'published',
        published_at = now(),
        version = v_version,
        updated_at = now()
    WHERE id = p_agent_id;

    RETURN jsonb_build_object(
        'success', true,
        'version', v_version,
        'published_at', now()
    );
END;
$$;

-- Function to rollback to a previous version
CREATE OR REPLACE FUNCTION rollback_agent(
    p_agent_id UUID,
    p_version INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_snapshot JSONB;
BEGIN
    -- Get the version snapshot
    SELECT config_snapshot INTO v_snapshot
    FROM ai_agent_versions
    WHERE agent_id = p_agent_id AND version = p_version;

    IF v_snapshot IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Version not found');
    END IF;

    -- Restore the config (excluding id, store_id, created_at)
    UPDATE ai_agent_config
    SET name = v_snapshot->>'name',
        description = v_snapshot->>'description',
        system_prompt = v_snapshot->>'system_prompt',
        model = v_snapshot->>'model',
        max_tokens = (v_snapshot->>'max_tokens')::int,
        max_tool_calls = (v_snapshot->>'max_tool_calls')::int,
        icon = v_snapshot->>'icon',
        accent_color = v_snapshot->>'accent_color',
        enabled_tools = v_snapshot->'enabled_tools',
        context_config = v_snapshot->'context_config',
        temperature = (v_snapshot->>'temperature')::double precision,
        tone = v_snapshot->>'tone',
        verbosity = v_snapshot->>'verbosity',
        can_query = (v_snapshot->>'can_query')::boolean,
        can_send = (v_snapshot->>'can_send')::boolean,
        can_modify = (v_snapshot->>'can_modify')::boolean,
        status = 'draft',
        updated_at = now()
    WHERE id = p_agent_id;

    RETURN jsonb_build_object(
        'success', true,
        'rolled_back_to_version', p_version
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION publish_agent TO authenticated;
GRANT EXECUTE ON FUNCTION rollback_agent TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE ai_agent_versions IS 'Version history for AI agents with full config snapshots';
COMMENT ON TABLE ai_prompt_templates IS 'Reusable prompt templates with variable support';
COMMENT ON TABLE ai_conversations IS 'Conversation sessions between agents and users';
COMMENT ON TABLE ai_agent_triggers IS 'Event/schedule/webhook triggers for agent execution';
COMMENT ON TABLE ai_safety_rules IS 'Safety guardrails and content filtering rules';
COMMENT ON FUNCTION get_agent_analytics IS 'Get comprehensive analytics for an agent';
COMMENT ON FUNCTION publish_agent IS 'Publish an agent, creating a version snapshot';
COMMENT ON FUNCTION rollback_agent IS 'Rollback an agent to a previous version';
