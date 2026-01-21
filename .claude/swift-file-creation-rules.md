# Swift File Creation Rules for Claude Agents

## 🚨 CRITICAL: DO NOT CREATE NEW SWIFT FILES WITHOUT ADDING TO XCODE

Every new `.swift` file MUST be added to the Xcode project or builds will fail.

## Required Workflow:

### Step 1: Create the file
```
Use Write tool to create: SwagManager/Components/NewFile.swift
```

### Step 2: Add to Xcode project IMMEDIATELY
```
Use Bash tool: ./add-to-xcode.sh SwagManager/Components/NewFile.swift
```

### Step 3: Verify build
```
Use Bash tool: xcodebuild -scheme SwagManager build 2>&1 | grep "BUILD"
```

## ALTERNATIVE: Add to existing files instead

**Preferred:** Add new components to existing files:
- `Components/ButtonStyles.swift`
- `Components/StateViews.swift`
- `Components/UnifiedGlassComponents.swift`

This avoids the Xcode project issue entirely.

## See full documentation:
`/Users/whale/Desktop/blackops/AGENT_RULES_XCODE.md`
