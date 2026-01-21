# Deploy tools-gateway Edge Function

## ✅ What We Fixed

1. **Swift App** - Now correctly loads `rpcFunction` and `edgeFunction` from database
2. **Database** - All 195 tools migrated to use `edge_function = "tools-gateway"`
3. **Edge Function Code** - Created universal gateway handler in `supabase/functions/tools-gateway/index.ts`

## 🚀 Deploy to Supabase

### Option 1: Supabase Dashboard (Easiest)

1. Go to https://supabase.com/dashboard/project/uaednwpxursknmwdeejn/functions
2. Click "Create a new function" or edit existing `tools-gateway`
3. Copy the code from `supabase/functions/tools-gateway/index.ts`
4. Paste into the editor
5. Click "Deploy"

### Option 2: Supabase CLI

```bash
cd /Users/whale/Desktop/blackops

# Link project (you'll need to enter the database password)
supabase link --project-ref uaednwpxursknmwdeejn --password holyfuckingshitfuck

# Deploy function
supabase functions deploy tools-gateway
```

## 🧪 Test After Deployment

```bash
curl -X POST "https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg" \
  -H "Content-Type: application/json" \
  -d '{"operation": "locations_list", "parameters": {}, "store_id": "cd2e1122-d511-4edb-be5d-98ef274b4baf"}'
```

Should return:
```json
{
  "success": true,
  "data": {
    "locations": [...],
    "total": 8
  }
}
```

## 📝 What the Edge Function Does

- **Universal Gateway**: Handles all 195 MCP tools through one endpoint
- **Category Routing**: Routes tools to appropriate handlers based on category
- **Locations Handler**: Fully implemented (`locations_list`)
- **Placeholder Handlers**: Other categories return success with notes to implement logic

## ⚡ Next Steps

1. Deploy the edge function
2. Test `locations_list` in SwagManager app
3. Gradually implement handlers for other tool categories as needed

## Architecture (Following Apple/Anthropic Principles)

✅ **Single responsibility**: One gateway for all tools
✅ **Standardized**: All tools use the same execution path
✅ **Extensible**: Easy to add new tool handlers
✅ **Maintainable**: Clear category-based routing
