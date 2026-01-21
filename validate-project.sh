#!/bin/bash
# SwagManager Project Validation Script
# Run this before building to catch issues early

set -e

echo "🔍 SwagManager Project Validation"
echo "=================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# 1. Check for corrupted project file
echo ""
echo "1️⃣  Checking project file integrity..."
if ! plutil -lint SwagManager.xcodeproj/project.pbxproj > /dev/null 2>&1; then
    echo -e "${RED}✗ Project file is corrupted!${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ Project file is valid${NC}"
fi

# 2. Check for missing PBXBuildFile entries
echo ""
echo "2️⃣  Checking for missing build file entries..."
MISSING_BUILD_FILES=$(ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('SwagManager.xcodeproj')
target = project.targets.first
missing = []
target.source_build_phase.files.each do |f|
  if f.file_ref.nil?
    missing << f.uuid
  end
end
puts missing.join('\n')
" 2>&1 | grep -E "^[A-F0-9]{24}$" || true)

if [ -n "$MISSING_BUILD_FILES" ]; then
    echo -e "${RED}✗ Found missing PBXBuildFile entries${NC}"
    echo "$MISSING_BUILD_FILES"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ All build file entries are valid${NC}"
fi

# 3. Check for stale derived data
echo ""
echo "3️⃣  Checking for stale derived data..."
DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData/SwagManager-* -maxdepth 0 2>/dev/null | wc -l)
if [ "$DERIVED_DATA" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $DERIVED_DATA stale derived data folder(s)${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓ No stale derived data${NC}"
fi

# 4. Check file permissions
echo ""
echo "4️⃣  Checking file permissions..."
RESTRICTED_FILES=$(find SwagManager -name "*.swift" -perm -600 ! -perm -644 2>/dev/null | wc -l)
if [ "$RESTRICTED_FILES" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $RESTRICTED_FILES files with restrictive permissions${NC}"
    find SwagManager -name "*.swift" -perm -600 ! -perm -644 2>/dev/null | head -5
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓ All Swift files have correct permissions${NC}"
fi

# 5. Check for .DS_Store and other junk
echo ""
echo "5️⃣  Checking for junk files..."
JUNK_FILES=$(find SwagManager -name ".DS_Store" -o -name "*.orig" -o -name "*.swp" 2>/dev/null | wc -l)
if [ "$JUNK_FILES" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $JUNK_FILES junk files${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓ No junk files found${NC}"
fi

# 6. Verify all Swift files are in target
echo ""
echo "6️⃣  Verifying Swift files in build target..."
TOTAL_SWIFT=$(find SwagManager -name "*.swift" -type f | wc -l | tr -d ' ')
IN_TARGET=$(grep "\.swift in Sources" SwagManager.xcodeproj/project.pbxproj | wc -l | tr -d ' ')
echo "   Total Swift files: $TOTAL_SWIFT"
echo "   In build target: $IN_TARGET"

# 7. Check for syntax errors in critical files
echo ""
echo "7️⃣  Quick syntax check on critical files..."
CRITICAL_FILES=(
    "SwagManager/Models/Order.swift"
    "SwagManager/Models/Chat.swift"
    "SwagManager/Utilities/AnyCodable.swift"
    "SwagManager/Services/SupabaseService.swift"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        if swiftc -typecheck "$file" 2>/dev/null; then
            echo -e "${GREEN}✓ $file${NC}"
        else
            echo -e "${RED}✗ $file has syntax errors${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${RED}✗ $file is missing!${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Summary
echo ""
echo "=================================="
echo "Summary:"
echo -e "  Errors:   ${RED}$ERRORS${NC}"
echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ Validation FAILED - fix errors before building${NC}"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Validation passed with warnings${NC}"
    exit 0
else
    echo ""
    echo -e "${GREEN}✅ All checks passed!${NC}"
    exit 0
fi
