#!/bin/bash
# Deploy tools-gateway edge function to Supabase

echo "🚀 Deploying tools-gateway edge function..."

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Installing..."
    brew install supabase/tap/supabase
fi

cd /Users/whale/Desktop/blackops

# Link to project if not already linked
supabase link --project-ref uaednwpxursknmwdeejn

# Deploy the function
supabase functions deploy tools-gateway

echo "✅ Deployment complete!"
echo ""
echo "Test the function:"
echo 'curl -X POST "https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway" \'
echo '  -H "apikey: YOUR_ANON_KEY" \'
echo '  -H "Content-Type: application/json" \'
echo '  -d'"'"'{"operation": "locations_list", "parameters": {}, "store_id": "cd2e1122-d511-4edb-be5d-98ef274b4baf"}'"'"''
