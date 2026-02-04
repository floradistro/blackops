-- Migration: API Tools with Batch Config Support
-- Date: 2026-01-30
-- Description: Enhances user_tools to support API templates, batch processing, and secret management

-- ============================================================================
-- 1. Update user_tools table to ensure http_config supports new fields
-- ============================================================================

-- The http_config JSONB column already exists and can store:
-- {
--   "url": "https://api.example.com",
--   "method": "POST",
--   "headers": {"Authorization": "Bearer {{API_KEY}}"},
--   "body_template": {...},
--   "query_params": {...},
--   "batch_config": {
--     "enabled": true,
--     "max_concurrent": 5,
--     "delay_between_ms": 100,
--     "batch_size": 10,
--     "input_array_path": "images",
--     "retry_on_failure": true,
--     "continue_on_error": true
--   },
--   "response_mapping": {
--     "result_path": "data.url",
--     "error_path": "error.message",
--     "success_condition": "status == 200"
--   }
-- }

-- Add template_id column to track which template was used
ALTER TABLE user_tools
ADD COLUMN IF NOT EXISTS template_id TEXT;

COMMENT ON COLUMN user_tools.template_id IS 'API template identifier (remove_bg, openai_images, etc.)';

-- ============================================================================
-- 2. Create user_tool_secrets table for encrypted API keys
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_tool_secrets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    tool_id UUID REFERENCES user_tools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    encrypted_value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, name)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_tool_secrets_store ON user_tool_secrets(store_id);
CREATE INDEX IF NOT EXISTS idx_user_tool_secrets_tool ON user_tool_secrets(tool_id);

-- RLS policies
ALTER TABLE user_tool_secrets ENABLE ROW LEVEL SECURITY;

-- Users can only access secrets for their store
CREATE POLICY "Users can view their store secrets" ON user_tool_secrets
    FOR SELECT USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert secrets for their store" ON user_tool_secrets
    FOR INSERT WITH CHECK (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their store secrets" ON user_tool_secrets
    FOR UPDATE USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their store secrets" ON user_tool_secrets
    FOR DELETE USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- 3. Create function to execute HTTP tools with secret injection
-- ============================================================================

CREATE OR REPLACE FUNCTION execute_http_tool(
    p_store_id UUID,
    p_tool_id UUID,
    p_input JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tool RECORD;
    v_config JSONB;
    v_url TEXT;
    v_headers JSONB;
    v_body JSONB;
    v_secrets JSONB;
    v_result JSONB;
BEGIN
    -- Get the tool configuration
    SELECT * INTO v_tool
    FROM user_tools
    WHERE id = p_tool_id AND store_id = p_store_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Tool not found or inactive');
    END IF;

    IF v_tool.execution_type != 'http' THEN
        RETURN jsonb_build_object('error', 'Tool is not an HTTP tool');
    END IF;

    v_config := v_tool.http_config;

    -- Get all secrets for this store
    SELECT jsonb_object_agg(name, encrypted_value) INTO v_secrets
    FROM user_tool_secrets
    WHERE store_id = p_store_id;

    -- The actual HTTP call would be made via an Edge Function
    -- This function prepares the configuration with secrets injected
    RETURN jsonb_build_object(
        'config', v_config,
        'input', p_input,
        'secrets_available', COALESCE(v_secrets, '{}'::jsonb) IS NOT NULL,
        'batch_enabled', COALESCE(v_config->'batch_config'->>'enabled', 'false')::boolean
    );
END;
$$;

-- ============================================================================
-- 4. Create batch execution tracking table
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_tool_batch_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    tool_id UUID NOT NULL REFERENCES user_tools(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed', 'partial')),
    total_items INT NOT NULL DEFAULT 0,
    completed_items INT NOT NULL DEFAULT 0,
    failed_items INT NOT NULL DEFAULT 0,
    input_data JSONB,
    results JSONB,
    errors JSONB,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_batch_executions_store ON user_tool_batch_executions(store_id);
CREATE INDEX IF NOT EXISTS idx_batch_executions_tool ON user_tool_batch_executions(tool_id);
CREATE INDEX IF NOT EXISTS idx_batch_executions_status ON user_tool_batch_executions(status);

-- RLS policies
ALTER TABLE user_tool_batch_executions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their batch executions" ON user_tool_batch_executions
    FOR SELECT USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert batch executions" ON user_tool_batch_executions
    FOR INSERT WITH CHECK (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their batch executions" ON user_tool_batch_executions
    FOR UPDATE USING (
        store_id IN (
            SELECT store_id FROM store_users
            WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- 5. Helper function to save/update secrets
-- ============================================================================

CREATE OR REPLACE FUNCTION upsert_tool_secret(
    p_store_id UUID,
    p_tool_id UUID,
    p_name TEXT,
    p_value TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO user_tool_secrets (store_id, tool_id, name, encrypted_value)
    VALUES (p_store_id, p_tool_id, p_name, p_value)
    ON CONFLICT (store_id, name)
    DO UPDATE SET
        encrypted_value = EXCLUDED.encrypted_value,
        tool_id = EXCLUDED.tool_id,
        updated_at = NOW();

    RETURN jsonb_build_object('success', true, 'name', p_name);
END;
$$;

-- ============================================================================
-- 6. Add common API templates as reference data
-- ============================================================================

CREATE TABLE IF NOT EXISTS api_templates (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL,
    icon TEXT,
    default_config JSONB NOT NULL,
    required_secrets TEXT[] NOT NULL DEFAULT '{}',
    supports_batch BOOLEAN DEFAULT false,
    default_input_schema JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default templates
INSERT INTO api_templates (id, display_name, description, category, icon, default_config, required_secrets, supports_batch, default_input_schema)
VALUES
    ('remove_bg', 'Remove.bg', 'Remove backgrounds from images automatically', 'images', 'person.crop.rectangle',
     '{"url": "https://api.remove.bg/v1.0/removebg", "method": "POST", "headers": {"X-Api-Key": "{{REMOVEBG_API_KEY}}"}, "body_template": {"image_url": "{{image_url}}", "size": "auto", "format": "png"}, "batch_config": {"enabled": false, "max_concurrent": 5, "delay_between_ms": 200, "batch_size": 10, "input_array_path": "image_urls"}, "response_mapping": {"result_path": "data", "error_path": "errors[0].title"}}',
     ARRAY['REMOVEBG_API_KEY'], true,
     '{"type": "object", "properties": {"image_url": {"type": "string", "description": "URL of the image to process"}, "image_urls": {"type": "array", "description": "Array of image URLs for batch processing"}}, "required": ["image_url"]}'),

    ('openai_images', 'OpenAI Images', 'Generate images with DALL-E 3', 'images', 'photo.artframe',
     '{"url": "https://api.openai.com/v1/images/generations", "method": "POST", "headers": {"Authorization": "Bearer {{OPENAI_API_KEY}}", "Content-Type": "application/json"}, "body_template": {"model": "dall-e-3", "prompt": "{{prompt}}", "n": 1, "size": "1024x1024", "quality": "standard"}, "batch_config": {"enabled": false, "max_concurrent": 3, "delay_between_ms": 500, "batch_size": 5, "input_array_path": "prompts"}, "response_mapping": {"result_path": "data[0].url", "error_path": "error.message"}}',
     ARRAY['OPENAI_API_KEY'], true,
     '{"type": "object", "properties": {"prompt": {"type": "string", "description": "Image generation prompt"}, "prompts": {"type": "array", "description": "Array of prompts for batch generation"}, "size": {"type": "string", "description": "Image size", "enum": ["1024x1024", "1792x1024", "1024x1792"]}, "quality": {"type": "string", "description": "Image quality", "enum": ["standard", "hd"]}}, "required": ["prompt"]}'),

    ('gemini_images', 'Gemini Images', 'Generate images with Google Gemini', 'images', 'photo.artframe',
     '{"url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent", "method": "POST", "headers": {"Content-Type": "application/json"}, "query_params": {"key": "{{GEMINI_API_KEY}}"}, "body_template": {"contents": [{"parts": [{"text": "{{prompt}}"}]}], "generationConfig": {"responseModalities": ["IMAGE", "TEXT"]}}, "batch_config": {"enabled": false, "max_concurrent": 3, "delay_between_ms": 500, "batch_size": 5, "input_array_path": "prompts"}, "response_mapping": {"result_path": "candidates[0].content.parts", "error_path": "error.message"}}',
     ARRAY['GEMINI_API_KEY'], true,
     '{"type": "object", "properties": {"prompt": {"type": "string", "description": "Image generation prompt"}, "prompts": {"type": "array", "description": "Array of prompts for batch generation"}}, "required": ["prompt"]}'),

    ('stability', 'Stability AI', 'Generate images with Stable Diffusion', 'images', 'photo.artframe',
     '{"url": "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image", "method": "POST", "headers": {"Authorization": "Bearer {{STABILITY_API_KEY}}", "Content-Type": "application/json"}, "body_template": {"text_prompts": [{"text": "{{prompt}}", "weight": 1}], "cfg_scale": 7, "height": 1024, "width": 1024, "samples": 1, "steps": 30}, "batch_config": {"enabled": false, "max_concurrent": 2, "delay_between_ms": 1000, "batch_size": 5, "input_array_path": "prompts"}, "response_mapping": {"result_path": "artifacts[0].base64", "error_path": "message"}}',
     ARRAY['STABILITY_API_KEY'], true,
     '{"type": "object", "properties": {"prompt": {"type": "string", "description": "Image generation prompt"}, "prompts": {"type": "array", "description": "Array of prompts for batch"}, "negative_prompt": {"type": "string", "description": "What to avoid"}}, "required": ["prompt"]}'),

    ('resend', 'Resend Email', 'Send transactional emails', 'email', 'envelope',
     '{"url": "https://api.resend.com/emails", "method": "POST", "headers": {"Authorization": "Bearer {{RESEND_API_KEY}}", "Content-Type": "application/json"}, "body_template": {"from": "{{from_email}}", "to": "{{to_email}}", "subject": "{{subject}}", "html": "{{html_body}}"}, "batch_config": {"enabled": false, "max_concurrent": 10, "delay_between_ms": 50, "batch_size": 50, "input_array_path": "recipients"}, "response_mapping": {"result_path": "id", "error_path": "message"}}',
     ARRAY['RESEND_API_KEY'], true,
     '{"type": "object", "properties": {"from_email": {"type": "string"}, "to_email": {"type": "string"}, "recipients": {"type": "array"}, "subject": {"type": "string"}, "html_body": {"type": "string"}}, "required": ["from_email", "to_email", "subject", "html_body"]}')
ON CONFLICT (id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    default_config = EXCLUDED.default_config,
    required_secrets = EXCLUDED.required_secrets,
    supports_batch = EXCLUDED.supports_batch,
    default_input_schema = EXCLUDED.default_input_schema;

-- Grant access to api_templates
GRANT SELECT ON api_templates TO authenticated;

COMMENT ON TABLE api_templates IS 'Pre-configured API templates for common services';
COMMENT ON TABLE user_tool_secrets IS 'Encrypted API keys and secrets for HTTP tools';
COMMENT ON TABLE user_tool_batch_executions IS 'Tracking for batch/bulk tool executions';
