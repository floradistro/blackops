-- Create get_collection_by_slug RPC function
-- This function queries creation_collections and returns collection with its items

DROP FUNCTION IF EXISTS public.get_collection_by_slug(text);

CREATE OR REPLACE FUNCTION public.get_collection_by_slug(p_slug text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_collection record;
  v_items json;
  v_result json;
BEGIN
  -- Get collection by slug from creation_collections
  SELECT * INTO v_collection
  FROM creation_collections
  WHERE slug = p_slug
  LIMIT 1;

  -- If not found, return null
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Get items with their creations
  SELECT json_agg(
    json_build_object(
      'id', cci.id,
      'position', cci.position,
      'label', cci.label,
      'creation', json_build_object(
        'id', c.id,
        'name', c.name,
        'slug', c.slug,
        'status', c.status,
        'is_public', c.is_public,
        'visibility', c.visibility,
        'creation_type', c.creation_type,
        'display_mode', c.display_mode,
        'icon_url', c.icon_url,
        'thumbnail_url', c.thumbnail_url,
        'cover_image_url', c.cover_image_url,
        'react_code', c.react_code,
        'data_config', c.data_config,
        'theme_config', c.theme_config,
        'layout_config', c.layout_config,
        'location_id', c.location_id,
        'store_id', c.store_id
      )
    ) ORDER BY cci.position
  ) INTO v_items
  FROM creation_collection_items cci
  JOIN creations c ON c.id = cci.creation_id
  WHERE cci.collection_id = v_collection.id;

  -- Build final result
  v_result := json_build_object(
    'id', v_collection.id,
    'name', v_collection.name,
    'slug', v_collection.slug,
    'description', v_collection.description,
    'is_template', v_collection.is_template,
    'is_public', v_collection.is_public,
    'is_pinned', v_collection.is_pinned,
    'visibility', v_collection.visibility,
    'logo_url', v_collection.logo_url,
    'accent_color', v_collection.accent_color,
    'background_color', v_collection.background_color,
    'design_system', v_collection.design_system,
    'launcher_style', v_collection.launcher_style,
    'location_id', v_collection.location_id,
    'store_id', v_collection.store_id,
    'items', COALESCE(v_items, '[]'::json)
  );

  RETURN v_result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_collection_by_slug(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_collection_by_slug(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_collection_by_slug(text) TO service_role;
