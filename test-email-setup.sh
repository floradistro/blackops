#!/bin/bash

# Test Email Categories Setup
# Quick diagnostic to check if everything is configured correctly

echo "🔍 Email Categories System - Diagnostic Test"
echo ""

# 1. Check if migration file exists
echo "1. Checking migration file..."
if [ -f "supabase/migrations/20260120_email_categories.sql" ]; then
    echo "   ✅ Migration file exists"
else
    echo "   ❌ Migration file NOT found!"
    echo "   Run this from /Users/whale/Desktop/blackops"
    exit 1
fi

# 2. Check if Supabase CLI is available
echo ""
echo "2. Checking Supabase CLI..."
if command -v supabase &> /dev/null; then
    echo "   ✅ Supabase CLI installed"
    supabase --version
else
    echo "   ❌ Supabase CLI not installed"
    echo "   Install: brew install supabase/tap/supabase"
fi

# 3. Check if SwagManager model files exist
echo ""
echo "3. Checking Swift model files..."

if [ -f "SwagManager/Models/EmailCategory.swift" ]; then
    echo "   ✅ EmailCategory.swift exists"
else
    echo "   ❌ EmailCategory.swift missing!"
fi

if grep -q "var categoryEnum" SwagManager/Models/ResendEmail.swift 2>/dev/null; then
    echo "   ✅ ResendEmail has categoryEnum property"
else
    echo "   ❌ ResendEmail missing categoryEnum!"
fi

# 4. Check if Xcode project compiles
echo ""
echo "4. Checking Xcode build status..."
echo "   (This might take a moment...)"

# Try to build just to check for errors
xcodebuild -project SwagManager.xcodeproj -scheme SwagManager -configuration Debug clean build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED" || echo "   ⚠️  Could not determine build status"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo ""
echo "If migration hasn't been run:"
echo "  ./deploy-email-categories.sh"
echo ""
echo "If Xcode has errors:"
echo "  1. Open SwagManager.xcodeproj"
echo "  2. Product → Clean Build Folder (Cmd+Shift+K)"
echo "  3. Product → Build (Cmd+B)"
echo ""
echo "To test in the app:"
echo "  1. Run the app (Cmd+R)"
echo "  2. Click 'Emails' in sidebar"
echo "  3. Click a category group (Orders, Authentication, etc.)"
echo "  4. Should see individual emails expand"
echo "  5. Scroll to bottom → Click 'Load More'"
echo ""
echo "✨ If all steps pass, the system is ready!"
