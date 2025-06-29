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
    
    # Stage 2: Email Notification - Build Started
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ]; then
        log_info "--- Stage 2: Sending Build Started Email ---"
        "${SCRIPT_DIR}/email_notifications.sh" "build_started" "iOS" "${CM_BUILD_ID:-unknown}" || log_warn "Failed to send build started email."
    fi
    
    # Stage 3: Handle Certificates and Provisioning Profiles
    log_info "--- Stage 3: Handling Certificates and Provisioning Profiles ---"
    if ! "${SCRIPT_DIR}/handle_certificates.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Certificate and profile handling failed."
        return 1
    fi
    
    # Stage 4: Branding Assets Setup
    log_info "--- Stage 4: Setting up Branding Assets ---"
    if ! "${SCRIPT_DIR}/branding_assets.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Branding assets setup failed."
        return 1
    fi
    
    # Stage 4.5: Generate Flutter Launcher Icons (iOS-specific)
    log_info "--- Stage 4.5: Generating Flutter Launcher Icons ---"
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
    else
        log_info "--- Stage 6.7: Firebase Setup Skipped (Push notifications disabled) ---"
    fi
    
    # Stage 7: Flutter Build Process (with emergency Firebase fallback)
    log_info "--- Stage 7: Building Flutter iOS App ---"
    if ! "${SCRIPT_DIR}/build_flutter_app.sh"; then
        log_warn "⚠️ Primary build failed, attempting emergency Firebase removal..."
        
        # Make emergency script executable
        chmod +x "${SCRIPT_DIR}/emergency_firebase_removal.sh"
        
        # Try emergency Firebase removal
        if "${SCRIPT_DIR}/emergency_firebase_removal.sh"; then
            log_success "✅ Emergency Firebase removal completed successfully"
            log_warn "⚠️ Note: Firebase features (push notifications) are disabled in this build"
            
            # Skip Stage 8 since emergency script handles IPA export
            log_info "--- Stage 8: Skipped (Emergency script handled IPA export) ---"
            
            # Stage 9: Email Notification - Build Success
            if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ]; then
                log_info "--- Stage 9: Sending Build Success Email ---"
                "${SCRIPT_DIR}/email_notifications.sh" "build_success" "iOS" "${CM_BUILD_ID:-unknown}" || log_warn "Failed to send build success email."
            fi
            
            log_success "iOS workflow completed successfully with emergency Firebase removal!"
            log_info "Build Summary:"
            log_info "   App: ${APP_NAME:-Unknown} v${VERSION_NAME:-Unknown}"
            log_info "   Bundle ID: ${BUNDLE_ID:-Unknown}"
            log_info "   Profile Type: ${PROFILE_TYPE:-Unknown}"
            log_info "   Output: ${OUTPUT_DIR:-Unknown}"
            log_warn "   Firebase: DISABLED (emergency removal applied)"
            
            return 0
        else
            send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Both primary build and emergency Firebase removal failed."
            return 1
        fi
    fi
    
    # Stage 8: IPA Export (only if primary build succeeded)
    log_info "--- Stage 8: Exporting IPA ---"
    if ! "${SCRIPT_DIR}/export_ipa.sh"; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "IPA export failed."
        return 1
    fi
    
    # Stage 9: Email Notification - Build Success
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ]; then
        log_info "--- Stage 9: Sending Build Success Email ---"
        "${SCRIPT_DIR}/email_notifications.sh" "build_success" "iOS" "${CM_BUILD_ID:-unknown}" || log_warn "Failed to send build success email."
    fi
    
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
