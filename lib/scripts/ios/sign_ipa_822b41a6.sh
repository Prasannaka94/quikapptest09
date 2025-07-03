#!/bin/bash

# Dedicated IPA signing function for 822B41A6 fix
sign_ipa_822b41a6() {
    local ipa_path="$1"
    local cert_identity="$2"
    local profile_uuid="$3"
    
    if [ ! -f "$ipa_path" ]; then
        echo "❌ IPA file not found: $ipa_path"
        return 1
    fi
    
    echo "🔐 Applying 822B41A6 signing fix to IPA: $(basename "$ipa_path")"
    echo "🎯 Certificate: $cert_identity"
    echo "📱 Profile UUID: $profile_uuid"
    
    # Create temporary directory for signing
    local temp_dir=$(mktemp -d)
    local app_dir="$temp_dir/Payload"
    
    # Extract IPA
    echo "📦 Extracting IPA for signing..."
    unzip -q "$ipa_path" -d "$temp_dir"
    
    if [ ! -d "$app_dir" ]; then
        echo "❌ Invalid IPA structure - Payload directory not found"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Find the app bundle
    local app_bundle=$(find "$app_dir" -name "*.app" -type d | head -1)
    
    if [ -z "$app_bundle" ]; then
        echo "❌ App bundle not found in IPA"
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo "📱 Found app bundle: $(basename "$app_bundle")"
    
    # Re-sign the app bundle with proper Apple Distribution certificate
    echo "🔐 Re-signing app bundle..."
    codesign --force --sign "$cert_identity" --verbose --preserve-metadata=identifier,entitlements,flags --timestamp=none "$app_bundle"
    
    if [ $? -eq 0 ]; then
        echo "✅ App bundle re-signed successfully"
        
        # Repackage IPA
        echo "📦 Repackaging IPA..."
        local signed_ipa="${ipa_path%.*}_822b41a6_signed.ipa"
        
        cd "$temp_dir"
        zip -q -r "$signed_ipa" Payload/
        cd - > /dev/null
        
        if [ -f "$signed_ipa" ]; then
            echo "✅ Signed IPA created: $(basename "$signed_ipa")"
            
            # Replace original IPA with signed version
            mv "$signed_ipa" "$ipa_path"
            echo "🔄 Original IPA replaced with signed version"
        else
            echo "❌ Failed to create signed IPA"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        echo "❌ Failed to re-sign app bundle"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    echo "✅ 822B41A6 signing fix completed successfully"
    return 0
}

# Export the function for use by other scripts
export -f sign_ipa_822b41a6
