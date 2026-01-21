#!/bin/bash
echo "Testing tools-gateway edge function..."
echo ""

curl -X POST "https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg" \
  -H "Content-Type: application/json" \
  -d '{"operation": "locations_list", "parameters": {}, "store_id": "cd2e1122-d511-4edb-be5d-98ef274b4baf"}' \
  | python3 -m json.tool
