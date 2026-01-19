-- Migration: Fix product stock status to auto-sync with stock quantity
-- This ensures stock_status accurately reflects stock_quantity
-- Created: 2026-01-19

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
    ELSE stock_status -- Keep existing status if not managing stock
END
WHERE manage_stock = true;

-- Log the update
DO $$
DECLARE
    updated_count INT;
BEGIN
    SELECT COUNT(*) INTO updated_count FROM products WHERE manage_stock = true;
    RAISE NOTICE 'Synced stock status for % products', updated_count;
END $$;
