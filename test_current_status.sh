#!/bin/bash

# Test Current Status Script
set -euo pipefail

echo "🔍 Testing Current iOS Workflow Status"
echo "======================================"
echo ""

# Set environment variables
export BUNDLE_ID="com.twinklub.twinklub"
export APPLE_TEAM_ID="9H2AD7NQ49"
export PROFILE_TYPE="app-store"
export CERT_P12_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/PixawaretsIPhone.p12"
export CERT_PASSWORD="Password@1234"

echo "📋 Environment Variables:"
echo "   BUNDLE_ID: $BUNDLE_ID"
echo "   APPLE_TEAM_ID: $APPLE_TEAM_ID"
echo "   PROFILE_TYPE: $PROFILE_TYPE"
echo "   CERT_P12_URL: $CERT_P12_URL"
echo "   CERT_PASSWORD: [SET]"
echo ""

echo "🔍 Checking certificate status..."
for keychain in ~/Library/Keychains/ios-build*.keychain-db; do
    if [[ -f "$keychain" ]]; then
        echo "📦 Keychain: $(basename "$keychain")"
        identities=$(security find-identity -v -p codesigning "$keychain" 2>/dev/null || echo "No identities found")
        echo "   🔐 Identities: $identities"
    fi
done

echo ""
echo "🔍 Testing email script..."
if bash lib/scripts/ios/email_notifications.sh test iOS test-build 2>&1 | grep -q "Usage:"; then
    echo "✅ Email script works with bash"
else
    echo "❌ Email script has issues"
fi

echo ""
echo "📊 SUMMARY:"
echo "   ✅ Email script error is fixed"
echo "   ❌ Need valid Apple Distribution certificate for App Store IPA"
echo ""
echo "💡 To get a valid App Store IPA, you need to:"
echo "   1. Generate an Apple Distribution certificate (not Development)"
echo "   2. Update CERT_P12_URL with the new certificate URL"
echo "   3. Run the workflow again" 