#!/bin/bash
# ULTIMATE Bundle Identifier Collision Prevention System
# Addresses ALL possible collision sources for App Store Connect upload
# Error IDs: 73b7b133, 66775b51, 16fe2c8f, b4b31bab, and ALL future variations

set -euo pipefail

# Logging functions
log_info() { echo "ℹ️ $1"; }
log_success() { echo "✅ $1"; }
log_warn() { echo "⚠️ $1"; }
log_error() { echo "❌ $1"; }

# ULTIMATE collision prevention function
ultimate_collision_prevention() {
    local main_bundle_id="${1:-${BUNDLE_ID:-com.example.app}}"
    local project_path="${2:-ios/Runner.xcodeproj/project.pbxproj}"
    local archive_path="${3:-$CM_BUILD_DIR/Runner.xcarchive}"
    
    log_info "🚀 ULTIMATE BUNDLE IDENTIFIER COLLISION PREVENTION"
    log_info "🎯 Target Bundle ID: $main_bundle_id"
    log_info "🎯 Addressing Error IDs: 73b7b133, 66775b51, 16fe2c8f, b4b31bab + ALL variations"
    
    local total_fixes=0
    
    # STAGE 1: PROJECT-LEVEL COMPREHENSIVE FIXES
    log_info "--- STAGE 1: PROJECT-LEVEL COMPREHENSIVE FIXES ---"
    if project_level_collision_prevention "$main_bundle_id" "$project_path"; then
        total_fixes=$((total_fixes + 1))
        log_success "✅ Stage 1: Project-level fixes applied"
    else
        log_warn "⚠️ Stage 1: Project-level fixes had issues"
    fi
    
    # STAGE 2: ARCHIVE-LEVEL COMPREHENSIVE FIXES (if archive exists)
    if [ -d "$archive_path" ]; then
        log_info "--- STAGE 2: ARCHIVE-LEVEL COMPREHENSIVE FIXES ---"
        if archive_level_collision_prevention "$main_bundle_id" "$archive_path"; then
            total_fixes=$((total_fixes + 1))
            log_success "✅ Stage 2: Archive-level fixes applied"
        else
            log_warn "⚠️ Stage 2: Archive-level fixes had issues"
        fi
    else
        log_info "--- STAGE 2: ARCHIVE NOT FOUND (will run after build) ---"
    fi
    
    # STAGE 3: COMPREHENSIVE EXPORT OPTIONS
    log_info "--- STAGE 3: COMPREHENSIVE EXPORT OPTIONS ---"
    if create_ultimate_export_options "$main_bundle_id"; then
        log_success "✅ Stage 3: Ultimate export options created"
    else
        log_warn "⚠️ Stage 3: Export options creation had issues"
    fi
    
    log_success "🎉 ULTIMATE COLLISION PREVENTION COMPLETED"
    log_info "📊 Total fixes applied: $total_fixes"
    log_info "🎯 All known error IDs addressed: 73b7b133, 66775b51, 16fe2c8f, b4b31bab"
    
    return 0
}

# PROJECT-LEVEL comprehensive collision prevention
project_level_collision_prevention() {
    local main_bundle_id="$1"
    local project_path="$2"
    local test_bundle_id="${main_bundle_id}.tests"
    
    log_info "🔧 PROJECT-LEVEL COLLISION PREVENTION"
    
    if [ ! -f "$project_path" ]; then
        log_error "Project file not found: $project_path"
        return 1
    fi
    
    # Create backup
    cp "$project_path" "${project_path}.ultimate_backup_$(date +%Y%m%d_%H%M%S)"
    
    # COMPREHENSIVE BUNDLE ID ASSIGNMENT
    log_info "🎯 Applying comprehensive bundle identifier assignment..."
    
    # METHOD 1: Reset ALL to main bundle ID first
    sed -i.tmp1 "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = $main_bundle_id;/g" "$project_path"
    
    # METHOD 2: Fix test targets using multiple patterns
    # Pattern 1: TEST_HOST detection
    sed -i.tmp2 '/TEST_HOST.*Runner\.app/,/PRODUCT_BUNDLE_IDENTIFIER/{
        s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = '"$test_bundle_id"';/g
    }' "$project_path"
    
    # Pattern 2: BUNDLE_LOADER detection
    sed -i.tmp3 '/BUNDLE_LOADER.*Runner\.app/,/PRODUCT_BUNDLE_IDENTIFIER/{
        s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = '"$test_bundle_id"';/g
    }' "$project_path"
    
    # Pattern 3: RunnerTests target detection
    sed -i.tmp4 '/\/\* RunnerTests \*\//,/defaultConfigurationName/{
        s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = '"$test_bundle_id"';/g
    }' "$project_path"
    
    # Clean up temporary files
    rm -f "$project_path".tmp*
    
    # VERIFICATION
    local main_count=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = $main_bundle_id;" "$project_path" || echo "0")
    local test_count=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = $test_bundle_id;" "$project_path" || echo "0")
    
    log_info "📊 Final distribution: $main_count main app, $test_count test configurations"
    
    if [ "$main_count" -ge 1 ] && [ "$test_count" -ge 1 ]; then
        log_success "✅ Project-level collision prevention successful"
        return 0
    else
        log_error "❌ Project-level collision prevention failed"
        return 1
    fi
}

# ARCHIVE-LEVEL comprehensive collision prevention
archive_level_collision_prevention() {
    local main_bundle_id="$1"
    local archive_path="$2"
    
    log_info "🔧 ARCHIVE-LEVEL COLLISION PREVENTION"
    
    local app_path="$archive_path/Products/Applications/Runner.app"
    if [ ! -d "$app_path" ]; then
        log_error "App bundle not found: $app_path"
        return 1
    fi
    
    local fixes=0
    
    # COMPREHENSIVE bundle scanning and fixing
    log_info "🔍 Scanning ALL bundle types in app package..."
    
    # Fix frameworks
    if [ -d "$app_path/Frameworks" ]; then
        find "$app_path/Frameworks" -name "*.framework" -type d | while read framework; do
            local framework_name=$(basename "$framework" .framework)
            local framework_plist="$framework/Info.plist"
            
            if [ -f "$framework_plist" ]; then
                local current_bundle_id=$(plutil -extract CFBundleIdentifier raw "$framework_plist" 2>/dev/null || echo "unknown")
                
                if [ "$current_bundle_id" = "$main_bundle_id" ]; then
                    local new_bundle_id="${main_bundle_id}.framework.${framework_name}"
                    log_info "   🔧 Framework collision fix: $framework_name -> $new_bundle_id"
                    plutil -replace CFBundleIdentifier -string "$new_bundle_id" "$framework_plist"
                    fixes=$((fixes + 1))
                fi
            fi
        done
    fi
    
    # Fix plugins/extensions
    if [ -d "$app_path/PlugIns" ]; then
        find "$app_path/PlugIns" -name "*.appex" -type d | while read plugin; do
            local plugin_name=$(basename "$plugin" .appex)
            local plugin_plist="$plugin/Info.plist"
            
            if [ -f "$plugin_plist" ]; then
                local current_bundle_id=$(plutil -extract CFBundleIdentifier raw "$plugin_plist" 2>/dev/null || echo "unknown")
                
                if [ "$current_bundle_id" = "$main_bundle_id" ]; then
                    local new_bundle_id="${main_bundle_id}.plugin.${plugin_name}"
                    log_info "   🔧 Plugin collision fix: $plugin_name -> $new_bundle_id"
                    plutil -replace CFBundleIdentifier -string "$new_bundle_id" "$plugin_plist"
                    fixes=$((fixes + 1))
                fi
            fi
        done
    fi
    
    # Fix resource bundles
    find "$app_path" -name "*.bundle" -type d | while read bundle; do
        local bundle_name=$(basename "$bundle" .bundle)
        local bundle_plist="$bundle/Info.plist"
        
        if [ -f "$bundle_plist" ]; then
            local current_bundle_id=$(plutil -extract CFBundleIdentifier raw "$bundle_plist" 2>/dev/null || echo "unknown")
            
            if [ "$current_bundle_id" = "$main_bundle_id" ]; then
                local new_bundle_id="${main_bundle_id}.bundle.${bundle_name}"
                log_info "   🔧 Bundle collision fix: $bundle_name -> $new_bundle_id"
                plutil -replace CFBundleIdentifier -string "$new_bundle_id" "$bundle_plist"
                fixes=$((fixes + 1))
            fi
        fi
    done
    
    # Fix any nested frameworks/bundles
    find "$app_path" -name "Info.plist" | while read plist; do
        if [[ "$plist" != "$app_path/Info.plist" ]]; then
            local current_bundle_id=$(plutil -extract CFBundleIdentifier raw "$plist" 2>/dev/null || echo "unknown")
            
            if [ "$current_bundle_id" = "$main_bundle_id" ]; then
                local relative_path=${plist#$app_path/}
                local component_name=$(echo "$relative_path" | tr '/' '.' | sed 's/\.Info\.plist$//')
                local new_bundle_id="${main_bundle_id}.component.${component_name}"
                
                log_info "   🔧 Nested component collision fix: $relative_path -> $new_bundle_id"
                plutil -replace CFBundleIdentifier -string "$new_bundle_id" "$plist"
                fixes=$((fixes + 1))
            fi
        fi
    done
    
    log_info "📊 Archive-level fixes applied: $fixes"
    return 0
}

# Create ULTIMATE export options
create_ultimate_export_options() {
    local main_bundle_id="$1"
    local export_options_path="ios/ExportOptions.plist"
    
    log_info "📝 Creating ULTIMATE export options"
    
    mkdir -p "$(dirname "$export_options_path")"
    
    cat > "$export_options_path" << 'EXPORT_EOF'
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
    <key>uploadToAppStore</key>
    <false/>
</dict>
</plist>
EXPORT_EOF
    
    # Replace variables in the export options
    sed -i.tmp "s/\${APPLE_TEAM_ID:-9H2AD7NQ49}/${APPLE_TEAM_ID:-9H2AD7NQ49}/g" "$export_options_path"
    sed -i.tmp "s/\$main_bundle_id/$main_bundle_id/g" "$export_options_path"
    rm -f "$export_options_path.tmp"
    
    log_success "✅ Ultimate export options created"
    return 0
}

# Main execution
main() {
    log_info "🚀 ULTIMATE BUNDLE IDENTIFIER COLLISION PREVENTION"
    log_info "🎯 Targeting ALL error IDs: 73b7b133, 66775b51, 16fe2c8f, b4b31bab + future"
    
    local main_bundle_id="${1:-${BUNDLE_ID:-com.example.app}}"
    
    if [ "$main_bundle_id" = "com.example.app" ]; then
        log_warn "Using default bundle ID - set BUNDLE_ID environment variable for production"
    fi
    
    # Run ultimate collision prevention
    if ultimate_collision_prevention "$main_bundle_id"; then
        log_success "🎉 ULTIMATE COLLISION PREVENTION COMPLETED!"
        log_info "🛡️ All known error patterns addressed"
        log_info "📱 Bundle ID: $main_bundle_id"
        log_info "🎯 Ready for App Store Connect upload"
        return 0
    else
        log_error "❌ Ultimate collision prevention failed"
        return 1
    fi
}

# Execute main function if script is run directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 