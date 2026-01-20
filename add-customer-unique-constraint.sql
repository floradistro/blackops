-- Add unique constraint to prevent duplicate customers going forward
-- This will fail if duplicates exist, showing us the problem

-- For phone numbers
ALTER TABLE customers
  ADD CONSTRAINT customers_store_phone_unique
  UNIQUE (store_id, phone)
  WHERE phone IS NOT NULL;

-- For emails (optional - some people share emails)
-- ALTER TABLE customers
--   ADD CONSTRAINT customers_store_email_unique
--   UNIQUE (store_id, email)
--   WHERE email IS NOT NULL;
