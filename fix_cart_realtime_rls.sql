-- Fix cart realtime by adding permissive RLS policies
-- Problem: Clients can't receive realtime events because RLS blocks SELECT
-- Solution: Add policies that allow clients to see carts they're working with

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "carts_store_access" ON carts;
DROP POLICY IF EXISTS "cart_items_access" ON cart_items;

-- Carts: Allow service_role full access
CREATE POLICY "Service role full access on carts"
ON carts FOR ALL
TO public
USING (auth.role() = 'service_role');

-- Carts: Allow users to see carts for their store
CREATE POLICY "Users can view carts for their store"
ON carts FOR SELECT
TO public
USING (store_id = get_user_store_id());

-- Carts: Allow users to see carts at locations they have access to
CREATE POLICY "Users can view carts at their locations"
ON carts FOR SELECT
TO public
USING (
  location_id IN (
    SELECT l.id
    FROM locations l
    WHERE l.store_id = get_user_store_id()
  )
);

-- Carts: Allow INSERT/UPDATE/DELETE for authenticated users (edge function uses service_role)
CREATE POLICY "Authenticated users can modify carts"
ON carts FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Cart Items: Allow service_role full access
CREATE POLICY "Service role full access on cart_items"
ON cart_items FOR ALL
TO public
USING (auth.role() = 'service_role');

-- Cart Items: Allow users to see items in carts they can access
CREATE POLICY "Users can view cart_items for accessible carts"
ON cart_items FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1
    FROM carts c
    WHERE c.id = cart_items.cart_id
      AND (
        c.store_id = get_user_store_id()
        OR c.location_id IN (
          SELECT l.id
          FROM locations l
          WHERE l.store_id = get_user_store_id()
        )
      )
  )
);

-- Cart Items: Allow INSERT/UPDATE/DELETE for authenticated users (edge function uses service_role)
CREATE POLICY "Authenticated users can modify cart_items"
ON cart_items FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Verify policies
SELECT schemaname, tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('carts', 'cart_items')
ORDER BY tablename, policyname;
