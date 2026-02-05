-- PROPER ARCHITECTURAL FIX FOR QUEUE + CART SYSTEM
-- Fixes the "works once then stops" bug
-- Date: 2026-01-22 23:50 EST

BEGIN;

-- ============================================
-- 1. FIX THE UNIQUE CONSTRAINT
-- ============================================
-- Problem: UNIQUE (location_id, cart_id) prevents re-adding same customer
-- Solution: UNIQUE (location_id, customer_id) prevents duplicate queue entries

ALTER TABLE location_queue
DROP CONSTRAINT IF EXISTS location_queue_location_id_cart_id_key;

ALTER TABLE location_queue
ADD CONSTRAINT location_queue_location_customer_unique
UNIQUE (location_id, customer_id);

-- ============================================
-- 2. CREATE ATOMIC "ADD TO QUEUE" FUNCTION
-- ============================================
-- Single atomic operation that:
-- - Creates/gets cart
-- - Adds to queue (or updates if exists)
-- - Returns everything
-- - Is idempotent (safe to call multiple times)

CREATE OR REPLACE FUNCTION add_customer_to_queue(
  p_customer_id UUID,
  p_location_id UUID,
  p_store_id UUID,
  p_fresh_start BOOLEAN DEFAULT TRUE,
  p_device_id UUID DEFAULT NULL
) RETURNS TABLE (
  queue_entry_id UUID,
  cart_id UUID,
  queue_position INTEGER,
  created_new BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart_id UUID;
  v_cart_created BOOLEAN;
  v_queue_id UUID;
  v_position INTEGER;
  v_existing_queue_id UUID;
BEGIN
  -- 1. Get or create cart (atomic, with fresh start option)
  SELECT get_or_create_cart.cart_id, get_or_create_cart.created
  INTO v_cart_id, v_cart_created
  FROM get_or_create_cart(
    p_customer_id,
    p_location_id,
    p_store_id,
    p_device_id,
    p_fresh_start
  );

  -- 2. Check if customer already in queue at this location
  SELECT id INTO v_existing_queue_id
  FROM location_queue
  WHERE location_id = p_location_id
    AND customer_id = p_customer_id;

  -- 3. Add to queue (or update if exists)
  IF v_existing_queue_id IS NULL THEN
    -- New queue entry
    INSERT INTO location_queue (
      location_id,
      cart_id,
      customer_id,
      position,
      added_at
    ) VALUES (
      p_location_id,
      v_cart_id,
      p_customer_id,
      (SELECT COALESCE(MAX(position), 0) + 1 FROM location_queue WHERE location_id = p_location_id),
      NOW()
    )
    RETURNING id, position INTO v_queue_id, v_position;
  ELSE
    -- Update existing entry
    UPDATE location_queue
    SET cart_id = v_cart_id,
        added_at = NOW()
    WHERE id = v_existing_queue_id
    RETURNING id, position INTO v_queue_id, v_position;
  END IF;

  -- 4. Return everything
  RETURN QUERY SELECT
    v_queue_id,
    v_cart_id,
    v_position,
    (v_existing_queue_id IS NULL) as created_new;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION add_customer_to_queue(UUID, UUID, UUID, BOOLEAN, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION add_customer_to_queue(UUID, UUID, UUID, BOOLEAN, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION add_customer_to_queue(UUID, UUID, UUID, BOOLEAN, UUID) TO anon;

COMMENT ON FUNCTION add_customer_to_queue IS 'Atomically adds customer to queue with cart. Idempotent - safe to call multiple times. Returns queue entry, cart, and position.';

COMMIT;

-- ============================================
-- 3. TEST THE FIX
-- ============================================

-- Test 1: Add customer to queue (should work)
SELECT * FROM add_customer_to_queue(
  'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804'::UUID,  -- Fahad
  '4d0685cc-6dfd-4c2e-a640-d8cfd4080975'::UUID,  -- Blowing Rock
  'cd2e1122-d511-4edb-be5d-98ef274b4baf'::UUID,  -- Store
  TRUE  -- fresh_start
);

-- Test 2: Add SAME customer again (should be idempotent - update existing)
SELECT * FROM add_customer_to_queue(
  'b3076a6c-98b5-4def-9fc2-ea3f8f3f2804'::UUID,
  '4d0685cc-6dfd-4c2e-a640-d8cfd4080975'::UUID,
  'cd2e1122-d511-4edb-be5d-98ef274b4baf'::UUID,
  TRUE
);

-- Test 3: Verify no duplicates
SELECT
  COUNT(*) as total_entries,
  COUNT(DISTINCT customer_id) as unique_customers
FROM location_queue
WHERE location_id = '4d0685cc-6dfd-4c2e-a640-d8cfd4080975';

-- Should show: total_entries = unique_customers (no duplicates!)
