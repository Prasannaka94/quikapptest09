#!/bin/bash

# Standalone iOS Icon Generator
# Purpose: Fix App Store validation error for iOS app icons with transparency
# Usage: ./generate_ios_icons.sh

set -e

echo "🎨 iOS App Icon Generator - Fixing App Store Validation Issues"
echo "=============================================================="

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: This script must be run from the root of a Flutter project"
    exit 1
fi

# Ensure flutter_launcher_icons is available
echo "📦 Checking flutter_launcher_icons dependency..."
if ! grep -q "flutter_launcher_icons:" pubspec.yaml; then
    echo "➕ Adding flutter_launcher_icons to pubspec.yaml..."
    echo "  flutter_launcher_icons: ^0.13.1" >> pubspec.yaml
fi

# Install dependencies
echo "📥 Installing dependencies..."
flutter pub get

# Ensure logo exists
if [ ! -f "assets/images/logo.png" ]; then
    echo "📸 Creating logo from existing iOS icon..."
    mkdir -p assets/images
    
    if [ -f "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" ]; then
        cp ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png assets/images/logo.png
        
        # Remove alpha channel using sips (macOS)
        if command -v sips &> /dev/null; then
            echo "🔧 Removing transparency from logo..."
            sips -s format jpeg assets/images/logo.png --out assets/images/logo_temp.jpg >/dev/null 2>&1
            sips -s format png assets/images/logo_temp.jpg --out assets/images/logo.png >/dev/null 2>&1
            rm -f assets/images/logo_temp.jpg
        fi
    else
        echo "❌ Error: No existing icon found to use as logo"
        exit 1
    fi
fi

# Generate icons
echo "🎨 Generating iOS app icons without transparency..."
dart run flutter_launcher_icons

# Verify the critical 1024x1024 icon
if [ -f "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" ]; then
    file_info=$(file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png)
    if echo "$file_info" | grep -q "with alpha"; then
        echo "⚠️ Icon still has transparency, applying additional fix..."
        
        # Additional transparency removal for all icons
        cd ios/Runner/Assets.xcassets/AppIcon.appiconset/
        for icon in *.png; do
            if [ -f "$icon" ]; then
                if command -v sips &> /dev/null; then
                    temp_file="${icon%.png}_temp.jpg"
                    sips -s format jpeg "$icon" --out "$temp_file" >/dev/null 2>&1
                    sips -s format png "$temp_file" --out "$icon" >/dev/null 2>&1
                    rm -f "$temp_file"
                fi
            fi
        done
        cd - >/dev/null
    fi
    
    # Final verification
    file_info=$(file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png)
    if echo "$file_info" | grep -q "with alpha"; then
        echo "❌ Error: Icon still contains transparency"
        exit 1
    else
        echo "✅ Success: 1024x1024 icon is now App Store compliant (no transparency)"
    fi
else
    echo "❌ Error: 1024x1024 icon not generated"
    exit 1
fi

echo ""
echo "🎉 iOS App Icons Generated Successfully!"
echo "============================================"
echo "✅ All iOS app icons are now App Store compliant"
echo "✅ Transparency/alpha channel issues fixed"
echo "✅ Ready for App Store submission"
echo ""
echo "Next steps:"
echo "1. Build and archive your iOS app"
echo "2. Upload to App Store Connect"
echo "3. The validation error should be resolved" 