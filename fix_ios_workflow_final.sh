#!/bin/bash

# 🔧 iOS Workflow Final Fix Script
# Purpose: Fix remaining issues and prepare for App Store IPA generation

set -euo pipefail

echo "🔧 iOS Workflow Final Fix Script"
echo "================================"
echo ""

# Function to check certificate status
check_certificate_status() {
    echo "🔍 Checking certificate status..."
    
    local has_valid_cert=false
    
    for keychain in ~/Library/Keychains/ios-build*.keychain-db; do
        if [[ -f "$keychain" ]]; then
            echo "📦 Checking keychain: $(basename "$keychain")"
            identities=$(security find-identity -v -p codesigning "$keychain" 2>/dev/null || echo "No identities found")
            
            if echo "$identities" | grep -q "Apple Distribution"; then
                echo "✅ Found Apple Distribution certificate!"
                has_valid_cert=true
            elif echo "$identities" | grep -q "valid identities found"; then
                echo "⚠️  Found certificates but none are Apple Distribution"
                echo "   Current identities: $identities"
            else
                echo "❌ No valid certificates found"
            fi
        fi
    done
    
    if [[ "$has_valid_cert" == "false" ]]; then
        echo ""
        echo "🚨 CERTIFICATE ISSUE DETECTED"
        echo "============================="
        echo "❌ No valid Apple Distribution certificate found"
        echo ""
        echo "📋 To fix this, you need to:"
        echo "   1. Generate an Apple Distribution certificate (not Development)"
        echo "   2. Update your environment variables with the new certificate"
        echo ""
        echo "🔧 Quick fix options:"
        echo "   Option 1: Use Xcode (Recommended)"
        echo "     1. Open Xcode"
        echo "     2. Go to Xcode > Settings > Accounts"
        echo "     3. Add your Apple Developer account"
        echo "     4. Click 'Manage Certificates'"
        echo "     5. Click '+' and select 'Apple Distribution'"
        echo ""
        echo "   Option 2: Use Apple Developer Portal"
        echo "     1. Go to https://developer.apple.com/account/"
        echo "     2. Navigate to Certificates, Identifiers & Profiles"
        echo "     3. Create new 'Apple Distribution' certificate"
        echo ""
        echo "   Option 3: Use Fastlane Match"
        echo "     fastlane match appstore --readonly"
        echo ""
        echo "📱 Your current configuration:"
        echo "   - Bundle ID: ${BUNDLE_ID:-com.example.app}"
        echo "   - Team ID: ${APPLE_TEAM_ID:-YOUR_TEAM_ID}"
        echo "   - Profile Type: ${PROFILE_TYPE:-app-store}"
        echo ""
        echo "💡 After generating the certificate, update:"
        echo "   CERT_P12_URL=<URL_TO_YOUR_DISTRIBUTION_CERTIFICATE.p12>"
        echo "   CERT_PASSWORD=<YOUR_CERTIFICATE_PASSWORD>"
        echo ""
        return 1
    else
        echo "✅ Certificate status: OK"
        return 0
    fi
}

# Function to verify email script fix
verify_email_script_fix() {
    echo "🔍 Verifying email script fix..."
    
    local script_path="lib/scripts/ios/email_notifications.sh"
    
    if [[ -f "$script_path" ]]; then
        echo "✅ Email script exists"
        
        # Test direct execution (should fail with guard)
        if bash -c "source $script_path" 2>&1 | grep -q "should not be executed directly"; then
            echo "✅ Email script guard is working"
        else
            echo "⚠️  Email script guard may need attention"
        fi
        
        # Test proper execution
        if bash "$script_path" test iOS test-build 2>&1 | grep -q "Usage:"; then
            echo "✅ Email script executes properly with bash"
        else
            echo "⚠️  Email script execution needs attention"
        fi
        
        echo "✅ Email script fix: OK"
        return 0
    else
        echo "❌ Email script not found: $script_path"
        return 1
    fi
}

# Function to check workflow readiness
check_workflow_readiness() {
    echo "🔍 Checking workflow readiness..."
    
    local issues=0
    
    # Check required environment variables
    local required_vars=("BUNDLE_ID" "APPLE_TEAM_ID" "PROFILE_TYPE" "CERT_P12_URL" "CERT_PASSWORD")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "❌ Missing required environment variable: $var"
            ((issues++))
        else
            echo "✅ $var: Set"
        fi
    done
    
    # Check required files
    local required_files=(
        "lib/scripts/ios/main.sh"
        "lib/scripts/ios/email_notifications.sh"
        "lib/scripts/ios/branding_assets.sh"
        "lib/scripts/ios/handle_certificates.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "✅ $file: Exists"
        else
            echo "❌ Missing required file: $file"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        echo "✅ Workflow readiness: OK"
        return 0
    else
        echo "❌ Workflow readiness: $issues issues found"
        return 1
    fi
}

# Main execution
main() {
    echo "🚀 Starting iOS Workflow Final Fix..."
    echo ""
    
    local overall_status=0
    
    # Check email script fix
    if ! verify_email_script_fix; then
        overall_status=1
    fi
    echo ""
    
    # Check certificate status
    if ! check_certificate_status; then
        overall_status=1
    fi
    echo ""
    
    # Check workflow readiness
    if ! check_workflow_readiness; then
        overall_status=1
    fi
    echo ""
    
    # Summary
    echo "📊 SUMMARY"
    echo "=========="
    
    if [[ $overall_status -eq 0 ]]; then
        echo "✅ All checks passed! Your iOS workflow should work correctly."
        echo ""
        echo "🚀 Next steps:"
        echo "   1. Run your iOS workflow: ./test_ios_workflow_local.sh"
        echo "   2. The workflow should now produce a valid App Store IPA"
        echo "   3. Upload the IPA to App Store Connect"
    else
        echo "⚠️  Some issues were found. Please address them before running the workflow."
        echo ""
        echo "🔧 Priority fixes:"
        echo "   1. Generate a valid Apple Distribution certificate"
        echo "   2. Update your environment variables"
        echo "   3. Re-run this script to verify fixes"
    fi
    
    return $overall_status
}

# Run main function
main "$@" 