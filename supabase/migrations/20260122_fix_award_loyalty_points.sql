-- Fix award_loyalty_points to actually update balance
CREATE OR REPLACE FUNCTION award_loyalty_points(
  p_customer_id UUID,
  p_order_id UUID,
  p_order_total NUMERIC,
  p_store_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_points INT;
  v_current_balance INT;
  v_new_balance INT;
BEGIN
  -- Check if points already awarded for this order (prevent duplicates)
  IF EXISTS (
    SELECT 1 FROM loyalty_transactions
    WHERE reference_id = p_order_id
    AND customer_id = p_customer_id
    AND transaction_type = 'earned'
  ) THEN
    RAISE NOTICE 'Loyalty points already awarded for order %', p_order_id;
    RETURN; -- Already awarded, skip
  END IF;

  -- Calculate points (1 point per dollar)
  v_points := FLOOR(p_order_total);

  IF v_points <= 0 THEN
    RETURN;
  END IF;

  -- Get current balance from store_customer_profiles
  SELECT COALESCE(loyalty_points, 0) INTO v_current_balance
  FROM store_customer_profiles
  WHERE relationship_id = p_customer_id;

  -- If no profile exists, current balance is 0
  IF v_current_balance IS NULL THEN
    v_current_balance := 0;
  END IF;

  v_new_balance := v_current_balance + v_points;

  -- Create loyalty transaction
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
    'Earned ' || v_points || ' points from order',
    v_current_balance,
    v_new_balance
  );

  -- Update balance in store_customer_profiles (upsert)
  INSERT INTO store_customer_profiles (relationship_id, loyalty_points)
  VALUES (p_customer_id, v_new_balance)
  ON CONFLICT (relationship_id)
  DO UPDATE SET loyalty_points = v_new_balance;

  RAISE NOTICE 'Awarded % points to customer %, new balance: %', v_points, p_customer_id, v_new_balance;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
