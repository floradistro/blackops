-- Migration: Assign field schemas and pricing schemas to categories
-- This populates the junction tables so products can display custom fields
-- Created: 2026-01-19

-- Assign Cannabis Product Details field schema to cannabis categories
INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, '4a8c45e8-28f3-4641-a3c0-921a1c85c67c', 1, true
FROM categories c
WHERE c.catalog_id = '368a849f-4a1d-4347-a9da-42a3e3709bf2'
  AND c.name IN ('Flower', 'Concentrates', 'Pre-Rolls', 'Edibles', 'Disposable Vape')
  AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

-- Assign pricing schemas to Flower category
INSERT INTO category_pricing_schemas (category_id, pricing_schema_id, sort_order, is_active)
SELECT
  '296c87ce-a31b-43a3-b48f-52902134a723',  -- Flower category ID
  ps.id,
  CASE ps.name
    WHEN 'Top Shelf' THEN 1
    WHEN 'Exotic' THEN 2
    ELSE 99
  END,
  true
FROM pricing_schemas ps
WHERE ps.name IN ('Top Shelf', 'Exotic')
  AND ps.catalog_id = '368a849f-4a1d-4347-a9da-42a3e3709bf2'
  AND ps.is_active = true
ON CONFLICT (category_id, pricing_schema_id) DO NOTHING;

-- Assign pricing schemas to Concentrates category
INSERT INTO category_pricing_schemas (category_id, pricing_schema_id, sort_order, is_active)
SELECT
  'e9b86776-f9f4-4f42-a7cc-873d34671d0a',  -- Concentrates category ID
  ps.id,
  CASE ps.name
    WHEN 'Crumble' THEN 1
    WHEN 'SHATTER' THEN 2
    ELSE 99
  END,
  true
FROM pricing_schemas ps
WHERE ps.name IN ('Crumble', 'SHATTER')
  AND ps.catalog_id = '368a849f-4a1d-4347-a9da-42a3e3709bf2'
  AND ps.is_active = true
ON CONFLICT (category_id, pricing_schema_id) DO NOTHING;

-- Log results
DO $$
DECLARE
    field_schema_count INT;
    pricing_schema_count INT;
BEGIN
    SELECT COUNT(*) INTO field_schema_count FROM category_field_schemas;
    SELECT COUNT(*) INTO pricing_schema_count FROM category_pricing_schemas;

    RAISE NOTICE 'Field schema assignments: %', field_schema_count;
    RAISE NOTICE 'Pricing schema assignments: %', pricing_schema_count;
END $$;
