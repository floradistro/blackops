-- Add API key field to ai_agent_config
-- This allows each agent to have its own Anthropic API key

ALTER TABLE ai_agent_config
ADD COLUMN IF NOT EXISTS api_key TEXT;

-- Add comment for documentation
COMMENT ON COLUMN ai_agent_config.api_key IS 'Anthropic API key for this agent (encrypted in production)';
