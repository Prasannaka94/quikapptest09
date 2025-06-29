#!/bin/bash

# Flutter iOS Build Script
# Purpose: Build the Flutter iOS application and create archive

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting Flutter iOS Build..."

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

# Function to handle Firebase compilation issues
handle_firebase_issues() {
    log_warn "Firebase compilation issues detected, applying emergency workaround..."
    
    # Create backup of pubspec.yaml
    cp pubspec.yaml pubspec.yaml.backup
    
    # Remove Firebase dependencies temporarily
    sed -i.tmp '/firebase_core:/d' pubspec.yaml
    sed -i.tmp '/firebase_messaging:/d' pubspec.yaml
    sed -i.tmp '/_flutterfire_internals:/d' pubspec.yaml
    sed -i.tmp '/firebase_core_platform_interface:/d' pubspec.yaml
    sed -i.tmp '/firebase_core_web:/d' pubspec.yaml
    sed -i.tmp '/firebase_messaging_platform_interface:/d' pubspec.yaml
    sed -i.tmp '/firebase_messaging_web:/d' pubspec.yaml
    rm -f pubspec.yaml.tmp
    
    log_info "Firebase dependencies temporarily removed from pubspec.yaml"
    
    # Clean project state
    flutter clean
    
    # Fix bundle identifier conflicts before regenerating iOS files
    log_info "Fixing bundle identifier conflicts..."
    
    # Clean up any remaining com.example references in iOS files
    if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
        cp "ios/Runner.xcodeproj/project.pbxproj" "ios/Runner.xcodeproj/project.pbxproj.backup"
        sed -i.tmp 's/com\.example\.quikapptest07/com.twinklub.twinklub/g' "ios/Runner.xcodeproj/project.pbxproj"
        sed -i.tmp 's/com\.example\.[a-zA-Z0-9_]*/com.twinklub.twinklub/g' "ios/Runner.xcodeproj/project.pbxproj"
        rm -f "ios/Runner.xcodeproj/project.pbxproj.tmp"
        log_info "Bundle identifier conflicts cleaned up"
    fi
    
    # Get dependencies
    flutter pub get
    
    # Determine organization from bundle ID
    local ORG_NAME="com.twinklub"
    if [ -n "${BUNDLE_ID:-}" ]; then
        ORG_NAME=$(echo "$BUNDLE_ID" | cut -d. -f1-2)
    fi
    
    log_info "Using organization: $ORG_NAME"
    
    # Regenerate iOS files with correct organization
    flutter create --platforms ios --org "$ORG_NAME" .
    
    # Clean and reinstall CocoaPods
    cd ios
    rm -rf Pods Podfile.lock
    
    # Use the bundle identifier collision fix to ensure proper Podfile
    if [ -f "../lib/scripts/ios/fix_bundle_identifier_collision_v2.sh" ]; then
        log_info "Applying bundle identifier collision fixes..."
        cd ..
        chmod +x lib/scripts/ios/fix_bundle_identifier_collision_v2.sh
        ./lib/scripts/ios/fix_bundle_identifier_collision_v2.sh || true
        cd ios
    fi
    
    # Install pods with Firebase disabled
    FIREBASE_DISABLED=true pod install --repo-update --verbose
    cd ..
    
    log_warn "Firebase functionality disabled for this build"
    export FIREBASE_DISABLED=true
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
    
    # Install pods with proven ios-workflow2 approach
    log_info "Installing CocoaPods with proven approach..."
    if pod install --repo-update --verbose; then
        log_success "CocoaPods installation completed"
    else
        log_warn "First attempt failed, trying with legacy mode..."
        if pod install --repo-update --verbose --legacy; then
            log_success "CocoaPods installation completed with legacy mode"
        else
            log_warn "Legacy mode failed, trying Firebase workaround..."
            
            # Firebase workaround: Remove Firebase pods if they cause issues
            if [ -f "Podfile" ]; then
                log_info "Applying Firebase workaround - removing problematic Firebase pods..."
                
                # Create backup
                cp Podfile Podfile.backup
                
                # Remove Firebase-related lines from Podfile
                sed -i.tmp '/firebase/d' Podfile
                sed -i.tmp '/Firebase/d' Podfile
                rm -f Podfile.tmp
                
                # Apply bundle identifier collision fixes to prevent conflicts
                if [ -f "../lib/scripts/ios/fix_bundle_identifier_collision_v2.sh" ]; then
                    log_info "Applying bundle identifier collision fixes..."
                    cd ..
                    chmod +x lib/scripts/ios/fix_bundle_identifier_collision_v2.sh
                    ./lib/scripts/ios/fix_bundle_identifier_collision_v2.sh || true
                    cd ios
                fi
                
                # Try installation again without Firebase
                if FIREBASE_DISABLED=true pod install --repo-update --verbose; then
                    log_success "CocoaPods installation completed without Firebase"
                    log_warn "Firebase functionality will be disabled for this build"
                    # Set environment variable to disable Firebase in subsequent steps
                    export FIREBASE_DISABLED=true
                else
                    log_error "CocoaPods installation failed even without Firebase"
                    cd ..
                    return 1
                fi
            else
                log_error "CocoaPods installation failed"
                cd ..
                return 1
            fi
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
        --dart-define=IS_LOAD_IND="${IS_LOAD_IND:-false}"
    
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

# Function to completely remove Firebase from project
completely_remove_firebase() {
    log_warn "🔥 Completely removing Firebase from project..."
    
    # 1. Remove Firebase from pubspec.yaml
    if [ -f "pubspec.yaml" ]; then
        cp pubspec.yaml pubspec.yaml.firebase_backup
        log_info "Backup created: pubspec.yaml.firebase_backup"
        
        # Remove all Firebase-related dependencies
        sed -i.tmp '/firebase_core:/d' pubspec.yaml
        sed -i.tmp '/firebase_messaging:/d' pubspec.yaml
        sed -i.tmp '/_flutterfire_internals:/d' pubspec.yaml
        sed -i.tmp '/firebase_core_platform_interface:/d' pubspec.yaml
        sed -i.tmp '/firebase_core_web:/d' pubspec.yaml
        sed -i.tmp '/firebase_messaging_platform_interface:/d' pubspec.yaml
        sed -i.tmp '/firebase_messaging_web:/d' pubspec.yaml
        sed -i.tmp '/cloud_firestore:/d' pubspec.yaml
        sed -i.tmp '/firebase_auth:/d' pubspec.yaml
        sed -i.tmp '/firebase_analytics:/d' pubspec.yaml
        sed -i.tmp '/firebase_crashlytics:/d' pubspec.yaml
        sed -i.tmp '/firebase_performance:/d' pubspec.yaml
        sed -i.tmp '/firebase_remote_config:/d' pubspec.yaml
        sed -i.tmp '/firebase_storage:/d' pubspec.yaml
        rm -f pubspec.yaml.tmp
        
        log_info "✅ Firebase dependencies removed from pubspec.yaml"
    fi
    
    # 2. Remove Firebase configuration files
    if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
        mv "ios/Runner/GoogleService-Info.plist" "ios/Runner/GoogleService-Info.plist.backup"
        log_info "✅ GoogleService-Info.plist backed up and removed"
    fi
    
    if [ -f "android/app/google-services.json" ]; then
        mv "android/app/google-services.json" "android/app/google-services.json.backup"
        log_info "✅ google-services.json backed up and removed"
    fi
    
    # 3. Clean Flutter project state
    log_info "🧹 Cleaning Flutter project state..."
    flutter clean
    rm -rf .dart_tool/
    rm -rf build/
    
    # 4. Clean iOS project
    log_info "🧹 Cleaning iOS project..."
    if [ -d "ios" ]; then
        cd ios
        rm -rf Pods/
        rm -f Podfile.lock
        rm -rf build/
        rm -rf .symlinks/
        rm -rf Flutter/ephemeral/
        cd ..
    fi
    
    # 5. Fix bundle identifier conflicts
    log_info "🔧 Fixing bundle identifier conflicts..."
    if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
        cp "ios/Runner.xcodeproj/project.pbxproj" "ios/Runner.xcodeproj/project.pbxproj.firebase_backup"
        sed -i.tmp 's/com\.example\.quikapptest07/com.twinklub.twinklub/g' "ios/Runner.xcodeproj/project.pbxproj"
        sed -i.tmp 's/com\.example\.[a-zA-Z0-9_]*/com.twinklub.twinklub/g' "ios/Runner.xcodeproj/project.pbxproj"
        rm -f "ios/Runner.xcodeproj/project.pbxproj.tmp"
        log_info "✅ Bundle identifier conflicts cleaned up"
    fi
    
    # 6. Get dependencies without Firebase
    log_info "📦 Installing dependencies without Firebase..."
    flutter pub get
    
    # 7. Regenerate iOS files with correct organization
    local ORG_NAME="com.twinklub"
    if [ -n "${BUNDLE_ID:-}" ]; then
        ORG_NAME=$(echo "$BUNDLE_ID" | cut -d. -f1-2)
    fi
    
    log_info "🔄 Regenerating iOS files with organization: $ORG_NAME"
    flutter create --platforms ios --org "$ORG_NAME" .
    
    # 8. Create a clean Podfile without Firebase
    log_info "📝 Creating clean Podfile without Firebase..."
    cat > ios/Podfile << 'EOF'
platform :ios, '13.0'
use_frameworks! :linkage => :static

ENV['COCOAPODS_DISABLE_STATS'] = 'true'
ENV['FIREBASE_DISABLED'] = 'true'

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
      # Core iOS settings
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      
      # Xcode 16.0 compatibility fixes
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['SWIFT_VERSION'] = '5.0'
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      config.build_settings['ENABLE_PREVIEWS'] = 'NO'
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      
      # Bundle identifier collision prevention
      next if target.name == 'Runner'
      
      if config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
        current_bundle_id = config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
        if current_bundle_id.include?('com.twinklub.twinklub') || current_bundle_id.include?('com.example')
          config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = current_bundle_id + '.pod.' + target.name.downcase
        end
      end
    end
  end
end
EOF
    
    # 9. Install CocoaPods with Firebase disabled
    log_info "📦 Installing CocoaPods without Firebase..."
    cd ios
    FIREBASE_DISABLED=true pod install --repo-update --verbose
    cd ..
    
    # 10. Set environment flag
    export FIREBASE_DISABLED=true
    echo "FIREBASE_DISABLED=true" >> "$HOME/.bashrc" 2>/dev/null || true
    
    log_success "✅ Firebase completely removed from project"
    log_warn "⚠️ Push notifications and Firebase features will be disabled"
    
    return 0
}

# Function to detect potential Firebase issues early
detect_firebase_issues() {
    log_info "🔍 Detecting potential Firebase issues..."
    
    # Check for known Firebase compilation issues with Xcode 16.0
    if [ -f "pubspec.yaml" ] && grep -q "firebase" pubspec.yaml; then
        log_info "Firebase dependencies detected, checking for potential issues..."
        
        # Check Xcode version
        local xcode_version=$(xcodebuild -version | head -1 | grep -o '[0-9]*\.[0-9]*')
        if [[ "$xcode_version" == "16."* ]]; then
            log_warn "⚠️ Xcode 16.x detected with Firebase - known compilation issues"
            log_info "Applying preemptive Firebase removal to avoid build failures..."
            return 1  # Indicates Firebase issues detected
        fi
        
        # Check for Firebase configuration files
        if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
            # Try to validate the Firebase configuration
            if ! plutil -lint "ios/Runner/GoogleService-Info.plist" >/dev/null 2>&1; then
                log_warn "⚠️ Invalid GoogleService-Info.plist detected"
                return 1  # Indicates Firebase issues detected
            fi
        fi
        
        # Check if Firebase dependencies exist but configuration is missing
        if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
            log_warn "⚠️ Firebase dependencies found but GoogleService-Info.plist missing"
            return 1  # Indicates Firebase issues detected
        fi
    fi
    
    log_info "✅ No immediate Firebase issues detected"
    return 0  # No issues detected
}

# Main execution
main() {
    log_info "Flutter iOS Build Starting..."
    
    # Early Firebase issue detection
    if detect_firebase_issues; then
        log_info "✅ Firebase checks passed, proceeding with normal build"
    else
        log_warn "🔥 Firebase issues detected, applying preemptive removal..."
        if completely_remove_firebase; then
            log_info "✅ Preemptive Firebase removal completed"
        else
            log_error "❌ Failed to remove Firebase preemptively"
            return 1
        fi
    fi
    
    # Generate Podfile if needed
    generate_podfile
    
    # Install dependencies
    if ! install_dependencies; then
        log_error "Failed to install dependencies"
        return 1
    fi
    
    # Build Flutter app
    if ! build_flutter_app; then
        log_error "Failed to build Flutter app"
        return 1
    fi
    
    # Create Xcode archive
    if ! create_xcode_archive; then
        log_warn "Xcode archive failed, trying comprehensive Firebase removal..."
        
        # Try comprehensive Firebase removal if archive fails
        if [ "${FIREBASE_DISABLED:-false}" != "true" ]; then
            log_info "Attempting comprehensive Firebase removal..."
            
            if completely_remove_firebase; then
                log_info "Firebase completely removed, rebuilding..."
                
                # Retry build without Firebase
                if ! build_flutter_app; then
                    log_error "Failed to build Flutter app even after Firebase removal"
                    return 1
                fi
                
                # Retry archive without Firebase
                if ! create_xcode_archive; then
                    log_error "Failed to create Xcode archive even after Firebase removal"
                    return 1
                fi
            else
                log_error "Failed to remove Firebase completely"
                return 1
            fi
        else
            log_error "Failed to create Xcode archive"
            return 1
        fi
    fi
    
    log_success "Flutter iOS Build completed successfully!"
    
    # Summary
    log_info "Build Summary:"
    log_info "  - App: ${APP_NAME:-Unknown}"
    log_info "  - Bundle ID: ${BUNDLE_ID:-Unknown}"
    log_info "  - Version: ${VERSION_NAME:-Unknown} (${VERSION_CODE:-Unknown})"
    log_info "  - Profile Type: ${PROFILE_TYPE:-Unknown}"
    log_info "  - Archive: ${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    if [ "${FIREBASE_DISABLED:-false}" = "true" ]; then
        log_warn "  - Firebase: DISABLED (due to compilation issues)"
    else
        log_info "  - Firebase: ENABLED"
    fi
    
    return 0
}

# Run main function
main "$@"
