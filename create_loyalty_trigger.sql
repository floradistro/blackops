-- Create trigger to auto-update loyalty balance
CREATE OR REPLACE FUNCTION update_loyalty_balance()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalculate total balance from all transactions
  UPDATE store_customer_profiles
  SET loyalty_points = (
    SELECT COALESCE(SUM(points), 0)
    FROM loyalty_transactions
    WHERE customer_id = NEW.customer_id
  )
  WHERE relationship_id = NEW.customer_id;

  -- If no profile exists, create one
  IF NOT FOUND THEN
    INSERT INTO store_customer_profiles (relationship_id, loyalty_points)
    VALUES (NEW.customer_id, NEW.points)
    ON CONFLICT (relationship_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS loyalty_balance_trigger ON loyalty_transactions;

-- Create trigger that fires after INSERT on loyalty_transactions
CREATE TRIGGER loyalty_balance_trigger
AFTER INSERT ON loyalty_transactions
FOR EACH ROW
EXECUTE FUNCTION update_loyalty_balance();
