-- Backfill customer names for all existing orders
-- This updates shipping_name from v_store_customers for orders that have customer_id

-- Update orders with customer names from v_store_customers view
UPDATE orders o
SET
    shipping_name = CONCAT(c.first_name, ' ', COALESCE(c.last_name, '')),
    updated_at = NOW()
FROM v_store_customers c
WHERE
    o.customer_id = c.id
    AND (o.shipping_name IS NULL OR o.shipping_name = '' OR o.shipping_name = 'Walk-In')
    AND c.first_name IS NOT NULL
    AND c.first_name != '';

-- Check how many were updated
SELECT
    COUNT(*) FILTER (WHERE shipping_name IS NOT NULL AND shipping_name != '' AND shipping_name != 'Walk-In') as with_customer_names,
    COUNT(*) FILTER (WHERE shipping_name IS NULL OR shipping_name = '' OR shipping_name = 'Walk-In') as without_customer_names,
    COUNT(*) as total_orders
FROM orders
WHERE order_type = 'walk_in';

\echo '✅ Customer names backfilled for existing orders'
\echo '   Orders with customer names now populated'
\echo '   Both iOS and macOS will now show customer names'
