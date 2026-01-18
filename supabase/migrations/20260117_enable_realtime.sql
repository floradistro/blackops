-- Enable Realtime for creation tables
-- This allows the SwagManager app to receive instant updates

-- Add tables to the supabase_realtime publication
-- This is required for Postgres changes to be broadcast via Supabase Realtime

-- First, drop and recreate to ensure clean state
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime;

-- Add core tables that need realtime updates
ALTER PUBLICATION supabase_realtime ADD TABLE creations;
ALTER PUBLICATION supabase_realtime ADD TABLE creation_collections;
ALTER PUBLICATION supabase_realtime ADD TABLE creation_collection_items;

-- Also add inventory-related tables for menu displays
ALTER PUBLICATION supabase_realtime ADD TABLE inventory;
ALTER PUBLICATION supabase_realtime ADD TABLE products;
ALTER PUBLICATION supabase_realtime ADD TABLE variants;
ALTER PUBLICATION supabase_realtime ADD TABLE inventory_adjustments;

-- Set REPLICA IDENTITY to FULL for tables that need DELETE event details
-- This allows the oldRecord to contain all columns, not just primary key
ALTER TABLE creations REPLICA IDENTITY FULL;
ALTER TABLE creation_collections REPLICA IDENTITY FULL;
ALTER TABLE creation_collection_items REPLICA IDENTITY FULL;

COMMENT ON PUBLICATION supabase_realtime IS 'Publication for Supabase Realtime - enables instant updates in SwagManager app';
