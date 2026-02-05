-- Fix existing orders missing location_id
-- This makes old orders from macOS visible in iOS location history

-- OPTIONAL: Only run if you want existing orders to show in iOS

-- Update orders that have pickup_location_id but missing location_id
-- This primarily affects walk_in orders created before the fix
UPDATE orders
SET
    location_id = pickup_location_id,
    updated_at = NOW()
WHERE
    location_id IS NULL
    AND pickup_location_id IS NOT NULL
    AND order_type = 'walk_in';

-- Verify the fix
SELECT
    COUNT(*) as total_orders,
    COUNT(location_id) as orders_with_location,
    COUNT(*) - COUNT(location_id) as orders_missing_location
FROM orders
WHERE order_type = 'walk_in';

\echo '✅ Existing orders updated - location_id now populated'
\echo '   Orders with location_id populated from pickup_location_id'
\echo '   These orders will now appear in iOS location history'
