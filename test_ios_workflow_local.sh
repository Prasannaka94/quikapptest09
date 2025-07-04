#!/bin/bash

# 🧪 Local iOS Workflow Test Script (with actual data)
# Purpose: Test the iOS workflow locally by simulating Codemagic environment with real values

set -euo pipefail

echo "🧪 Local iOS Workflow Test (Actual Data)"
echo "========================================="
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

if command -v flutter &> /dev/null; then
    echo "✅ Flutter: $(flutter --version | head -n 1)"
else
    echo "❌ Flutter not found"
    exit 1
fi

if command -v xcodebuild &> /dev/null; then
    echo "✅ Xcode: $(xcodebuild -version | head -n 1)"
else
    echo "❌ Xcode not found"
    exit 1
fi

if command -v pod &> /dev/null; then
    echo "✅ CocoaPods: $(pod --version)"
else
    echo "❌ CocoaPods not found"
    exit 1
fi

echo "✅ All prerequisites met"

# Set up environment variables (from user-provided actual data)
export WORKFLOW_ID="ios-workflow"
export USER_NAME="prasannasrie"
export APP_ID="1002"
export VERSION_NAME="1.0.6"
export VERSION_CODE="66"
export APP_NAME="Twinklub App"
export ORG_NAME="JPR Garments"
export WEB_URL="https://twinklub.com/"
export PKG_NAME="com.twinklub.twinklub"
export BUNDLE_ID="com.twinklub.twinklub"
export EMAIL_ID="prasannasrinivasan32@gmail.com"

export PUSH_NOTIFY="true"
export IS_CHATBOT="true"
export IS_DOMAIN_URL="true"
export IS_SPLASH="true"
export IS_PULLDOWN="true"
export IS_BOTTOMMENU="true"
export IS_LOAD_IND="true"

export IS_CAMERA="false"
export IS_LOCATION="false"
export IS_MIC="true"
export IS_NOTIFICATION="true"
export IS_CONTACT="false"
export IS_BIOMETRIC="false"
export IS_CALENDAR="false"
export IS_STORAGE="true"

export LOGO_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/twinklub_png_logo.png"
export SPLASH_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/twinklub_png_logo.png"
export SPLASH_BG_URL=""
export SPLASH_BG_COLOR="#cbdbf5"
export SPLASH_TAGLINE="TWINKLUB"
export SPLASH_TAGLINE_COLOR="#a30237"
export SPLASH_ANIMATION="zoom"
export SPLASH_DURATION="4"

export BOTTOMMENU_ITEMS='[{"label":"Home","icon":{"type":"preset","name":"home_outlined"},"url":"https://twinklub.com/"},{"label":"New Arraivals","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/card.svg","icon_size":"24"},"url":"https://www.twinklub.com/collections/new-arrivals"},{"label":"Collections","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/about.svg","icon_size":"24"},"url":"https://www.twinklub.com/collections/all"},{"label":"Contact","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/contact.svg","icon_size":"24"},"url":"https://www.twinklub.com/account"}]'
export BOTTOMMENU_BG_COLOR="#FFFFFF"
export BOTTOMMENU_ICON_COLOR="#6d6e8c"
export BOTTOMMENU_TEXT_COLOR="#6d6e8c"
export BOTTOMMENU_FONT="DM Sans"
export BOTTOMMENU_FONT_SIZE="12"
export BOTTOMMENU_FONT_BOLD="false"
export BOTTOMMENU_FONT_ITALIC="false"
export BOTTOMMENU_ACTIVE_TAB_COLOR="#a30237"
export BOTTOMMENU_ICON_POSITION="above"

export FIREBASE_CONFIG_ANDROID="https://raw.githubusercontent.com/prasanna91/QuikApp/main/google-services-TK.json"
export FIREBASE_CONFIG_IOS="https://raw.githubusercontent.com/prasanna91/QuikApp/main/GoogleService-Info-TK.plist"

export APPLE_TEAM_ID="9H2AD7NQ49"
export APNS_KEY_ID="V566SWNF69"
export APNS_AUTH_KEY_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/AuthKey_V566SWNF69.p8"

export PROFILE_TYPE="app-store"
export PROFILE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/tk-profile.mobileprovision"

# --- Automatically extract and export MOBILEPROVISION_UUID ---
echo "🔍 Downloading provisioning profile for UUID extraction..."
curl -s -o /tmp/profile.mobileprovision "$PROFILE_URL"
UUID=$(grep -a -A1 UUID /tmp/profile.mobileprovision | grep -ioE '([A-F0-9\-]{36})' | head -n1)
if [ -n "$UUID" ]; then
    export MOBILEPROVISION_UUID="$UUID"
    echo "✅ Extracted and exported MOBILEPROVISION_UUID: $MOBILEPROVISION_UUID"
else
    echo "❌ Failed to extract MOBILEPROVISION_UUID from provisioning profile!"
    exit 1
fi

# --- Copy Apple Distribution Certificate to Build Keychain ---
echo "🔐 Setting up keychain configuration for Apple Distribution certificates..."
# Set the keychain search list to include both system and build keychains
security list-keychains -s login.keychain ios-build.keychain-db
echo "✅ Keychain search list configured to include system certificates"

# Export the system keychain certificates for the workflow to use
echo "🔐 Exporting system Apple Distribution certificates for workflow use..."
set +e  # Disable exit on error for this block
DIST_CERT=$(timeout 10s security find-identity -v -p codesigning login.keychain 2>/dev/null | grep "Apple Distribution" | head -1 | awk '{print $2}' | tr -d '"')
CERT_STATUS=$?
set -e  # Re-enable exit on error

if [ $CERT_STATUS -ne 0 ]; then
    echo "❌ Error running security find-identity. Continuing with fallback."
    export APPLE_DISTRIBUTION_CERT_ID=""
elif [ -n "$DIST_CERT" ]; then
    echo "✅ Found Apple Distribution certificate: $DIST_CERT"
    export APPLE_DISTRIBUTION_CERT_ID="$DIST_CERT"
else
    echo "⚠️ No Apple Distribution certificate found in system keychain"
    echo "🔄 Will use provided CER+KEY certificates instead"
    export APPLE_DISTRIBUTION_CERT_ID=""
fi

echo ">>> Certificate check complete, proceeding to main workflow"

export CERT_P12_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/certificate.p12"
export CERT_PASSWORD="opeN@1234"

# Fallback certificate options (CER + KEY method)
export CERT_CER_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/certificate.cer"
export CERT_KEY_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/privatekey.key"

# Add logic to handle empty/null P12 certificates
if [ -z "$CERT_P12_URL" ] || [ "$CERT_P12_URL" = "null" ] || [ "$CERT_P12_URL" = "" ]; then
    echo "⚠️ P12 certificate URL is empty/null, will use CER+KEY method"
    export CERT_P12_URL=""
    export CERT_PASSWORD=""
else
    echo "✅ P12 certificate URL provided: $CERT_P12_URL"
fi

export IS_TESTFLIGHT="false"

export APPLE_ID="pixaware.co@gmail.com"
export APPLE_ID_PASSWORD="umor-gpxa-iohu-nitb"

export APP_STORE_CONNECT_KEY_IDENTIFIER="ZFD9GRMS7R"
export APP_STORE_CONNECT_API_KEY="https://raw.githubusercontent.com/prasanna91/QuikApp/main/AuthKey_ZFD9GRMS7R.p8"
export APP_STORE_CONNECT_API_KEY_PATH="https://raw.githubusercontent.com/prasanna91/QuikApp/main/AuthKey_ZFD9GRMS7R.p8"
export APP_STORE_CONNECT_ISSUER_ID="a99a2ebd-ed3e-4117-9f97-f195823774a7"

export KEY_STORE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/keystore.jks"
export CM_KEYSTORE_PASSWORD="opeN@1234"
export CM_KEY_ALIAS="my_key_alias"
export CM_KEY_PASSWORD="opeN@1234"

export ENABLE_EMAIL_NOTIFICATIONS="true"
export EMAIL_SMTP_SERVER="smtp.gmail.com"
export EMAIL_SMTP_PORT="587"
export EMAIL_SMTP_USER="prasannasrie@gmail.com"
export EMAIL_SMTP_PASS="lrnu krfm aarp urux"

export CM_BUILD_ID="local-test-$(date +%s)"
export CM_BUILD_DIR="$(pwd)"
export OUTPUT_DIR="output/ios"

# Print key variables for confirmation
echo "✅ Test environment variables set (actual data)"
echo "📋 Key variables:"
echo "   BUNDLE_ID: $BUNDLE_ID"
echo "   APP_NAME: $APP_NAME"
echo "   PROFILE_TYPE: $PROFILE_TYPE"
echo "   WORKFLOW_ID: $WORKFLOW_ID"
echo "   APPLE_ID: $APPLE_ID"
echo "   EMAIL_ID: $EMAIL_ID"

echo ""
echo "📁 Creating output directory..."
mkdir -p "$OUTPUT_DIR"
echo "✅ Output directory created: $OUTPUT_DIR"

echo ""
echo "🚀 Running iOS Workflow..."
echo "=========================="

chmod +x lib/scripts/ios/main.sh

echo "🚀 Proceeding to main iOS workflow (lib/scripts/ios/main.sh)"
echo ">>> About to call main iOS workflow"
if bash lib/scripts/ios/main.sh; then
    echo ""
    echo "✅ iOS Workflow completed successfully!"
else
    echo ""
    echo "❌ iOS Workflow failed!"
    exit 1
fi
echo ">>> Returned from main iOS workflow"

echo ""
echo "📊 Test Results Summary"
echo "======================"
echo "🔍 Checking key files:"

if [ -f "ios/ExportOptions.plist" ]; then
    echo "✅ ExportOptions.plist created"
else
    echo "❌ ExportOptions.plist not found"
fi

if [ -f "ios/Runner/Info.plist" ]; then
    echo "✅ Info.plist exists"
    if grep -q "$BUNDLE_ID" ios/Runner/Info.plist; then
        echo "✅ Bundle ID updated in Info.plist"
    else
        echo "⚠️ Bundle ID not found in Info.plist"
    fi
else
    echo "❌ Info.plist not found"
fi

if [ -f "pubspec.yaml" ]; then
    echo "✅ pubspec.yaml exists"
    if grep -q "$APP_NAME" pubspec.yaml; then
        echo "✅ App name updated in pubspec.yaml"
    else
        echo "⚠️ App name not found in pubspec.yaml"
    fi
else
    echo "❌ pubspec.yaml not found"
fi

if [ -d "$OUTPUT_DIR" ]; then
    echo "✅ Output directory exists"
    ls -la "$OUTPUT_DIR" 2>/dev/null || echo "   (empty)"
else
    echo "❌ Output directory not found"
fi

echo ""
echo "🧹 Cleaning up test artifacts..."
if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
    echo "✅ Removed test output directory"
fi
if [ -f "ios/ExportOptions.plist" ]; then
    rm -f "ios/ExportOptions.plist"
    echo "✅ Removed test ExportOptions.plist"
fi
echo "✅ Cleanup completed"

echo ""
echo "🎉 Local iOS Workflow Test completed!"
echo "📋 Check the logs above for any issues." 