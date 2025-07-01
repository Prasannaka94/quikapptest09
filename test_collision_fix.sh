#!/bin/bash

echo "🔍 TESTING COLLISION FIX..."
echo "================================"

# Count main bundle ID occurrences
MAIN_COUNT=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = com.insurancegroupmo.insurancegroupmo;" ios/Runner.xcodeproj/project.pbxproj)
echo "📱 Main bundle ID occurrences: $MAIN_COUNT"

# Count test bundle ID occurrences  
TEST_COUNT=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = com.insurancegroupmo.insurancegroupmo.tests;" ios/Runner.xcodeproj/project.pbxproj)
echo "🧪 Test bundle ID occurrences: $TEST_COUNT"

# Count total bundle IDs
TOTAL_BUNDLE_IDS=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER =" ios/Runner.xcodeproj/project.pbxproj)
echo "📦 Total bundle ID references: $TOTAL_BUNDLE_IDS"

# Show all bundle IDs
echo ""
echo "📋 ALL BUNDLE IDs:"
grep "PRODUCT_BUNDLE_IDENTIFIER =" ios/Runner.xcodeproj/project.pbxproj | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = //;s/;//' | sort

echo ""
if [ "$MAIN_COUNT" -eq 3 ] && [ "$TEST_COUNT" -eq 3 ] && [ "$TOTAL_BUNDLE_IDS" -eq 6 ]; then
    echo "✅ COLLISION FIX SUCCESSFUL!"
    echo "🎯 Main app: 3 occurrences (Debug, Release, Profile)"
    echo "🧪 Tests: 3 occurrences (Debug, Release, Profile)"
    echo "💥 NO DUPLICATES - Ready for App Store Connect!"
else
    echo "❌ COLLISION STILL EXISTS"
    echo "🔧 Manual review needed"
fi 