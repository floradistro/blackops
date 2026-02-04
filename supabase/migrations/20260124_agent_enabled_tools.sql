-- Add enabled_tools JSONB column to ai_agent_config
-- Stores array of tool IDs that the agent can use

ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS enabled_tools JSONB DEFAULT '[]'::jsonb;

-- Add context_config for storing context data (products, locations, customer segments)
ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS context_config JSONB DEFAULT '{}'::jsonb;

-- Add personality settings
ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS temperature DOUBLE PRECISION DEFAULT 0.7;

ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS tone VARCHAR(50) DEFAULT 'professional';

ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS verbosity VARCHAR(50) DEFAULT 'moderate';

-- Add capability flags
ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS can_query BOOLEAN DEFAULT true;

ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS can_send BOOLEAN DEFAULT false;

ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS can_modify BOOLEAN DEFAULT false;

-- Comment on columns
COMMENT ON COLUMN ai_agent_config.enabled_tools IS 'Array of tool IDs (UUIDs) from ai_tool_registry that this agent can use';
COMMENT ON COLUMN ai_agent_config.context_config IS 'JSON config for context data access (products, locations, customers)';
COMMENT ON COLUMN ai_agent_config.temperature IS 'Claude temperature setting (0-1)';
COMMENT ON COLUMN ai_agent_config.tone IS 'Agent tone: friendly, professional, formal, casual';
COMMENT ON COLUMN ai_agent_config.verbosity IS 'Response verbosity: concise, moderate, detailed';
