-- Migration: Delete test orders and their related data
-- Date: 2026-01-25
-- Description: Safely removes test orders (shipping_name containing 'test')
--              along with their order_items and payment_intents

-- First, create a function to handle the cleanup properly
CREATE OR REPLACE FUNCTION delete_test_orders()
RETURNS TABLE(
  orders_deleted INT,
  order_items_deleted INT,
  payment_intents_deleted INT,
  customers_orphaned INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_orders_deleted INT := 0;
  v_order_items_deleted INT := 0;
  v_payment_intents_deleted INT := 0;
  v_customers_orphaned INT := 0;
  v_order_ids UUID[];
BEGIN
  -- Get all test order IDs
  SELECT ARRAY_AGG(id) INTO v_order_ids
  FROM orders
  WHERE shipping_name ILIKE '%test%';

  IF v_order_ids IS NULL OR array_length(v_order_ids, 1) IS NULL THEN
    RETURN QUERY SELECT 0, 0, 0, 0;
    RETURN;
  END IF;

  -- Delete order_items first (child table)
  DELETE FROM order_items
  WHERE order_id = ANY(v_order_ids);
  GET DIAGNOSTICS v_order_items_deleted = ROW_COUNT;

  -- Delete payment_intents (child table)
  DELETE FROM payment_intents
  WHERE order_id = ANY(v_order_ids);
  GET DIAGNOSTICS v_payment_intents_deleted = ROW_COUNT;

  -- Delete the orders themselves
  DELETE FROM orders
  WHERE id = ANY(v_order_ids);
  GET DIAGNOSTICS v_orders_deleted = ROW_COUNT;

  -- Check for orphaned test customers (no orders left)
  SELECT COUNT(*) INTO v_customers_orphaned
  FROM customers c
  WHERE (c.first_name ILIKE '%test%' OR c.last_name ILIKE '%user%')
  AND NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id
  );

  RETURN QUERY SELECT v_orders_deleted, v_order_items_deleted, v_payment_intents_deleted, v_customers_orphaned;
END;
$$;

-- Execute the cleanup
DO $$
DECLARE
  result RECORD;
BEGIN
  SELECT * INTO result FROM delete_test_orders();
  RAISE NOTICE 'Test Data Cleanup Results:';
  RAISE NOTICE '  Orders deleted: %', result.orders_deleted;
  RAISE NOTICE '  Order items deleted: %', result.order_items_deleted;
  RAISE NOTICE '  Payment intents deleted: %', result.payment_intents_deleted;
  RAISE NOTICE '  Orphaned test customers remaining: %', result.customers_orphaned;
END;
$$;

-- Drop the function after use (cleanup)
DROP FUNCTION IF EXISTS delete_test_orders();
