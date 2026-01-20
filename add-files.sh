#!/bin/bash

# Add files to Xcode project using xcodebuild

cd /Users/whale/Desktop/blackops

# Open Xcode project and let it fix any issues
open SwagManager.xcodeproj

echo "✅ Opened Xcode project"
echo ""
echo "📋 Please add these files manually in Xcode:"
echo ""
echo "1. MCPServer.swift → Models folder"
echo "2. EditorStore+MCPManagement.swift → Stores folder"
echo "3. SidebarMCPServersSection.swift → Views/Editor/Sidebar folder"
echo "4. MCPServerDetailPanel.swift → Views/Editor folder"
echo ""
echo "See ADD_FILES_TO_XCODE.md for detailed instructions"
