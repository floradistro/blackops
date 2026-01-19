-- Migration: Add catalog_id to field_schemas and pricing_schemas for catalog separation
-- This enables proper isolation of field/pricing schemas between different catalogs
-- Created: 2026-01-18

-- Add catalog_id column to field_schemas
ALTER TABLE field_schemas 
ADD COLUMN IF NOT EXISTS catalog_id UUID REFERENCES catalogs(id) ON DELETE SET NULL;

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_field_schemas_catalog_id ON field_schemas(catalog_id);

-- Add catalog_id column to pricing_schemas
ALTER TABLE pricing_schemas 
ADD COLUMN IF NOT EXISTS catalog_id UUID REFERENCES catalogs(id) ON DELETE SET NULL;

-- Add index for faster queries  
CREATE INDEX IF NOT EXISTS idx_pricing_schemas_catalog_id ON pricing_schemas(catalog_id);

-- Assign Real Estate field schemas to the Real Estate catalog (test store)
-- This fixes the issue where Real Estate configs were showing in Flora Distro
UPDATE field_schemas 
SET catalog_id = 'dcb45d1b-19d5-47d2-a25a-d3a69d833a84'  -- Real Estate catalog
WHERE name IN ('Residential Property Details', 'Commercial Property Details', 'Land & Investment Details')
AND owner_user_id = '63d7def6-ad0f-47fa-a17e-e970ca75113b'
AND catalog_id IS NULL;

-- Assign Real Estate pricing schemas to the Real Estate catalog (test store)
UPDATE pricing_schemas 
SET catalog_id = 'dcb45d1b-19d5-47d2-a25a-d3a69d833a84'  -- Real Estate catalog
WHERE name IN ('Residential Property Pricing', 'Commercial Property Pricing', 'Land & Investment Pricing')
AND owner_user_id = '63d7def6-ad0f-47fa-a17e-e970ca75113b'
AND catalog_id IS NULL;

-- Comment: Schemas with catalog_id = NULL are treated as global/public schemas
-- that apply to all catalogs (legacy behavior for existing cannabis schemas)
