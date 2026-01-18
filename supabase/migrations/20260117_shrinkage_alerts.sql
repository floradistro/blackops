-- Shrinkage Alert Trigger
-- Fires alerts when inventory adjustments are logged for shrinkage-related events
-- Integrates with existing event_alerts system

-- 1. Create trigger function to fire alerts on shrinkage adjustments
CREATE OR REPLACE FUNCTION trg_shrinkage_alert()
RETURNS TRIGGER AS $$
DECLARE
    v_threshold RECORD;
    v_product_name TEXT;
    v_location_name TEXT;
    v_shrinkage_types TEXT[] := ARRAY['auto_zero', 'dust_cleanup', 'shrinkage', 'theft', 'damage', 'waste', 'expired'];
BEGIN
    -- Only fire for shrinkage-related adjustment types
    IF NOT (NEW.adjustment_type = ANY(v_shrinkage_types)) THEN
        RETURN NEW;
    END IF;

    -- Get product and location names for alert description
    SELECT p.name INTO v_product_name FROM products p WHERE p.id = NEW.product_id;
    SELECT l.name INTO v_location_name FROM locations l WHERE l.id = NEW.location_id;

    -- Check against inventory_shrinkage threshold (single event >= 10 units)
    SELECT * INTO v_threshold
    FROM alert_thresholds
    WHERE tenant_id = NEW.store_id
      AND alert_type = 'inventory_shrinkage'
      AND is_active = true;

    IF FOUND AND ABS(NEW.quantity_change) >= v_threshold.threshold_value THEN
        INSERT INTO event_alerts (
            tenant_id,
            alert_type,
            severity,
            title,
            description,
            payload,
            threshold_value,
            actual_value
        ) VALUES (
            NEW.store_id,
            'inventory_shrinkage',
            v_threshold.severity,
            'Inventory Shrinkage: ' || COALESCE(v_product_name, 'Unknown Product'),
            v_product_name || ' at ' || v_location_name || ': ' ||
            ABS(NEW.quantity_change) || ' units (' || NEW.adjustment_type || '). ' ||
            COALESCE(NEW.reason, 'No reason provided'),
            jsonb_build_object(
                'adjustment_id', NEW.id,
                'product_id', NEW.product_id,
                'product_name', v_product_name,
                'location_id', NEW.location_id,
                'location_name', v_location_name,
                'adjustment_type', NEW.adjustment_type,
                'quantity_before', NEW.quantity_before,
                'quantity_after', NEW.quantity_after,
                'quantity_change', NEW.quantity_change,
                'reason', NEW.reason,
                'is_ai_action', NEW.is_ai_action
            ),
            v_threshold.threshold_value,
            ABS(NEW.quantity_change)
        );
    END IF;

    -- Check against daily_shrinkage threshold (accumulated >= 50 units today)
    SELECT * INTO v_threshold
    FROM alert_thresholds
    WHERE tenant_id = NEW.store_id
      AND alert_type = 'daily_shrinkage'
      AND is_active = true;

    IF FOUND THEN
        DECLARE
            v_daily_total NUMERIC;
        BEGIN
            -- Calculate today's total shrinkage
            SELECT COALESCE(SUM(ABS(quantity_change)), 0) INTO v_daily_total
            FROM inventory_adjustments
            WHERE store_id = NEW.store_id
              AND adjustment_type = ANY(v_shrinkage_types)
              AND created_at >= CURRENT_DATE;

            IF v_daily_total >= v_threshold.threshold_value THEN
                -- Check if we already fired this alert today
                IF NOT EXISTS (
                    SELECT 1 FROM event_alerts
                    WHERE tenant_id = NEW.store_id
                      AND alert_type = 'daily_shrinkage'
                      AND created_at >= CURRENT_DATE
                ) THEN
                    INSERT INTO event_alerts (
                        tenant_id,
                        alert_type,
                        severity,
                        title,
                        description,
                        payload,
                        threshold_value,
                        actual_value
                    ) VALUES (
                        NEW.store_id,
                        'daily_shrinkage',
                        v_threshold.severity,
                        'Daily Shrinkage Alert: ' || v_daily_total || ' units',
                        'Total shrinkage today has reached ' || v_daily_total || ' units across all locations. ' ||
                        'Latest: ' || v_product_name || ' at ' || v_location_name,
                        jsonb_build_object(
                            'daily_total', v_daily_total,
                            'latest_adjustment_id', NEW.id,
                            'latest_product', v_product_name,
                            'latest_location', v_location_name,
                            'date', CURRENT_DATE
                        ),
                        v_threshold.threshold_value,
                        v_daily_total
                    );
                END IF;
            END IF;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create the trigger on inventory_adjustments
DROP TRIGGER IF EXISTS trg_shrinkage_alert ON inventory_adjustments;
CREATE TRIGGER trg_shrinkage_alert
    AFTER INSERT ON inventory_adjustments
    FOR EACH ROW
    EXECUTE FUNCTION trg_shrinkage_alert();

-- 3. Add dust_cleanup threshold if not exists (low priority, info level)
INSERT INTO alert_thresholds (tenant_id, alert_type, name, description, threshold_value, comparison, severity, is_active)
SELECT
    'cd2e1122-d511-4edb-be5d-98ef274b4baf',
    'dust_cleanup',
    'Dust Cleanup Alert',
    'Auto-zeroed items >= 5 in single batch',
    5,
    'gte',
    'info',
    true
WHERE NOT EXISTS (
    SELECT 1 FROM alert_thresholds
    WHERE alert_type = 'dust_cleanup'
      AND tenant_id = 'cd2e1122-d511-4edb-be5d-98ef274b4baf'
);

COMMENT ON FUNCTION trg_shrinkage_alert IS
'Fires alerts to event_alerts when shrinkage-related inventory adjustments occur.
Checks against inventory_shrinkage (single event) and daily_shrinkage (accumulated) thresholds.';
