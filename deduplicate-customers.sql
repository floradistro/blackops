-- Deduplicate customers by phone number
-- Keep the customer with the most data and earliest created_at

BEGIN;

-- Create temp table with customers to keep (one per phone)
CREATE TEMP TABLE customers_to_keep AS
WITH ranked_customers AS (
  SELECT
    id,
    phone,
    email,
    store_id,
    created_at,
    -- Rank by data completeness and age
    ROW_NUMBER() OVER (
      PARTITION BY store_id, phone
      ORDER BY
        -- Prefer records with email
        CASE WHEN email IS NOT NULL THEN 0 ELSE 1 END,
        -- Prefer older records
        created_at ASC
    ) as rn
  FROM customers
  WHERE phone IS NOT NULL
)
SELECT id, phone, store_id
FROM ranked_customers
WHERE rn = 1;

-- Show what will be merged
SELECT
  'Phone duplicates to merge:' as action,
  COUNT(*) as count
FROM customers c
WHERE phone IS NOT NULL
  AND id NOT IN (SELECT id FROM customers_to_keep)
  AND EXISTS (
    SELECT 1 FROM customers_to_keep k
    WHERE k.phone = c.phone AND k.store_id = c.store_id
  );

-- For each duplicate, update references then delete

-- 1. Update orders to point to the keeper customer
UPDATE orders o
SET customer_id = k.id
FROM customers c
JOIN customers_to_keep k ON k.phone = c.phone AND k.store_id = c.store_id
WHERE o.customer_id = c.id
  AND c.id != k.id
  AND c.phone IS NOT NULL;

-- 2. Update customer_loyalty to point to keeper (or delete if duplicate)
UPDATE customer_loyalty cl
SET customer_id = k.id
FROM customers c
JOIN customers_to_keep k ON k.phone = c.phone AND k.store_id = c.store_id
WHERE cl.customer_id = c.id
  AND c.id != k.id
  AND c.phone IS NOT NULL
  -- Only if keeper doesn't already have loyalty record
  AND NOT EXISTS (
    SELECT 1 FROM customer_loyalty WHERE customer_id = k.id AND store_id = k.store_id
  );

-- Delete duplicate loyalty records
DELETE FROM customer_loyalty cl
USING customers c, customers_to_keep k
WHERE cl.customer_id = c.id
  AND k.phone = c.phone
  AND k.store_id = c.store_id
  AND c.id != k.id
  AND c.phone IS NOT NULL;

-- 3. Update customer_notes to point to keeper
UPDATE customer_notes cn
SET customer_id = k.id
FROM customers c
JOIN customers_to_keep k ON k.phone = c.phone AND k.store_id = c.store_id
WHERE cn.customer_id = c.id
  AND c.id != k.id
  AND c.phone IS NOT NULL;

-- 4. Delete duplicate customer records
DELETE FROM customers c
USING customers_to_keep k
WHERE k.phone = c.phone
  AND k.store_id = c.store_id
  AND c.id != k.id
  AND c.phone IS NOT NULL;

-- Show results
SELECT
  'Customers remaining:' as status,
  COUNT(*) as count
FROM customers;

-- Add unique constraint to prevent future duplicates
ALTER TABLE customers
  DROP CONSTRAINT IF EXISTS customers_store_phone_unique;

ALTER TABLE customers
  ADD CONSTRAINT customers_store_phone_unique
  UNIQUE (store_id, phone)
  WHERE phone IS NOT NULL;

COMMIT;
