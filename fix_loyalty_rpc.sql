-- Drop and recreate award_loyalty_points RPC properly
DROP FUNCTION IF EXISTS public.award_loyalty_points(UUID, UUID, NUMERIC, UUID);

CREATE OR REPLACE FUNCTION public.award_loyalty_points(
  p_customer_id UUID,
  p_order_id UUID,
  p_order_total NUMERIC,
  p_store_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_points INTEGER;
  v_current_balance INTEGER;
  v_new_balance INTEGER;
BEGIN
  -- Prevent duplicate awards
  IF EXISTS (
    SELECT 1 FROM loyalty_transactions
    WHERE reference_id = p_order_id
    AND customer_id = p_customer_id
    AND transaction_type = 'earned'
  ) THEN
    RAISE NOTICE 'Points already awarded for order %', p_order_id;
    RETURN;
  END IF;

  -- Calculate points (1 point per dollar)
  v_points := FLOOR(p_order_total)::INTEGER;

  IF v_points <= 0 THEN
    RETURN;
  END IF;

  -- Get current balance
  SELECT COALESCE(loyalty_points, 0)
  INTO v_current_balance
  FROM store_customer_profiles
  WHERE relationship_id = p_customer_id;

  -- Calculate new balance
  v_new_balance := COALESCE(v_current_balance, 0) + v_points;

  -- Insert transaction
  INSERT INTO loyalty_transactions (
    customer_id,
    transaction_type,
    points,
    reference_type,
    reference_id,
    description,
    balance_before,
    balance_after
  ) VALUES (
    p_customer_id,
    'earned',
    v_points,
    'order',
    p_order_id,
    format('Earned %s points from order', v_points),
    COALESCE(v_current_balance, 0),
    v_new_balance
  );

  -- Update balance (UPSERT)
  INSERT INTO store_customer_profiles (relationship_id, loyalty_points)
  VALUES (p_customer_id, v_new_balance)
  ON CONFLICT (relationship_id)
  DO UPDATE SET loyalty_points = EXCLUDED.loyalty_points;

  RAISE NOTICE 'Awarded % points to customer %, new balance: %', v_points, p_customer_id, v_new_balance;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.award_loyalty_points(UUID, UUID, NUMERIC, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.award_loyalty_points(UUID, UUID, NUMERIC, UUID) TO service_role;
