#!/bin/bash

# Flutter iOS Build Script
# Purpose: Build the Flutter iOS application and create archive

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting Flutter iOS Build..."

# Function to check Firebase requirement
check_firebase_requirement() {
    log_info "🔍 Checking Firebase requirement based on PUSH_NOTIFY flag..."
    
    if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
        log_info "🔔 Push notifications ENABLED - Firebase required"
        export FIREBASE_REQUIRED=true
        export FIREBASE_DISABLED=false
        return 0
    else
        log_info "🔕 Push notifications DISABLED - Firebase NOT required"
        export FIREBASE_REQUIRED=false
        export FIREBASE_DISABLED=true
        
        # Proactively remove Firebase to prevent conflicts
        log_info "🧹 Proactively removing Firebase dependencies..."
        remove_firebase_dependencies_proactive
        return 0
    fi
}

# Function to proactively remove Firebase dependencies when not needed
remove_firebase_dependencies_proactive() {
    if [ "${FIREBASE_DISABLED:-false}" = "true" ] || [ "${PUSH_NOTIFY:-false}" = "false" ]; then
        log_info "🔥 Removing Firebase dependencies (not required for this build)..."
        
        if [ -f "pubspec.yaml" ]; then
            # Create backup
            cp pubspec.yaml pubspec.yaml.no_firebase_backup
            
            # Remove Firebase dependencies
            sed -i.tmp '/firebase_core:/d' pubspec.yaml
            sed -i.tmp '/firebase_messaging:/d' pubspec.yaml
            sed -i.tmp '/_flutterfire_internals:/d' pubspec.yaml
            sed -i.tmp '/cloud_firestore:/d' pubspec.yaml
            sed -i.tmp '/firebase_auth:/d' pubspec.yaml
            sed -i.tmp '/firebase_analytics:/d' pubspec.yaml
            sed -i.tmp '/firebase_crashlytics:/d' pubspec.yaml
            sed -i.tmp '/firebase_storage:/d' pubspec.yaml
            sed -i.tmp '/firebase_remote_config:/d' pubspec.yaml
            rm -f pubspec.yaml.tmp
            
            log_success "✅ Firebase dependencies removed from pubspec.yaml"
        fi
        
        # Remove Firebase config files
        if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
            mv "ios/Runner/GoogleService-Info.plist" "ios/Runner/GoogleService-Info.plist.disabled"
            log_info "✅ GoogleService-Info.plist disabled"
        fi
        
        if [ -f "android/app/google-services.json" ]; then
            mv "android/app/google-services.json" "android/app/google-services.json.disabled"
            log_info "✅ google-services.json disabled"
        fi
    fi
}

# Function to generate Podfile
generate_podfile() {
    log_info "Generating Podfile for iOS..."
    
    if [ ! -f "ios/Podfile" ]; then
        log_info "Creating basic Podfile..."
        cat > ios/Podfile << 'EOF'
platform :ios, '13.0'
use_frameworks! :linkage => :static

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      # Disable code signing for pods to avoid conflicts
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
    end
  end
end
EOF
        log_success "Basic Podfile created"
    else
        log_info "Podfile already exists"
    fi
}

# Function to apply Firebase Xcode 16.0 compatibility fixes
apply_firebase_xcode16_fixes() {
    log_info "🔧 Applying Firebase Xcode 16.0 compatibility fixes..."
    
    # Apply the Firebase fixes if Firebase is enabled
    if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
        if [ -f "lib/scripts/ios/fix_firebase_xcode16.sh" ]; then
            chmod +x lib/scripts/ios/fix_firebase_xcode16.sh
            if lib/scripts/ios/fix_firebase_xcode16.sh; then
                log_success "✅ Firebase Xcode 16.0 fixes applied successfully"
            else
                log_error "❌ Failed to apply Firebase Xcode 16.0 fixes"
                return 1
            fi
        else
            log_warn "⚠️ Firebase Xcode 16.0 fix script not found"
            return 1
        fi
    else
        log_info "ℹ️ Firebase disabled, skipping Firebase-specific fixes"
    fi
    
    return 0
}

# Function to install dependencies
install_dependencies() {
    log_info "Installing Flutter dependencies..."
    
    # Flutter pub get
    flutter pub get
    log_success "Flutter dependencies installed"
    
    # Generate iOS platform files
    log_info "Generating iOS platform files..."
    flutter create --platforms ios .
    
    # Install CocoaPods dependencies
    log_info "Installing CocoaPods dependencies..."
    cd ios
    
    # Clean Pods if exists
    if [ -d "Pods" ]; then
        rm -rf Pods
        log_info "Cleaned existing Pods"
    fi
    
    if [ -f "Podfile.lock" ]; then
        rm -f Podfile.lock
        log_info "Removed existing Podfile.lock"
    fi
    
    # Apply Firebase Xcode 16.0 fixes first if needed
    if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
        log_info "🔧 Firebase enabled, applying Xcode 16.0 compatibility fixes..."
        cd ..
        if ! apply_firebase_xcode16_fixes; then
            log_error "❌ Failed to apply Firebase Xcode 16.0 fixes"
            return 1
        fi
        cd ios
    fi
    
    # Install pods with enhanced approach
    log_info "Installing CocoaPods with enhanced approach..."
    if pod install --repo-update --verbose; then
        log_success "CocoaPods installation completed successfully"
    else
        log_warn "First attempt failed, trying with legacy mode..."
        if pod install --repo-update --verbose --legacy; then
            log_success "CocoaPods installation completed with legacy mode"
        else
            log_error "CocoaPods installation failed"
            log_error "This indicates a configuration issue that must be resolved:"
            log_error "  1. Check Firebase configuration (if PUSH_NOTIFY=true)"
            log_error "  2. Verify bundle identifier consistency"
            log_error "  3. Ensure Xcode 16.0 compatibility fixes are applied"
            cd ..
            return 1
        fi
    fi
    
    cd ..
    log_success "CocoaPods dependencies installed"
}

# Function to build Flutter app
build_flutter_app() {
    log_info "Building Flutter iOS app..."
    
    # Determine build configuration based on profile type
    local build_mode="release"
    local build_config="Release"
    
    case "${PROFILE_TYPE:-app-store}" in
        "development")
            build_mode="debug"
            build_config="Debug"
            ;;
        "ad-hoc"|"enterprise"|"app-store")
            build_mode="release"
            build_config="Release"
            ;;
    esac
    
    log_info "Building in $build_mode mode for $PROFILE_TYPE distribution"
    
    # Build Flutter iOS app
    flutter build ios \
        --$build_mode \
        --no-codesign \
        --dart-define=APP_NAME="${APP_NAME:-}" \
        --dart-define=BUNDLE_ID="${BUNDLE_ID:-}" \
        --dart-define=VERSION_NAME="${VERSION_NAME:-}" \
        --dart-define=VERSION_CODE="${VERSION_CODE:-}" \
        --dart-define=LOGO_URL="${LOGO_URL:-}" \
        --dart-define=SPLASH_URL="${SPLASH_URL:-}" \
        --dart-define=SPLASH_BG_URL="${SPLASH_BG_URL:-}" \
        --dart-define=BOTTOMMENU_ITEMS="${BOTTOMMENU_ITEMS:-}" \
        --dart-define=PUSH_NOTIFY="${PUSH_NOTIFY:-false}" \
        --dart-define=IS_DOMAIN_URL="${IS_DOMAIN_URL:-false}" \
        --dart-define=IS_CHATBOT="${IS_CHATBOT:-false}" \
        --dart-define=IS_SPLASH="${IS_SPLASH:-false}" \
        --dart-define=IS_PULLDOWN="${IS_PULLDOWN:-false}" \
        --dart-define=IS_BOTTOMMENU="${IS_BOTTOMMENU:-false}" \
        --dart-define=IS_LOAD_IND="${IS_LOAD_IND:-false}" \
        --dart-define=FIREBASE_DISABLED="${FIREBASE_DISABLED:-false}"
    
    log_success "Flutter iOS app built successfully"
}

# Function to create Xcode archive
create_xcode_archive() {
    log_info "Creating Xcode archive..."
    
    local scheme="Runner"
    local workspace="ios/Runner.xcworkspace"
    local archive_path="${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    local build_config="Release"
    
    # Ensure output directory exists
    ensure_directory "${OUTPUT_DIR:-output/ios}"
    
    # Determine build configuration
    case "${PROFILE_TYPE:-app-store}" in
        "development")
            build_config="Debug"
            ;;
        *)
            build_config="Release"
            ;;
    esac
    
    log_info "Creating archive with configuration: $build_config"
    
    # Create Xcode archive with proven ios-workflow2 approach
    xcodebuild archive \
        -workspace "$workspace" \
        -scheme "$scheme" \
        -configuration "$build_config" \
        -archivePath "$archive_path" \
        -allowProvisioningUpdates \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
        PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID:-}" \
        MARKETING_VERSION="${VERSION_NAME:-1.0.0}" \
        CURRENT_PROJECT_VERSION="${VERSION_CODE:-1}" \
        IPHONEOS_DEPLOYMENT_TARGET="13.0" \
        ENABLE_BITCODE=NO \
        COMPILER_INDEX_STORE_ENABLE=NO \
        ONLY_ACTIVE_ARCH=NO
    
    if [ -d "$archive_path" ]; then
        log_success "Xcode archive created successfully: $archive_path"
        
        # Validate archive
        if [ -f "$archive_path/Info.plist" ]; then
            log_success "Archive validation passed"
        else
            log_error "Archive validation failed - Info.plist not found"
            return 1
        fi
    else
        log_error "Failed to create Xcode archive"
        return 1
    fi
}

# Function to validate build prerequisites
validate_build_prerequisites() {
    log_info "🔍 Validating build prerequisites..."
    
    # Check if conditional Firebase injection was run
    if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
        log_info "🔥 Firebase enabled - validating Firebase setup..."
        
        # Check for Firebase config files
        if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
            log_error "❌ GoogleService-Info.plist not found but Firebase is enabled"
            log_error "   Ensure conditional_firebase_injection.sh was run successfully"
            return 1
        fi
        
        # Check for Firebase dependencies in pubspec.yaml
        if ! grep -q "firebase_core:" pubspec.yaml; then
            log_error "❌ Firebase dependencies not found in pubspec.yaml but Firebase is enabled"
            log_error "   Ensure conditional_firebase_injection.sh was run successfully"
            return 1
        fi
        
        log_success "✅ Firebase configuration validated"
    else
        log_info "🚫 Firebase disabled - validating Firebase-free setup..."
        
        # Ensure Firebase files are not present when disabled
        if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
            log_warn "⚠️ Firebase config file found but Firebase is disabled"
            log_info "   This will be handled by conditional Firebase injection"
        fi
        
        log_success "✅ Firebase-free configuration validated"
    fi
    
    # Check bundle identifier consistency
    if grep -q "com.example" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null; then
        log_error "❌ Bundle identifier conflicts detected (com.example references found)"
        log_error "   Ensure bundle identifier collision fixes were applied"
        return 1
    fi
    
    log_success "✅ Build prerequisites validated successfully"
    return 0
}

# Main execution function
main() {
    log_info "Starting Flutter iOS Build Process..."
    
    # Step 1: Validate build prerequisites
    if ! validate_build_prerequisites; then
        log_error "Build prerequisites validation failed"
        return 1
    fi
    
    # Step 2: Check Firebase requirement based on PUSH_NOTIFY flag
    check_firebase_requirement
    
    # Step 3: Generate Podfile (if needed)
    generate_podfile
    
    # Step 4: Install dependencies (with Firebase Xcode 16.0 fixes if needed)
    if ! install_dependencies; then
        log_error "Failed to install dependencies"
        log_error "This is a hard failure - check Firebase configuration and Xcode compatibility"
        return 1
    fi
    
    # Step 5: Build Flutter app
    if ! build_flutter_app; then
        log_error "Failed to build Flutter app"
        log_error "This is a hard failure - build must succeed cleanly"
        return 1
    fi
    
    # Step 6: Create Xcode archive
    if ! create_xcode_archive; then
        log_error "Failed to create Xcode archive"
        log_error "This is a hard failure - archive creation must succeed"
        return 1
    fi
    
    log_success "Flutter iOS build completed successfully!"
    log_info "Build Summary:"
    log_info "  - App: ${APP_NAME:-Unknown} v${VERSION_NAME:-Unknown}"
    log_info "  - Bundle ID: ${BUNDLE_ID:-Unknown}"
    log_info "  - Profile Type: ${PROFILE_TYPE:-Unknown}"
    log_info "  - Firebase: $([ "${PUSH_NOTIFY:-false}" = "true" ] && echo "ENABLED" || echo "DISABLED")"
    log_info "  - Push Notifications: ${PUSH_NOTIFY:-false}"
    log_info "  - Xcode Compatibility: 16.0+ with enhanced fixes"
    
    return 0
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
