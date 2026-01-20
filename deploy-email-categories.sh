#!/bin/bash

# Email Categories Deployment Script
# Deploys the new email category system to Supabase
# Run from project root: ./deploy-email-categories.sh

set -e  # Exit on error

echo "🚀 Deploying Email Category System..."
echo ""

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Error: Supabase CLI is not installed"
    echo "Install it with: brew install supabase/tap/supabase"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "supabase/config.toml" ]; then
    echo "❌ Error: supabase/config.toml not found"
    echo "Run this script from the project root directory"
    exit 1
fi

# Run the migration
echo "📦 Applying migration: 20260120_email_categories.sql"
supabase db push

echo ""
echo "✅ Migration applied successfully!"
echo ""
echo "📊 Summary of changes:"
echo "  - Added 'category' column to email_sends table"
echo "  - Created indexes for fast filtering"
echo "  - Backfilled existing emails with intelligent defaults"
echo "  - Added get_email_category_name() helper function"
echo ""
echo "🎯 Next steps:"
echo "  1. Rebuild the SwagManager app (Cmd+B in Xcode)"
echo "  2. Test the new email categories in the sidebar"
echo "  3. Scroll to bottom of email list to load more emails"
echo ""
echo "📚 Email Categories Available:"
echo "  Authentication: Password Reset, Email Verification, Welcome, 2FA, Security Alert"
echo "  Orders: Confirmation, Processing, Shipped, Delivered, Delayed, Cancelled, Refunds"
echo "  Receipts & Payments: Order Receipt, Refund Receipt, Payment Failed, Payment Reminder"
echo "  Support: Ticket Created, Ticket Reply, Ticket Resolved"
echo "  Campaigns: Promotional, Newsletter, Seasonal, Flash Sale"
echo "  Loyalty: Points Earned, Reward Available, Tier Upgraded, Win-back, Abandoned Cart"
echo "  System: Notifications, Maintenance, Admin Alerts"
echo ""
echo "✨ Done!"
