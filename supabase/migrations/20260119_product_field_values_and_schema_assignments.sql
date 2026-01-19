-- Migration: Add product field values and schema assignments
-- This allows products to have custom field values and assigned pricing schemas
-- Created: 2026-01-19

-- Add field_values JSONB column to products table
-- This stores actual field values for the product as { "thc_percentage": 25.5, "strain_type": "Hybrid", ... }
ALTER TABLE products
ADD COLUMN IF NOT EXISTS field_values JSONB DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_products_field_values ON products USING GIN(field_values);

-- Create junction table for product -> field_schema assignments
-- This tracks which field schemas apply to this specific product
CREATE TABLE IF NOT EXISTS product_field_schemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    field_schema_id UUID NOT NULL REFERENCES field_schemas(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(product_id, field_schema_id)
);

-- Create junction table for product -> pricing_schema assignments
-- This tracks which pricing schemas apply to this specific product
CREATE TABLE IF NOT EXISTS product_pricing_schemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    pricing_schema_id UUID NOT NULL REFERENCES pricing_schemas(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(product_id, pricing_schema_id)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_product_field_schemas_product ON product_field_schemas(product_id);
CREATE INDEX IF NOT EXISTS idx_product_field_schemas_schema ON product_field_schemas(field_schema_id);
CREATE INDEX IF NOT EXISTS idx_product_pricing_schemas_product ON product_pricing_schemas(product_id);
CREATE INDEX IF NOT EXISTS idx_product_pricing_schemas_schema ON product_pricing_schemas(pricing_schema_id);

-- Enable RLS
ALTER TABLE product_field_schemas ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_pricing_schemas ENABLE ROW LEVEL SECURITY;

-- RLS policies for product_field_schemas
CREATE POLICY "product_field_schemas_select" ON product_field_schemas FOR SELECT
    USING (true);

CREATE POLICY "product_field_schemas_manage" ON product_field_schemas FOR ALL
    USING (
        product_id IN (
            SELECT p.id FROM products p
            JOIN stores s ON p.store_id = s.id
            JOIN platform_users pu ON s.owner_user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- RLS policies for product_pricing_schemas
CREATE POLICY "product_pricing_schemas_select" ON product_pricing_schemas FOR SELECT
    USING (true);

CREATE POLICY "product_pricing_schemas_manage" ON product_pricing_schemas FOR ALL
    USING (
        product_id IN (
            SELECT p.id FROM products p
            JOIN stores s ON p.store_id = s.id
            JOIN platform_users pu ON s.owner_user_id = pu.id
            WHERE pu.auth_id = auth.uid()
        )
    );

-- Service role full access
CREATE POLICY "product_field_schemas_service" ON product_field_schemas FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "product_pricing_schemas_service" ON product_pricing_schemas FOR ALL
    USING (auth.role() = 'service_role');

-- Grant permissions
GRANT ALL ON product_field_schemas TO authenticated;
GRANT SELECT ON product_field_schemas TO anon;
GRANT ALL ON product_pricing_schemas TO authenticated;
GRANT SELECT ON product_pricing_schemas TO anon;
