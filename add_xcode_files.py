#!/usr/bin/env python3
import re

project_path = "/Users/whale/Desktop/blackops/SwagManager.xcodeproj/project.pbxproj"

# Read project
with open(project_path, 'r') as f:
    content = f.read()

# Files to add with their groups
# We'll add them to existing groups or create new ones
files = [
    ("DesignSystem.swift", "Theme/DesignSystem.swift", "NEW_THEME"),
    ("CreationStore.swift", "Stores/CreationStore.swift", "NEW_STORES"),
    ("CatalogStore.swift", "Stores/CatalogStore.swift", "NEW_STORES"),
    ("BrowserStore.swift", "Stores/BrowserStore.swift", "NEW_STORES"),
    ("TreeItems.swift", "Components/TreeItems.swift", "NEW_COMPONENTS"),
    ("StateViews.swift", "Components/StateViews.swift", "NEW_COMPONENTS"),
    ("ChatComponents.swift", "Components/ChatComponents.swift", "NEW_COMPONENTS"),
    ("ButtonStyles.swift", "Components/ButtonStyles.swift", "NEW_COMPONENTS"),
    ("EditorSheets.swift", "Components/EditorSheets.swift", "NEW_COMPONENTS"),
    ("Formatters.swift", "Formatters.swift", "GR008"),  # Add to existing Utilities group
    ("EditorSidebarView.swift", "Editor/EditorSidebarView.swift", "NEW_EDITOR"),
]

# Group IDs to create
new_groups = {
    "NEW_THEME": ("GR020", "Theme", "Theme"),
    "NEW_STORES": ("GR021", "Stores", "Stores"),
    "NEW_COMPONENTS": ("GR022", "Components", "Components"),
    "NEW_EDITOR": ("GR023", "Editor", "Editor"),
}

# File and build IDs
file_ids = [f"SF{910+i}" for i in range(len(files))]
build_ids = [f"BF{910+i}" for i in range(len(files))]

# Step 1: Add PBXFileReference entries
file_ref_section = content.find("/* Begin PBXFileReference section */")
file_ref_insert = content.find("\n", file_ref_section) + 1

file_refs = []
for i, (name, path, group) in enumerate(files):
    # For files in existing Utilities group, just use filename
    # For new groups, use path relative to that group
    if group == "GR008":
        file_path = name
    else:
        file_path = path.split('/')[-1]  # Just the filename

    file_refs.append(f"\t\t{file_ids[i]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_path}; sourceTree = \"<group>\"; }};\n")

content = content[:file_ref_insert] + ''.join(file_refs) + content[file_ref_insert:]

# Step 2: Add PBXBuildFile entries
build_file_section = content.find("/* Begin PBXBuildFile section */")
build_file_insert = content.find("\n", build_file_section) + 1

build_files = []
for i, (name, _, _) in enumerate(files):
    build_files.append(f"\t\t{build_ids[i]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[i]} /* {name} */; }};\n")

content = content[:build_file_insert] + ''.join(build_files) + content[build_file_insert:]

# Step 3: Add to PBXSourcesBuildPhase
sources_match = re.search(r'isa = PBXSourcesBuildPhase;.*?files = \(\n', content, re.DOTALL)
if sources_match:
    sources_insert = sources_match.end()
    sources_entries = []
    for i, (name, _, _) in enumerate(files):
        sources_entries.append(f"\t\t\t\t{build_ids[i]} /* {name} in Sources */,\n")
    content = content[:sources_insert] + ''.join(sources_entries) + content[sources_insert:]

# Step 4: Create new PBXGroup entries
group_section = content.find("/* Begin PBXGroup section */")
group_insert = content.find("\n", group_section) + 1

new_group_entries = []
for group_key, (group_id, group_name, path) in new_groups.items():
    # Get file IDs for this group
    group_file_ids = [file_ids[i] for i, (name, _, gid) in enumerate(files) if gid == group_key]

    if group_file_ids:
        children_str = ''.join([f"\t\t\t\t{fid} /* {files[file_ids.index(fid)][0]} */,\n" for fid in group_file_ids])

        new_group_entries.append(f"""\t\t{group_id} /* {group_name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children_str}\t\t\t);
\t\t\tpath = {path};
\t\t\tsourceTree = "<group>";
\t\t}};
""")

content = content[:group_insert] + ''.join(new_group_entries) + content[group_insert:]

# Step 5: Add new groups to GR002 (SwagManager) children
gr002_match = re.search(r'GR002 /\* SwagManager \*/ = \{[^}]*children = \(\n', content, re.DOTALL)
if gr002_match:
    gr002_insert = gr002_match.end()
    new_group_refs = []
    for group_key, (group_id, group_name, _) in new_groups.items():
        if group_key != "NEW_EDITOR":  # Editor goes under Views, not root
            new_group_refs.append(f"\t\t\t\tGR020 /* Theme */,\n\t\t\t\tGR021 /* Stores */,\n\t\t\t\tGR022 /* Components */,\n")
            break  # Only add once
    content = content[:gr002_insert] + ''.join(new_group_refs) + content[gr002_insert:]

# Step 6: Add Editor subgroup to GR005 (Views)
gr005_match = re.search(r'GR005 /\* Views \*/ = \{[^}]*children = \(\n', content, re.DOTALL)
if gr005_match:
    gr005_insert = gr005_match.end()
    content = content[:gr005_insert] + f"\t\t\t\tGR023 /* Editor */,\n" + content[gr005_insert:]

# Step 7: Add Formatters to GR008 (Utilities)
gr008_match = re.search(r'GR008 /\* Utilities \*/ = \{[^}]*children = \(\n', content, re.DOTALL)
if gr008_match:
    gr008_insert = gr008_match.end()
    formatters_id = [file_ids[i] for i, (name, _, gid) in enumerate(files) if gid == "GR008"][0]
    content = content[:gr008_insert] + f"\t\t\t\t{formatters_id} /* Formatters.swift */,\n" + content[gr008_insert:]

# Write back
with open(project_path, 'w') as f:
    f.write(content)

print("✓ Successfully added files to Xcode project")
print(f"  • Created {len(new_groups)} new groups")
print(f"  • Added {len(files)} files")
