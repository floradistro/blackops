-- Team Channels Setup: Create default channels for team communication
-- Created: 2026-01-19
-- Purpose: Discord-like channel structure with default channels per store

-- ============================================================================
-- 1. CREATE DEFAULT CHANNELS FOR EXISTING STORES
-- ============================================================================

-- Function to create default channels for a store
CREATE OR REPLACE FUNCTION public.create_default_channels_for_store(p_store_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only create if they don't exist already

  -- General team chat
  INSERT INTO lisa_conversations (store_id, title, chat_type, status, metadata)
  SELECT p_store_id, 'general', 'team', 'active', jsonb_build_object('is_default', true, 'description', 'General team discussion')
  WHERE NOT EXISTS (
    SELECT 1 FROM lisa_conversations
    WHERE store_id = p_store_id AND title = 'general' AND chat_type = 'team'
  );

  -- Bugs channel
  INSERT INTO lisa_conversations (store_id, title, chat_type, status, metadata)
  SELECT p_store_id, 'bugs', 'bugs', 'active', jsonb_build_object('is_default', true, 'description', 'Bug reports and issues')
  WHERE NOT EXISTS (
    SELECT 1 FROM lisa_conversations
    WHERE store_id = p_store_id AND title = 'bugs' AND chat_type = 'bugs'
  );

  -- Alerts channel
  INSERT INTO lisa_conversations (store_id, title, chat_type, status, metadata)
  SELECT p_store_id, 'alerts', 'alerts', 'active', jsonb_build_object('is_default', true, 'description', 'System alerts and notifications')
  WHERE NOT EXISTS (
    SELECT 1 FROM lisa_conversations
    WHERE store_id = p_store_id AND title = 'alerts' AND chat_type = 'alerts'
  );

  -- Announcements channel
  INSERT INTO lisa_conversations (store_id, title, chat_type, status, metadata)
  SELECT p_store_id, 'announcements', 'team', 'active', jsonb_build_object('is_default', true, 'description', 'Important team announcements')
  WHERE NOT EXISTS (
    SELECT 1 FROM lisa_conversations
    WHERE store_id = p_store_id AND title = 'announcements' AND chat_type = 'team'
  );

  -- Create location channels for each active location
  INSERT INTO lisa_conversations (store_id, location_id, title, chat_type, status, metadata)
  SELECT
    p_store_id,
    l.id,
    l.name,
    'location',
    'active',
    jsonb_build_object('is_default', true, 'description', 'Chat for ' || l.name || ' location')
  FROM locations l
  WHERE l.store_id = p_store_id
    AND l.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM lisa_conversations
      WHERE store_id = p_store_id AND location_id = l.id AND chat_type = 'location'
    );

END;
$$;

GRANT EXECUTE ON FUNCTION public.create_default_channels_for_store(uuid) TO authenticated;

-- ============================================================================
-- 2. CREATE DEFAULT CHANNELS FOR ALL EXISTING STORES
-- ============================================================================

DO $$
DECLARE
  v_store record;
BEGIN
  FOR v_store IN SELECT id FROM stores WHERE status = 'active' OR status IS NULL LOOP
    PERFORM create_default_channels_for_store(v_store.id);
  END LOOP;
END;
$$;

-- ============================================================================
-- 3. TRIGGER TO AUTO-CREATE CHANNELS FOR NEW STORES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trigger_create_default_channels()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM create_default_channels_for_store(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_store_created_create_channels ON stores;

CREATE TRIGGER on_store_created_create_channels
  AFTER INSERT ON stores
  FOR EACH ROW
  EXECUTE FUNCTION trigger_create_default_channels();

-- ============================================================================
-- 4. TRIGGER TO CREATE LOCATION CHANNEL WHEN NEW LOCATION IS ADDED
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trigger_create_location_channel()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.is_active = true THEN
    INSERT INTO lisa_conversations (store_id, location_id, title, chat_type, status, metadata)
    VALUES (
      NEW.store_id,
      NEW.id,
      NEW.name,
      'location',
      'active',
      jsonb_build_object('is_default', true, 'description', 'Chat for ' || NEW.name || ' location')
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_location_created_create_channel ON locations;

CREATE TRIGGER on_location_created_create_channel
  AFTER INSERT ON locations
  FOR EACH ROW
  EXECUTE FUNCTION trigger_create_location_channel();

-- ============================================================================
-- 5. HELPER FUNCTION TO GET CHANNELS GROUPED BY CATEGORY
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_store_channels_grouped(p_store_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'team_channels', (
      SELECT COALESCE(json_agg(row_to_json(c) ORDER BY c.title), '[]'::json)
      FROM lisa_conversations c
      WHERE c.store_id = p_store_id AND c.chat_type = 'team' AND c.status = 'active'
    ),
    'location_channels', (
      SELECT COALESCE(json_agg(row_to_json(c) ORDER BY c.title), '[]'::json)
      FROM lisa_conversations c
      WHERE c.store_id = p_store_id AND c.chat_type = 'location' AND c.status = 'active'
    ),
    'alert_channels', (
      SELECT COALESCE(json_agg(row_to_json(c) ORDER BY c.title), '[]'::json)
      FROM lisa_conversations c
      WHERE c.store_id = p_store_id AND c.chat_type IN ('alerts', 'bugs') AND c.status = 'active'
    ),
    'dm_channels', (
      SELECT COALESCE(json_agg(row_to_json(c) ORDER BY c.updated_at DESC), '[]'::json)
      FROM lisa_conversations c
      WHERE c.store_id = p_store_id AND c.chat_type = 'dm' AND c.status = 'active'
    ),
    'ai_channels', (
      SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json)
      FROM (
        SELECT c.*
        FROM lisa_conversations c
        WHERE c.store_id = p_store_id AND c.chat_type = 'ai' AND c.status = 'active'
        ORDER BY c.updated_at DESC
        LIMIT 10
      ) c
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_store_channels_grouped(uuid) TO authenticated;

-- ============================================================================
-- Summary:
-- ============================================================================
-- 1. create_default_channels_for_store(store_id) - Creates default channels
-- 2. trigger_create_default_channels()            - Auto-creates on new store
-- 3. trigger_create_location_channel()            - Auto-creates on new location
-- 4. get_store_channels_grouped(store_id)        - Gets channels grouped by type
