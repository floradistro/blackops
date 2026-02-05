-- Quick Order Verification Script
-- Run this after making a test order to verify all 4 critical systems

-- 1. Get most recent order
SELECT
    id,
    order_number,
    created_at,
    location_id,
    customer_id,
    total,
    status,
    CASE
        WHEN location_id IS NOT NULL THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as location_check
FROM orders
ORDER BY created_at DESC
LIMIT 1;

-- 2. Check order items for quantity_grams and inventory_id
SELECT
    product_name,
    quantity,
    quantity_grams,
    inventory_id,
    tier_label,
    unit_price,
    CASE
        WHEN quantity_grams IS NOT NULL THEN '✅'
        ELSE '❌ MISSING'
    END as quantity_grams_check,
    CASE
        WHEN inventory_id IS NOT NULL THEN '✅'
        ELSE '❌ MISSING'
    END as inventory_id_check
FROM order_items
WHERE order_id = (SELECT id FROM orders ORDER BY created_at DESC LIMIT 1);

-- 3. Check loyalty transactions (customer orders only)
SELECT
    lt.points_earned,
    lt.transaction_type,
    lt.created_at,
    '✅ Loyalty awarded' as status
FROM loyalty_transactions lt
WHERE order_id = (SELECT id FROM orders ORDER BY created_at DESC LIMIT 1);

-- 4. Check inventory deduction
SELECT
    it.transaction_type,
    it.quantity_change,
    it.quantity_grams,
    it.created_at,
    i.sku,
    i.available_quantity as current_stock,
    '✅ Inventory deducted' as status
FROM inventory_transactions it
JOIN inventory i ON it.inventory_id = i.id
WHERE it.order_id = (SELECT id FROM orders ORDER BY created_at DESC LIMIT 1);

-- 5. Summary check
SELECT
    o.order_number,
    CASE WHEN o.location_id IS NOT NULL THEN '✅' ELSE '❌' END as location_id,
    CASE WHEN COUNT(DISTINCT oi.id) = COUNT(DISTINCT CASE WHEN oi.quantity_grams IS NOT NULL THEN oi.id END)
         THEN '✅' ELSE '❌' END as quantity_grams,
    CASE WHEN COUNT(DISTINCT oi.id) = COUNT(DISTINCT CASE WHEN oi.inventory_id IS NOT NULL THEN oi.id END)
         THEN '✅' ELSE '❌' END as inventory_id,
    CASE
        WHEN o.customer_id IS NULL THEN '⚠️ Guest (N/A)'
        WHEN EXISTS(SELECT 1 FROM loyalty_transactions WHERE order_id = o.id) THEN '✅'
        ELSE '❌'
    END as loyalty,
    CASE WHEN EXISTS(SELECT 1 FROM inventory_transactions WHERE order_id = o.id)
         THEN '✅' ELSE '❌' END as inventory_deduction,
    CASE
        WHEN o.location_id IS NOT NULL
        AND COUNT(DISTINCT oi.id) = COUNT(DISTINCT CASE WHEN oi.quantity_grams IS NOT NULL THEN oi.id END)
        AND COUNT(DISTINCT oi.id) = COUNT(DISTINCT CASE WHEN oi.inventory_id IS NOT NULL THEN oi.id END)
        AND (o.customer_id IS NULL OR EXISTS(SELECT 1 FROM loyalty_transactions WHERE order_id = o.id))
        AND EXISTS(SELECT 1 FROM inventory_transactions WHERE order_id = o.id)
        THEN '✅ ALL SYSTEMS WORKING'
        ELSE '❌ SOME SYSTEMS FAILING'
    END as overall_status
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.id
WHERE o.id = (SELECT id FROM orders ORDER BY created_at DESC LIMIT 1)
GROUP BY o.id, o.order_number, o.location_id, o.customer_id;
