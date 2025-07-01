#!/bin/bash

# 🛡️ Enhanced iOS Build Error Handler
# 🎯 Comprehensive error handling with retry logic and recovery mechanisms
# 🔧 Handles build failures, IPA export issues, and upload problems

set -euo pipefail

# Global error tracking
ERROR_LOG="build_errors.log"
RETRY_COUNT=0
MAX_RETRIES=3
BUILD_PHASE=""
LAST_COMMAND=""
EXIT_CODE=0

# Initialize error logging
initialize_error_logging() {
    echo "🛡️ Enhanced iOS Build Error Handler - $(date)" > "$ERROR_LOG"
    echo "📊 Build Environment:" >> "$ERROR_LOG"
    echo "   - Xcode: $(xcodebuild -version | head -1)" >> "$ERROR_LOG"
    echo "   - Flutter: $(flutter --version | head -1)" >> "$ERROR_LOG"
    echo "   - CocoaPods: $(pod --version)" >> "$ERROR_LOG"
    echo "   - Bundle ID: ${BUNDLE_ID:-'Not Set'}" >> "$ERROR_LOG"
    echo "   - Profile Type: ${PROFILE_TYPE:-'Not Set'}" >> "$ERROR_LOG"
    echo "" >> "$ERROR_LOG"
}

# Enhanced trap function for error handling
error_trap() {
    local exit_code=$?
    local line_no=$1
    local command="$2"
    
    echo "❌ ERROR DETECTED in $BUILD_PHASE" | tee -a "$ERROR_LOG"
    echo "   Line: $line_no" | tee -a "$ERROR_LOG"
    echo "   Command: $command" | tee -a "$ERROR_LOG"
    echo "   Exit Code: $exit_code" | tee -a "$ERROR_LOG"
    echo "   Time: $(date)" | tee -a "$ERROR_LOG"
    echo "" | tee -a "$ERROR_LOG"
    
    # Analyze error and suggest solutions
    analyze_error "$exit_code" "$command" "$line_no"
    
    # Attempt recovery if possible
    attempt_recovery "$exit_code" "$command"
    
    EXIT_CODE=$exit_code
}

# Analyze specific errors and provide solutions
analyze_error() {
    local exit_code=$1
    local command="$2"
    local line_no=$3
    
    echo "🔍 ERROR ANALYSIS:" | tee -a "$ERROR_LOG"
    
    case "$command" in
        *"flutter build"* | *"xcodebuild"*)
            analyze_build_error "$exit_code" "$command"
            ;;
        *"pod install"* | *"pod update"*)
            analyze_pod_error "$exit_code" "$command"
            ;;
        *"code-sign"* | *"codesign"*)
            analyze_signing_error "$exit_code" "$command"
            ;;
        *"export"* | *".ipa"*)
            analyze_export_error "$exit_code" "$command"
            ;;
        *)
            echo "   - Generic error detected" | tee -a "$ERROR_LOG"
            ;;
    esac
}

# Analyze build-specific errors
analyze_build_error() {
    local exit_code=$1
    local command="$2"
    
    echo "   🏗️ Build Error Analysis:" | tee -a "$ERROR_LOG"
    
    case "$exit_code" in
        65)
            echo "   - Exit Code 65: Build dependency or configuration error" | tee -a "$ERROR_LOG"
            echo "   - Likely cause: Missing dependencies, configuration issues" | tee -a "$ERROR_LOG"
            echo "   - Recovery: Clean build, regenerate pods, check configuration" | tee -a "$ERROR_LOG"
            ;;
        70)
            echo "   - Exit Code 70: Code signing error" | tee -a "$ERROR_LOG"
            echo "   - Likely cause: Invalid certificates, provisioning profiles" | tee -a "$ERROR_LOG"
            echo "   - Recovery: Validate signing configuration, regenerate profiles" | tee -a "$ERROR_LOG"
            ;;
        72)
            echo "   - Exit Code 72: Archive creation failed" | tee -a "$ERROR_LOG"
            echo "   - Likely cause: Build configuration issues, missing files" | tee -a "$ERROR_LOG"
            echo "   - Recovery: Clean build, check project configuration" | tee -a "$ERROR_LOG"
            ;;
        *)
            echo "   - Exit Code $exit_code: General build failure" | tee -a "$ERROR_LOG"
            echo "   - Check build logs for specific error details" | tee -a "$ERROR_LOG"
            ;;
    esac
}

# Analyze pod-specific errors
analyze_pod_error() {
    local exit_code=$1
    local command="$2"
    
    echo "   📦 Pod Error Analysis:" | tee -a "$ERROR_LOG"
    
    case "$exit_code" in
        1)
            echo "   - Pod installation failed" | tee -a "$ERROR_LOG"
            echo "   - Likely cause: Dependency conflicts, network issues" | tee -a "$ERROR_LOG"
            echo "   - Recovery: Clean pod cache, update repositories" | tee -a "$ERROR_LOG"
            ;;
        *)
            echo "   - Generic pod error" | tee -a "$ERROR_LOG"
            ;;
    esac
}

# Analyze signing-specific errors
analyze_signing_error() {
    local exit_code=$1
    local command="$2"
    
    echo "   🔐 Code Signing Error Analysis:" | tee -a "$ERROR_LOG"
    echo "   - Code signing configuration error" | tee -a "$ERROR_LOG"
    echo "   - Check certificates, provisioning profiles, and bundle IDs" | tee -a "$ERROR_LOG"
}

# Analyze export-specific errors
analyze_export_error() {
    local exit_code=$1
    local command="$2"
    
    echo "   📦 Export Error Analysis:" | tee -a "$ERROR_LOG"
    echo "   - IPA export or upload error" | tee -a "$ERROR_LOG"
    echo "   - Check export options, App Store Connect configuration" | tee -a "$ERROR_LOG"
}

# Attempt automatic recovery
attempt_recovery() {
    local exit_code=$1
    local command="$2"
    
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "🔄 ATTEMPTING RECOVERY (Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES):" | tee -a "$ERROR_LOG"
        
        case "$command" in
            *"pod install"*)
                recovery_pod_install
                ;;
            *"flutter build"*)
                recovery_flutter_build
                ;;
            *"xcodebuild"*)
                recovery_xcodebuild
                ;;
            *)
                echo "   - No specific recovery available for this command" | tee -a "$ERROR_LOG"
                return 1
                ;;
        esac
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        return 0
    else
        echo "❌ Maximum retry attempts reached ($MAX_RETRIES)" | tee -a "$ERROR_LOG"
        return 1
    fi
}

# Recovery for pod install failures
recovery_pod_install() {
    echo "   📦 Pod Install Recovery:" | tee -a "$ERROR_LOG"
    
    # Clean pod cache and dependencies
    echo "   - Cleaning pod cache..." | tee -a "$ERROR_LOG"
    rm -rf ios/Pods ios/Podfile.lock ios/.symlinks ~/.cocoapods/repos/master 2>/dev/null || true
    
    # Update pod repository
    echo "   - Updating pod repositories..." | tee -a "$ERROR_LOG"
    pod repo update --silent 2>/dev/null || true
    
    # Reinstall pods
    echo "   - Reinstalling pods..." | tee -a "$ERROR_LOG"
    cd ios && pod install --repo-update && cd ..
}

# Recovery for Flutter build failures
recovery_flutter_build() {
    echo "   🚀 Flutter Build Recovery:" | tee -a "$ERROR_LOG"
    
    # Clean Flutter build
    echo "   - Cleaning Flutter build..." | tee -a "$ERROR_LOG"
    flutter clean
    
    # Regenerate dependencies
    echo "   - Regenerating dependencies..." | tee -a "$ERROR_LOG"
    flutter pub get
    
    # Clean iOS build
    echo "   - Cleaning iOS build..." | tee -a "$ERROR_LOG"
    rm -rf ios/build ios/Runner.xcworkspace/xcuserdata 2>/dev/null || true
}

# Recovery for Xcode build failures
recovery_xcodebuild() {
    echo "   🔨 Xcode Build Recovery:" | tee -a "$ERROR_LOG"
    
    # Clean derived data
    echo "   - Cleaning derived data..." | tee -a "$ERROR_LOG"
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
    
    # Reset iOS build
    echo "   - Resetting iOS build..." | tee -a "$ERROR_LOG"
    rm -rf ios/build 2>/dev/null || true
}

# Execute command with error handling and retry logic
execute_with_retry() {
    local command="$1"
    local phase="$2"
    
    BUILD_PHASE="$phase"
    RETRY_COUNT=0
    
    echo "🔄 Executing: $phase" | tee -a "$ERROR_LOG"
    echo "   Command: $command" | tee -a "$ERROR_LOG"
    
    while [ $RETRY_COUNT -le $MAX_RETRIES ]; do
        if [ $RETRY_COUNT -gt 0 ]; then
            echo "🔄 Retry attempt $RETRY_COUNT/$MAX_RETRIES for: $phase" | tee -a "$ERROR_LOG"
        fi
        
        # Set trap for this specific command
        trap 'error_trap $LINENO "$command"' ERR
        
        # Execute the command
        if eval "$command"; then
            echo "✅ Success: $phase" | tee -a "$ERROR_LOG"
            trap - ERR
            return 0
        else
            local exit_code=$?
            echo "❌ Failed: $phase (Exit Code: $exit_code)" | tee -a "$ERROR_LOG"
            
            # Attempt recovery if retries are available
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                if attempt_recovery "$exit_code" "$command"; then
                    RETRY_COUNT=$((RETRY_COUNT + 1))
                    sleep 5  # Brief pause before retry
                    continue
                fi
            fi
            
            # If we reach here, all retries failed
            echo "❌ All retry attempts failed for: $phase" | tee -a "$ERROR_LOG"
            trap - ERR
            return $exit_code
        fi
    done
}

# Validate build environment
validate_environment() {
    echo "🔍 ENVIRONMENT VALIDATION:" | tee -a "$ERROR_LOG"
    
    local validation_errors=0
    
    # Check required tools
    if ! command -v flutter >/dev/null 2>&1; then
        echo "❌ Flutter not found" | tee -a "$ERROR_LOG"
        validation_errors=$((validation_errors + 1))
    else
        echo "✅ Flutter: $(flutter --version | head -1)" | tee -a "$ERROR_LOG"
    fi
    
    if ! command -v xcodebuild >/dev/null 2>&1; then
        echo "❌ Xcode not found" | tee -a "$ERROR_LOG"
        validation_errors=$((validation_errors + 1))
    else
        echo "✅ Xcode: $(xcodebuild -version | head -1)" | tee -a "$ERROR_LOG"
    fi
    
    if ! command -v pod >/dev/null 2>&1; then
        echo "❌ CocoaPods not found" | tee -a "$ERROR_LOG"
        validation_errors=$((validation_errors + 1))
    else
        echo "✅ CocoaPods: $(pod --version)" | tee -a "$ERROR_LOG"
    fi
    
    # Check required environment variables
    if [ -z "${BUNDLE_ID:-}" ]; then
        echo "⚠️ BUNDLE_ID not set" | tee -a "$ERROR_LOG"
        validation_errors=$((validation_errors + 1))
    else
        echo "✅ Bundle ID: $BUNDLE_ID" | tee -a "$ERROR_LOG"
    fi
    
    if [ -z "${PROFILE_TYPE:-}" ]; then
        echo "⚠️ PROFILE_TYPE not set" | tee -a "$ERROR_LOG"
        validation_errors=$((validation_errors + 1))
    else
        echo "✅ Profile Type: $PROFILE_TYPE" | tee -a "$ERROR_LOG"
    fi
    
    if [ $validation_errors -gt 0 ]; then
        echo "❌ Environment validation failed with $validation_errors errors" | tee -a "$ERROR_LOG"
        return 1
    else
        echo "✅ Environment validation successful" | tee -a "$ERROR_LOG"
        return 0
    fi
}

# Generate comprehensive error report
generate_error_report() {
    local build_success=$1
    
    echo "" | tee -a "$ERROR_LOG"
    echo "📊 BUILD SUMMARY REPORT" | tee -a "$ERROR_LOG"
    echo "======================" | tee -a "$ERROR_LOG"
    echo "Build Date: $(date)" | tee -a "$ERROR_LOG"
    echo "Build Status: $([ $build_success -eq 0 ] && echo "SUCCESS" || echo "FAILED")" | tee -a "$ERROR_LOG"
    echo "Total Retry Attempts: $RETRY_COUNT" | tee -a "$ERROR_LOG"
    echo "Last Build Phase: $BUILD_PHASE" | tee -a "$ERROR_LOG"
    echo "Final Exit Code: $EXIT_CODE" | tee -a "$ERROR_LOG"
    echo "" | tee -a "$ERROR_LOG"
    
    if [ $build_success -ne 0 ]; then
        echo "❌ BUILD FAILED - Check the detailed error log above" | tee -a "$ERROR_LOG"
        echo "📋 Recommended Actions:" | tee -a "$ERROR_LOG"
        echo "   1. Review error analysis above" | tee -a "$ERROR_LOG"
        echo "   2. Check environment configuration" | tee -a "$ERROR_LOG"
        echo "   3. Verify certificates and provisioning profiles" | tee -a "$ERROR_LOG"
        echo "   4. Consider manual intervention for persistent issues" | tee -a "$ERROR_LOG"
    else
        echo "✅ BUILD SUCCESSFUL" | tee -a "$ERROR_LOG"
    fi
    
    echo "" | tee -a "$ERROR_LOG"
    echo "📁 Build Artifacts:" | tee -a "$ERROR_LOG"
    
    # List available artifacts
    if [ -d "output/ios" ]; then
        find output/ios -name "*.ipa" -o -name "*.xcarchive" | while read -r file; do
            if [ -f "$file" ]; then
                local size=$(du -h "$file" | cut -f1)
                echo "   📦 $(basename "$file"): $size" | tee -a "$ERROR_LOG"
            fi
        done
    fi
    
    if [ -d "build/ios/ipa" ]; then
        find build/ios/ipa -name "*.ipa" | while read -r file; do
            if [ -f "$file" ]; then
                local size=$(du -h "$file" | cut -f1)
                echo "   📦 $(basename "$file"): $size" | tee -a "$ERROR_LOG"
            fi
        done
    fi
}

# Main error handler initialization
if [ "${1:-}" = "--init" ]; then
    initialize_error_logging
    validate_environment
    echo "🛡️ Enhanced Error Handler initialized successfully"
elif [ "${1:-}" = "--report" ]; then
    generate_error_report "${2:-1}"
else
    echo "🛡️ Enhanced iOS Build Error Handler"
    echo "Usage: $0 --init  (initialize error handling)"
    echo "       $0 --report [exit_code]  (generate final report)"
    echo ""
    echo "Functions available for use in scripts:"
    echo "  - execute_with_retry 'command' 'phase_name'"
    echo "  - validate_environment"
    echo "  - generate_error_report exit_code"
fi 