#!/bin/bash

# iOS Workflow 3 - Simplified and Robust Build Script
# Purpose: Handle iOS builds with proper certificate management and error handling

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to send email notifications
send_email() {
    local email_type="$1"
    local platform="$2"
    local build_id="$3"
    local error_message="$4"
    
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ] && [ -f "lib/scripts/utils/send_email.py" ]; then
        log_info "Sending $email_type email for $platform build $build_id"
        python3 lib/scripts/utils/send_email.py "$email_type" "$platform" "$build_id" "$error_message" || log_warn "Failed to send email notification"
    fi
}

# Function to validate environment variables
validate_environment() {
    log_info "Validating environment variables..."
    
    # Check essential variables
    if [ -z "${BUNDLE_ID:-}" ]; then
        log_error "BUNDLE_ID is not set"
        return 1
    fi
    
    if [ -z "${PROFILE_TYPE:-}" ]; then
        log_warn "PROFILE_TYPE not set, defaulting to app-store"
        export PROFILE_TYPE="app-store"
    fi
    
    if [ -z "${APP_NAME:-}" ]; then
        log_error "APP_NAME is not set"
        return 1
    fi
    
    # Check certificate configuration - make it optional
    local cert_config_found=false
    
    if [ -n "${CERT_P12_URL:-}" ] && [ "$CERT_P12_URL" != "\$CERT_P12_URL" ]; then
        log_info "P12 certificate configuration found"
        cert_config_found=true
    fi
    
    if [ -n "${CERT_CER_URL:-}" ] && [ "$CERT_CER_URL" != "\$CERT_CER_URL" ] && [ -n "${CERT_KEY_URL:-}" ] && [ "$CERT_KEY_URL" != "\$CERT_KEY_URL" ]; then
        log_info "CER + KEY certificate configuration found"
        cert_config_found=true
    fi
    
    if [ "$cert_config_found" = false ]; then
        log_warn "⚠️ No certificate configuration found - will attempt unsigned build"
        log_info "💡 To enable code signing, set either:"
        log_info "   - CERT_P12_URL + CERT_PASSWORD, or"
        log_info "   - CERT_CER_URL + CERT_KEY_URL + CERT_PASSWORD"
        export SKIP_CODE_SIGNING="true"
    else
        export SKIP_CODE_SIGNING="false"
    fi
    
    log_success "Environment validation passed"
    return 0
}

# Function to setup certificate and provisioning profile
setup_certificates() {
    log_info "Setting up certificates and provisioning profiles..."
    
    # Check if we should skip code signing
    if [ "${SKIP_CODE_SIGNING:-false}" = "true" ]; then
        log_warn "⚠️ Skipping certificate setup - will attempt unsigned build"
        log_info "💡 Note: Unsigned builds may not work for App Store distribution"
        return 0
    fi
    
    # Create certificates directory
    mkdir -p ios/certificates
    
    # Setup keychain
    local keychain_name="ios-build.keychain"
    local keychain_password="${KEYCHAIN_PASSWORD:-build123}"
    
    # Delete existing keychain if it exists
    security delete-keychain "$keychain_name" 2>/dev/null || true
    
    # Create new keychain
    if ! security create-keychain -p "$keychain_password" "$keychain_name"; then
        log_error "Failed to create keychain"
        return 1
    fi
    
    # Configure keychain settings
    security set-keychain-settings -lut 21600 "$keychain_name"
    security unlock-keychain -p "$keychain_password" "$keychain_name"
    security list-keychains -s "$keychain_name"
    security default-keychain -s "$keychain_name"
    
    log_success "Keychain setup completed"
    
    # Handle P12 certificate
    if [ -n "${CERT_P12_URL:-}" ] && [ "$CERT_P12_URL" != "\$CERT_P12_URL" ]; then
        log_info "Processing P12 certificate from: $CERT_P12_URL"
        
        # Validate URL format
        if [[ ! "$CERT_P12_URL" =~ ^https?:// ]]; then
            log_error "Invalid P12 URL format: $CERT_P12_URL"
            return 1
        fi
        
        # Download P12 file
        local p12_file="ios/certificates/certificate.p12"
        if ! curl -L -f -s -o "$p12_file" "$CERT_P12_URL"; then
            log_error "Failed to download P12 certificate"
            return 1
        fi
        
        # Check if file was downloaded successfully
        if [ ! -f "$p12_file" ] || [ ! -s "$p12_file" ]; then
            log_error "P12 file is empty or not downloaded"
            return 1
        fi
        
        # Install P12 certificate
        local password="${CERT_PASSWORD:-Password@1234}"
        if ! security import "$p12_file" -k "$keychain_name" -P "$password" -T /usr/bin/codesign; then
            log_error "Failed to import P12 certificate"
            return 1
        fi
        
        # Set key partition list
        security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_name" || true
        
        log_success "P12 certificate installed successfully"
        
    # Handle CER + KEY certificate
    elif [ -n "${CERT_CER_URL:-}" ] && [ "$CERT_CER_URL" != "\$CERT_CER_URL" ] && [ -n "${CERT_KEY_URL:-}" ] && [ "$CERT_KEY_URL" != "\$CERT_KEY_URL" ]; then
        log_info "Processing CER + KEY certificates"
        
        # Download CER file
        local cer_file="ios/certificates/certificate.cer"
        if ! curl -L -f -s -o "$cer_file" "$CERT_CER_URL"; then
            log_error "Failed to download CER certificate"
            return 1
        fi
        
        # Download KEY file
        local key_file="ios/certificates/certificate.key"
        if ! curl -L -f -s -o "$key_file" "$CERT_KEY_URL"; then
            log_error "Failed to download KEY file"
            return 1
        fi
        
        # Generate P12 from CER and KEY
        local p12_file="ios/certificates/certificate.p12"
        local password="${CERT_PASSWORD:-Password@1234}"
        
        if ! openssl pkcs12 -export -in "$cer_file" -inkey "$key_file" -out "$p12_file" -password "pass:$password" -name "iOS Distribution Certificate"; then
            log_error "Failed to generate P12 from CER and KEY"
            return 1
        fi
        
        # Install generated P12 certificate
        if ! security import "$p12_file" -k "$keychain_name" -P "$password" -T /usr/bin/codesign; then
            log_error "Failed to import generated P12 certificate"
            return 1
        fi
        
        # Set key partition list
        security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_name" || true
        
        log_success "CER + KEY certificates converted and installed successfully"
    else
        log_warn "⚠️ No valid certificate configuration found - skipping certificate setup"
        return 0
    fi
    
    # Handle provisioning profile
    if [ -n "${PROFILE_URL:-}" ] && [ "$PROFILE_URL" != "\$PROFILE_URL" ]; then
        log_info "Processing provisioning profile from: $PROFILE_URL"
        
        # Download provisioning profile
        local profile_file="ios/certificates/profile.mobileprovision"
        if ! curl -L -f -s -o "$profile_file" "$PROFILE_URL"; then
            log_error "Failed to download provisioning profile"
            return 1
        fi
        
        # Extract UUID from profile
        local profile_uuid
        profile_uuid=$(security cms -D -i "$profile_file" 2>/dev/null | plutil -extract UUID xml1 -o - - 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | head -1)
        
        if [ -n "$profile_uuid" ]; then
            # Install provisioning profile
            local profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
            mkdir -p "$profiles_dir"
            local target_file="$profiles_dir/$profile_uuid.mobileprovision"
            cp "$profile_file" "$target_file"
            
            export MOBILEPROVISION_UUID="$profile_uuid"
            log_success "Provisioning profile installed with UUID: $profile_uuid"
        else
            log_error "Failed to extract UUID from provisioning profile"
            return 1
        fi
    else
        log_warn "⚠️ No provisioning profile URL found - skipping profile setup"
    fi
    
    # Validate code signing only if certificates were installed
    if [ -n "${CERT_P12_URL:-}" ] || [ -n "${CERT_CER_URL:-}" ]; then
        local identities
        identities=$(security find-identity -v -p codesigning "$keychain_name" 2>/dev/null)
        
        if [ -n "$identities" ]; then
            log_success "Code signing identities found:"
            echo "$identities" | while read line; do
                log_info "   $line"
            done
        else
            log_error "No code signing identities found"
            return 1
        fi
    else
        log_warn "⚠️ Skipping code signing validation - no certificates installed"
    fi
    
    return 0
}

# Function to setup Flutter environment
setup_flutter() {
    log_info "Setting up Flutter environment..."
    
    # Get Flutter packages
    flutter pub get
    
    # Clean previous builds
    flutter clean
    
    log_success "Flutter environment setup completed"
}

# Function to build iOS app
build_ios_app() {
    log_info "Building iOS app..."
    
    # Create output directory
    mkdir -p output/ios
    
    # Determine build approach based on code signing availability
    if [ "${SKIP_CODE_SIGNING:-false}" = "true" ]; then
        log_warn "⚠️ Building without code signing (unsigned build)"
        log_info "💡 This build may not be suitable for App Store distribution"
        
        # Build without code signing
        flutter build ios --release --no-codesign \
            --build-name="${VERSION_NAME:-1.0.0}" \
            --build-number="${VERSION_CODE:-1}"
    else
        log_info "Building with code signing for $PROFILE_TYPE distribution..."
        
        # Build with code signing
        if [ "$PROFILE_TYPE" = "app-store" ]; then
            flutter build ipa --release \
                --build-name="${VERSION_NAME:-1.0.0}" \
                --build-number="${VERSION_CODE:-1}" \
                --export-options-plist=ios/ExportOptions.plist
        else
            flutter build ipa --release \
                --build-name="${VERSION_NAME:-1.0.0}" \
                --build-number="${VERSION_CODE:-1}"
        fi
    fi
    
    # Copy build artifacts to output directory
    if [ -f "build/ios/ipa/Runner.ipa" ]; then
        cp build/ios/ipa/Runner.ipa output/ios/
        log_success "IPA built successfully: output/ios/Runner.ipa"
    elif [ -d "build/ios/Release-iphoneos/Runner.app" ]; then
        # For unsigned builds, we might get a .app instead of .ipa
        log_info "Unsigned build created: build/ios/Release-iphoneos/Runner.app"
        cp -r build/ios/Release-iphoneos/Runner.app output/ios/
        log_success "App bundle copied: output/ios/Runner.app"
    else
        log_error "No build artifacts found after build"
        log_info "Checking build directory contents:"
        ls -la build/ios/ || true
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    log_info "🚀 Starting iOS Workflow 3 Build"
    
    # Validate environment
    if ! validate_environment; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Environment validation failed"
        exit 1
    fi
    
    # Send build started email
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ]; then
        send_email "build_started" "iOS" "${CM_BUILD_ID:-unknown}" ""
    fi
    
    # Setup certificates
    if ! setup_certificates; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Certificate setup failed"
        exit 1
    fi
    
    # Setup Flutter
    if ! setup_flutter; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Flutter setup failed"
        exit 1
    fi
    
    # Build iOS app
    if ! build_ios_app; then
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "iOS build failed"
        exit 1
    fi
    
    # Send success email
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ]; then
        send_email "build_success" "iOS" "${CM_BUILD_ID:-unknown}" ""
    fi
    
    log_success "🎉 iOS Workflow 3 Build completed successfully!"
}

# Run main function
main "$@" 