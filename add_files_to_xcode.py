#!/usr/bin/env python3
import re
import uuid

project_path = "/Users/whale/Desktop/blackops/SwagManager.xcodeproj/project.pbxproj"

# Files to add - just filenames and their directories
files_to_add = [
    {"name": "DesignSystem.swift", "dir": "Theme"},
    {"name": "CreationStore.swift", "dir": "Stores"},
    {"name": "CatalogStore.swift", "dir": "Stores"},
    {"name": "BrowserStore.swift", "dir": "Stores"},
    {"name": "TreeItems.swift", "dir": "Components"},
    {"name": "StateViews.swift", "dir": "Components"},
    {"name": "ChatComponents.swift", "dir": "Components"},
    {"name": "ButtonStyles.swift", "dir": "Components"},
    {"name": "EditorSheets.swift", "dir": "Components"},
    {"name": "Formatters.swift", "dir": "Utilities"},
    {"name": "EditorSidebarView.swift", "dir": "Views/Editor"},
]

# Read project file
with open(project_path, 'r') as f:
    lines = f.readlines()

# Generate IDs
for file_info in files_to_add:
    file_info['file_id'] = f"SF{900 + files_to_add.index(file_info):03d}"
    file_info['build_id'] = f"BF{900 + files_to_add.index(file_info):03d}"

# Find sections
pbx_build_file_start = None
pbx_file_ref_start = None
pbx_sources_phase_files = None
pbx_group_children = None

for i, line in enumerate(lines):
    if "/* Begin PBXBuildFile section */" in line:
        pbx_build_file_start = i + 1
    elif "/* Begin PBXFileReference section */" in line:
        pbx_file_ref_start = i + 1
    elif "isa = PBXSourcesBuildPhase" in line:
        # Find the files = ( line after this
        for j in range(i, min(i + 20, len(lines))):
            if "files = (" in lines[j]:
                pbx_sources_phase_files = j + 1
                break
    elif "GR002 /* SwagManager */ = {" in line:
        # Find children = ( line after this
        for j in range(i, min(i + 20, len(lines))):
            if "children = (" in lines[j]:
                pbx_group_children = j + 1
                break

if not all([pbx_build_file_start, pbx_file_ref_start, pbx_sources_phase_files, pbx_group_children]):
    print(f"ERROR: Could not find required sections")
    print(f"  PBXBuildFile: {pbx_build_file_start}")
    print(f"  PBXFileReference: {pbx_file_ref_start}")
    print(f"  SourcesPhase: {pbx_sources_phase_files}")
    print(f"  GroupChildren: {pbx_group_children}")
    exit(1)

# Build new entries
build_file_entries = []
file_ref_entries = []
sources_entries = []
group_entries = []

for file_info in files_to_add:
    name = file_info['name']
    dir_path = file_info['dir']
    file_id = file_info['file_id']
    build_id = file_info['build_id']
    full_path = f"{dir_path}/{name}"

    # PBXBuildFile entry
    build_file_entries.append(f"\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {name} */; }};\n")

    # PBXFileReference entry with full relative path
    file_ref_entries.append(f"\t\t{file_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{full_path}\"; sourceTree = \"<group>\"; }};\n")

    # Sources phase entry
    sources_entries.append(f"\t\t\t\t{build_id} /* {name} in Sources */,\n")

    # Group children entry
    group_entries.append(f"\t\t\t\t{file_id} /* {name} */,\n")

# Insert entries
lines[pbx_build_file_start:pbx_build_file_start] = build_file_entries
file_ref_offset = len(build_file_entries)

lines[pbx_file_ref_start + file_ref_offset:pbx_file_ref_start + file_ref_offset] = file_ref_entries
sources_offset = file_ref_offset + len(file_ref_entries)

lines[pbx_sources_phase_files + sources_offset:pbx_sources_phase_files + sources_offset] = sources_entries
group_offset = sources_offset + len(sources_entries)

lines[pbx_group_children + group_offset:pbx_group_children + group_offset] = group_entries

# Write back
with open(project_path, 'w') as f:
    f.writelines(lines)

print(f"✓ Added {len(files_to_add)} files to Xcode project")
for file_info in files_to_add:
    print(f"  • {file_info['dir']}/{file_info['name']}")
