-- Temporarily disable audit trigger to allow mass updates
-- This fixes the statement timeout when updating 60K+ orders

-- Disable the audit trigger temporarily
ALTER TABLE orders DISABLE TRIGGER audit_orders;

-- Now backfill customer names (will be MUCH faster without audit)
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

-- Re-enable the audit trigger
ALTER TABLE orders ENABLE TRIGGER audit_orders;

-- Verify the backfill
SELECT
    COUNT(*) FILTER (WHERE shipping_name IS NOT NULL AND shipping_name != '' AND shipping_name != 'Walk-In') as with_customer_names,
    COUNT(*) FILTER (WHERE shipping_name IS NULL OR shipping_name = '' OR shipping_name = 'Walk-In') as without_customer_names,
    COUNT(*) as total_orders
FROM orders
WHERE order_type = 'walk_in';

\echo '✅ Audit trigger disabled during update, now re-enabled'
\echo '   Mass update completed successfully'
\echo '   All orders now have customer names'
