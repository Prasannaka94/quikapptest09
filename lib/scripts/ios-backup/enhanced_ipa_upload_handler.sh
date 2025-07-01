#!/bin/bash

# 📤 Enhanced IPA Upload Handler
# 🎯 Multiple upload methods with retry logic and comprehensive validation
# 🔧 Handles App Store Connect uploads, TestFlight, and validation errors

set -euo pipefail

# Global upload configuration
UPLOAD_LOG="ipa_upload.log"
MAX_UPLOAD_RETRIES=3
UPLOAD_RETRY_COUNT=0
IPA_VALIDATION_PASSED=false
UPLOAD_METHOD=""
UPLOAD_SUCCESS=false

# Initialize upload logging
initialize_upload_logging() {
    echo "📤 Enhanced IPA Upload Handler - $(date)" > "$UPLOAD_LOG"
    echo "📊 Upload Environment:" >> "$UPLOAD_LOG"
    echo "   - Bundle ID: ${BUNDLE_ID:-'Not Set'}" >> "$UPLOAD_LOG"
    echo "   - Profile Type: ${PROFILE_TYPE:-'Not Set'}" >> "$UPLOAD_LOG"
    echo "   - App Store Connect Key ID: ${APP_STORE_CONNECT_KEY_IDENTIFIER:-'Not Set'}" >> "$UPLOAD_LOG"
    echo "   - App Store Connect Issuer ID: ${APP_STORE_CONNECT_ISSUER_ID:-'Not Set'}" >> "$UPLOAD_LOG"
    echo "" >> "$UPLOAD_LOG"
}

# Comprehensive IPA validation
validate_ipa() {
    local ipa_path="$1"
    
    echo "🔍 IPA VALIDATION:" | tee -a "$UPLOAD_LOG"
    echo "   IPA Path: $ipa_path" | tee -a "$UPLOAD_LOG"
    
    # Check if IPA exists
    if [ ! -f "$ipa_path" ]; then
        echo "❌ IPA file not found: $ipa_path" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    # Check IPA size
    local ipa_size=$(du -h "$ipa_path" | cut -f1)
    local ipa_size_bytes=$(du -b "$ipa_path" | cut -f1)
    echo "   📦 IPA Size: $ipa_size" | tee -a "$UPLOAD_LOG"
    
    # Check if IPA is too small (likely invalid)
    if [ "$ipa_size_bytes" -lt 1048576 ]; then  # Less than 1MB
        echo "❌ IPA file appears to be too small (< 1MB) - likely invalid" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    # Check if IPA is too large (App Store limit)
    if [ "$ipa_size_bytes" -gt 4294967296 ]; then  # Greater than 4GB
        echo "⚠️ IPA file is very large (> 4GB) - may exceed App Store limits" | tee -a "$UPLOAD_LOG"
    fi
    
    # Validate IPA structure
    echo "   🔍 Validating IPA structure..." | tee -a "$UPLOAD_LOG"
    
    # Check if IPA can be unzipped
    if ! unzip -t "$ipa_path" >/dev/null 2>&1; then
        echo "❌ IPA file appears to be corrupted - cannot unzip" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    # Check for Payload directory
    if ! unzip -l "$ipa_path" | grep -q "Payload/"; then
        echo "❌ IPA file missing Payload directory" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    # Check for .app bundle
    if ! unzip -l "$ipa_path" | grep -q "\.app/"; then
        echo "❌ IPA file missing .app bundle" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    echo "   ✅ IPA structure validation passed" | tee -a "$UPLOAD_LOG"
    
    # Validate bundle identifier in IPA
    echo "   🔍 Validating bundle identifier..." | tee -a "$UPLOAD_LOG"
    
    # Extract and check Info.plist
    local temp_dir=$(mktemp -d)
    if unzip -q "$ipa_path" -d "$temp_dir" 2>/dev/null; then
        local app_path=$(find "$temp_dir/Payload" -name "*.app" -type d | head -1)
        if [ -n "$app_path" ] && [ -f "$app_path/Info.plist" ]; then
            local ipa_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_path/Info.plist" 2>/dev/null || echo "NOT_FOUND")
            
            if [ "$ipa_bundle_id" = "NOT_FOUND" ]; then
                echo "⚠️ Could not extract bundle identifier from IPA" | tee -a "$UPLOAD_LOG"
            elif [ "$ipa_bundle_id" != "${BUNDLE_ID:-}" ]; then
                echo "⚠️ IPA bundle ID ($ipa_bundle_id) does not match expected (${BUNDLE_ID:-})" | tee -a "$UPLOAD_LOG"
            else
                echo "   ✅ Bundle identifier validation passed: $ipa_bundle_id" | tee -a "$UPLOAD_LOG"
            fi
            
            # Check version information
            local ipa_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app_path/Info.plist" 2>/dev/null || echo "NOT_FOUND")
            local ipa_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$app_path/Info.plist" 2>/dev/null || echo "NOT_FOUND")
            
            echo "   📋 Version: $ipa_version" | tee -a "$UPLOAD_LOG"
            echo "   📋 Build: $ipa_build" | tee -a "$UPLOAD_LOG"
        fi
        
        rm -rf "$temp_dir"
    fi
    
    echo "   ✅ IPA validation completed successfully" | tee -a "$UPLOAD_LOG"
    IPA_VALIDATION_PASSED=true
    return 0
}

# Download App Store Connect API key
download_api_key() {
    local api_key_url="$1"
    local api_key_path="/tmp/AuthKey_${APP_STORE_CONNECT_KEY_IDENTIFIER}.p8"
    
    echo "📥 Downloading App Store Connect API key..." | tee -a "$UPLOAD_LOG"
    echo "   URL: $api_key_url" | tee -a "$UPLOAD_LOG"
    echo "   Local Path: $api_key_path" | tee -a "$UPLOAD_LOG"
    
    if curl -fsSL -o "$api_key_path" "$api_key_url"; then
        echo "   ✅ API key downloaded successfully" | tee -a "$UPLOAD_LOG"
        
        # Validate API key format
        if grep -q "BEGIN PRIVATE KEY" "$api_key_path"; then
            echo "   ✅ API key format validation passed" | tee -a "$UPLOAD_LOG"
            echo "$api_key_path"
            return 0
        else
            echo "   ❌ API key format validation failed" | tee -a "$UPLOAD_LOG"
            return 1
        fi
    else
        echo "   ❌ Failed to download API key" | tee -a "$UPLOAD_LOG"
        return 1
    fi
}

# Upload using xcrun altool (primary method)
upload_with_altool() {
    local ipa_path="$1"
    local api_key_path="$2"
    
    echo "📤 UPLOAD METHOD: xcrun altool" | tee -a "$UPLOAD_LOG"
    UPLOAD_METHOD="altool"
    
    local upload_cmd="xcrun altool --upload-app --type ios --file \"$ipa_path\""
    upload_cmd="$upload_cmd --apiKey \"${APP_STORE_CONNECT_KEY_IDENTIFIER}\""
    upload_cmd="$upload_cmd --apiIssuer \"${APP_STORE_CONNECT_ISSUER_ID}\""
    upload_cmd="$upload_cmd --apiKeyPath \"$api_key_path\""
    
    echo "   📋 Upload command: $upload_cmd" | tee -a "$UPLOAD_LOG"
    
    if eval "$upload_cmd"; then
        echo "   ✅ Upload via altool successful" | tee -a "$UPLOAD_LOG"
        return 0
    else
        local exit_code=$?
        echo "   ❌ Upload via altool failed (Exit Code: $exit_code)" | tee -a "$UPLOAD_LOG"
        return $exit_code
    fi
}

# Upload using xcrun notarytool (alternative method)
upload_with_notarytool() {
    local ipa_path="$1"
    local api_key_path="$2"
    
    echo "📤 UPLOAD METHOD: xcrun notarytool" | tee -a "$UPLOAD_LOG"
    UPLOAD_METHOD="notarytool"
    
    local upload_cmd="xcrun notarytool submit \"$ipa_path\""
    upload_cmd="$upload_cmd --key \"$api_key_path\""
    upload_cmd="$upload_cmd --key-id \"${APP_STORE_CONNECT_KEY_IDENTIFIER}\""
    upload_cmd="$upload_cmd --issuer \"${APP_STORE_CONNECT_ISSUER_ID}\""
    upload_cmd="$upload_cmd --wait"
    
    echo "   📋 Upload command: $upload_cmd" | tee -a "$UPLOAD_LOG"
    
    if eval "$upload_cmd"; then
        echo "   ✅ Upload via notarytool successful" | tee -a "$UPLOAD_LOG"
        return 0
    else
        local exit_code=$?
        echo "   ❌ Upload via notarytool failed (Exit Code: $exit_code)" | tee -a "$UPLOAD_LOG"
        return $exit_code
    fi
}

# Upload using Transporter (macOS App Store tool)
upload_with_transporter() {
    local ipa_path="$1"
    local api_key_path="$2"
    
    echo "📤 UPLOAD METHOD: Transporter" | tee -a "$UPLOAD_LOG"
    UPLOAD_METHOD="transporter"
    
    # Check if Transporter is available
    if ! command -v xcrun >/dev/null 2>&1; then
        echo "   ❌ xcrun not available - cannot use Transporter" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    local upload_cmd="xcrun iTMSTransporter -m upload"
    upload_cmd="$upload_cmd -f \"$ipa_path\""
    upload_cmd="$upload_cmd -k \"$api_key_path\""
    upload_cmd="$upload_cmd -i \"${APP_STORE_CONNECT_KEY_IDENTIFIER}\""
    upload_cmd="$upload_cmd -issuer \"${APP_STORE_CONNECT_ISSUER_ID}\""
    upload_cmd="$upload_cmd -v normal"
    
    echo "   📋 Upload command: $upload_cmd" | tee -a "$UPLOAD_LOG"
    
    if eval "$upload_cmd"; then
        echo "   ✅ Upload via Transporter successful" | tee -a "$UPLOAD_LOG"
        return 0
    else
        local exit_code=$?
        echo "   ❌ Upload via Transporter failed (Exit Code: $exit_code)" | tee -a "$UPLOAD_LOG"
        return $exit_code
    fi
}

# Attempt upload with multiple methods and retry logic
attempt_upload() {
    local ipa_path="$1"
    
    echo "🚀 STARTING IPA UPLOAD PROCESS" | tee -a "$UPLOAD_LOG"
    echo "   IPA: $ipa_path" | tee -a "$UPLOAD_LOG"
    echo "   Max Retries: $MAX_UPLOAD_RETRIES" | tee -a "$UPLOAD_LOG"
    
    # Validate IPA first
    if ! validate_ipa "$ipa_path"; then
        echo "❌ IPA validation failed - cannot proceed with upload" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    # Check App Store Connect configuration
    if [ -z "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ] || [ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]; then
        echo "❌ App Store Connect API configuration incomplete" | tee -a "$UPLOAD_LOG"
        echo "   Missing: Key ID or Issuer ID" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    # Download API key if it's a URL
    local api_key_path=""
    if [[ "${APP_STORE_CONNECT_API_KEY_PATH:-}" == http* ]]; then
        api_key_path=$(download_api_key "$APP_STORE_CONNECT_API_KEY_PATH")
        if [ $? -ne 0 ]; then
            echo "❌ Failed to download API key" | tee -a "$UPLOAD_LOG"
            return 1
        fi
    elif [ -f "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]; then
        api_key_path="$APP_STORE_CONNECT_API_KEY_PATH"
    else
        echo "❌ App Store Connect API key not found" | tee -a "$UPLOAD_LOG"
        echo "   Path: ${APP_STORE_CONNECT_API_KEY_PATH:-'Not Set'}" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    # Define upload methods in order of preference
    local upload_methods=(
        "upload_with_altool"
        "upload_with_transporter"
        "upload_with_notarytool"
    )
    
    # Try each upload method with retry logic
    for method in "${upload_methods[@]}"; do
        UPLOAD_RETRY_COUNT=0
        
        while [ $UPLOAD_RETRY_COUNT -le $MAX_UPLOAD_RETRIES ]; do
            if [ $UPLOAD_RETRY_COUNT -gt 0 ]; then
                echo "🔄 Retry attempt $UPLOAD_RETRY_COUNT/$MAX_UPLOAD_RETRIES for $method" | tee -a "$UPLOAD_LOG"
                sleep $((UPLOAD_RETRY_COUNT * 10))  # Progressive delay
            fi
            
            echo "📤 Attempting upload with $method..." | tee -a "$UPLOAD_LOG"
            
            if $method "$ipa_path" "$api_key_path"; then
                echo "✅ Upload successful with $method" | tee -a "$UPLOAD_LOG"
                UPLOAD_SUCCESS=true
                return 0
            else
                local exit_code=$?
                echo "❌ Upload failed with $method (Exit Code: $exit_code)" | tee -a "$UPLOAD_LOG"
                
                # Analyze error for retry decision
                case "$exit_code" in
                    1|65|70)
                        echo "   💡 Retryable error - will retry" | tee -a "$UPLOAD_LOG"
                        UPLOAD_RETRY_COUNT=$((UPLOAD_RETRY_COUNT + 1))
                        ;;
                    *)
                        echo "   💡 Non-retryable error - trying next method" | tee -a "$UPLOAD_LOG"
                        break
                        ;;
                esac
            fi
        done
        
        echo "❌ All retry attempts failed for $method" | tee -a "$UPLOAD_LOG"
    done
    
    echo "❌ All upload methods failed" | tee -a "$UPLOAD_LOG"
    return 1
}

# Find and upload best available IPA
find_and_upload_ipa() {
    echo "🔍 SEARCHING FOR IPA FILES" | tee -a "$UPLOAD_LOG"
    
    # Define search paths in order of preference
    local search_paths=(
        "output/ios/Runner.ipa"
        "output/ios/*.ipa"
        "build/ios/ipa/Runner.ipa"
        "build/ios/ipa/*.ipa"
        "ios/build/Runner.ipa"
        "ios/build/*.ipa"
        "*.ipa"
    )
    
    # Find best IPA file
    local best_ipa=""
    local best_size=0
    
    for search_path in "${search_paths[@]}"; do
        for ipa_file in $search_path; do
            if [ -f "$ipa_file" ]; then
                local file_size=$(du -b "$ipa_file" | cut -f1)
                echo "   📦 Found: $ipa_file ($(du -h "$ipa_file" | cut -f1))" | tee -a "$UPLOAD_LOG"
                
                # Choose largest IPA (likely most complete)
                if [ "$file_size" -gt "$best_size" ]; then
                    best_ipa="$ipa_file"
                    best_size="$file_size"
                fi
            fi
        done
    done
    
    if [ -z "$best_ipa" ]; then
        echo "❌ No IPA files found" | tee -a "$UPLOAD_LOG"
        return 1
    fi
    
    echo "🎯 Selected IPA: $best_ipa" | tee -a "$UPLOAD_LOG"
    
    # Attempt upload
    if attempt_upload "$best_ipa"; then
        echo "✅ IPA upload completed successfully" | tee -a "$UPLOAD_LOG"
        return 0
    else
        echo "❌ IPA upload failed" | tee -a "$UPLOAD_LOG"
        return 1
    fi
}

# Generate upload report
generate_upload_report() {
    local upload_success=$1
    
    echo "" | tee -a "$UPLOAD_LOG"
    echo "📊 UPLOAD SUMMARY REPORT" | tee -a "$UPLOAD_LOG"
    echo "========================" | tee -a "$UPLOAD_LOG"
    echo "Upload Date: $(date)" | tee -a "$UPLOAD_LOG"
    echo "Upload Status: $([ $upload_success -eq 0 ] && echo "SUCCESS" || echo "FAILED")" | tee -a "$UPLOAD_LOG"
    echo "IPA Validation: $([ "$IPA_VALIDATION_PASSED" = true ] && echo "PASSED" || echo "FAILED")" | tee -a "$UPLOAD_LOG"
    echo "Upload Method: ${UPLOAD_METHOD:-'None'}" | tee -a "$UPLOAD_LOG"
    echo "Total Retry Attempts: $UPLOAD_RETRY_COUNT" | tee -a "$UPLOAD_LOG"
    echo "" | tee -a "$UPLOAD_LOG"
    
    if [ $upload_success -eq 0 ]; then
        echo "✅ UPLOAD SUCCESSFUL" | tee -a "$UPLOAD_LOG"
        echo "📱 Your app is now available in App Store Connect" | tee -a "$UPLOAD_LOG"
        echo "🚀 Check App Store Connect for TestFlight processing" | tee -a "$UPLOAD_LOG"
    else
        echo "❌ UPLOAD FAILED" | tee -a "$UPLOAD_LOG"
        echo "📋 Recommended Actions:" | tee -a "$UPLOAD_LOG"
        echo "   1. Check App Store Connect API configuration" | tee -a "$UPLOAD_LOG"
        echo "   2. Verify certificates and provisioning profiles" | tee -a "$UPLOAD_LOG"
        echo "   3. Ensure IPA is properly signed for App Store distribution" | tee -a "$UPLOAD_LOG"
        echo "   4. Check App Store Connect account status" | tee -a "$UPLOAD_LOG"
    fi
}

# Main upload handler
case "${1:-}" in
    "--upload")
        initialize_upload_logging
        if find_and_upload_ipa; then
            generate_upload_report 0
            exit 0
        else
            generate_upload_report 1
            exit 1
        fi
        ;;
    "--validate")
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 --validate <ipa_path>"
            exit 1
        fi
        initialize_upload_logging
        validate_ipa "$2"
        ;;
    "--report")
        generate_upload_report "${2:-1}"
        ;;
    *)
        echo "📤 Enhanced IPA Upload Handler"
        echo "Usage: $0 --upload                (find and upload best IPA)"
        echo "       $0 --validate <ipa_path>   (validate specific IPA)"
        echo "       $0 --report [exit_code]    (generate upload report)"
        ;;
esac 