#!/bin/bash
set -e

echo "🔧 Fixing Xcode project file..."

# Close Xcode if open
osascript -e 'tell application "Xcode" to quit' 2>/dev/null || true
sleep 2

cd /Users/whale/Desktop/blackops

# Backup current project file
cp SwagManager.xcodeproj/project.pbxproj SwagManager.xcodeproj/project.pbxproj.backup.$(date +%s)

# The safest way is to just use the Package.swift
# But if you want to use .xcodeproj, you need to manually add files in Xcode GUI

echo ""
echo "✅ Backed up project file"
echo ""
echo "📝 INSTRUCTIONS:"
echo ""
echo "Option 1 (RECOMMENDED - No manual work needed):"
echo "  Open Package.swift in Xcode instead of SwagManager.xcodeproj"
echo "  It will automatically see all files and build correctly"
echo ""
echo "Option 2 (Use existing .xcodeproj):"
echo "  1. Open SwagManager.xcodeproj in Xcode"
echo "  2. In Project Navigator, right-click 'Models' folder"
echo "  3. Choose 'Add Files to SwagManager...'"
echo "  4. Navigate to SwagManager/Models/Customer.swift"
echo "  5. UNCHECK 'Copy items if needed'"
echo "  6. CHECK 'Add to targets: SwagManager'"
echo "  7. Click Add"
echo "  8. Repeat for these files:"
echo "     - Services/CustomerService.swift"
echo "     - Stores/EditorStore+Customers.swift"
echo "     - Components/Tree/CustomerTreeItem.swift"
echo "     - Views/Editor/CustomerDetailPanel.swift"
echo "     - Views/Editor/Sidebar/SidebarCustomersSection.swift"
echo ""
echo "🎯 EASIEST: Just run 'open Package.swift' and build from there!"
echo ""
