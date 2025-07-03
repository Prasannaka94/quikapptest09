#!/bin/bash

# Fix project.pbxproj syntax errors by removing malformed comment lines
echo "🔧 Fixing project.pbxproj syntax errors..."

PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

# Create backup
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Remove malformed comment lines that break plist parser
echo "🧹 Removing malformed comment lines..."
# Use a more robust regex to match any whitespace and any number of digits
sed -i '' '/^[[:space:]]*Target [0-9][0-9]* (Main App): com\.twinklub\.twinklub[[:space:]]*$/d' "$PROJECT_FILE"

# Verify the fix
if grep -q "Target [0-9][0-9]* (Main App): com\.twinklub\.twinklub" "$PROJECT_FILE"; then
    echo "❌ Failed to remove all malformed lines"
    exit 1
else
    echo "✅ Successfully removed malformed comment lines"
fi

# Test plist syntax
echo "🔍 Validating plist syntax..."
if plutil -lint "$PROJECT_FILE" > /dev/null 2>&1; then
    echo "✅ Project file syntax is now valid"
else
    echo "❌ Project file still has syntax errors"
    echo "Restoring backup..."
    cp "${PROJECT_FILE}.backup.$(date +%Y%m%d_%H%M%S)" "$PROJECT_FILE"
    exit 1
fi

echo "🎉 Project file syntax fixed successfully!" 