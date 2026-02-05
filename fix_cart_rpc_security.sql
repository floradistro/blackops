-- Fix get_or_create_cart to use SECURITY DEFINER
-- This allows it to bypass RLS policies which are causing ambiguous column reference

DROP FUNCTION IF EXISTS get_or_create_cart(UUID, UUID, UUID, UUID, BOOLEAN);

CREATE OR REPLACE FUNCTION get_or_create_cart(
  p_customer_id UUID,
  p_location_id UUID,
  p_store_id UUID,
  p_device_id UUID DEFAULT NULL,
  p_fresh_start BOOLEAN DEFAULT FALSE
) RETURNS TABLE (
  cart_id UUID,
  created BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER  -- Run with function owner's privileges, bypass RLS
SET search_path = public
AS $$
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
    store_id = COALESCE(EXCLUDED.store_id, carts.store_id)
  RETURNING id, (xmax = 0) INTO v_cart_id, v_created;

  -- If fresh_start, clear all items (now bypasses RLS)
  IF p_fresh_start THEN
    DELETE FROM cart_items WHERE cart_items.cart_id = v_cart_id;
  END IF;

  RETURN QUERY SELECT v_cart_id, v_created;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_or_create_cart(UUID, UUID, UUID, UUID, BOOLEAN) TO service_role;
GRANT EXECUTE ON FUNCTION get_or_create_cart(UUID, UUID, UUID, UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION get_or_create_cart(UUID, UUID, UUID, UUID, BOOLEAN) TO anon;

COMMENT ON FUNCTION get_or_create_cart IS 'Atomically gets or creates a cart for a customer at a location. Uses SECURITY DEFINER to bypass RLS ambiguity issues.';
