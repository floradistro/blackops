#!/usr/bin/env python3
"""
Add all new files to Xcode project
"""

import re
import uuid

def generate_uuid():
    """Generate a unique 24-character hex ID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

project_file = "SwagManager.xcodeproj/project.pbxproj"

# Read the project file
with open(project_file, 'r') as f:
    lines = f.readlines()
    content = ''.join(lines)

# New files to add with their paths
new_files = [
    # Models
    ("Customer.swift", "SwagManager/Models/Customer.swift", "Models"),
    ("Order.swift", "SwagManager/Models/Order.swift", "Models"),
    ("MCPServer.swift", "SwagManager/Models/MCPServer.swift", "Models"),

    # Services
    ("CustomerService.swift", "SwagManager/Services/CustomerService.swift", "Services"),
    ("OrderService.swift", "SwagManager/Services/OrderService.swift", "Services"),
    ("LocationQueueService.swift", "SwagManager/Services/LocationQueueService.swift", "Services"),

    # Stores
    ("EditorStore+Customers.swift", "SwagManager/Stores/EditorStore+Customers.swift", "Stores"),
    ("EditorStore+Orders.swift", "SwagManager/Stores/EditorStore+Orders.swift", "Stores"),
    ("EditorStore+MCPManagement.swift", "SwagManager/Stores/EditorStore+MCPManagement.swift", "Stores"),
    ("EditorStore+QueueManagement.swift", "SwagManager/Stores/EditorStore+QueueManagement.swift", "Stores"),
    ("LocationQueueStore.swift", "SwagManager/Stores/LocationQueueStore.swift", "Stores"),

    # Components
    ("CustomerTreeItem.swift", "SwagManager/Components/Tree/CustomerTreeItem.swift", "Tree"),
    ("OrderTreeItem.swift", "SwagManager/Components/Tree/OrderTreeItem.swift", "Tree"),
    ("FloatingContextBar.swift", "SwagManager/Components/FloatingContextBar.swift", "Components"),

    # Views - Sidebar
    ("SidebarCustomersSection.swift", "SwagManager/Views/Editor/Sidebar/SidebarCustomersSection.swift", "Sidebar"),
    ("SidebarOrdersSection.swift", "SwagManager/Views/Editor/Sidebar/SidebarOrdersSection.swift", "Sidebar"),
    ("SidebarLocationsSection.swift", "SwagManager/Views/Editor/Sidebar/SidebarLocationsSection.swift", "Sidebar"),
    ("SidebarQueuesSection.swift", "SwagManager/Views/Editor/Sidebar/SidebarQueuesSection.swift", "Sidebar"),
    ("SidebarMCPServersSection.swift", "SwagManager/Views/Editor/Sidebar/SidebarMCPServersSection.swift", "Sidebar"),

    # Views - Detail Panels
    ("CustomerDetailPanel.swift", "SwagManager/Views/Editor/CustomerDetailPanel.swift", "Editor"),
    ("OrderDetailPanel.swift", "SwagManager/Views/Editor/OrderDetailPanel.swift", "Editor"),
    ("LocationDetailPanel.swift", "SwagManager/Views/Editor/LocationDetailPanel.swift", "Editor"),
    ("MCPServerDetailPanel.swift", "SwagManager/Views/Editor/MCPServerDetailPanel.swift", "Editor"),

    # Views - Queue
    ("LocationQueueView.swift", "SwagManager/Views/Queue/LocationQueueView.swift", "Queue"),
    ("LocationQueueDebugView.swift", "SwagManager/Views/Queue/LocationQueueDebugView.swift", "Queue"),

    # Utilities
    ("WindowZoomManager.swift", "SwagManager/Utilities/WindowZoomManager.swift", "Utilities"),
]

# Generate UUIDs for each file
file_refs = {}
build_files = {}

for filename, filepath, group in new_files:
    file_refs[filename] = generate_uuid()
    build_files[filename] = generate_uuid()

# Find the PBXBuildFile section
buildfile_section_match = re.search(r'/\* Begin PBXBuildFile section \*/\n', content)
if buildfile_section_match:
    insert_pos = buildfile_section_match.end()

    # Create PBXBuildFile entries
    new_buildfiles = []
    for filename, filepath, group in new_files:
        entry = f"\t\t{build_files[filename]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filename]} /* {filename} */; }};\n"
        new_buildfiles.append(entry)

    content = content[:insert_pos] + ''.join(new_buildfiles) + content[insert_pos:]

# Find the PBXFileReference section
fileref_section_match = re.search(r'/\* Begin PBXFileReference section \*/\n', content)
if fileref_section_match:
    insert_pos = fileref_section_match.end()

    # Create PBXFileReference entries
    new_filerefs = []
    for filename, filepath, group in new_files:
        # Extract just the path after SwagManager/
        path = filepath.replace('SwagManager/', '')
        entry = f"\t\t{file_refs[filename]} /* {filename} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = \"{filename}\"; sourceTree = \"<group>\"; }};\n"
        new_filerefs.append(entry)

    content = content[:insert_pos] + ''.join(new_filerefs) + content[insert_pos:]

# Add to Sources build phase
sources_phase_match = re.search(r'files = \(\n(.*?)\);.*?name = Sources;', content, re.DOTALL)
if sources_phase_match:
    files_section_end = sources_phase_match.end(1)

    new_source_entries = []
    for filename, filepath, group in new_files:
        entry = f"\t\t\t\t{build_files[filename]} /* {filename} in Sources */,\n"
        new_source_entries.append(entry)

    content = content[:files_section_end] + ''.join(new_source_entries) + content[files_section_end:]

# Write the updated project file
with open(project_file, 'w') as f:
    f.write(content)

print(f"✅ Added {len(new_files)} new files to Xcode project")
print("")
print("Added files:")
for filename, filepath, group in new_files:
    print(f"  • {filename}")
