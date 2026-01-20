#!/usr/bin/env python3
"""
Fix Xcode project file by:
1. Removing references to deleted files
2. Adding references to new files
"""

import re
import uuid

project_file = "SwagManager.xcodeproj/project.pbxproj"

# Read the project file
with open(project_file, 'r') as f:
    content = f.read()

# Files to remove (deleted files)
files_to_remove = [
    "EditorStore+Zoom.swift",
]

# Remove references to deleted files
for filename in files_to_remove:
    # Remove PBXBuildFile entries
    content = re.sub(
        r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/ = \{isa = PBXBuildFile; fileRef = [A-F0-9]+ /\* ' + re.escape(filename) + r' \*/; \};\n',
        '',
        content
    )

    # Remove PBXFileReference entries
    content = re.sub(
        r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/ = \{isa = PBXFileReference;[^\}]+\};\n',
        '',
        content
    )

    # Remove from file lists
    content = re.sub(
        r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/,\n',
        '',
        content
    )

    # Remove from Sources build phase
    content = re.sub(
        r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/,\n',
        '',
        content
    )

# Write the fixed project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Removed references to deleted files")
print("✅ Project file fixed!")
print("")
print("ℹ️  The new files (Customer, Order, MCP, etc.) will be automatically")
print("   discovered by Xcode when you open the project.")
