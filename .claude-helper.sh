#!/bin/bash
# Updated helper - smarter cache clearing

touch_swift_files() {
    find ~/Desktop/blackops/SwagManager -name "*.swift" -mmin -5 -exec touch {} \;
    echo "✓ Touched recently modified Swift files"
}

smart_clean() {
    # Smart cache clearing - keeps Swift packages
    DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -name "SwagManager-*" -type d -maxdepth 1 | head -1)
    
    if [ -z "$DERIVED_DATA" ]; then
        echo "⚠️  No DerivedData found"
        return 0
    fi
    
    # Only clear build artifacts, not Swift packages
    rm -rf "$DERIVED_DATA/Build" 2>/dev/null
    rm -rf "$DERIVED_DATA/ModuleCache" 2>/dev/null
    rm -rf "$DERIVED_DATA/Index" 2>/dev/null
    
    echo "✅ Cleared Build, ModuleCache, Index"
    echo "✅ Swift packages intact (no re-download needed)"
}

nuclear_clean() {
    # Full nuclear option - only use if really needed
    rm -rf ~/Library/Developer/Xcode/DerivedData/SwagManager-*
    echo "☢️  Nuclear clean - packages will need to be resolved"
}

export -f touch_swift_files
export -f smart_clean
export -f nuclear_clean
