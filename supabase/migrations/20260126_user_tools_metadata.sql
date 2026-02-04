-- Migration: Add metadata columns for user-extensible fields
-- Allows users to add custom fields without schema changes

-- Add metadata to user_tools
ALTER TABLE user_tools
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- Add metadata to user_triggers
ALTER TABLE user_triggers
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- Add metadata to trigger_queue for custom execution context
ALTER TABLE trigger_queue
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- Create index for efficient JSONB queries on metadata
CREATE INDEX IF NOT EXISTS idx_user_tools_metadata ON user_tools USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_user_triggers_metadata ON user_triggers USING gin(metadata);

-- Add tags array for categorization/filtering
ALTER TABLE user_tools
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

ALTER TABLE user_triggers
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- Create GIN index for array containment queries
CREATE INDEX IF NOT EXISTS idx_user_tools_tags ON user_tools USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_user_triggers_tags ON user_triggers USING gin(tags);

-- Update the get_user_tools function to include metadata and tags
CREATE OR REPLACE FUNCTION get_user_tools(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', id,
                'name', name,
                'display_name', display_name,
                'description', description,
                'category', category,
                'icon', icon,
                'input_schema', input_schema,
                'execution_type', execution_type,
                'is_read_only', is_read_only,
                'requires_approval', requires_approval,
                'metadata', COALESCE(metadata, '{}'::jsonb),
                'tags', COALESCE(tags, '{}'::text[])
            )
        ), '[]'::jsonb)
        FROM user_tools
        WHERE store_id = p_store_id AND is_active = true
    );
END;
$$;

-- Helper function to update metadata (merge, not replace)
CREATE OR REPLACE FUNCTION update_tool_metadata(
    p_tool_id UUID,
    p_metadata JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE user_tools
    SET metadata = COALESCE(metadata, '{}'::jsonb) || p_metadata,
        updated_at = now()
    WHERE id = p_tool_id
    RETURNING metadata INTO v_result;

    RETURN v_result;
END;
$$;

-- Helper function to update trigger metadata (merge, not replace)
CREATE OR REPLACE FUNCTION update_trigger_metadata(
    p_trigger_id UUID,
    p_metadata JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE user_triggers
    SET metadata = COALESCE(metadata, '{}'::jsonb) || p_metadata,
        updated_at = now()
    WHERE id = p_trigger_id
    RETURNING metadata INTO v_result;

    RETURN v_result;
END;
$$;

-- Function to search tools by tag
CREATE OR REPLACE FUNCTION get_tools_by_tag(
    p_store_id UUID,
    p_tag TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
        FROM user_tools t
        WHERE store_id = p_store_id
          AND is_active = true
          AND p_tag = ANY(tags)
    );
END;
$$;

-- Function to search tools by metadata key/value
CREATE OR REPLACE FUNCTION get_tools_by_metadata(
    p_store_id UUID,
    p_key TEXT,
    p_value TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
        FROM user_tools t
        WHERE store_id = p_store_id
          AND is_active = true
          AND metadata->>p_key = p_value
    );
END;
$$;

COMMENT ON COLUMN user_tools.metadata IS 'User-defined custom fields as JSON. Use update_tool_metadata() to merge updates.';
COMMENT ON COLUMN user_tools.tags IS 'Array of tags for categorization and filtering. Query with @> operator.';
COMMENT ON COLUMN user_triggers.metadata IS 'User-defined custom fields as JSON. Use update_trigger_metadata() to merge updates.';
COMMENT ON COLUMN user_triggers.tags IS 'Array of tags for categorization and filtering. Query with @> operator.';
