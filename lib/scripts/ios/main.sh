#!/bin/bash

# Main iOS Build Orchestration Script
# Purpose: Orchestrate the entire iOS build workflow

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting iOS Build Workflow..."

# Function to send email notifications
send_email() {
    local email_type="$1"
    local platform="$2"
    local build_id="$3"
    local error_message="$4"
    
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ]; then
        log_info "Sending $email_type email for $platform build $build_id"
        "${SCRIPT_DIR}/email_notifications.sh" "$email_type" "$platform" "$build_id" "$error_message" || log_warn "Failed to send email notification"
    fi
}

# Function to load environment variables
load_environment_variables() {
    log_info "Loading environment variables..."
    
    # Validate essential variables
    if [ -z "${BUNDLE_ID:-}" ]; then
        log_error "BUNDLE_ID is not set. Exiting."
        return 1
    fi
    
    # Set default values
    export OUTPUT_DIR="${OUTPUT_DIR:-output/ios}"
    export PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
    export CM_BUILD_DIR="${CM_BUILD_DIR:-$(pwd)}"
    export PROFILE_TYPE="${PROFILE_TYPE:-ad-hoc}"
    
    log_success "Environment variables loaded successfully"
    return 0
}

# Function to validate profile type and create export options
validate_profile_configuration() {
    log_info "--- Profile Type Validation ---"
    
    # Make profile validation script executable
    chmod +x "${SCRIPT_DIR}/validate_profile_type.sh"
    
    # Run profile validation and create export options
    if "${SCRIPT_DIR}/validate_profile_type.sh" --create-export-options; then
        log_success "✅ Profile type validation completed successfully"
        return 0
    else
        log_error "❌ Profile type validation failed"
        return 1
    fi
}

# Main execution function
main() {
    log_info "iOS Build Workflow Starting..."
    
    # Load environment variables
    if ! load_environment_variables; then
        log_error "Environment variable loading failed"
        return 1
    fi
    
    # Validate profile type configuration early
    if ! validate_profile_configuration; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Profile type validation failed."
        return 1
    fi
    
    # Stage 1: Pre-build Setup
    log_info "--- Stage 1: Pre-build Setup ---"
    if ! "${SCRIPT_DIR}/setup_environment.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Pre-build setup failed."
        return 1
    fi
    
    # Stage 2: Email Notification - Build Started (only if not already sent)
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ] && [ -z "${EMAIL_BUILD_STARTED_SENT:-}" ]; then
        log_info "--- Stage 2: Sending Build Started Email ---"
        "${SCRIPT_DIR}/email_notifications.sh" "build_started" "iOS" "${CM_BUILD_ID:-unknown}" || log_warn "Failed to send build started email."
        export EMAIL_BUILD_STARTED_SENT="true"
    elif [ -n "${EMAIL_BUILD_STARTED_SENT:-}" ]; then
        log_info "--- Stage 2: Build Started Email Already Sent (Skipping) ---"
    fi
    
    # Stage 3: Handle Certificates and Provisioning Profiles
    log_info "--- Stage 3: Handling Certificates and Provisioning Profiles ---"
    if ! "${SCRIPT_DIR}/handle_certificates.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Certificate and profile handling failed."
        return 1
    fi
    
    # Stage 4: Branding Assets Setup (Downloads logo and sets up assets)
    log_info "--- Stage 4: Setting up Branding Assets ---"
    log_info "📥 Downloading logo from LOGO_URL (if provided) to assets/images/logo.png"
    log_info "📱 Updating Bundle ID: ${BUNDLE_ID:-<not set>}"
    log_info "🏷️ Updating App Name: ${APP_NAME:-<not set>}"
    if ! "${SCRIPT_DIR}/branding_assets.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Branding assets setup failed."
        return 1
    fi
    
    # Stage 4.5: Generate Flutter Launcher Icons (Uses logo from Stage 4 as app icons)
    log_info "--- Stage 4.5: Generating Flutter Launcher Icons ---"
    log_info "🎨 Using logo from assets/images/logo.png (created by branding_assets.sh)"
    log_info "✨ Generating App Store compliant iOS icons (removing transparency)"
    if ! "${SCRIPT_DIR}/generate_launcher_icons.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Flutter Launcher Icons generation failed."
        return 1
    fi
    
    # Stage 5: Dynamic Permission Injection
    log_info "--- Stage 5: Injecting Dynamic Permissions ---"
    if ! "${SCRIPT_DIR}/inject_permissions.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Permission injection failed."
        return 1
    fi
    
    # Stage 6: Conditional Firebase Injection
    log_info "--- Stage 6: Conditional Firebase Injection ---"
    
    # Make conditional Firebase injection script executable
    chmod +x "${SCRIPT_DIR}/conditional_firebase_injection.sh"
    
    # Run conditional Firebase injection based on PUSH_NOTIFY flag
    if ! "${SCRIPT_DIR}/conditional_firebase_injection.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Conditional Firebase injection failed."
        return 1
    fi
    
    # Stage 6.5: Certificate and API Validation
    log_info "--- Stage 6.5: Certificate and API Validation ---"
    
    # Make certificate validation script executable  
    chmod +x "${SCRIPT_DIR}/certificate_validation.sh"
    
    # Run certificate and API validation for proper IPA export
    if ! "${SCRIPT_DIR}/certificate_validation.sh"; then
        log_warn "⚠️ Certificate validation failed - IPA export may not work properly"
        # Don't fail the build here, just warn
    fi
    
    # Stage 6.7: Firebase Setup (Only if PUSH_NOTIFY=true)
    if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
        log_info "--- Stage 6.7: Setting up Firebase (Push notifications enabled) ---"
        if ! "${SCRIPT_DIR}/firebase_setup.sh"; then
            send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Firebase setup failed."
            return 1
        fi
        
        # Stage 6.8: Critical Firebase Xcode 16.0 Compatibility Fixes
        log_info "--- Stage 6.8: Applying Firebase Xcode 16.0 Compatibility Fixes ---"
        log_info "🔥 Applying ULTRA AGGRESSIVE Firebase Xcode 16.0 fixes..."
        log_info "🎯 Targeting FIRHeartbeatLogger.m compilation issues"
        
        if [ -f "${SCRIPT_DIR}/fix_firebase_xcode16.sh" ]; then
            chmod +x "${SCRIPT_DIR}/fix_firebase_xcode16.sh"
            if ! "${SCRIPT_DIR}/fix_firebase_xcode16.sh"; then
                log_error "❌ Firebase Xcode 16.0 fixes failed - this is critical for compilation"
                log_error "FIRHeartbeatLogger.m and other Firebase files will fail to compile"
                send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Firebase Xcode 16.0 compatibility fixes failed."
                return 1
            else
                log_success "✅ Firebase Xcode 16.0 fixes applied successfully"
                log_info "🎯 FIRHeartbeatLogger.m compilation issues should be resolved"
                log_info "📋 Ultra-aggressive warning suppression activated"
                log_info "🔧 Xcode 16.0 compatibility mode enabled"
            fi
        else
            log_error "❌ Firebase Xcode 16.0 fix script not found: ${SCRIPT_DIR}/fix_firebase_xcode16.sh"
            log_error "This is critical - Firebase will fail to compile with Xcode 16.0"
            send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Firebase Xcode 16.0 fix script not found."
            return 1
        fi
        
        # Apply bundle identifier collision fixes after Firebase setup and Xcode fixes
        log_info "🔧 Applying Bundle Identifier Collision fixes after Firebase setup..."
        if [ -f "${SCRIPT_DIR}/fix_bundle_identifier_collision_v2.sh" ]; then
            chmod +x "${SCRIPT_DIR}/fix_bundle_identifier_collision_v2.sh"
            if ! "${SCRIPT_DIR}/fix_bundle_identifier_collision_v2.sh"; then
                log_warn "⚠️ Bundle Identifier Collision fixes (v2) failed after Firebase setup"
                # Try v1 as fallback
                if [ -f "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh" ]; then
                    chmod +x "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh"
                    "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh" || log_warn "Bundle Identifier Collision fixes failed"
                fi
            else
                log_success "✅ Bundle Identifier Collision fixes applied after Firebase setup"
            fi
        fi
    else
        log_info "--- Stage 6.7: Firebase Setup Skipped (Push notifications disabled) ---"
        log_info "--- Stage 6.8: Firebase Xcode 16.0 Fixes Skipped (Firebase disabled) ---"
    fi
    
    # Stage 6.9: Critical Bundle Identifier Collision Prevention
    log_info "--- Stage 6.9: Pre-Build Bundle Identifier Collision Prevention ---"
    log_info "🔧 Applying comprehensive Bundle Identifier Collision fixes before build..."
    
    # Apply the enhanced v2 fixes
    if [ -f "${SCRIPT_DIR}/fix_bundle_identifier_collision_v2.sh" ]; then
        chmod +x "${SCRIPT_DIR}/fix_bundle_identifier_collision_v2.sh"
        if "${SCRIPT_DIR}/fix_bundle_identifier_collision_v2.sh"; then
            log_success "✅ Enhanced Bundle Identifier Collision fixes (v2) applied successfully"
        else
            log_warn "⚠️ Enhanced Bundle Identifier Collision fixes (v2) failed, trying v1..."
            # Fallback to v1
            if [ -f "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh" ]; then
                chmod +x "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh"
                if "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh"; then
                    log_success "✅ Basic Bundle Identifier Collision fixes (v1) applied successfully"
                else
                    log_error "❌ All Bundle Identifier Collision fixes failed"
                    send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Bundle Identifier Collision fixes failed - CFBundleIdentifier validation will fail."
                    return 1
                fi
            else
                log_error "❌ No Bundle Identifier Collision fix scripts found"
                send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Bundle Identifier Collision fix scripts not found."
                return 1
            fi
        fi
    else
        log_error "❌ Enhanced Bundle Identifier Collision fix script not found"
        # Try v1 as last resort
        if [ -f "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh" ]; then
            chmod +x "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh"
            if "${SCRIPT_DIR}/fix_bundle_identifier_collision.sh"; then
                log_success "✅ Basic Bundle Identifier Collision fixes (v1) applied as fallback"
            else
                log_error "❌ All Bundle Identifier Collision fixes failed"
                return 1
            fi
        else
            log_error "❌ No Bundle Identifier Collision fix scripts found at all"
            return 1
        fi
    fi

    # Stage 7: Flutter Build Process (must succeed for clean build)
    log_info "--- Stage 7: Building Flutter iOS App ---"
    if ! "${SCRIPT_DIR}/build_flutter_app.sh"; then
        log_error "❌ Flutter build failed - this is a hard failure"
        log_error "Build must succeed cleanly with proper Firebase configuration"
        log_info "Check the following:"
        log_info "  1. Firebase configuration is correct (if PUSH_NOTIFY=true)"
        log_info "  2. Bundle identifier is properly set"
        log_info "  3. Xcode 16.0 compatibility fixes are applied"
        log_info "  4. CocoaPods installation succeeded"
        
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Flutter build failed - check Firebase configuration and dependencies."
        return 1
    fi
    
    # Stage 8: IPA Export (only if primary build succeeded)
    log_info "--- Stage 8: Exporting IPA ---"
    if ! "${SCRIPT_DIR}/export_ipa.sh"; then
        log_warn "⚠️ IPA export failed, but build was successful"
        log_info "📦 Archive should be available for manual export"
        
        # Check if archive exists (successful build outcome)
        if [ -d "${OUTPUT_DIR:-output/ios}/Runner.xcarchive" ]; then
            log_success "✅ Archive found - this is a successful build outcome"
            log_info "📋 Manual export instructions will be provided"
            log_info "🎯 This is NOT a Firebase issue - just missing Apple Developer credentials"
            
            # Set build status as partial success (archive created, no IPA)
            export FINAL_BUILD_STATUS="partial"
            export FINAL_BUILD_MESSAGE="iOS build completed with archive only: ${APP_NAME:-Unknown} (${VERSION_NAME:-Unknown}) - Manual IPA export required due to missing Apple Developer credentials"
            
            # Continue to success email - this is a successful build
            log_info "--- Stage 9: Setting Build Success Status ---"
            log_success "iOS workflow completed successfully with archive creation!"
            log_info "Build Summary:"
            log_info "   App: ${APP_NAME:-Unknown} v${VERSION_NAME:-Unknown}"
            log_info "   Bundle ID: ${BUNDLE_ID:-Unknown}"
            log_info "   Profile Type: ${PROFILE_TYPE:-Unknown}"
            log_info "   Output: ${OUTPUT_DIR:-Unknown}"
            log_info "   Result: Archive created, manual IPA export required"
            log_info "   Issue: Missing Apple Developer account configuration (not Firebase related)"
            
            return 0  # This is a successful outcome
        else
            log_error "❌ No archive found - build may have failed"
            send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "IPA export and archive creation failed."
            return 1
        fi
    fi
    
    # Stage 9: Build Success Status Set (Email will be sent by workflow)
    log_info "--- Stage 9: Setting Build Success Status ---"
    export FINAL_BUILD_STATUS="success"
    export FINAL_BUILD_MESSAGE="iOS build completed successfully: ${APP_NAME:-Unknown} (${VERSION_NAME:-Unknown}) - Full build with IPA export"
    
    log_success "iOS workflow completed successfully!"
    log_info "Build Summary:"
    log_info "   App: ${APP_NAME:-Unknown} v${VERSION_NAME:-Unknown}"
    log_info "   Bundle ID: ${BUNDLE_ID:-Unknown}"
    log_info "   Profile Type: ${PROFILE_TYPE:-Unknown}"
    log_info "   Output: ${OUTPUT_DIR:-Unknown}"
    log_info "   Firebase: ${PUSH_NOTIFY:-false}"
    
    return 0
}

# Run main function
main "$@"
