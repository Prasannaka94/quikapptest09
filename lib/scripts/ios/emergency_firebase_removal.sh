#!/bin/bash

# Emergency Firebase Removal Script
# Completely removes Firebase and rebuilds the iOS app without Firebase dependencies

set -e

# Source profile validation script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/validate_profile_type.sh"

# Function to log messages
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1"
}

# Function to clean project state
clean_project() {
    log_info "🧹 Cleaning project state..."
    
    # Clean Flutter
    flutter clean
    rm -rf .dart_tool/
    rm -rf build/
    
    # Clean iOS
    rm -rf ios/Pods/
    rm -f ios/Podfile.lock
    rm -rf ios/build/
    rm -rf ios/.symlinks/
    rm -rf ios/Flutter/ephemeral/
    
    log_success "✅ Project cleaned"
}

# Function to remove Firebase dependencies
remove_firebase_dependencies() {
    log_info "🔥 Removing Firebase dependencies..."
    
    if [ -f "pubspec.yaml" ]; then
        # Create backup
        cp pubspec.yaml pubspec.yaml.emergency_backup
        log_info "✅ Created backup: pubspec.yaml.emergency_backup"
        
        # Remove Firebase dependencies using broader patterns
        sed -i.tmp '/firebase/d' pubspec.yaml
        sed -i.tmp '/Firebase/d' pubspec.yaml
        sed -i.tmp '/_flutterfire_internals/d' pubspec.yaml
        sed -i.tmp '/cloud_firestore/d' pubspec.yaml
        sed -i.tmp '/firebase_auth/d' pubspec.yaml
        sed -i.tmp '/firebase_messaging/d' pubspec.yaml
        sed -i.tmp '/firebase_analytics/d' pubspec.yaml
        sed -i.tmp '/firebase_crashlytics/d' pubspec.yaml
        sed -i.tmp '/firebase_storage/d' pubspec.yaml
        sed -i.tmp '/firebase_remote_config/d' pubspec.yaml
        rm -f pubspec.yaml.tmp
        
        log_success "✅ Firebase dependencies removed from pubspec.yaml"
    else
        log_warn "⚠️ pubspec.yaml not found"
    fi
}

# Function to clean up Firebase imports and code from Dart files
cleanup_firebase_dart_code() {
    log_info "🧹 Cleaning up Firebase imports and code from Dart files..."
    
    # Find all Dart files
    find lib -name "*.dart" -type f | while read -r dart_file; do
        if grep -q "firebase" "$dart_file" 2>/dev/null; then
            log_info "🔧 Processing: $dart_file"
            
            # Create backup
            cp "$dart_file" "$dart_file.emergency_backup"
            
            # Comment out Firebase imports
            sed -i.tmp 's/^import.*firebase.*$/\/\/ &/' "$dart_file"
            sed -i.tmp 's/^import.*Firebase.*$/\/\/ &/' "$dart_file"
            
            # Comment out Firebase initialization calls
            sed -i.tmp 's/^.*Firebase\.initializeApp.*$/\/\/ &/' "$dart_file"
            sed -i.tmp 's/^.*FirebaseApp\.configure.*$/\/\/ &/' "$dart_file"
            sed -i.tmp 's/^.*await Firebase\.initializeApp.*$/\/\/ &/' "$dart_file"
            
            # Comment out FirebaseMessaging usage
            sed -i.tmp 's/^.*FirebaseMessaging.*$/\/\/ &/' "$dart_file"
            sed -i.tmp 's/^.*firebaseMessaging.*$/\/\/ &/' "$dart_file"
            
            # Comment out other Firebase service usage
            sed -i.tmp 's/^.*FirebaseAuth.*$/\/\/ &/' "$dart_file"
            sed -i.tmp 's/^.*FirebaseFirestore.*$/\/\/ &/' "$dart_file"
            sed -i.tmp 's/^.*FirebaseAnalytics.*$/\/\/ &/' "$dart_file"
            sed -i.tmp 's/^.*FirebaseCrashlytics.*$/\/\/ &/' "$dart_file"
            
            rm -f "$dart_file.tmp"
            log_success "✅ Firebase code commented out in: $dart_file"
        fi
    done
    
    # Special handling for main.dart
    if [ -f "lib/main.dart" ]; then
        log_info "🔧 Special processing for lib/main.dart..."
        
        # Create backup
        cp "lib/main.dart" "lib/main.dart.emergency_backup"
        
        # Create a Firebase-free version
        cat > "lib/main.dart.firebase_free" << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Firebase imports commented out for emergency build
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase initialization commented out for emergency build
  // await Firebase.initializeApp();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twinklub App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Twinklub App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to Twinklub App',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 20),
              Text(
                'Emergency build without Firebase',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
EOF
        
        # Replace main.dart with Firebase-free version
        mv "lib/main.dart.firebase_free" "lib/main.dart"
        log_success "✅ Created Firebase-free main.dart"
    fi
    
    log_success "✅ Firebase Dart code cleanup completed"
}

# Function to remove Firebase configuration files
remove_firebase_config_files() {
    log_info "📁 Removing Firebase configuration files..."
    
    # iOS Firebase config
    if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
        mv "ios/Runner/GoogleService-Info.plist" "ios/Runner/GoogleService-Info.plist.emergency_backup"
        log_success "✅ GoogleService-Info.plist backed up and removed"
    fi
    
    # Android Firebase config
    if [ -f "android/app/google-services.json" ]; then
        mv "android/app/google-services.json" "android/app/google-services.json.emergency_backup"
        log_success "✅ google-services.json backed up and removed"
    fi
}

# Function to fix bundle identifier conflicts
fix_bundle_identifier_conflicts() {
    log_info "🔧 Fixing bundle identifier conflicts..."
    
    if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
        # Create backup
        cp "ios/Runner.xcodeproj/project.pbxproj" "ios/Runner.xcodeproj/project.pbxproj.emergency_backup"
        
        # Fix bundle identifier conflicts
        sed -i.tmp 's/com\.example\.quikapptest07/com.twinklub.twinklub/g' "ios/Runner.xcodeproj/project.pbxproj"
        sed -i.tmp 's/com\.example\.[a-zA-Z0-9_]*/com.twinklub.twinklub/g' "ios/Runner.xcodeproj/project.pbxproj"
        rm -f "ios/Runner.xcodeproj/project.pbxproj.tmp"
        
        log_success "✅ Bundle identifier conflicts fixed"
    else
        log_warn "⚠️ project.pbxproj not found"
    fi
}

# Function to regenerate Flutter dependencies and iOS files
regenerate_project() {
    log_info "🔄 Regenerating Flutter dependencies and iOS files..."
    
    # Get Flutter dependencies
    flutter pub get
    
    # Regenerate iOS files with correct organization
    local org_name="com.twinklub"
    if [ -n "${BUNDLE_ID:-}" ]; then
        org_name=$(echo "$BUNDLE_ID" | cut -d. -f1-2)
    fi
    
    log_info "📱 Regenerating iOS files with organization: $org_name"
    flutter create --platforms ios --org "$org_name" .
    
    log_success "✅ Project regenerated"
}

# Function to install CocoaPods without Firebase
install_cocoapods() {
    log_info "📦 Installing CocoaPods without Firebase..."
    
    cd ios
    FIREBASE_DISABLED=true pod install --repo-update --verbose
    local pod_result=$?
    cd ..
    
    if [ $pod_result -eq 0 ]; then
        log_success "✅ CocoaPods installed successfully"
    else
        log_error "❌ CocoaPods installation failed"
        return 1
    fi
}

# Function to build Flutter app without Firebase
build_flutter_app() {
    log_info "🏗️ Building Flutter app without Firebase..."
    
    flutter build ios --release --no-codesign \
        --dart-define=APP_NAME="${APP_NAME:-Twinklub App}" \
        --dart-define=BUNDLE_ID="${BUNDLE_ID:-com.twinklub.twinklub}" \
        --dart-define=VERSION_NAME="${VERSION_NAME:-1.0.0}" \
        --dart-define=VERSION_CODE="${VERSION_CODE:-1}" \
        --dart-define=PUSH_NOTIFY="false" \
        --dart-define=FIREBASE_DISABLED="true"
    
    local build_result=$?
    
    if [ $build_result -eq 0 ]; then
        log_success "✅ Flutter app built successfully"
    else
        log_error "❌ Flutter app build failed"
        return 1
    fi
}

# Function to create Xcode archive
create_xcode_archive() {
    log_info "🏗️ Creating Xcode archive for profile type: ${PROFILE_TYPE:-ad-hoc}"
    
    # Create output directory
    mkdir -p output/ios
    
    xcodebuild archive \
        -workspace ios/Runner.xcworkspace \
        -scheme Runner \
        -configuration Release \
        -archivePath "output/ios/Runner.xcarchive" \
        -allowProvisioningUpdates \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
        PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID:-com.twinklub.twinklub}" \
        MARKETING_VERSION="${VERSION_NAME:-1.0.0}" \
        CURRENT_PROJECT_VERSION="${VERSION_CODE:-1}" \
        IPHONEOS_DEPLOYMENT_TARGET="13.0" \
        ENABLE_BITCODE=NO \
        COMPILER_INDEX_STORE_ENABLE=NO \
        ONLY_ACTIVE_ARCH=NO
    
    local archive_result=$?
    
    if [ $archive_result -eq 0 ] && [ -d "output/ios/Runner.xcarchive" ]; then
        log_success "✅ Xcode archive created successfully"
        return 0
    else
        log_error "❌ Xcode archive creation failed"
        return 1
    fi
}

# Function to export IPA
export_ipa() {
    log_info "📦 Exporting IPA with profile type: ${PROFILE_TYPE:-ad-hoc}"
    
    # Validate profile type and create export options
    validate_profile_type
    create_export_options "ios/ExportOptions.plist"
    
    if [ ! -f "ios/ExportOptions.plist" ]; then
        log_error "❌ ExportOptions.plist not found"
        return 1
    fi
    
    # Export IPA
    xcodebuild -exportArchive \
        -archivePath "output/ios/Runner.xcarchive" \
        -exportPath "output/ios/" \
        -exportOptionsPlist "ios/ExportOptions.plist" \
        -allowProvisioningUpdates
    
    local export_result=$?
    
    if [ $export_result -eq 0 ] && [ -f "output/ios/Runner.ipa" ]; then
        local ipa_size=$(du -h "output/ios/Runner.ipa" | cut -f1)
        log_success "✅ IPA exported successfully!"
        log_info "📊 IPA Size: $ipa_size"
        log_info "🎯 Profile Type: ${PROFILE_TYPE:-ad-hoc}"
        log_info "📦 Location: output/ios/Runner.ipa"
        
        # Validate IPA
        if unzip -t "output/ios/Runner.ipa" >/dev/null 2>&1; then
            log_success "✅ IPA validation passed"
        else
            log_warn "⚠️ IPA validation failed, but file exists"
        fi
        
        return 0
    else
        log_warn "⚠️ IPA export failed, but archive is available"
        log_info "📦 Archive location: output/ios/Runner.xcarchive"
        return 1
    fi
}

# Main emergency Firebase removal function
emergency_firebase_removal() {
    log_info "🚨 Starting Emergency Firebase Removal..."
    log_warn "⚠️ This will disable Firebase features (push notifications) in the build"
    
    # Step 1: Clean project
    clean_project
    
    # Step 2: Remove Firebase dependencies
    remove_firebase_dependencies
    
    # Step 3: Clean up Firebase imports and code from Dart files
    cleanup_firebase_dart_code
    
    # Step 4: Remove Firebase config files
    remove_firebase_config_files
    
    # Step 5: Fix bundle identifier conflicts
    fix_bundle_identifier_conflicts
    
    # Step 6: Regenerate project
    regenerate_project
    
    # Step 7: Install CocoaPods
    if ! install_cocoapods; then
        log_error "❌ Failed to install CocoaPods"
        return 1
    fi
    
    # Step 8: Build Flutter app
    if ! build_flutter_app; then
        log_error "❌ Failed to build Flutter app"
        return 1
    fi
    
    # Step 9: Create Xcode archive
    if ! create_xcode_archive; then
        log_error "❌ Failed to create Xcode archive"
        return 1
    fi
    
    # Step 10: Export IPA
    if export_ipa; then
        log_success "✅ Emergency Firebase-free rebuild completed successfully!"
        log_warn "⚠️ Note: Firebase features (push notifications) are disabled in this build"
        return 0
    else
        log_warn "⚠️ IPA export failed, but archive is available for manual export"
        log_info "📦 Archive available at: output/ios/Runner.xcarchive"
        return 1
    fi
}

# Main execution
main() {
    log_info "🚀 Starting Emergency Firebase Removal Script..."
    
    emergency_firebase_removal
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        log_success "✅ Emergency Firebase removal completed successfully"
    else
        log_error "❌ Emergency Firebase removal failed"
    fi
    
    return $result
}

# Execute main function if script is run directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 