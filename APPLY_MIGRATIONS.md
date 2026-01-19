# Apply Database Migrations

The app is currently failing because two database migrations need to be applied to add the `field_values` column and `stock_status` syncing.

## Quick Fix - Copy & Paste into Supabase SQL Editor

1. **Go to your Supabase Dashboard**: https://supabase.com/dashboard/project/uaednwpxursknmwdeejn
2. **Click "SQL Editor"** in the left sidebar
3. **Click "New Query"**
4. **Copy and paste the SQL below** into the editor
5. **Click "Run"**

```sql
-- Migration 1: Add product field values and schema assignments
-- ============================================================

-- Add field_values JSONB column to products table
ALTER TABLE products
ADD COLUMN IF NOT EXISTS field_values JSONB DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_products_field_values ON products USING GIN(field_values);

-- Create junction table for product -> field_schema assignments
CREATE TABLE IF NOT EXISTS product_field_schemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    field_schema_id UUID NOT NULL REFERENCES field_schemas(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(product_id, field_schema_id)
);

-- Create junction table for product -> pricing_schema assignments
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
DROP POLICY IF EXISTS "product_field_schemas_select" ON product_field_schemas;
CREATE POLICY "product_field_schemas_select" ON product_field_schemas FOR SELECT USING (true);

DROP POLICY IF EXISTS "product_field_schemas_manage" ON product_field_schemas;
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
DROP POLICY IF EXISTS "product_pricing_schemas_select" ON product_pricing_schemas;
CREATE POLICY "product_pricing_schemas_select" ON product_pricing_schemas FOR SELECT USING (true);

DROP POLICY IF EXISTS "product_pricing_schemas_manage" ON product_pricing_schemas;
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
DROP POLICY IF EXISTS "product_field_schemas_service" ON product_field_schemas;
CREATE POLICY "product_field_schemas_service" ON product_field_schemas FOR ALL
USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "product_pricing_schemas_service" ON product_pricing_schemas;
CREATE POLICY "product_pricing_schemas_service" ON product_pricing_schemas FOR ALL
USING (auth.role() = 'service_role');

-- Grant permissions
GRANT ALL ON product_field_schemas TO authenticated;
GRANT SELECT ON product_field_schemas TO anon;
GRANT ALL ON product_pricing_schemas TO authenticated;
GRANT SELECT ON product_pricing_schemas TO anon;

-- Migration 2: Fix product stock status
-- ======================================

-- Function to automatically update stock_status based on stock_quantity
CREATE OR REPLACE FUNCTION sync_product_stock_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update if manage_stock is true
    IF NEW.manage_stock = true THEN
        IF NEW.stock_quantity IS NULL OR NEW.stock_quantity <= 0 THEN
            NEW.stock_status = 'outofstock';
        ELSIF NEW.stock_quantity > 0 AND NEW.stock_quantity < 10 THEN
            NEW.stock_status = 'lowstock';
        ELSE
            NEW.stock_status = 'instock';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS products_sync_stock_status ON products;

-- Create trigger to run before insert or update
CREATE TRIGGER products_sync_stock_status
    BEFORE INSERT OR UPDATE OF stock_quantity, manage_stock
    ON products
    FOR EACH ROW
    EXECUTE FUNCTION sync_product_stock_status();

-- Update all existing products to have correct stock_status
UPDATE products
SET stock_status = CASE
    WHEN manage_stock = true AND (stock_quantity IS NULL OR stock_quantity <= 0) THEN 'outofstock'
    WHEN manage_stock = true AND stock_quantity > 0 AND stock_quantity < 10 THEN 'lowstock'
    WHEN manage_stock = true AND stock_quantity >= 10 THEN 'instock'
    ELSE stock_status
END
WHERE manage_stock = true;
```

## After Running the Migration

Once the SQL has been executed successfully:

1. **Restart the SwagManager app**
2. The app will now properly load:
   - Product field values will work (though they'll be empty until data is added)
   - Stock statuses will be accurate and auto-sync with quantities
   - Products will show only schemas assigned to their category

## Alternative: Use Command Line (if you have psql installed)

```bash
chmod +x run-migrations.sh
./run-migrations.sh
```

You'll need to update the `DB_PASSWORD` variable in `run-migrations.sh` with your database password from the Supabase dashboard.
