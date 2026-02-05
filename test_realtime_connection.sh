#!/bin/bash

# Test Supabase Realtime WebSocket connection
# This checks if the realtime service is accessible

PROJECT_URL="https://uaednwpxursknmwdeejn.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg"

echo "🧪 Testing Supabase Realtime Connection"
echo "========================================"
echo ""

# Test 1: Check if realtime endpoint is accessible
echo "1️⃣ Testing realtime WebSocket endpoint..."
REALTIME_URL="${PROJECT_URL}/realtime/v1/websocket"

# Try to connect (this will fail but should give us connection info)
curl -v -N \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  "${REALTIME_URL}?apikey=${ANON_KEY}&vsn=1.0.0" \
  2>&1 | head -20

echo ""
echo "========================================"
echo ""

# Test 2: Check Supabase project health
echo "2️⃣ Testing Supabase project health..."
curl -s "${PROJECT_URL}/rest/v1/" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  | head -5

echo ""
echo "========================================"
