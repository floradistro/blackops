#!/bin/bash
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI"
BASE_URL="https://uaednwpxursknmwdeejn.supabase.co/rest/v1"
CHARLOTTE_MONROE="8cb9154e-c89c-4f5e-b751-74820e348b8a"
STORE_ID="cd2e1122-d511-4edb-be5d-98ef274b4baf"

# Drink category IDs
EDIBLES="5533179e-43e0-4565-a600-b1e7aa270a60"
DAY_DRINKER="02385a4b-be34-442d-8fb5-accdc15e4e66"
GOLDEN_HOUR="995622a0-6d46-4a5e-8e04-4be1fedbe31f"
DARKSIDE="0c0ea857-e76c-4a75-a23e-ee39597539f2"
RIPTIDE="84c5d6ed-818b-4583-99cb-f188d42a2d8e"

echo "=== Charlotte Monroe - Edibles & Drinks react_code (first 30 lines) ==="
curl -s "$BASE_URL/creations?id=eq.4a022ba0-f3ad-42ae-99d1-507d6131ecbf&select=react_code" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" | jq -r '.[0].react_code' | head -30

echo ""
echo "=== Edibles with stock at Charlotte Monroe ==="
curl -s "$BASE_URL/rpc/get_products_for_creation" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"p_store_id\": \"$STORE_ID\", \"p_location_id\": \"$CHARLOTTE_MONROE\", \"p_category_id\": \"$EDIBLES\", \"p_in_stock_only\": true}" | jq '. | length'

echo ""
echo "=== All Drinks with stock at Charlotte Monroe ==="
for cat in $DAY_DRINKER $GOLDEN_HOUR $DARKSIDE $RIPTIDE; do
  count=$(curl -s "$BASE_URL/rpc/get_products_for_creation" \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"p_store_id\": \"$STORE_ID\", \"p_location_id\": \"$CHARLOTTE_MONROE\", \"p_category_id\": \"$cat\", \"p_in_stock_only\": true}" | jq '. | length')
  echo "Category $cat: $count products"
done
