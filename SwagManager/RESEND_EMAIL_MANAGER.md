# Resend Email Manager

Complete email monitoring and management system integrated into SwagManager Mac app.

## Overview

This implementation adds a full-featured email management interface to your SwagManager app, allowing you to monitor, track, and manage all emails sent through the Resend API directly from your Mac app's left navigation bar.

## Architecture

### Frontend Components (Swift/SwiftUI)

#### 1. **ResendEmail Model** (`Models/ResendEmail.swift`)
- Complete data model matching Resend API structure
- Includes all email metadata: recipients, content, status, timestamps
- Computed properties for UI display (colors, labels, dates)
- Support for order linking and custom metadata

#### 2. **SidebarResendSection** (`Views/Editor/Sidebar/SidebarResendSection.swift`)
- Collapsible sidebar section following app patterns
- Groups emails by status (Failed, Queued, Sent, Delivered, Opened, Clicked, Bounced)
- Priority ordering (Failed emails shown first)
- Real-time count badges
- Tree-style navigation matching existing sections

#### 3. **ResendEmailDetailPanel** (`Views/Editor/ResendEmailDetailPanel.swift`)
- 4-tab interface:
  - **Details**: Status, timestamps, recipients, metadata
  - **Content**: HTML preview with WebKit rendering + plain text fallback
  - **Timeline**: Event history (sent, delivered, opened, clicked, etc.)
  - **Raw**: JSON view of full email object
- Linked order navigation (opens order detail when clicked)
- Refresh functionality
- Error display for failed emails

#### 4. **EditorStore+Resend Extension** (`Stores/EditorStore+Resend.swift`)
- Email loading with store filtering
- Status-based email filtering (7 computed properties)
- Tab management (open/close email tabs)
- Resend functionality
- Test email sending

#### 5. **EditorModels Updates** (`Views/Editor/EditorModels.swift`)
- Added `.email(ResendEmail)` case to `OpenTabItem` enum
- Icon, color, and terminal styling for email tabs

### Backend (PostgreSQL + Supabase)

#### Database Schema (`Database/resend_email_tables.sql`)

**Tables:**

1. **resend_emails**
   - Core email storage
   - Tracks: recipients, content, status, timestamps, errors
   - Relations: user_id, store_id, order_id
   - Metadata JSONB for extensibility

2. **resend_email_events**
   - Event timeline from Resend webhooks
   - Tracks: sent, delivered, opened, clicked, bounced, failed
   - Linked to resend_emails via foreign key

**Features:**
- Row-Level Security (RLS) policies
- Automatic status updates via trigger
- Indexes for performance
- RPC functions: `resend_email()`, `send_test_email()`

## Integration Points

### 1. Navigation
- Email section added to `EditorSidebarView.swift`
- Loads automatically when store is selected
- Refreshes when store changes

### 2. Tab System
- Email tabs open via `store.openEmail(email)`
- Integrated with Safari/Xcode-style tab bar
- Status color coding in tabs

### 3. Order Linking
- Emails linked to orders via `order_id`
- Click "Open Order" button in email detail
- Navigates to existing OrderDetailPanel

## Setup Instructions

### 1. Database Setup

Run the migration SQL:

```bash
psql "postgresql://postgres:holyfuckingshitfuck@db.uaednwpxursknmwdeejn.supabase.co:5432/postgres?sslmode=require" \
  -f ~/Desktop/blackops/SwagManager/Database/resend_email_tables.sql
```

Or via Supabase Dashboard:
1. Go to SQL Editor
2. Paste contents of `resend_email_tables.sql`
3. Run query

### 2. Resend API Configuration

You'll need to set up:

1. **Edge Function for Sending Emails** (Supabase Edge Function):
```typescript
// supabase/functions/send-email/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Resend } from "npm:resend@2.0.0"

const resend = new Resend("YOUR_RESEND_API_KEY")

serve(async (req) => {
  const { to, from, subject, html, metadata } = await req.json()

  const { data, error } = await resend.emails.send({
    from,
    to,
    subject,
    html,
  })

  if (error) {
    return new Response(JSON.stringify({ error }), { status: 400 })
  }

  // Store in database
  // ... insert into resend_emails table

  return new Response(JSON.stringify({ data }), { status: 200 })
})
```

2. **Webhook Handler** (Supabase Edge Function):
```typescript
// supabase/functions/resend-webhook/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

serve(async (req) => {
  const event = await req.json()

  // Verify webhook signature
  // ... verify Resend signature

  // Parse event
  const { type, data } = event

  // Insert event into database
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  )

  await supabase.from("resend_email_events").insert({
    email_id: data.email_id,
    event: type,
    timestamp: new Date(),
    metadata: data
  })

  return new Response("OK", { status: 200 })
})
```

3. **Configure Resend Webhooks**:
   - Go to Resend Dashboard → Webhooks
   - Add webhook URL: `https://[YOUR-PROJECT].supabase.co/functions/v1/resend-webhook`
   - Enable events: sent, delivered, opened, clicked, bounced, failed

### 3. Environment Variables

Add to your Supabase project settings:

```bash
RESEND_API_KEY=re_YOUR_KEY_HERE
```

## Usage

### Viewing Emails

1. Select a store in SwagManager
2. Click "Emails" in left sidebar (with envelope icon)
3. Expand status groups to see emails
4. Click any email to open detail view

### Email Details

**Details Tab:**
- Status badge (color-coded)
- All timestamps (created, sent, opened, clicked, etc.)
- Recipient information (to, from, cc, bcc, reply-to)
- Metadata key-value pairs
- Error messages (if failed)

**Content Tab:**
- Live HTML preview (rendered with WebKit)
- Plain text fallback
- Subject line

**Timeline Tab:**
- Chronological event list
- Event types with color coding
- Event metadata

**Raw Tab:**
- Complete JSON object
- Copy-friendly format

### Sending Test Emails

Call from code:
```swift
await store.sendTestEmail(
    to: "test@example.com",
    subject: "Test Email",
    html: "<h1>Hello World</h1>"
)
```

### Resending Failed Emails

Click email in sidebar → Use refresh button (will trigger resend)

Or programmatically:
```swift
await store.resendEmail(email)
```

## Features

### Status Tracking
- **Queued**: Email queued for sending
- **Sent**: Email accepted by recipient server
- **Delivered**: Email delivered to inbox
- **Opened**: Recipient opened the email
- **Clicked**: Recipient clicked a link
- **Bounced**: Email bounced back
- **Failed**: Sending failed (shows error)

### Visual Design
- Follows SwagManager design system
- Liquid glass/glassmorphism effects
- Terminal-style icons (✉)
- Status color coding
- Collapsible tree navigation

### Performance
- Loads only 200 most recent emails
- Filtered by selected store
- Indexed database queries
- Lazy loading in sidebar

### Security
- Row-Level Security enforced
- Users only see their store's emails
- Service role access for webhooks
- Staff member validation

## Data Flow

```
1. User Action (send email)
   ↓
2. Edge Function (send-email)
   ↓
3. Resend API
   ↓
4. Database Insert (resend_emails)
   ↓
5. SwagManager UI Update
   ↓
6. Resend Webhook → Edge Function
   ↓
7. Database Insert (resend_email_events)
   ↓
8. Trigger → Update email status
   ↓
9. SwagManager UI Refresh
```

## Database Queries

### Load Emails
```sql
SELECT * FROM resend_emails
WHERE store_id = $1
ORDER BY created_at DESC
LIMIT 200
```

### Load Email Events
```sql
SELECT * FROM resend_email_events
WHERE email_id = $1
ORDER BY timestamp DESC
```

### Update Status (via trigger)
```sql
-- Automatically handled by update_email_status_from_event() function
-- Triggered on insert into resend_email_events
```

## API Reference

### EditorStore Methods

```swift
// Load all emails for current store
await store.loadEmails()

// Open email in detail panel
store.openEmail(email)

// Close email tab
store.closeEmailTab(email)

// Resend failed email
await store.resendEmail(email)

// Send test email
await store.sendTestEmail(
    to: "test@example.com",
    subject: "Test",
    html: "<p>Content</p>"
)
```

### Computed Properties

```swift
store.queuedEmails   // [ResendEmail]
store.sentEmails     // [ResendEmail]
store.deliveredEmails // [ResendEmail]
store.openedEmails   // [ResendEmail]
store.clickedEmails  // [ResendEmail]
store.bouncedEmails  // [ResendEmail]
store.failedEmails   // [ResendEmail]
```

## Customization

### Add Custom Email Templates

Extend the metadata field:
```swift
let metadata = [
    "template": "order_confirmation",
    "order_number": "12345",
    "custom_field": "value"
]
```

### Add More Event Types

1. Update `EmailStatus` enum
2. Add case to `update_email_status_from_event()` function
3. Update UI color mappings

### Integrate with Other Services

The architecture supports:
- SendGrid (change edge function)
- Mailgun (change edge function)
- AWS SES (change edge function)
- Custom SMTP (change edge function)

Just update the edge function implementation while keeping the same database schema.

## Troubleshooting

### Emails not loading
- Check store selection
- Verify RLS policies
- Check console logs: `NSLog("[EditorStore] Loading emails...")`

### Status not updating
- Verify webhook is configured
- Check edge function logs
- Verify trigger is enabled: `SELECT * FROM pg_trigger WHERE tgname = 'update_email_status_trigger'`

### HTML not rendering
- Check WebKit preferences
- Verify HTML is valid
- Try plain text fallback

## Future Enhancements

- [ ] Bulk email operations
- [ ] Email templates manager
- [ ] A/B testing support
- [ ] Analytics dashboard
- [ ] Email scheduling
- [ ] Draft emails
- [ ] Rich text editor
- [ ] Attachment support
- [ ] Email campaigns

## Credits

Built following SwagManager architecture patterns:
- Liquid glass design system
- Tree navigation components
- Tab management system
- RLS security model

Database connection details provided in initial request.
Resend API key required from user: `AT sbp_61d26780afeff82787f7926476ca820bbc6e289f`
