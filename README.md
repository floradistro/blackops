# SwagManager - Mac Admin App

## How to Open and Build

**IMPORTANT: Always use Package.swift, NOT Xcode project files**

```bash
cd /Users/whale/Desktop/blackops
open Package.swift
```

This will open in Xcode and automatically include ALL Swift files.

## Why Package.swift?

- ✅ Automatically discovers all `.swift` files in `SwagManager/` folder
- ✅ No need to manually add files to build target
- ✅ Simple and clean
- ❌ Never use `.xcodeproj` files - they get out of sync

## Building

In Xcode: Press `Cmd+B`

Or from terminal:
```bash
swift build
swift run
```

## Project Structure

```
blackops/
├── Package.swift          ← Open this to launch in Xcode
├── SwagManager/           ← All source code
│   ├── App/              ← App entry point
│   ├── Models/           ← Data models
│   ├── Views/            ← SwiftUI views
│   ├── Services/         ← Business logic
│   ├── Stores/           ← State management
│   ├── Components/       ← Reusable UI components
│   └── Theme/            ← Design system
└── supabase/             ← Database migrations
```

## DO NOT Create

- ❌ `.xcodeproj` files
- ❌ Xcode workspace files
- ❌ Manual file management scripts

The Swift Package Manager handles everything automatically.
