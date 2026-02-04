-- Migration: Clean up duplicate field schemas
-- Issue: Old "Cannabis Product Details" schema contains ALL fields for all categories
-- Solution: Remove old schema, ensure modular schemas are properly assigned
-- Created: 2026-02-02

-- Step 1: Identify and remove the old monolithic "Cannabis Product Details" schema
-- It has ALL fields mixed together which causes duplicates

-- First, remove all assignments of the old schema
DELETE FROM category_field_schemas
WHERE field_schema_id = '4a8c45e8-28f3-4641-a3c0-921a1c85c67c';

-- Soft-delete the old schema (mark as inactive)
UPDATE field_schemas
SET is_active = false, deleted_at = now()
WHERE id = '4a8c45e8-28f3-4641-a3c0-921a1c85c67c';

-- Step 2: Create the proper modular field schemas
-- These are designed to be composable (base + category-specific)

-- Base Cannabis Schema (for ALL cannabis products)
INSERT INTO field_schemas (id, name, description, icon, fields, is_active, is_public)
VALUES (
    'a0000001-0000-0000-0000-000000000001',
    'Base Cannabis',
    'Basic fields for all cannabis products',
    'leaf',
    '[
        {"key": "tagline", "label": "Tagline", "type": "text"},
        {"key": "effects", "label": "Effects", "type": "text"}
    ]'::jsonb,
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    fields = EXCLUDED.fields,
    is_active = true;

-- Cannabinoid Profile Schema (for Flower, Concentrates, Disposable Vapes)
INSERT INTO field_schemas (id, name, description, icon, fields, is_active, is_public)
VALUES (
    'a0000002-0000-0000-0000-000000000002',
    'Cannabinoid Profile',
    'THC/cannabinoid percentages and strain info',
    'percent',
    '[
        {"key": "thca_percentage", "label": "THCa %", "type": "number", "unit": "%"},
        {"key": "d9_percentage", "label": "D9 THC %", "type": "number", "unit": "%"},
        {"key": "strain_type", "label": "Strain Type", "type": "select", "options": ["Indica", "Sativa", "Hybrid"]},
        {"key": "genetics", "label": "Genetics", "type": "text"},
        {"key": "terpenes", "label": "Terpenes", "type": "text"},
        {"key": "nose", "label": "Nose/Aroma", "type": "text"}
    ]'::jsonb,
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    fields = EXCLUDED.fields,
    is_active = true;

-- Flower Specific Schema (empty - all flower fields are in Cannabinoid Profile)
-- Keeping for future flower-only fields if needed
INSERT INTO field_schemas (id, name, description, icon, fields, is_active, is_public)
VALUES (
    'a0000003-0000-0000-0000-000000000003',
    'Flower Specific',
    'Fields specific to flower products',
    'leaf.circle',
    '[]'::jsonb,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    is_active = false;

-- Concentrate Specific Schema
INSERT INTO field_schemas (id, name, description, icon, fields, is_active, is_public)
VALUES (
    'a0000004-0000-0000-0000-000000000004',
    'Concentrate Specific',
    'Fields specific to concentrate products',
    'drop.fill',
    '[
        {"key": "concentrate_type", "label": "Concentrate Type", "type": "select", "options": ["Shatter", "Wax", "Crumble", "Budder", "Live Resin", "Rosin", "Diamonds", "Sauce"]},
        {"key": "consistency", "label": "Consistency", "type": "text"}
    ]'::jsonb,
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    fields = EXCLUDED.fields,
    is_active = true;

-- Edibles Specific Schema
INSERT INTO field_schemas (id, name, description, icon, fields, is_active, is_public)
VALUES (
    'a0000005-0000-0000-0000-000000000005',
    'Edibles Specific',
    'Fields specific to edible products (mg dosing)',
    'birthday.cake',
    '[
        {"key": "thc_mg_per_piece", "label": "THC mg/piece", "type": "number", "unit": "mg"},
        {"key": "thc_mg_total", "label": "THC mg total", "type": "number", "unit": "mg"},
        {"key": "servings", "label": "Servings", "type": "number"},
        {"key": "flavor", "label": "Flavor", "type": "text"},
        {"key": "edible_type", "label": "Type", "type": "select", "options": ["Gummy", "Chocolate", "Baked Good", "Beverage", "Candy", "Other"]}
    ]'::jsonb,
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    fields = EXCLUDED.fields,
    is_active = true;

-- Disposable Vape Specific Schema
INSERT INTO field_schemas (id, name, description, icon, fields, is_active, is_public)
VALUES (
    'a0000006-0000-0000-0000-000000000006',
    'Disposable Vape Specific',
    'Fields specific to disposable vapes',
    'smoke',
    '[
        {"key": "vape_type", "label": "Vape Type", "type": "select", "options": ["Distillate", "Live Resin", "Live Rosin", "Full Spectrum"]},
        {"key": "tank_size", "label": "Tank Size", "type": "text"}
    ]'::jsonb,
    true,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    fields = EXCLUDED.fields,
    is_active = true;

-- Step 3: Clear all existing category_field_schemas and reassign properly
DELETE FROM category_field_schemas
WHERE category_id IN (
    SELECT id FROM categories
    WHERE name IN ('Flower', 'Concentrates', 'Edibles', 'Disposable Vape', 'Pre-Rolls')
);

-- Step 4: Assign schemas to categories properly

-- Flower: Base + Cannabinoid + Flower Specific
INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000001-0000-0000-0000-000000000001', 1, true
FROM categories c WHERE c.name = 'Flower' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000002-0000-0000-0000-000000000002', 2, true
FROM categories c WHERE c.name = 'Flower' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

-- Flower Specific schema disabled - nose is in Cannabinoid Profile

-- Concentrates: Base + Cannabinoid + Concentrate Specific
INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000001-0000-0000-0000-000000000001', 1, true
FROM categories c WHERE c.name = 'Concentrates' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000002-0000-0000-0000-000000000002', 2, true
FROM categories c WHERE c.name = 'Concentrates' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000004-0000-0000-0000-000000000004', 3, true
FROM categories c WHERE c.name = 'Concentrates' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

-- Edibles: Base + Edibles Specific (NO cannabinoid profile - they use mg not %)
INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000001-0000-0000-0000-000000000001', 1, true
FROM categories c WHERE c.name = 'Edibles' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000005-0000-0000-0000-000000000005', 2, true
FROM categories c WHERE c.name = 'Edibles' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

-- Disposable Vape: Base + Cannabinoid + Vape Specific
INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000001-0000-0000-0000-000000000001', 1, true
FROM categories c WHERE c.name = 'Disposable Vape' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000002-0000-0000-0000-000000000002', 2, true
FROM categories c WHERE c.name = 'Disposable Vape' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

INSERT INTO category_field_schemas (category_id, field_schema_id, sort_order, is_active)
SELECT c.id, 'a0000006-0000-0000-0000-000000000006', 3, true
FROM categories c WHERE c.name = 'Disposable Vape' AND c.is_active = true
ON CONFLICT (category_id, field_schema_id) DO NOTHING;

-- Step 5: Audit results
DO $$
DECLARE
    schema_count INT;
    assignment_count INT;
    r RECORD;
BEGIN
    SELECT COUNT(*) INTO schema_count FROM field_schemas WHERE is_active = true;
    SELECT COUNT(*) INTO assignment_count FROM category_field_schemas WHERE is_active = true;

    RAISE NOTICE '=== FIELD SCHEMA CLEANUP COMPLETE ===';
    RAISE NOTICE 'Active schemas: %', schema_count;
    RAISE NOTICE 'Category assignments: %', assignment_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Assignments by category:';

    FOR r IN
        SELECT c.name as cat_name, COUNT(cfs.id) as schema_count
        FROM categories c
        LEFT JOIN category_field_schemas cfs ON c.id = cfs.category_id AND cfs.is_active = true
        WHERE c.name IN ('Flower', 'Concentrates', 'Edibles', 'Disposable Vape')
        GROUP BY c.name
        ORDER BY c.name
    LOOP
        RAISE NOTICE '  %: % schemas', r.cat_name, r.schema_count;
    END LOOP;
END $$;
