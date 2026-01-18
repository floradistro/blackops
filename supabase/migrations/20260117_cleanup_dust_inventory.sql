-- Dust Inventory Cleanup
-- Problem: Fractional sales leave tiny quantities (0.04g, 0.16g) that show as "in stock" but aren't sellable
-- Solution: Scheduled job to zero out quantities below minimum sellable threshold

-- 1. Create the cleanup function
CREATE OR REPLACE FUNCTION cleanup_dust_inventory(
    p_threshold NUMERIC DEFAULT 1.0,  -- Minimum sellable quantity (default 1 unit)
    p_dry_run BOOLEAN DEFAULT false   -- If true, just report what would be cleaned
)
RETURNS TABLE (
    inventory_id UUID,
    product_name TEXT,
    location_name TEXT,
    old_quantity NUMERIC,
    action TEXT
) AS $$
BEGIN
    IF p_dry_run THEN
        -- Dry run: just return what would be cleaned
        RETURN QUERY
        SELECT
            i.id as inventory_id,
            p.name as product_name,
            l.name as location_name,
            i.quantity as old_quantity,
            'WOULD_ZERO'::TEXT as action
        FROM inventory i
        JOIN products p ON p.id = i.product_id
        JOIN locations l ON l.id = i.location_id
        WHERE i.quantity > 0
          AND i.quantity < p_threshold;
    ELSE
        -- Actual cleanup: zero out dust quantities and return affected rows
        RETURN QUERY
        WITH updated AS (
            UPDATE inventory i
            SET quantity = 0,
                updated_at = NOW()
            FROM products p, locations l
            WHERE p.id = i.product_id
              AND l.id = i.location_id
              AND i.quantity > 0
              AND i.quantity < p_threshold
            RETURNING i.id as inventory_id, p.name as product_name, l.name as location_name, i.quantity as old_quantity
        )
        SELECT
            updated.inventory_id,
            updated.product_name,
            updated.location_name,
            updated.old_quantity,
            'ZEROED'::TEXT as action
        FROM updated;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create audit log table for inventory adjustments
CREATE TABLE IF NOT EXISTS inventory_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inventory_id UUID REFERENCES inventory(id),
    product_id UUID REFERENCES products(id),
    location_id UUID REFERENCES locations(id),
    adjustment_type TEXT NOT NULL,  -- 'DUST_CLEANUP', 'CYCLE_COUNT', 'MANUAL', etc.
    old_quantity NUMERIC NOT NULL,
    new_quantity NUMERIC NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID  -- staff_id if manual
);

-- 3. Create cleanup function WITH audit trail
CREATE OR REPLACE FUNCTION cleanup_dust_inventory_with_audit(
    p_threshold NUMERIC DEFAULT 1.0
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
    v_record RECORD;
BEGIN
    FOR v_record IN
        SELECT
            i.id as inventory_id,
            i.product_id,
            i.location_id,
            i.quantity as old_quantity
        FROM inventory i
        WHERE i.quantity > 0
          AND i.quantity < p_threshold
    LOOP
        -- Zero out the inventory
        UPDATE inventory
        SET quantity = 0, updated_at = NOW()
        WHERE id = v_record.inventory_id;

        -- Log the adjustment
        INSERT INTO inventory_adjustments (
            inventory_id, product_id, location_id,
            adjustment_type, old_quantity, new_quantity, reason
        ) VALUES (
            v_record.inventory_id, v_record.product_id, v_record.location_id,
            'DUST_CLEANUP', v_record.old_quantity, 0,
            'Auto-cleanup: quantity ' || v_record.old_quantity || ' below threshold ' || p_threshold
        );

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Optional: Trigger to auto-zero on update (more aggressive)
-- Uncomment if you want immediate cleanup when quantity drops below threshold
/*
CREATE OR REPLACE FUNCTION auto_zero_dust_inventory()
RETURNS TRIGGER AS $$
BEGIN
    -- If quantity dropped below 1 but is still > 0, zero it out
    IF NEW.quantity > 0 AND NEW.quantity < 1.0 THEN
        -- Log the auto-adjustment
        INSERT INTO inventory_adjustments (
            inventory_id, product_id, location_id,
            adjustment_type, old_quantity, new_quantity, reason
        ) VALUES (
            NEW.id, NEW.product_id, NEW.location_id,
            'AUTO_ZERO', NEW.quantity, 0,
            'Auto-zeroed: quantity ' || NEW.quantity || ' below minimum sellable'
        );

        NEW.quantity := 0;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_zero_dust_inventory
    BEFORE UPDATE OF quantity ON inventory
    FOR EACH ROW
    EXECUTE FUNCTION auto_zero_dust_inventory();
*/

-- 5. Grant execute permissions
GRANT EXECUTE ON FUNCTION cleanup_dust_inventory TO service_role;
GRANT EXECUTE ON FUNCTION cleanup_dust_inventory_with_audit TO service_role;

-- 6. Schedule with pg_cron (run daily at 3 AM)
-- Note: pg_cron must be enabled in Supabase dashboard > Database > Extensions
-- SELECT cron.schedule('cleanup-dust-inventory', '0 3 * * *', 'SELECT cleanup_dust_inventory_with_audit(1.0)');

COMMENT ON FUNCTION cleanup_dust_inventory IS
'Cleans up "dust inventory" - quantities below minimum sellable threshold.
Use p_dry_run=true to preview what would be cleaned.
Example: SELECT * FROM cleanup_dust_inventory(1.0, true);';

COMMENT ON FUNCTION cleanup_dust_inventory_with_audit IS
'Same as cleanup_dust_inventory but creates audit trail in inventory_adjustments table.
Returns count of rows cleaned. Run manually or schedule with pg_cron.';
