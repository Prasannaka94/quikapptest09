#!/bin/bash

# Enhanced IPA Export Script with Framework Provisioning Profile Fix
# Purpose: Export IPA while properly handling embedded frameworks that don't support provisioning profiles

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

# Function to create export options without embedded framework signing
create_framework_safe_export_options() {
    local cert_identity="$1"
    local profile_uuid="$2"
    local bundle_id="$3"
    local team_id="$4"
    
    log_info "📝 Creating framework-safe export options..."
    
    cat > "ios/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${team_id}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingCertificate</key>
    <string>${cert_identity}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${bundle_id}</key>
        <string>${profile_uuid}</string>
    </dict>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>destination</key>
    <string>export</string>
    <key>iCloudContainerEnvironment</key>
    <string>Production</string>
    <key>onDemandInstallCapable</key>
    <false/>
    <key>embedOnDemandResourcesAssetPacksInBundle</key>
    <false/>
    <key>generateAppStoreInformation</key>
    <true/>
    <key>distributionBundleIdentifier</key>
    <string>${bundle_id}</string>
    <key>signingOptions</key>
    <dict>
        <key>signingCertificate</key>
        <string>${cert_identity}</string>
        <key>manualSigning</key>
        <true/>
    </dict>
</dict>
</plist>
EOF
    
    log_success "✅ Framework-safe export options created"
}

# Function to create alternative export options for automatic framework signing
create_automatic_framework_export_options() {
    local cert_identity="$1"
    local profile_uuid="$2"
    local bundle_id="$3"
    local team_id="$4"
    
    log_info "📝 Creating automatic framework signing export options..."
    
    cat > "ios/ExportOptionsAutomatic.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${team_id}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>destination</key>
    <string>export</string>
    <key>iCloudContainerEnvironment</key>
    <string>Production</string>
    <key>onDemandInstallCapable</key>
    <false/>
    <key>embedOnDemandResourcesAssetPacksInBundle</key>
    <false/>
    <key>generateAppStoreInformation</key>
    <true/>
    <key>distributionBundleIdentifier</key>
    <string>${bundle_id}</string>
</dict>
</plist>
EOF
    
    log_success "✅ Automatic framework signing export options created"
}

# Function to export IPA with multiple fallback methods
export_ipa_with_framework_fix() {
    local archive_path="$1"
    local export_path="$2"
    local cert_identity="$3"
    local profile_uuid="$4"
    local bundle_id="$5"
    local team_id="$6"
    local keychain_path="$7"
    
    log_info "🚀 Starting enhanced IPA export with framework compatibility..."
    log_info "📁 Archive: $archive_path"
    log_info "📁 Export Path: $export_path"
    log_info "🔐 Certificate: $cert_identity"
    log_info "📱 Profile UUID: $profile_uuid"
    log_info "📦 Bundle ID: $bundle_id"
    log_info "👥 Team ID: $team_id"
    
    # Ensure export directory exists
    mkdir -p "$export_path"
    
    # Set keychain as default
    log_info "🔐 Setting up keychain for export..."
    security list-keychains -d user -s "$keychain_path" $(security list-keychains -d user | xargs) 2>/dev/null || true
    security default-keychain -s "$keychain_path" 2>/dev/null || true
    
    # Method 1: Manual signing with framework-safe options
    log_info "🎯 Method 1: Manual signing with framework-safe export options..."
    create_framework_safe_export_options "$cert_identity" "$profile_uuid" "$bundle_id" "$team_id"
    
    if xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "ios/ExportOptions.plist" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$team_id" \
        CODE_SIGN_IDENTITY="$cert_identity" \
        PROVISIONING_PROFILE="$profile_uuid" 2>&1 | tee export_method1.log; then
        
        log_success "✅ Method 1 successful - Manual signing with framework-safe options"
        return 0
    else
        log_warn "⚠️ Method 1 failed - Manual signing with framework-safe options"
        cat export_method1.log | tail -20
    fi
    
    # Method 2: Automatic signing for frameworks
    log_info "🎯 Method 2: Automatic signing for frameworks..."
    create_automatic_framework_export_options "$cert_identity" "$profile_uuid" "$bundle_id" "$team_id"
    
    if xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "ios/ExportOptionsAutomatic.plist" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$team_id" 2>&1 | tee export_method2.log; then
        
        log_success "✅ Method 2 successful - Automatic signing for frameworks"
        return 0
    else
        log_warn "⚠️ Method 2 failed - Automatic signing for frameworks"
        cat export_method2.log | tail -20
    fi
    
    # Method 3: Ad-hoc distribution (for testing)
    log_info "🎯 Method 3: Ad-hoc distribution for testing..."
    
    cat > "ios/ExportOptionsAdHoc.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>${team_id}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
    <key>destination</key>
    <string>export</string>
    <key>distributionBundleIdentifier</key>
    <string>${bundle_id}</string>
</dict>
</plist>
EOF
    
    if xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "ios/ExportOptionsAdHoc.plist" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$team_id" 2>&1 | tee export_method3.log; then
        
        log_success "✅ Method 3 successful - Ad-hoc distribution (for testing)"
        log_warn "⚠️ Note: This is an ad-hoc build, not suitable for App Store distribution"
        return 0
    else
        log_warn "⚠️ Method 3 failed - Ad-hoc distribution"
        cat export_method3.log | tail -20
    fi
    
    # Method 4: Enterprise distribution (if applicable)
    if [[ "$cert_identity" == *"Enterprise"* ]]; then
        log_info "🎯 Method 4: Enterprise distribution..."
        
        cat > "ios/ExportOptionsEnterprise.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>enterprise</string>
    <key>teamID</key>
    <string>${team_id}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
    <key>destination</key>
    <string>export</string>
    <key>distributionBundleIdentifier</key>
    <string>${bundle_id}</string>
</dict>
</plist>
EOF
        
        if xcodebuild -exportArchive \
            -archivePath "$archive_path" \
            -exportPath "$export_path" \
            -exportOptionsPlist "ios/ExportOptionsEnterprise.plist" \
            -allowProvisioningUpdates \
            DEVELOPMENT_TEAM="$team_id" 2>&1 | tee export_method4.log; then
            
            log_success "✅ Method 4 successful - Enterprise distribution"
            return 0
        else
            log_warn "⚠️ Method 4 failed - Enterprise distribution"
            cat export_method4.log | tail -20
        fi
    fi
    
    log_error "❌ All export methods failed"
    log_error "🔧 Framework provisioning profile issues could not be resolved"
    
    # Show detailed error analysis
    log_info "📋 Error Analysis:"
    if [ -f export_method1.log ]; then
        log_info "🔍 Manual signing errors:"
        grep -i "error\|fail" export_method1.log | head -5 | while read line; do
            log_info "   $line"
        done
    fi
    
    if [ -f export_method2.log ]; then
        log_info "🔍 Automatic signing errors:"
        grep -i "error\|fail" export_method2.log | head -5 | while read line; do
            log_info "   $line"
        done
    fi
    
    return 1
}

# Main function
main() {
    log_info "🚀 Enhanced IPA Export with Framework Fix"
    
    # Validate required parameters
    local archive_path="${1:-${OUTPUT_DIR:-output/ios}/Runner.xcarchive}"
    local export_path="${2:-${OUTPUT_DIR:-output/ios}}"
    local cert_identity="${3:-}"
    local profile_uuid="${4:-}"
    local bundle_id="${5:-${BUNDLE_ID}}"
    local team_id="${6:-${APPLE_TEAM_ID}}"
    local keychain_path="${7:-}"
    
    # Validate inputs
    if [ -z "$cert_identity" ]; then
        log_error "❌ Certificate identity is required"
        return 1
    fi
    
    if [ -z "$profile_uuid" ]; then
        log_error "❌ Provisioning profile UUID is required"
        return 1
    fi
    
    if [ -z "$bundle_id" ]; then
        log_error "❌ Bundle ID is required"
        return 1
    fi
    
    if [ -z "$team_id" ]; then
        log_error "❌ Apple Team ID is required"
        return 1
    fi
    
    if [ -z "$keychain_path" ]; then
        # Try to find the keychain
        keychain_path=$(security list-keychains | grep "ios-build.keychain" | head -1 | sed 's/^[[:space:]]*"\([^"]*\)".*/\1/')
        if [ -z "$keychain_path" ]; then
            keychain_path="$HOME/Library/Keychains/ios-build.keychain-db"
        fi
    fi
    
    # Check if archive exists
    if [ ! -d "$archive_path" ]; then
        log_error "❌ Archive not found: $archive_path"
        return 1
    fi
    
    # Export IPA with framework fix
    export_ipa_with_framework_fix "$archive_path" "$export_path" "$cert_identity" "$profile_uuid" "$bundle_id" "$team_id" "$keychain_path"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 