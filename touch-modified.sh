#!/bin/bash
# Touch recently modified Swift files to force Xcode to notice
find ~/Desktop/blackops/SwagManager -name "*.swift" -mmin -5 -exec touch {} \;
echo "✓ Touched recently modified Swift files"
