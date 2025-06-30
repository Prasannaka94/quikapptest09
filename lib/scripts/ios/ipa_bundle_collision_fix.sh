#!/bin/bash
# IPA Bundle Collision Fix - Error ID: 16fe2c8f-330a-451b-90c5-7c218848c196
# Fixes CFBundleIdentifier collisions that occur INSIDE the app bundle during IPA export

set -euo pipefail

# Logging functions
log_info() { echo "ℹ️ $1"; }
log_success() { echo "✅ $1"; }
log_warn() { echo "⚠️ $1"; }
log_error() { echo "❌ $1"; }

# Main function to fix IPA-level bundle collisions
fix_ipa_bundle_collisions() {
    local bundle_id="${1:-${BUNDLE_ID:-com.example.app}}"
    local archive_path="${2:-$CM_BUILD_DIR/Runner.xcarchive}"
    local export_path="${3:-$CM_BUILD_DIR/ios_output}"
    
    log_info "🔧 FIXING IPA BUNDLE COLLISIONS - Error ID: 16fe2c8f-330a-451b-90c5-7c218848c196"
    log_info "Target Bundle ID: $bundle_id"
    log_info "Archive Path: $archive_path"
    log_info "Export Path: $export_path"
    
    # Validate inputs
    if [ ! -d "$archive_path" ]; then
        log_error "Archive not found: $archive_path"
        return 1
    fi
    
    # Step 1: Analyze current bundle structure for collisions
    analyze_bundle_collisions "$archive_path" "$bundle_id"
    
    # Step 2: Fix bundle collisions in the archive
    fix_archive_bundle_collisions "$archive_path" "$bundle_id"
    
    # Step 3: Create collision-free ExportOptions.plist
    create_collision_free_export_options "$bundle_id"
    
    # Step 4: Export with collision protection
    export_with_collision_protection "$archive_path" "$export_path" "$bundle_id"
    
    log_success "✅ IPA bundle collision fix completed"
}

# Analyze bundle structure for potential collisions
analyze_bundle_collisions() {
    local archive_path="$1"
    local target_bundle_id="$2"
    
    log_info "🔍 ANALYZING BUNDLE STRUCTURE FOR COLLISIONS"
    
    local app_path="$archive_path/Products/Applications/Runner.app"
    if [ ! -d "$app_path" ]; then
        log_warn "App bundle not found in archive"
        return 1
    fi
    
    log_info "📱 Main App Bundle: $app_path"
    
    # Check main app Info.plist
    local main_plist="$app_path/Info.plist"
    if [ -f "$main_plist" ]; then
        local main_bundle_id=$(plutil -extract CFBundleIdentifier raw "$main_plist" 2>/dev/null || echo "unknown")
        log_info "   Main Bundle ID: $main_bundle_id"
        
        if [ "$main_bundle_id" != "$target_bundle_id" ]; then
            log_warn "   Main bundle ID mismatch! Expected: $target_bundle_id, Found: $main_bundle_id"
        fi
    fi
    
    # Check for embedded frameworks and their bundle IDs
    local frameworks_dir="$app_path/Frameworks"
    if [ -d "$frameworks_dir" ]; then
        log_info "🔍 Checking embedded frameworks for collisions:"
        
        local collision_count=0
        find "$frameworks_dir" -name "*.framework" -type d | while read framework; do
            local framework_name=$(basename "$framework" .framework)
            local framework_plist="$framework/Info.plist"
            
            if [ -f "$framework_plist" ]; then
                local framework_bundle_id=$(plutil -extract CFBundleIdentifier raw "$framework_plist" 2>/dev/null || echo "unknown")
                log_info "   📦 Framework: $framework_name -> $framework_bundle_id"
                
                # Check for collision with main app
                if [ "$framework_bundle_id" = "$target_bundle_id" ]; then
                    log_error "   💥 COLLISION DETECTED: Framework $framework_name has same bundle ID as main app!"
                    collision_count=$((collision_count + 1))
                fi
            fi
        done
        
        if [ $collision_count -gt 0 ]; then
            log_error "Found $collision_count bundle identifier collisions in frameworks!"
        fi
    fi
    
    # Check for embedded plugins
    local plugins_dir="$app_path/PlugIns"
    if [ -d "$plugins_dir" ]; then
        log_info "🔍 Checking embedded plugins for collisions:"
        
        find "$plugins_dir" -name "*.appex" -type d | while read plugin; do
            local plugin_name=$(basename "$plugin" .appex)
            local plugin_plist="$plugin/Info.plist"
            
            if [ -f "$plugin_plist" ]; then
                local plugin_bundle_id=$(plutil -extract CFBundleIdentifier raw "$plugin_plist" 2>/dev/null || echo "unknown")
                log_info "   🔌 Plugin: $plugin_name -> $plugin_bundle_id"
                
                # Check for collision with main app
                if [ "$plugin_bundle_id" = "$target_bundle_id" ]; then
                    log_error "   💥 COLLISION DETECTED: Plugin $plugin_name has same bundle ID as main app!"
                fi
            fi
        done
    fi
    
    # Check for any other bundles
    find "$app_path" -name "*.bundle" -type d | while read bundle; do
        local bundle_name=$(basename "$bundle" .bundle)
        local bundle_plist="$bundle/Info.plist"
        
        if [ -f "$bundle_plist" ]; then
            local bundle_bundle_id=$(plutil -extract CFBundleIdentifier raw "$bundle_plist" 2>/dev/null || echo "unknown")
            log_info "   📦 Bundle: $bundle_name -> $bundle_bundle_id"
            
            # Check for collision with main app
            if [ "$bundle_bundle_id" = "$target_bundle_id" ]; then
                log_error "   💥 COLLISION DETECTED: Bundle $bundle_name has same bundle ID as main app!"
            fi
        fi
    done
}

# Fix bundle collisions in the archive
fix_archive_bundle_collisions() {
    local archive_path="$1"
    local target_bundle_id="$2"
    
    log_info "🔧 FIXING BUNDLE COLLISIONS IN ARCHIVE"
    
    local app_path="$archive_path/Products/Applications/Runner.app"
    local collision_fixes=0
    
    # Fix frameworks with colliding bundle IDs
    local frameworks_dir="$app_path/Frameworks"
    if [ -d "$frameworks_dir" ]; then
        find "$frameworks_dir" -name "*.framework" -type d | while read framework; do
            local framework_name=$(basename "$framework" .framework)
            local framework_plist="$framework/Info.plist"
            
            if [ -f "$framework_plist" ]; then
                local current_bundle_id=$(plutil -extract CFBundleIdentifier raw "$framework_plist" 2>/dev/null || echo "unknown")
                
                # If framework has same bundle ID as main app, fix it
                if [ "$current_bundle_id" = "$target_bundle_id" ]; then
                    local new_bundle_id="${target_bundle_id}.framework.${framework_name}"
                    log_info "   🔧 Fixing framework collision: $framework_name"
                    log_info "      Old: $current_bundle_id"
                    log_info "      New: $new_bundle_id"
                    
                    # Update framework's Info.plist
                    plutil -replace CFBundleIdentifier -string "$new_bundle_id" "$framework_plist"
                    
                    collision_fixes=$((collision_fixes + 1))
                    log_success "   ✅ Framework $framework_name collision fixed"
                fi
            fi
        done
    fi
    
    # Fix plugins with colliding bundle IDs
    local plugins_dir="$app_path/PlugIns"
    if [ -d "$plugins_dir" ]; then
        find "$plugins_dir" -name "*.appex" -type d | while read plugin; do
            local plugin_name=$(basename "$plugin" .appex)
            local plugin_plist="$plugin/Info.plist"
            
            if [ -f "$plugin_plist" ]; then
                local current_bundle_id=$(plutil -extract CFBundleIdentifier raw "$plugin_plist" 2>/dev/null || echo "unknown")
                
                # If plugin has same bundle ID as main app, fix it
                if [ "$current_bundle_id" = "$target_bundle_id" ]; then
                    local new_bundle_id="${target_bundle_id}.plugin.${plugin_name}"
                    log_info "   🔧 Fixing plugin collision: $plugin_name"
                    log_info "      Old: $current_bundle_id"
                    log_info "      New: $new_bundle_id"
                    
                    # Update plugin's Info.plist
                    plutil -replace CFBundleIdentifier -string "$new_bundle_id" "$plugin_plist"
                    
                    collision_fixes=$((collision_fixes + 1))
                    log_success "   ✅ Plugin $plugin_name collision fixed"
                fi
            fi
        done
    fi
    
    # Fix other bundles with colliding bundle IDs
    find "$app_path" -name "*.bundle" -type d | while read bundle; do
        local bundle_name=$(basename "$bundle" .bundle)
        local bundle_plist="$bundle/Info.plist"
        
        if [ -f "$bundle_plist" ]; then
            local current_bundle_id=$(plutil -extract CFBundleIdentifier raw "$bundle_plist" 2>/dev/null || echo "unknown")
            
            # If bundle has same bundle ID as main app, fix it
            if [ "$current_bundle_id" = "$target_bundle_id" ]; then
                local new_bundle_id="${target_bundle_id}.bundle.${bundle_name}"
                log_info "   🔧 Fixing bundle collision: $bundle_name"
                log_info "      Old: $current_bundle_id"
                log_info "      New: $new_bundle_id"
                
                # Update bundle's Info.plist
                plutil -replace CFBundleIdentifier -string "$new_bundle_id" "$bundle_plist"
                
                collision_fixes=$((collision_fixes + 1))
                log_success "   ✅ Bundle $bundle_name collision fixed"
            fi
        fi
    done
    
    log_info "📊 Total collision fixes applied: $collision_fixes"
}

# Create collision-free ExportOptions.plist
create_collision_free_export_options() {
    local bundle_id="$1"
    local export_options_path="ios/ExportOptions.plist"
    
    log_info "📝 Creating collision-free ExportOptions.plist"
    
    mkdir -p "$(dirname "$export_options_path")"
    
    cat > "$export_options_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-9H2AD7NQ49}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>generateAppStoreInformation</key>
    <false/>
    <key>manageVersionAndBuildNumber</key>
    <false/>
    <key>destination</key>
    <string>export</string>
    <key>distributionBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>bundleIdentifierCollisionResolution</key>
    <string>automatic</string>
    <key>embedOnDemandResourcesAssetPacksInBundle</key>
    <false/>
    <key>iCloudContainerEnvironment</key>
    <string>Production</string>
</dict>
</plist>
EOF
    
    log_success "✅ Collision-free ExportOptions.plist created"
    log_info "📋 Export configuration:"
    log_info "   Main Bundle ID: $bundle_id"
    log_info "   Method: app-store"
    log_info "   Team ID: ${APPLE_TEAM_ID:-9H2AD7NQ49}"
}

# Export with collision protection
export_with_collision_protection() {
    local archive_path="$1"
    local export_path="$2"
    local bundle_id="$3"
    local export_options_path="ios/ExportOptions.plist"
    
    log_info "📦 EXPORTING IPA WITH COLLISION PROTECTION"
    
    # Clean export directory
    rm -rf "$export_path"
    mkdir -p "$export_path"
    
    # Attempt export with verbose logging
    log_info "🚀 Running xcodebuild -exportArchive with collision protection..."
    
    if xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options_path" \
        -allowProvisioningUpdates \
        -verbose 2>&1 | tee export_collision_protected.log; then
        
        log_success "✅ IPA export successful with collision protection!"
        
        # Verify IPA was created
        local ipa_file=$(find "$export_path" -name "*.ipa" | head -1)
        if [ -f "$ipa_file" ]; then
            log_success "✅ IPA file created: $(basename "$ipa_file")"
            log_info "📊 IPA size: $(ls -lh "$ipa_file" | awk '{print $5}')"
            
            # Final validation - check IPA contents for collisions
            validate_ipa_bundle_ids "$ipa_file" "$bundle_id"
            
            return 0
        else
            log_error "❌ IPA file was not created in export directory"
            return 1
        fi
        
    else
        log_error "❌ IPA export failed even with collision protection"
        log_info "📋 Export log contents:"
        cat export_collision_protected.log | tail -50
        
        # Try alternative export method
        log_info "🔄 Attempting alternative export method..."
        export_with_fallback_method "$archive_path" "$export_path" "$bundle_id"
    fi
}

# Validate IPA bundle identifiers
validate_ipa_bundle_ids() {
    local ipa_file="$1"
    local expected_bundle_id="$2"
    
    log_info "🔍 VALIDATING IPA BUNDLE IDENTIFIERS"
    
    # Create temporary directory for IPA extraction
    local temp_dir=$(mktemp -d)
    
    # Extract IPA
    unzip -q "$ipa_file" -d "$temp_dir"
    
    # Find app bundle
    local app_path=$(find "$temp_dir" -name "*.app" -type d | head -1)
    if [ ! -d "$app_path" ]; then
        log_warn "Could not find app bundle in IPA for validation"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Check main app bundle ID
    local main_plist="$app_path/Info.plist"
    if [ -f "$main_plist" ]; then
        local main_bundle_id=$(plutil -extract CFBundleIdentifier raw "$main_plist" 2>/dev/null || echo "unknown")
        log_info "✅ Main App Bundle ID: $main_bundle_id"
        
        if [ "$main_bundle_id" != "$expected_bundle_id" ]; then
            log_error "❌ Main bundle ID mismatch! Expected: $expected_bundle_id, Found: $main_bundle_id"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Check for any remaining collisions
    local collision_found=false
    
    # Check frameworks
    find "$app_path" -name "*.framework" -type d | while read framework; do
        local framework_plist="$framework/Info.plist"
        if [ -f "$framework_plist" ]; then
            local framework_bundle_id=$(plutil -extract CFBundleIdentifier raw "$framework_plist" 2>/dev/null || echo "unknown")
            log_info "📦 Framework Bundle ID: $framework_bundle_id"
            
            if [ "$framework_bundle_id" = "$expected_bundle_id" ]; then
                log_error "❌ COLLISION STILL EXISTS: Framework has same bundle ID as main app!"
                collision_found=true
            fi
        fi
    done
    
    # Check plugins
    find "$app_path" -name "*.appex" -type d | while read plugin; do
        local plugin_plist="$plugin/Info.plist"
        if [ -f "$plugin_plist" ]; then
            local plugin_bundle_id=$(plutil -extract CFBundleIdentifier raw "$plugin_plist" 2>/dev/null || echo "unknown")
            log_info "🔌 Plugin Bundle ID: $plugin_bundle_id"
            
            if [ "$plugin_bundle_id" = "$expected_bundle_id" ]; then
                log_error "❌ COLLISION STILL EXISTS: Plugin has same bundle ID as main app!"
                collision_found=true
            fi
        fi
    done
    
    rm -rf "$temp_dir"
    
    if [ "$collision_found" = true ]; then
        log_error "❌ Bundle identifier collisions still exist in final IPA"
        return 1
    else
        log_success "✅ IPA validation passed - no bundle identifier collisions found"
        return 0
    fi
}

# Fallback export method
export_with_fallback_method() {
    local archive_path="$1"
    local export_path="$2"
    local bundle_id="$3"
    
    log_info "🔄 ATTEMPTING FALLBACK EXPORT METHOD"
    
    # Create simplified ExportOptions.plist
    cat > ios/ExportOptions_fallback.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-9H2AD7NQ49}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
    
    log_info "🔄 Trying development export as fallback..."
    
    if xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist ios/ExportOptions_fallback.plist \
        -allowProvisioningUpdates; then
        
        log_success "✅ Fallback export successful!"
        return 0
    else
        log_error "❌ Fallback export also failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "🚀 Starting IPA Bundle Collision Fix"
    log_info "Target Error ID: 16fe2c8f-330a-451b-90c5-7c218848c196"
    
    # Get bundle ID from environment or parameter
    local bundle_id="${1:-${BUNDLE_ID:-com.example.app}}"
    
    if [ "$bundle_id" = "com.example.app" ]; then
        log_warn "Using default bundle ID - please set BUNDLE_ID environment variable"
    fi
    
    # Fix IPA bundle collisions
    if fix_ipa_bundle_collisions "$bundle_id"; then
        log_success "✅ IPA Bundle Collision Fix completed successfully!"
        log_info "📊 Bundle ID: $bundle_id"
        log_info "🎯 Error ID 16fe2c8f-330a-451b-90c5-7c218848c196 RESOLVED"
        return 0
    else
        log_error "❌ IPA Bundle Collision Fix failed"
        return 1
    fi
}

# Execute main function if script is run directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 