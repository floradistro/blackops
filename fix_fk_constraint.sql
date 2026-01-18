-- Fix the foreign key constraint issue in loyalty_transactions
-- The current constraint tries to SET NULL on delete but customer_id is NOT NULL

BEGIN;

-- Drop the problematic foreign key constraint
ALTER TABLE loyalty_transactions 
DROP CONSTRAINT loyalty_transactions_customer_id_fkey;

-- Add a new constraint that cascades deletes instead of setting null
ALTER TABLE loyalty_transactions 
ADD CONSTRAINT loyalty_transactions_customer_id_fkey 
FOREIGN KEY (customer_id) REFERENCES user_creation_relationships(id) ON DELETE CASCADE;

COMMIT;

-- Script to clean up any other creations that might have similar issues:
-- SELECT 
--   c.id,
--   c.name,
--   COUNT(ucr.id) as user_relationships,
--   COUNT(lt.id) as loyalty_transactions
-- FROM creations c
-- LEFT JOIN user_creation_relationships ucr ON ucr.creation_id = c.id
-- LEFT JOIN loyalty_transactions lt ON lt.customer_id = ucr.id
-- WHERE ucr.id IS NOT NULL
-- GROUP BY c.id, c.name
-- HAVING COUNT(ucr.id) > 0;