-- Migration: Email Categories System
-- Adds granular categorization for email tracking
-- Author: SwagManager Engineering
-- Date: 2026-01-20

-- Add category column to email_sends
ALTER TABLE email_sends
ADD COLUMN IF NOT EXISTS category TEXT;

-- Create index for category filtering (performance)
CREATE INDEX IF NOT EXISTS idx_email_sends_category
ON email_sends(category);

-- Create index for composite filtering (category + store_id)
CREATE INDEX IF NOT EXISTS idx_email_sends_category_store
ON email_sends(store_id, category, created_at DESC);

-- Add check constraint for valid categories
ALTER TABLE email_sends
ADD CONSTRAINT email_sends_category_check
CHECK (category IS NULL OR category IN (
  -- Authentication emails
  'auth_password_reset',
  'auth_verify_email',
  'auth_welcome',
  'auth_2fa_code',
  'auth_security_alert',

  -- Order lifecycle emails
  'order_confirmation',
  'order_processing',
  'order_shipped',
  'order_out_for_delivery',
  'order_delivered',
  'order_delayed',
  'order_cancelled',
  'order_refund_initiated',
  'order_refund_completed',

  -- Receipt and payment emails
  'receipt_order',
  'receipt_refund',
  'payment_failed',
  'payment_reminder',

  -- Customer service emails
  'support_ticket_created',
  'support_ticket_replied',
  'support_ticket_resolved',

  -- Marketing campaign emails
  'campaign_promotional',
  'campaign_newsletter',
  'campaign_seasonal',
  'campaign_flash_sale',

  -- Loyalty and retention emails
  'loyalty_points_earned',
  'loyalty_reward_available',
  'loyalty_tier_upgraded',
  'retention_winback',
  'retention_abandoned_cart',

  -- System and notification emails
  'system_notification',
  'system_maintenance',
  'admin_alert'
));

-- Backfill existing records with intelligent defaults based on email_type and subject
UPDATE email_sends
SET category = CASE
  -- Try to infer from subject line
  WHEN LOWER(subject) LIKE '%password%reset%' THEN 'auth_password_reset'
  WHEN LOWER(subject) LIKE '%verify%email%' THEN 'auth_verify_email'
  WHEN LOWER(subject) LIKE '%welcome%' THEN 'auth_welcome'
  WHEN LOWER(subject) LIKE '%shipped%' THEN 'order_shipped'
  WHEN LOWER(subject) LIKE '%delivered%' THEN 'order_delivered'
  WHEN LOWER(subject) LIKE '%cancelled%' THEN 'order_cancelled'
  WHEN LOWER(subject) LIKE '%refund%' THEN 'order_refund_completed'
  WHEN LOWER(subject) LIKE '%receipt%' THEN 'receipt_order'
  WHEN LOWER(subject) LIKE '%abandoned%cart%' THEN 'retention_abandoned_cart'

  -- Fallback to email_type
  WHEN email_type = 'transactional' AND order_id IS NOT NULL THEN 'order_confirmation'
  WHEN email_type = 'transactional' THEN 'system_notification'
  WHEN email_type = 'marketing' AND campaign_id IS NOT NULL THEN 'campaign_promotional'
  WHEN email_type = 'marketing' THEN 'campaign_newsletter'

  -- Default fallback
  ELSE 'system_notification'
END
WHERE category IS NULL;

-- Add comment to table for documentation
COMMENT ON COLUMN email_sends.category IS 'Granular email category for filtering and analytics. See EmailCategory enum in Swift code for valid values.';

-- Create helper function to get category display name
CREATE OR REPLACE FUNCTION get_email_category_name(cat TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE cat
    WHEN 'auth_password_reset' THEN 'Password Reset'
    WHEN 'auth_verify_email' THEN 'Email Verification'
    WHEN 'auth_welcome' THEN 'Welcome Email'
    WHEN 'auth_2fa_code' THEN '2FA Code'
    WHEN 'auth_security_alert' THEN 'Security Alert'
    WHEN 'order_confirmation' THEN 'Order Confirmation'
    WHEN 'order_processing' THEN 'Order Processing'
    WHEN 'order_shipped' THEN 'Order Shipped'
    WHEN 'order_out_for_delivery' THEN 'Out for Delivery'
    WHEN 'order_delivered' THEN 'Order Delivered'
    WHEN 'order_delayed' THEN 'Order Delayed'
    WHEN 'order_cancelled' THEN 'Order Cancelled'
    WHEN 'order_refund_initiated' THEN 'Refund Initiated'
    WHEN 'order_refund_completed' THEN 'Refund Completed'
    WHEN 'receipt_order' THEN 'Order Receipt'
    WHEN 'receipt_refund' THEN 'Refund Receipt'
    WHEN 'payment_failed' THEN 'Payment Failed'
    WHEN 'payment_reminder' THEN 'Payment Reminder'
    WHEN 'support_ticket_created' THEN 'Ticket Created'
    WHEN 'support_ticket_replied' THEN 'Ticket Reply'
    WHEN 'support_ticket_resolved' THEN 'Ticket Resolved'
    WHEN 'campaign_promotional' THEN 'Promotional Campaign'
    WHEN 'campaign_newsletter' THEN 'Newsletter'
    WHEN 'campaign_seasonal' THEN 'Seasonal Campaign'
    WHEN 'campaign_flash_sale' THEN 'Flash Sale'
    WHEN 'loyalty_points_earned' THEN 'Points Earned'
    WHEN 'loyalty_reward_available' THEN 'Reward Available'
    WHEN 'loyalty_tier_upgraded' THEN 'Tier Upgraded'
    WHEN 'retention_winback' THEN 'Win-back Campaign'
    WHEN 'retention_abandoned_cart' THEN 'Abandoned Cart'
    WHEN 'system_notification' THEN 'System Notification'
    WHEN 'system_maintenance' THEN 'Maintenance Notice'
    WHEN 'admin_alert' THEN 'Admin Alert'
    ELSE 'Unknown'
  END;
END;
$$;
