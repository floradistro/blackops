#!/usr/bin/env python3
"""
Add new files to their proper PBXGroup sections
"""

import re

project_file = "SwagManager.xcodeproj/project.pbxproj"

# Read the project file
with open(project_file, 'r') as f:
    content = f.read()

# File UUID mappings (from the generated UUIDs)
files_to_add = {
    "Models": [
        "7455DA6D99394CF4A5522EEF /* Customer.swift */",
        "04562B7E476140D596D42176 /* MCPServer.swift */",
    ],
    "Services": [
        "4F91CECA9CFA446E9DA30CB4 /* CustomerService.swift */",
        "1EAE4E0BBA0F486A902F3A26 /* OrderService.swift */",
        "AE41D5D20CA84FE38F5F6A6E /* LocationQueueService.swift */",
    ],
    "Stores": [
        "DAA1D5EF09774FD1A4A43B14 /* EditorStore+Customers.swift */",
        "C2B065A6A38C49408E6D2E4D /* EditorStore+Orders.swift */",
        "28AC8B5B8B8B4EB98F02A1C3 /* EditorStore+MCPManagement.swift */",
        "AF74E3E913D540F4A20F5169 /* EditorStore+QueueManagement.swift */",
        "7DD46CC0B2154DB09D933DE5 /* LocationQueueStore.swift */",
    ],
}

# Find and update each group
for group_name, files in files_to_add.items():
    # Find the group section
    pattern = rf'(children = \(\n(?:.*?\n)*?)\s*\);\s*path = {group_name};'
    match = re.search(pattern, content)

    if match:
        children_section = match.group(1)
        # Add the new files to the children section
        for file_ref in files:
            if file_ref not in children_section:
                # Insert before the closing );
                insertion_point = match.end(1)
                indent = "\t\t\t\t"
                new_line = f"{indent}{file_ref},\n"
                content = content[:insertion_point] + new_line + content[insertion_point:]
        print(f"✅ Updated {group_name} group")
    else:
        print(f"❌ Could not find {group_name} group")

# Write the updated project file
with open(project_file, 'w') as f:
    f.write(content)

print("\n✅ Project file groups updated!")
