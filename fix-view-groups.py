#!/usr/bin/env python3
"""
Add view files to their proper PBXGroup sections
"""

import re

project_file = "SwagManager.xcodeproj/project.pbxproj"

# Read the project file
with open(project_file, 'r') as f:
    content = f.read()

# Get UUIDs for all the view files
view_files = {
    "CustomerDetailPanel.swift": "B3E2E63EBE4C4E8D992B7FBE",
    "OrderDetailPanel.swift": "1F2BF26C1BBE48AEBAD47DD2",
    "LocationDetailPanel.swift": "C38F6E3D5B724E74A5FBD3A3",
    "MCPServerDetailPanel.swift": "AC3C05A0F2BC43B8AC6C5E43",
    "LocationQueueView.swift": "4C3F0FB9E38F44AAA1932D9D",
    "LocationQueueDebugView.swift": "1C41F2F9A62B459CA5D59F98",
}

sidebar_files = {
    "SidebarCustomersSection.swift": "B4D13ADD59A84B01AA4E8D77",
    "SidebarOrdersSection.swift": "D7F4DA83E38B48B2B0D13E02",
    "SidebarLocationsSection.swift": "8B33C4D6ACC8423FA3B83CA6",
    "SidebarQueuesSection.swift": "3F1DD25DC8DD491EB4D25F93",
    "SidebarMCPServersSection.swift": "4B57DA3D9D5F4C6D83E6D5B4",
}

tree_files = {
    "CustomerTreeItem.swift": "DD46D1F3D4C6461BA3BD3CE1",
    "OrderTreeItem.swift": "5F52EA0A93924E6CBCE19D55",
}

component_files = {
    "FloatingContextBar.swift": "C3B8E2B9F1B44EC0AC47E1C9",
}

# Find Views/Editor group and add detail panels
editor_pattern = r'(GR\w+ /\* Editor \*/ = \{[^}]*children = \(\n(?:.*?\n)*?)\s*\);\s*path = Editor;'
match = re.search(editor_pattern, content)
if match:
    for filename, uuid in view_files.items():
        ref = f"{uuid} /* {filename} */"
        if ref not in match.group(1):
            insertion_point = match.end(1)
            content = content[:insertion_point] + f"\t\t\t\t{ref},\n" + content[insertion_point:]
    print("✅ Updated Views/Editor group")
else:
    print("❌ Could not find Views/Editor group")

# Find Views/Editor/Sidebar group and add sidebar sections
sidebar_pattern = r'(GR\w+ /\* Sidebar \*/ = \{[^}]*children = \(\n(?:.*?\n)*?)\s*\);\s*path = Sidebar;'
match = re.search(sidebar_pattern, content)
if match:
    for filename, uuid in sidebar_files.items():
        ref = f"{uuid} /* {filename} */"
        if ref not in match.group(1):
            insertion_point = match.end(1)
            content = content[:insertion_point] + f"\t\t\t\t{ref},\n" + content[insertion_point:]
    print("✅ Updated Views/Editor/Sidebar group")
else:
    print("❌ Could not find Views/Editor/Sidebar group")

# Find Components/Tree group and add tree items
tree_pattern = r'(GR\w+ /\* Tree \*/ = \{[^}]*children = \(\n(?:.*?\n)*?)\s*\);\s*path = Tree;'
match = re.search(tree_pattern, content)
if match:
    for filename, uuid in tree_files.items():
        ref = f"{uuid} /* {filename} */"
        if ref not in match.group(1):
            insertion_point = match.end(1)
            content = content[:insertion_point] + f"\t\t\t\t{ref},\n" + content[insertion_point:]
    print("✅ Updated Components/Tree group")
else:
    print("❌ Could not find Components/Tree group")

# Find Components group and add FloatingContextBar
comp_pattern = r'(GR\w+ /\* Components \*/ = \{[^}]*children = \(\n(?:.*?\n)*?)\s*\);\s*path = Components;'
match = re.search(comp_pattern, content)
if match:
    for filename, uuid in component_files.items():
        ref = f"{uuid} /* {filename} */"
        if ref not in match.group(1):
            insertion_point = match.end(1)
            content = content[:insertion_point] + f"\t\t\t\t{ref},\n" + content[insertion_point:]
    print("✅ Updated Components group")
else:
    print("❌ Could not find Components group")

# Write the updated project file
with open(project_file, 'w') as f:
    f.write(content)

print("\n✅ View groups updated!")
