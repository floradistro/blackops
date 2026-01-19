-- Migration: Create category-schema junction tables for proper schema assignments
-- This enables each category to have its own specific field and pricing schemas
-- Created: 2026-01-18

-- Create junction table for category -> field_schema assignments
CREATE TABLE IF NOT EXISTS category_field_schemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    field_schema_id UUID NOT NULL REFERENCES field_schemas(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(category_id, field_schema_id)
);

-- Create junction table for category -> pricing_schema assignments
CREATE TABLE IF NOT EXISTS category_pricing_schemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    pricing_schema_id UUID NOT NULL REFERENCES pricing_schemas(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(category_id, pricing_schema_id)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_category_field_schemas_category ON category_field_schemas(category_id);
CREATE INDEX IF NOT EXISTS idx_category_field_schemas_schema ON category_field_schemas(field_schema_id);
CREATE INDEX IF NOT EXISTS idx_category_pricing_schemas_category ON category_pricing_schemas(category_id);
CREATE INDEX IF NOT EXISTS idx_category_pricing_schemas_schema ON category_pricing_schemas(pricing_schema_id);

-- Enable RLS
ALTER TABLE category_field_schemas ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_pricing_schemas ENABLE ROW LEVEL SECURITY;

-- RLS policies for category_field_schemas
CREATE POLICY "category_field_schemas_select" ON category_field_schemas FOR SELECT
    USING (true);

CREATE POLICY "category_field_schemas_manage" ON category_field_schemas FOR ALL
    USING (
        category_id IN (
            SELECT c.id FROM categories c
            JOIN stores s ON c.store_id = s.id
            JOIN platform_users pu ON s.owner_user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- RLS policies for category_pricing_schemas
CREATE POLICY "category_pricing_schemas_select" ON category_pricing_schemas FOR SELECT
    USING (true);

CREATE POLICY "category_pricing_schemas_manage" ON category_pricing_schemas FOR ALL
    USING (
        category_id IN (
            SELECT c.id FROM categories c
            JOIN stores s ON c.store_id = s.id
            JOIN platform_users pu ON s.owner_user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- Service role full access
CREATE POLICY "category_field_schemas_service" ON category_field_schemas FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "category_pricing_schemas_service" ON category_pricing_schemas FOR ALL
    USING (auth.role() = 'service_role');
