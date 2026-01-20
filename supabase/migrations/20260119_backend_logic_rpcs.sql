-- Backend Logic Migration: Move business logic from Swift to Supabase
-- Created: 2026-01-19
-- Purpose: Reduce client-side complexity, improve performance
-- FIXED: Updated table names and column types to match actual schema

-- ============================================================================
-- 1. GET ALL STORE CONVERSATIONS
-- Replaces: ChatService.swift:56-84 (sequential loop + deduplication)
-- Impact: 3+ API calls → 1 query
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_all_store_conversations(uuid);

CREATE OR REPLACE FUNCTION public.get_all_store_conversations(p_store_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_agg(row_to_json(subq) ORDER BY subq.updated_at DESC)
  INTO v_result
  FROM (
    SELECT DISTINCT c.id, c.store_id, c.location_id, c.title, c.chat_type,
           c.status, c.created_at, c.updated_at, c.metadata
    FROM lisa_conversations c
    WHERE c.store_id = p_store_id

    UNION

    SELECT DISTINCT c.id, c.store_id, c.location_id, c.title, c.chat_type,
           c.status, c.created_at, c.updated_at, c.metadata
    FROM lisa_conversations c
    JOIN locations l ON c.location_id = l.id
    WHERE l.store_id = p_store_id
  ) subq;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_store_conversations(uuid) TO authenticated;

-- ============================================================================
-- 2. GET ALL COLLECTION ITEMS (with creations)
-- Replaces: CreationStore.swift:88-93 (N+1 query pattern)
-- Impact: N queries → 1 query
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_all_collection_items();

CREATE OR REPLACE FUNCTION public.get_all_collection_items()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_object_agg(
    collection_id::text,
    creation_ids
  )
  INTO v_result
  FROM (
    SELECT
      collection_id,
      json_agg(creation_id ORDER BY position) as creation_ids
    FROM creation_collection_items
    GROUP BY collection_id
  ) grouped;

  RETURN COALESCE(v_result, '{}'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_collection_items() TO authenticated;

-- ============================================================================
-- 3. ASSIGN CATEGORIES TO CATALOG (atomic batch)
-- Replaces: CatalogService.swift:112-141 (N+1 update loop)
-- Impact: N updates → 1 atomic transaction
-- ============================================================================

DROP FUNCTION IF EXISTS public.assign_categories_to_catalog(uuid, uuid, boolean);

CREATE OR REPLACE FUNCTION public.assign_categories_to_catalog(
  p_catalog_id uuid,
  p_store_id uuid,
  p_orphans_only boolean DEFAULT true
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated_count integer;
BEGIN
  IF p_orphans_only THEN
    -- Only update categories without a catalog_id
    UPDATE categories
    SET catalog_id = p_catalog_id,
        updated_at = NOW()
    WHERE store_id = p_store_id
      AND catalog_id IS NULL
      AND is_active = true;
  ELSE
    -- Update ALL categories for this store
    UPDATE categories
    SET catalog_id = p_catalog_id,
        updated_at = NOW()
    WHERE store_id = p_store_id
      AND is_active = true;
  END IF;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  RETURN v_updated_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_categories_to_catalog(uuid, uuid, boolean) TO authenticated;

-- ============================================================================
-- 4. GET PRODUCT EDITOR DATA
-- Replaces: EditorStore+ProductEditor.swift:18-73 (3+ sequential queries)
-- Impact: 3 queries → 1 query
-- FIXED: Use 'inventory' table not 'inventory_products'
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_product_editor_data(uuid);

CREATE OR REPLACE FUNCTION public.get_product_editor_data(p_product_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_product record;
  v_field_schemas json;
  v_pricing_schema_name text;
  v_stock_by_location json;
  v_result json;
BEGIN
  -- Get product basic info
  SELECT * INTO v_product
  FROM products
  WHERE id = p_product_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Get field schemas for product's category
  IF v_product.primary_category_id IS NOT NULL THEN
    SELECT json_agg(fs.*)
    INTO v_field_schemas
    FROM field_schemas fs
    JOIN category_field_schemas cfs ON fs.id = cfs.field_schema_id
    WHERE cfs.category_id = v_product.primary_category_id
      AND fs.is_active = true;
  END IF;

  -- Get pricing schema name
  IF v_product.pricing_schema_id IS NOT NULL THEN
    SELECT name INTO v_pricing_schema_name
    FROM pricing_schemas
    WHERE id = v_product.pricing_schema_id;
  END IF;

  -- Get stock by location (using correct table: inventory)
  SELECT json_agg(
    json_build_object(
      'location_name', l.name,
      'quantity', inv.quantity
    ) ORDER BY l.name
  )
  INTO v_stock_by_location
  FROM inventory inv
  JOIN locations l ON inv.location_id = l.id
  WHERE inv.product_id = p_product_id;

  -- Build result
  v_result := json_build_object(
    'field_schemas', COALESCE(v_field_schemas, '[]'::json),
    'pricing_schema_name', v_pricing_schema_name,
    'stock_by_location', COALESCE(v_stock_by_location, '[]'::json)
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_product_editor_data(uuid) TO authenticated;

-- ============================================================================
-- 5. GET CATEGORY DESCENDANTS (recursive)
-- Replaces: EditorStore+CategoryHierarchy.swift:25-54 (recursive in-memory)
-- Impact: Client recursion → SQL WITH RECURSIVE
-- FIXED: Use is_active instead of deleted_at
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_category_descendants(uuid);

CREATE OR REPLACE FUNCTION public.get_category_descendants(p_category_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  WITH RECURSIVE category_tree AS (
    -- Base case: the category itself
    SELECT id, parent_id, name, 0 as depth
    FROM categories
    WHERE id = p_category_id
      AND is_active = true

    UNION ALL

    -- Recursive case: children
    SELECT c.id, c.parent_id, c.name, ct.depth + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
    WHERE c.is_active = true
  )
  SELECT json_agg(
    json_build_object(
      'id', id,
      'name', name,
      'depth', depth
    ) ORDER BY depth, name
  )
  INTO v_result
  FROM category_tree
  WHERE id != p_category_id; -- Exclude the root category itself

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_category_descendants(uuid) TO authenticated;

-- ============================================================================
-- 6. GET PRODUCTS IN CATEGORY TREE
-- Replaces: productsInCategoryTree in EditorStore+CategoryHierarchy.swift
-- Impact: In-memory filter → Single SQL query
-- FIXED: Use is_active for categories, status for products
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_products_in_category_tree(uuid);

CREATE OR REPLACE FUNCTION public.get_products_in_category_tree(p_category_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  WITH RECURSIVE category_tree AS (
    SELECT id FROM categories WHERE id = p_category_id AND is_active = true
    UNION ALL
    SELECT c.id FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
    WHERE c.is_active = true
  )
  SELECT json_agg(p.*)
  INTO v_result
  FROM products p
  WHERE p.primary_category_id IN (SELECT id FROM category_tree)
    AND p.status != 'trash';

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_products_in_category_tree(uuid) TO authenticated;

-- ============================================================================
-- 7. CATEGORY PRODUCT COUNTS VIEW
-- Replaces: directProductCount/totalProductCount in EditorStore
-- Impact: Client-side counting → Materialized or regular view
-- FIXED: Use is_active for categories, status for products
-- ============================================================================

DROP VIEW IF EXISTS public.v_category_product_counts;

CREATE OR REPLACE VIEW public.v_category_product_counts AS
WITH RECURSIVE category_tree AS (
  SELECT id, id as root_id
  FROM categories
  WHERE is_active = true

  UNION ALL

  SELECT c.id, ct.root_id
  FROM categories c
  JOIN category_tree ct ON c.parent_id = ct.id
  WHERE c.is_active = true
)
SELECT
  c.id,
  c.name,
  COUNT(DISTINCT p_direct.id) as direct_count,
  COUNT(DISTINCT p_tree.id) as total_count
FROM categories c
LEFT JOIN products p_direct ON p_direct.primary_category_id = c.id AND p_direct.status != 'trash'
LEFT JOIN category_tree ct ON ct.root_id = c.id
LEFT JOIN products p_tree ON p_tree.primary_category_id = ct.id AND p_tree.status != 'trash'
WHERE c.is_active = true
GROUP BY c.id, c.name;

GRANT SELECT ON public.v_category_product_counts TO authenticated;

-- ============================================================================
-- 8. GET CREATION STATISTICS
-- Replaces: CreationService.swift:237-254 (loop aggregation)
-- Impact: Loop aggregation → Single GROUP BY query
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_creation_statistics();

CREATE OR REPLACE FUNCTION public.get_creation_statistics()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total integer;
  v_by_type json;
  v_by_status json;
BEGIN
  -- Get total count
  SELECT COUNT(*) INTO v_total
  FROM creations
  WHERE deleted_at IS NULL;

  -- Get counts by type
  SELECT json_object_agg(creation_type, cnt)
  INTO v_by_type
  FROM (
    SELECT creation_type, COUNT(*) as cnt
    FROM creations
    WHERE deleted_at IS NULL
    GROUP BY creation_type
  ) t;

  -- Get counts by status
  SELECT json_object_agg(status, cnt)
  INTO v_by_status
  FROM (
    SELECT status, COUNT(*) as cnt
    FROM creations
    WHERE deleted_at IS NULL AND status IS NOT NULL
    GROUP BY status
  ) s;

  RETURN json_build_object(
    'total', v_total,
    'by_type', COALESCE(v_by_type, '{}'::json),
    'by_status', COALESCE(v_by_status, '{}'::json)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creation_statistics() TO authenticated;

-- ============================================================================
-- 9. ORPHAN CREATIONS VIEW
-- Replaces: CreationStore.swift:53-56 (client-side set filtering)
-- Impact: Client filter → Database view
-- ============================================================================

DROP VIEW IF EXISTS public.v_orphan_creations;

CREATE OR REPLACE VIEW public.v_orphan_creations AS
SELECT c.*
FROM creations c
WHERE c.deleted_at IS NULL
  AND c.id NOT IN (
    SELECT DISTINCT creation_id
    FROM creation_collection_items
  );

GRANT SELECT ON public.v_orphan_creations TO authenticated;

-- ============================================================================
-- 10. DELETE PRICING SCHEMA (atomic with cascade)
-- Replaces: ProductSchemaService+PricingSchemas.swift:147-175
-- Impact: 2 sequential operations → 1 atomic transaction
-- ============================================================================

DROP FUNCTION IF EXISTS public.delete_pricing_schema(uuid);

CREATE OR REPLACE FUNCTION public.delete_pricing_schema(p_schema_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Soft delete the schema
  UPDATE pricing_schemas
  SET is_active = false,
      deleted_at = NOW()
  WHERE id = p_schema_id;

  -- Remove junction records
  DELETE FROM category_pricing_schemas
  WHERE pricing_schema_id = p_schema_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_pricing_schema(uuid) TO authenticated;

-- ============================================================================
-- 11. GET PRICING SCHEMAS (with proper filtering)
-- Replaces: ProductSchemaService+PricingSchemas.swift:53-76
-- Impact: Fetch-all-then-filter → Single filtered query
-- FIXED: Use jsonb containment (@>) for applicable_categories
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_pricing_schemas(uuid, text);

CREATE OR REPLACE FUNCTION public.get_pricing_schemas(
  p_catalog_id uuid DEFAULT NULL,
  p_category_name text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_agg(ps.*)
  INTO v_result
  FROM pricing_schemas ps
  WHERE ps.is_active = true
    AND ps.deleted_at IS NULL
    AND (p_catalog_id IS NULL OR ps.catalog_id = p_catalog_id OR ps.catalog_id IS NULL)
    AND (p_category_name IS NULL
         OR ps.applicable_categories IS NULL
         OR ps.applicable_categories = '[]'::jsonb
         OR ps.applicable_categories @> to_jsonb(p_category_name));

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pricing_schemas(uuid, text) TO authenticated;

-- ============================================================================
-- 12. GET FIELD SCHEMAS (with proper filtering)
-- Replaces: ProductSchemaService+FieldSchemas.swift (same pattern)
-- FIXED: Use jsonb containment (@>) for applicable_categories
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_field_schemas(uuid, text);

CREATE OR REPLACE FUNCTION public.get_field_schemas(
  p_catalog_id uuid DEFAULT NULL,
  p_category_name text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_agg(fs.*)
  INTO v_result
  FROM field_schemas fs
  WHERE fs.is_active = true
    AND fs.deleted_at IS NULL
    AND (p_catalog_id IS NULL OR fs.catalog_id = p_catalog_id OR fs.catalog_id IS NULL)
    AND (p_category_name IS NULL
         OR fs.applicable_categories IS NULL
         OR fs.applicable_categories = '[]'::jsonb
         OR fs.applicable_categories @> to_jsonb(p_category_name));

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_field_schemas(uuid, text) TO authenticated;

-- ============================================================================
-- Summary of backend functions:
-- ============================================================================
-- 1.  get_all_store_conversations(store_id)    - All conversations for store
-- 2.  get_all_collection_items()               - All collection->creation mappings
-- 3.  assign_categories_to_catalog(...)        - Atomic batch category assignment
-- 4.  get_product_editor_data(product_id)      - All product editor data in one call
-- 5.  get_category_descendants(category_id)    - Recursive category tree
-- 6.  get_products_in_category_tree(cat_id)    - Products in category + subcategories
-- 7.  v_category_product_counts                - View with direct/total counts
-- 8.  get_creation_statistics()                - Aggregated creation stats
-- 9.  v_orphan_creations                       - View of creations not in collections
-- 10. delete_pricing_schema(schema_id)         - Atomic soft delete with cascade
-- 11. get_pricing_schemas(catalog_id, cat_name) - Filtered pricing schemas
-- 12. get_field_schemas(catalog_id, cat_name)   - Filtered field schemas
