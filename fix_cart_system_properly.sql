-- PROPER FIX FOR CART SYSTEM
-- Adds unique constraints and atomic RPC function
-- Date: 2026-01-22 19:50 EST

BEGIN;

-- ============================================
-- 1. ADD UNIQUE CONSTRAINT
-- ============================================
-- This PREVENTS duplicate active carts at the database level

-- For carts with customers (most common case)
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_cart_per_customer_location
ON carts(customer_id, location_id)
WHERE status = 'active' AND customer_id IS NOT NULL;

-- For anonymous carts (no customer, identified by device_id)
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_cart_anonymous
ON carts(location_id, device_id)
WHERE status = 'active' AND customer_id IS NULL AND device_id IS NOT NULL;

-- ============================================
-- 2. CREATE ATOMIC RPC FUNCTION
-- ============================================
-- This function gets-or-creates a cart ATOMICALLY
-- No race conditions possible!

CREATE OR REPLACE FUNCTION get_or_create_cart(
  p_customer_id UUID,
  p_location_id UUID,
  p_store_id UUID,
  p_device_id UUID DEFAULT NULL,
  p_fresh_start BOOLEAN DEFAULT FALSE
) RETURNS TABLE (
  cart_id UUID,
  created BOOLEAN
) AS $$
DECLARE
  v_cart_id UUID;
  v_created BOOLEAN := FALSE;
BEGIN
  -- Try to insert, or update if exists (ATOMIC UPSERT)
  INSERT INTO carts (
    customer_id,
    location_id,
    store_id,
    device_id,
    status,
    expires_at,
    created_at,
    updated_at
  ) VALUES (
    p_customer_id,
    p_location_id,
    p_store_id,
    p_device_id,
    'active',
    NOW() + INTERVAL '4 hours',
    NOW(),
    NOW()
  )
  ON CONFLICT (customer_id, location_id)
  WHERE status = 'active' AND customer_id IS NOT NULL
  DO UPDATE SET
    updated_at = NOW(),
    expires_at = NOW() + INTERVAL '4 hours',
    -- Update store_id if provided
    store_id = COALESCE(EXCLUDED.store_id, carts.store_id)
  RETURNING id, (xmax = 0) INTO v_cart_id, v_created;

  -- If fresh_start, clear all items
  IF p_fresh_start THEN
    DELETE FROM cart_items WHERE cart_id = v_cart_id;
  END IF;

  RETURN QUERY SELECT v_cart_id, v_created;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_or_create_cart(UUID, UUID, UUID, UUID, BOOLEAN) TO service_role;
GRANT EXECUTE ON FUNCTION get_or_create_cart(UUID, UUID, UUID, UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION get_or_create_cart(UUID, UUID, UUID, UUID, BOOLEAN) TO anon;

-- ============================================
-- 3. TEST THE FUNCTION
-- ============================================
-- This should create a cart
SELECT * FROM get_or_create_cart(
  'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804'::UUID,  -- customer
  '4d0685cc-6dfd-4c2e-a640-d8cfd4080975'::UUID,  -- location
  'cd2e1122-d511-4edb-be5d-98ef274b4baf'::UUID,  -- store
  NULL,
  FALSE
);

-- Call it again - should return SAME cart
SELECT * FROM get_or_create_cart(
  'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804'::UUID,
  '4d0685cc-6dfd-4c2e-a640-d8cfd4080975'::UUID,
  'cd2e1122-d511-4edb-be5d-98ef274b4baf'::UUID,
  NULL,
  FALSE
);

COMMIT;

-- ============================================
-- 4. VERIFY NO DUPLICATES POSSIBLE
-- ============================================
SELECT
  customer_id,
  location_id,
  COUNT(*) as cart_count
FROM carts
WHERE status = 'active'
AND customer_id IS NOT NULL
GROUP BY customer_id, location_id
HAVING COUNT(*) > 1;

-- Should return 0 rows!
