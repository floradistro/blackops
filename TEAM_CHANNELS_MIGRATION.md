# Team Channels Migration Guide

## Overview

This migration adds a Discord-like channel structure to your SwagManager app with automatic creation of default channels for team communication.

## What's Changed

### 1. SwagManager UI (`SidebarTeamChatSection.swift`)

**Before:**
- Section titled "TEAM CHAT"
- Conversations shown in basic list
- No clear organization or grouping

**After:**
- Section titled "COMMUNICATIONS"
- Discord-like channel structure with categories:
  - **TEAM CHANNELS** - #general, #announcements, etc.
  - **LOCATIONS** - One channel per location
  - **ALERTS & BUGS** - #alerts, #bugs
  - **DIRECT MESSAGES** - DMs with team members
  - **AI ASSISTANTS** - AI chat conversations

### 2. Database Schema (Migration: `20260119_team_channels_setup.sql`)

**New Functions:**
- `create_default_channels_for_store(store_id)` - Creates default channels for a store
- `get_store_channels_grouped(store_id)` - Returns channels grouped by category

**New Triggers:**
- `on_store_created_create_channels` - Auto-creates channels when new store is added
- `on_location_created_create_channel` - Auto-creates channel when new location is added

**Default Channels Created:**
- `#general` - General team discussion (chat_type: "team")
- `#announcements` - Important announcements (chat_type: "team")
- `#bugs` - Bug reports and issues (chat_type: "bugs")
- `#alerts` - System alerts and notifications (chat_type: "alerts")
- Location channels - One per active location (chat_type: "location")

## How to Apply the Migration

### Option 1: Supabase Dashboard (Recommended)

1. Go to https://supabase.com/dashboard/project/uaednwpxursknmwdeejn
2. Navigate to **SQL Editor**
3. Create a new query
4. Copy the contents of `supabase/migrations/20260119_team_channels_setup.sql`
5. Paste and run the query
6. Verify success in the output

### Option 2: Command Line (requires database password)

```bash
# Using psql directly
PGPASSWORD='your-db-password' psql \
  -h db.uaednwpxursknmwdeejn.supabase.co \
  -p 5432 \
  -U postgres \
  -d postgres \
  -f supabase/migrations/20260119_team_channels_setup.sql

# Or using the Node.js script
SUPABASE_DB_PASSWORD='your-db-password' node apply-channel-migration.js
```

### Option 3: Supabase CLI

```bash
# If you have Supabase CLI installed
supabase db push
```

## Verification

After applying the migration:

1. **Check Functions Created:**
   ```sql
   SELECT routine_name
   FROM information_schema.routines
   WHERE routine_name LIKE '%channel%';
   ```

2. **Check Default Channels:**
   ```sql
   SELECT store_id, title, chat_type, metadata
   FROM lisa_conversations
   WHERE metadata->>'is_default' = 'true';
   ```

3. **Test in SwagManager:**
   - Open SwagManager
   - Select a store
   - Expand "COMMUNICATIONS" in the sidebar
   - You should see channels grouped by category

## Channel Structure

### Team Channels
- General team communication
- Announcements
- Can create custom team channels

### Location Channels
- Automatically created for each location
- Named after the location
- Location-specific discussions

### Alerts & Bugs
- System alerts
- Bug reports and tracking

### Direct Messages
- Person-to-person conversations
- Sorted by most recent

### AI Assistants
- AI-powered conversations
- Limited to 10 most recent

## Adding New Channels

Channels can be created dynamically by inserting into `lisa_conversations`:

```sql
INSERT INTO lisa_conversations (store_id, title, chat_type, status, metadata)
VALUES (
  'your-store-id',
  'feature-requests',
  'team',
  'active',
  '{"description": "Feature requests and ideas"}'::jsonb
);
```

## Troubleshooting

### Migration Fails

**Error:** `relation "lisa_conversations" does not exist`
- **Solution:** Ensure the `lisa_conversations` table exists in your database

**Error:** `function already exists`
- **Solution:** The migration is idempotent - it drops existing functions before creating them

### No Channels Showing in SwagManager

1. **Check store is selected:**
   - Ensure you have selected a store in SwagManager

2. **Check conversations loaded:**
   - Look for log messages in console: `[EditorStore] Loaded X conversations`

3. **Verify data in database:**
   ```sql
   SELECT * FROM lisa_conversations WHERE store_id = 'your-store-id';
   ```

4. **Force reload:**
   - Restart SwagManager
   - Switch to different store and back

## Next Steps

1. Apply the migration to create default channels
2. Open SwagManager and verify channels appear
3. Start using the channel structure for team communication
4. Create additional custom channels as needed

## Files Modified

- `SwagManager/Views/Editor/Sidebar/SidebarTeamChatSection.swift` - New Discord-like UI
- `supabase/migrations/20260119_team_channels_setup.sql` - Database migration
- `apply-channel-migration.js` - Migration helper script
