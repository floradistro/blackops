# SwagManager - Mac Admin App

## How to Open and Build

**Open the Xcode project:**

```bash
cd /Users/whale/Desktop/blackops
open SwagManager.xcodeproj
```

## Building

In Xcode: Press `Cmd+B` to build, `Cmd+R` to run

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
