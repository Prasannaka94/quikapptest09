#!/bin/bash

# 🍎 Apple Distribution Certificate Generator
# Purpose: Generate a new Apple Distribution certificate for App Store submission

set -euo pipefail

echo "🍎 Apple Distribution Certificate Generator"
echo "==========================================="
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script must be run on macOS"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is required but not found"
    echo "💡 Please install Xcode from the App Store"
    exit 1
fi

echo "✅ Xcode found: $(xcodebuild -version | head -n 1)"
echo ""

# Check if we have access to Apple Developer account
echo "🔍 Checking Apple Developer account access..."
if ! xcodebuild -showBuildSettings -project ios/Runner.xcodeproj 2>/dev/null | grep -q "DEVELOPMENT_TEAM"; then
    echo "❌ No Apple Developer account configured in Xcode"
    echo "💡 Please:"
    echo "   1. Open Xcode"
    echo "   2. Go to Xcode → Preferences → Accounts"
    echo "   3. Add your Apple ID"
    echo "   4. Select your team"
    exit 1
fi

echo "✅ Apple Developer account configured"
echo ""

# Get team ID
TEAM_ID=$(xcodebuild -showBuildSettings -project ios/Runner.xcodeproj 2>/dev/null | grep "DEVELOPMENT_TEAM" | head -1 | awk '{print $3}')
if [ -z "$TEAM_ID" ]; then
    echo "❌ Could not determine Team ID"
    exit 1
fi

echo "👥 Team ID: $TEAM_ID"
echo ""

# Create certificates directory
CERT_DIR="ios/certificates"
mkdir -p "$CERT_DIR"

echo "📁 Creating certificates directory: $CERT_DIR"
echo ""

# Check for existing certificates
echo "🔍 Checking for existing Apple Distribution certificates..."
EXISTING_CERTS=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Distribution" || echo "")

if [ -n "$EXISTING_CERTS" ]; then
    echo "✅ Found existing Apple Distribution certificates:"
    echo "$EXISTING_CERTS"
    echo ""
    
    read -p "Do you want to export an existing certificate? (y/n): " export_existing
    
    if [[ "$export_existing" == "y" || "$export_existing" == "Y" ]]; then
        echo "📤 Exporting existing certificate..."
        
        # Find the certificate
        CERT_ID=$(security find-identity -v -p codesigning | grep "Apple Distribution" | head -1 | awk '{print $2}' | tr -d '"')
        
        if [ -z "$CERT_ID" ]; then
            echo "❌ Could not find Apple Distribution certificate"
            exit 1
        fi
        
        echo "🔍 Found certificate: $CERT_ID"
        
        # Export as P12
        echo "📦 Exporting as P12 file..."
        P12_PASSWORD="Password@1234"
        security export -k login.keychain -t identities -f pkcs12 -o "$CERT_DIR/certificate.p12" -P "$P12_PASSWORD" "$CERT_ID"
        
        if [ $? -eq 0 ]; then
            echo "✅ Certificate exported to: $CERT_DIR/certificate.p12"
            echo "🔑 Password: $P12_PASSWORD"
        else
            echo "❌ Failed to export certificate"
            exit 1
        fi
        
        # Also export as CER and KEY for fallback
        echo "📄 Exporting as CER and KEY files..."
        
        # Export certificate (CER)
        security export -k login.keychain -t certs -f pem -o "$CERT_DIR/certificate.cer" "$CERT_ID"
        if [ $? -eq 0 ]; then
            echo "✅ Certificate exported to: $CERT_DIR/certificate.cer"
        else
            echo "⚠️ Failed to export CER file"
        fi
        
        # Export private key (KEY)
        security export -k login.keychain -t privkeys -f pem -o "$CERT_DIR/privatekey.key" "$CERT_ID"
        if [ $? -eq 0 ]; then
            echo "✅ Private key exported to: $CERT_DIR/privatekey.key"
        else
            echo "⚠️ Failed to export KEY file"
        fi
        
        echo ""
        echo "🎉 Certificate export completed!"
        echo "📁 Files created in: $CERT_DIR"
        echo ""
        
        # Update the test script with new certificate paths
        echo "🔄 Updating test script with new certificate paths..."
        
        # Update CERT_P12_URL to use local file
        sed -i '' 's|export CERT_P12_URL=""|export CERT_P12_URL="file://'"$(pwd)/$CERT_DIR/certificate.p12"'"|' test_ios_workflow_local.sh
        
        # Update CERT_PASSWORD
        sed -i '' 's|export CERT_PASSWORD="1234"|export CERT_PASSWORD="'"$P12_PASSWORD"'"|' test_ios_workflow_local.sh
        
        # Update CER and KEY URLs to use local files
        sed -i '' 's|export CERT_CER_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/certificate.cer"|export CERT_CER_URL="file://'"$(pwd)/$CERT_DIR/certificate.cer"'"|' test_ios_workflow_local.sh
        sed -i '' 's|export CERT_KEY_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/privatekey.key"|export CERT_KEY_URL="file://'"$(pwd)/$CERT_DIR/privatekey.key"'"|' test_ios_workflow_local.sh
        
        echo "✅ Test script updated with new certificate paths"
        echo ""
        
        # Verify the certificate
        echo "🔍 Verifying certificate..."
        security find-identity -v -p codesigning | grep "Apple Distribution"
        echo ""
        
        echo "🚀 Ready to test with new certificate!"
        echo "💡 Run: bash test_ios_workflow_local.sh"
        echo ""
        
        echo "🎉 Certificate generation process completed successfully!"
        exit 0
    fi
else
    echo "❌ No existing Apple Distribution certificates found"
    echo ""
fi

# If no existing certificates or user chose not to export, provide instructions
echo "📋 To create a new Apple Distribution certificate:"
echo ""
echo "1️⃣  Open Xcode"
echo "2️⃣  Go to Xcode → Settings → Accounts"
echo "3️⃣  Select your Apple Developer account"
echo "4️⃣  Click 'Manage Certificates'"
echo "5️⃣  Click '+' to add new certificate"
echo "6️⃣  Choose 'Apple Distribution'"
echo "7️⃣  Follow the wizard to create the certificate"
echo ""
echo "💡 Alternative method:"
echo "1️⃣  Go to https://developer.apple.com/account/"
echo "2️⃣  Navigate to Certificates, Identifiers & Profiles"
echo "3️⃣  Click '+' to create a new certificate"
echo "4️⃣  Select 'Apple Distribution'"
echo "5️⃣  Follow the steps to create a Certificate Signing Request (CSR)"
echo "6️⃣  Download the .cer file and convert to .p12"
echo ""
echo "🔧 Your current configuration:"
echo "   - Bundle ID: com.twinklub.twinklub"
echo "   - Team ID: $TEAM_ID"
echo "   - Profile Type: app-store"
echo ""
echo "📱 Once you have created the certificate in Xcode or Apple Developer portal,"
echo "   run this script again to export it for use in the workflow."
echo ""
echo "✅ Instructions provided - please create the certificate and run this script again" 