# Email Categories System - Implementation Guide

## Overview

The Email Categories System provides a comprehensive, type-safe taxonomy for organizing and filtering emails in SwagManager. This replaces the simple two-category system (transactional/marketing) with 40+ granular categories organized into 7 major groups.

**Built with Apple-level engineering standards:**
- Type-safe enums (no magic strings)
- Infinite scroll pagination (loads ALL emails)
- Nested category UI with SF Symbols
- Performance-optimized with database indexes
- Intelligent backfilling of existing data

---

## Architecture

### Database Layer
**File:** `supabase/migrations/20260120_email_categories.sql`

- Adds `category` column to `email_sends` table
- Creates composite indexes for fast filtering
- Backfills existing emails with intelligent defaults
- Provides `get_email_category_name()` SQL helper function

### Model Layer
**File:** `SwagManager/Models/EmailCategory.swift`

Type-safe enum with 40+ categories organized into groups:
- Authentication (5 categories)
- Orders (9 categories)
- Receipts & Payments (4 categories)
- Support (3 categories)
- Campaigns (4 categories)
- Loyalty & Retention (5 categories)
- System (3 categories)

Each category provides:
- `displayName`: Human-readable name
- `icon`: SF Symbol icon name
- `color`: Semantic color
- `group`: Parent group

**File:** `SwagManager/Models/ResendEmail.swift`

Extended with category support:
- `category: EmailCategory?` - Type-safe category enum
- `categoryDisplayName` - Display name
- `categoryIcon` - SF Symbol
- `categoryColor` - Semantic color
- `categoryGroup` - Parent group
- Helper properties: `isAuthEmail`, `isOrderEmail`, etc.

### Store Layer
**File:** `SwagManager/Stores/EditorStore+Resend.swift`

Infinite scroll pagination:
- `loadEmails()` - Load initial batch
- `loadMoreEmails()` - Load next page
- `refreshEmails()` - Pull to refresh
- `hasLoadedAllEmails` - Pagination state

Category filtering:
- `emails(for: EmailCategory)` - Filter by specific category
- `emails(for: EmailCategory.Group)` - Filter by group
- Computed properties for each group (authenticationEmails, orderEmails, etc.)

### UI Layer
**File:** `SwagManager/Views/Editor/Sidebar/EmailCategorySection.swift`

Reusable component for displaying category groups with:
- Collapsible group headers
- Nested subcategory sections
- Email count badges
- Color-coded icons

**File:** `SwagManager/Views/Editor/Sidebar/SidebarResendSection.swift`

Updated sidebar with:
- Priority "Failed" section at top
- Dynamic category groups (only shows groups with emails)
- "Load More" button when more emails available
- Loading indicators for pagination
- Empty states

---

## Email Categories

### Authentication
- **Password Reset** (`auth_password_reset`) - Password reset emails
- **Email Verification** (`auth_verify_email`) - Email verification links
- **Welcome Email** (`auth_welcome`) - New user welcome emails
- **2FA Code** (`auth_2fa_code`) - Two-factor authentication codes
- **Security Alert** (`auth_security_alert`) - Security notifications

### Orders
- **Order Confirmation** (`order_confirmation`) - Order placed confirmation
- **Order Processing** (`order_processing`) - Order is being prepared
- **Order Shipped** (`order_shipped`) - Shipping notification
- **Out for Delivery** (`order_out_for_delivery`) - Last mile delivery
- **Order Delivered** (`order_delivered`) - Delivery confirmation
- **Order Delayed** (`order_delayed`) - Delay notification
- **Order Cancelled** (`order_cancelled`) - Cancellation confirmation
- **Refund Initiated** (`order_refund_initiated`) - Refund started
- **Refund Completed** (`order_refund_completed`) - Refund processed

### Receipts & Payments
- **Order Receipt** (`receipt_order`) - Purchase receipt
- **Refund Receipt** (`receipt_refund`) - Refund receipt
- **Payment Failed** (`payment_failed`) - Payment failure notification
- **Payment Reminder** (`payment_reminder`) - Payment due reminder

### Customer Support
- **Ticket Created** (`support_ticket_created`) - Support ticket opened
- **Ticket Reply** (`support_ticket_replied`) - Support response
- **Ticket Resolved** (`support_ticket_resolved`) - Ticket closed

### Marketing Campaigns
- **Promotional Campaign** (`campaign_promotional`) - Promotional offers
- **Newsletter** (`campaign_newsletter`) - Regular newsletters
- **Seasonal Campaign** (`campaign_seasonal`) - Holiday/seasonal campaigns
- **Flash Sale** (`campaign_flash_sale`) - Limited-time sales

### Loyalty & Retention
- **Points Earned** (`loyalty_points_earned`) - Loyalty points notification
- **Reward Available** (`loyalty_reward_available`) - Reward ready to claim
- **Tier Upgraded** (`loyalty_tier_upgraded`) - Loyalty tier increase
- **Win-back Campaign** (`retention_winback`) - Re-engagement email
- **Abandoned Cart** (`retention_abandoned_cart`) - Cart reminder

### System
- **System Notification** (`system_notification`) - General system messages
- **Maintenance Notice** (`system_maintenance`) - Downtime notifications
- **Admin Alert** (`admin_alert`) - Internal admin alerts

---

## Deployment

### 1. Deploy Database Migration

```bash
cd /Users/whale/Desktop/blackops
./deploy-email-categories.sh
```

This will:
1. Apply the migration to add the `category` column
2. Create performance indexes
3. Backfill existing emails with intelligent defaults

### 2. Rebuild SwagManager

Open Xcode and rebuild:
```bash
open SwagManager.xcodeproj
# Press Cmd+B to build
```

### 3. Test the Features

1. **Category Organization**
   - Open the app
   - Expand the "Emails" section in sidebar
   - See emails organized by category groups
   - Click to expand subcategories

2. **Infinite Scroll**
   - Scroll to bottom of email list
   - Click "Load More" button
   - Emails load in batches of 200
   - Keeps loading until all emails retrieved

3. **Failed Emails Priority**
   - Failed emails always show at top
   - Highlighted in red
   - Separate from other categories

---

## Usage Examples

### Backend: Setting Category When Sending Email

When creating emails via your Edge Function or backend:

```typescript
// supabase edge function
await supabase
  .from('email_sends')
  .insert({
    store_id: storeId,
    customer_id: customerId,
    order_id: orderId,
    email_type: 'transactional',
    category: 'order_shipped', // ← New field
    to_email: customer.email,
    subject: 'Your order has shipped!',
    // ... other fields
  })
```

### Swift: Filtering by Category

```swift
// In your view or store
let passwordResets = store.emails.filter(category: .authPasswordReset)
let orderEmails = store.emails.filter(group: .orders)
let authEmails = store.authenticationEmails

// Check email properties
if email.isOrderEmail {
    print("This is an order-related email")
}

print(email.categoryDisplayName) // "Order Shipped"
print(email.categoryIcon) // "shippingbox.fill"
```

### UI: Custom Category Filters

```swift
// Create custom filtered views
struct OrderEmailsList: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        List(store.orderEmails) { email in
            EmailRow(email: email)
        }
    }
}
```

---

## Performance Optimizations

### Database
- Composite index on `(store_id, category, created_at)` for fast queries
- Single index on `category` for global filtering
- Check constraint ensures only valid categories

### App
- Pagination loads 200 emails at a time
- Prevents loading thousands of emails at once
- Smooth infinite scroll UX
- Loading states prevent duplicate requests

### UI
- Only renders visible category groups
- Collapsed sections don't render child emails
- Lazy loading of email details

---

## Migration Strategy

### For Existing Emails

The migration intelligently backfills categories based on:

1. **Subject line keywords** (highest priority)
   - "password reset" → `auth_password_reset`
   - "shipped" → `order_shipped`
   - "delivered" → `order_delivered`
   - "refund" → `order_refund_completed`
   - etc.

2. **Email type + linked data** (medium priority)
   - `transactional` + `order_id` → `order_confirmation`
   - `marketing` + `campaign_id` → `campaign_promotional`

3. **Email type fallback** (lowest priority)
   - `transactional` → `system_notification`
   - `marketing` → `campaign_newsletter`

### For New Emails

Set the `category` field explicitly when creating emails:

```sql
INSERT INTO email_sends (
    ...,
    email_type,
    category
) VALUES (
    ...,
    'transactional',
    'order_shipped'
);
```

---

## Troubleshooting

### Emails not loading
**Issue:** Sidebar shows "No emails yet"

**Solutions:**
1. Check `email_sends` table has data
2. Verify store filter is correct
3. Check RLS policies allow access
4. Look for errors in Xcode console

### Categories not showing
**Issue:** All emails in "System" category

**Solutions:**
1. Run migration: `./deploy-email-categories.sh`
2. Check `category` column exists in database
3. Verify backfill query ran successfully
4. Set `category` explicitly when creating new emails

### Load More not working
**Issue:** Can't load more than 200 emails

**Solutions:**
1. Check `hasLoadedAllEmails` state
2. Verify pagination logic in `EditorStore+Resend.swift`
3. Check Supabase `.range()` query
4. Look for loading state conflicts

### Build errors
**Issue:** Swift compilation errors

**Solutions:**
1. Clean build folder (Cmd+Shift+K)
2. Rebuild (Cmd+B)
3. Check all new files are included in target
4. Verify `EmailCategory.swift` is in project

---

## API Reference

### EmailCategory Enum

```swift
enum EmailCategory: String, CaseIterable, Codable {
    case authPasswordReset = "auth_password_reset"
    // ... 40+ more cases

    var displayName: String { ... }
    var icon: String { ... }
    var color: Color { ... }
    var group: EmailCategory.Group { ... }
}
```

### EmailCategory.Group Enum

```swift
enum EmailCategory.Group: String, CaseIterable {
    case authentication
    case orders
    case receiptsPayments
    case support
    case campaigns
    case loyalty
    case system

    var displayName: String { ... }
    var icon: String { ... }
    var color: Color { ... }
    var categories: [EmailCategory] { ... }
}
```

### ResendEmail Extensions

```swift
extension ResendEmail {
    var categoryEnum: EmailCategory? { ... }
    var categoryDisplayName: String { ... }
    var categoryIcon: String { ... }
    var categoryColor: Color { ... }
    var categoryGroup: EmailCategory.Group? { ... }
    var isAuthEmail: Bool { ... }
    var isOrderEmail: Bool { ... }
    var isMarketingEmail: Bool { ... }
    var isLoyaltyEmail: Bool { ... }
}
```

### EditorStore Methods

```swift
extension EditorStore {
    func loadEmails() async
    func loadMoreEmails() async
    func refreshEmails() async

    func emails(for category: EmailCategory) -> [ResendEmail]
    func emails(for group: EmailCategory.Group) -> [ResendEmail]

    var authenticationEmails: [ResendEmail] { ... }
    var orderEmails: [ResendEmail] { ... }
    var campaignEmails: [ResendEmail] { ... }
    // ... more computed properties
}
```

---

## Future Enhancements

### Potential Additions
- [ ] Search within categories
- [ ] Category-based analytics dashboard
- [ ] Custom category creation for tenants
- [ ] Category-based notification preferences
- [ ] Bulk actions by category
- [ ] Export emails by category
- [ ] Category performance metrics

### Analytics Ideas
- Open rates by category
- Click rates by category
- Best performing categories
- Category trends over time

---

## Questions?

For issues or questions about the email categories system:
1. Check this documentation
2. Review the code comments
3. Test in Xcode with breakpoints
4. Check Supabase logs for backend issues

**Key Files:**
- Database: `supabase/migrations/20260120_email_categories.sql`
- Model: `SwagManager/Models/EmailCategory.swift`
- Store: `SwagManager/Stores/EditorStore+Resend.swift`
- UI: `SwagManager/Views/Editor/Sidebar/SidebarResendSection.swift`
