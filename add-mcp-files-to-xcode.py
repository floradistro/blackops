#!/usr/bin/env python3
"""
Add MCP-related Swift files to Xcode project
"""

import re
import uuid

# Files to add
files_to_add = [
    {
        'name': 'MCPServer.swift',
        'path': 'SwagManager/Models/MCPServer.swift',
        'group': 'Models'
    },
    {
        'name': 'EditorStore+MCPManagement.swift',
        'path': 'SwagManager/Stores/EditorStore+MCPManagement.swift',
        'group': 'Stores'
    },
    {
        'name': 'SidebarMCPServersSection.swift',
        'path': 'SwagManager/Views/Editor/Sidebar/SidebarMCPServersSection.swift',
        'group': 'Sidebar'
    },
    {
        'name': 'MCPServerDetailPanel.swift',
        'path': 'SwagManager/Views/Editor/MCPServerDetailPanel.swift',
        'group': 'Editor'
    }
]

# Read the project file
with open('SwagManager.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate unique IDs for each file
def generate_unique_id():
    """Generate a unique ID that doesn't exist in the project"""
    while True:
        # Generate format like SF### for file refs, BF### for build files
        num = str(uuid.uuid4().int)[:3]
        test_id = f"SF{num}"
        if test_id not in content:
            return num

# Find the Models group children section
models_match = re.search(r'(/\* Models \*/.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
stores_match = re.search(r'(/\* Stores \*/.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
sidebar_match = re.search(r'(/\* Sidebar \*/.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
editor_match = re.search(r'(/\* Editor \*/.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)

# Find the PBXBuildFile section
build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/)(.*?)(/\* End PBXBuildFile section \*/)', content, re.DOTALL)

# Find the PBXFileReference section
file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/)(.*?)(/\* End PBXFileReference section \*/)', content, re.DOTALL)

# Find the PBXSourcesBuildPhase section
sources_section = re.search(r'(/\* Sources \*/.*?files = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)

new_build_files = []
new_file_refs = []
new_sources = []
group_additions = {
    'Models': [],
    'Stores': [],
    'Sidebar': [],
    'Editor': []
}

for file_info in files_to_add:
    num = generate_unique_id()
    file_id = f"SF{num}"
    build_id = f"BF{num}"

    # Create build file entry
    build_entry = f"\t\t{build_id} /* {file_info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {file_info['name']} */; }};\n"
    new_build_files.append(build_entry)

    # Create file reference entry
    file_entry = f"\t\t{file_id} /* {file_info['name']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_info['name']}; sourceTree = \"<group>\"; }};\n"
    new_file_refs.append(file_entry)

    # Create sources entry
    source_entry = f"\t\t\t\t{build_id} /* {file_info['name']} in Sources */,\n"
    new_sources.append(source_entry)

    # Create group entry
    group_entry = f"\t\t\t\t{file_id} /* {file_info['name']} */,\n"
    group_additions[file_info['group']].append(group_entry)

# Insert new build files
if build_file_section:
    build_section_content = build_file_section.group(2)
    new_build_section = build_section_content + ''.join(new_build_files)
    content = content.replace(build_file_section.group(2), new_build_section)

# Insert new file references
if file_ref_section:
    file_section_content = file_ref_section.group(2)
    new_file_section = file_section_content + ''.join(new_file_refs)
    content = content.replace(file_ref_section.group(2), new_file_section)

# Insert new sources
if sources_section:
    sources_content = sources_section.group(2)
    new_sources_content = sources_content + ''.join(new_sources)
    content = content.replace(sources_section.group(2), new_sources_content)

# Insert into group sections
if models_match and group_additions['Models']:
    models_content = models_match.group(2)
    new_models_content = models_content + ''.join(group_additions['Models'])
    content = content.replace(models_match.group(0), models_match.group(1) + new_models_content + models_match.group(3))

if stores_match and group_additions['Stores']:
    stores_content = stores_match.group(2)
    new_stores_content = stores_content + ''.join(group_additions['Stores'])
    old_match = stores_match.group(0)
    # Need to find it again after previous replacement
    stores_match_new = re.search(r'(/\* Stores \*/.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
    if stores_match_new:
        content = content.replace(stores_match_new.group(0), stores_match_new.group(1) + stores_match_new.group(2) + ''.join(group_additions['Stores']) + stores_match_new.group(3))

if sidebar_match and group_additions['Sidebar']:
    sidebar_match_new = re.search(r'(/\* Sidebar \*/.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
    if sidebar_match_new:
        content = content.replace(sidebar_match_new.group(0), sidebar_match_new.group(1) + sidebar_match_new.group(2) + ''.join(group_additions['Sidebar']) + sidebar_match_new.group(3))

if editor_match and group_additions['Editor']:
    editor_match_new = re.search(r'(/\* Editor \*/.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
    if editor_match_new:
        content = content.replace(editor_match_new.group(0), editor_match_new.group(1) + editor_match_new.group(2) + ''.join(group_additions['Editor']) + editor_match_new.group(3))

# Write the updated project file
with open('SwagManager.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ Added MCP files to Xcode project:")
for file_info in files_to_add:
    print(f"  - {file_info['name']}")
