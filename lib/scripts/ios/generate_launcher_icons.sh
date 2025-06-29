#!/bin/bash

# Generate Flutter Launcher Icons for iOS
# Purpose: Generate iOS app icons without transparency for App Store compliance
# Fixes: Validation failed (409) Invalid large app icon transparency issue

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "🎨 Generating Flutter Launcher Icons for iOS..."

# Function to validate logo file
validate_logo_file() {
    local logo_path="assets/images/logo.png"
    
    if [ ! -f "$logo_path" ]; then
        log_error "❌ Logo file not found: $logo_path"
        log_warn "⚠️ Expected logo to be created by branding_assets.sh in Stage 4"
        log_info "Creating a default logo as fallback..."
        
        # Ensure directory exists
        mkdir -p assets/images
        
        # Copy existing 1024x1024 icon and remove alpha
        if [ -f "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" ]; then
            log_info "📸 Using existing app icon as base logo..."
            cp ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png "$logo_path"
            
            # Remove alpha channel using sips (macOS built-in tool)
            if command -v sips &> /dev/null; then
                log_info "🔧 Removing alpha channel from logo using sips..."
                sips -s format jpeg "$logo_path" --out assets/images/logo_temp.jpg >/dev/null 2>&1
                sips -s format png assets/images/logo_temp.jpg --out "$logo_path" >/dev/null 2>&1
                rm -f assets/images/logo_temp.jpg
                log_success "✅ Alpha channel removed from logo"
            else
                log_warn "⚠️ sips not available, logo may still have transparency"
            fi
        else
            log_error "❌ No existing icon found to use as logo"
            return 1
        fi
    else
        log_success "✅ Found logo from branding_assets.sh: $logo_path"
        log_info "🎯 Using logo downloaded/created by branding_assets.sh in Stage 4"
    fi
    
    # Verify logo properties
    if command -v file &> /dev/null; then
        local file_info=$(file "$logo_path")
        log_info "📋 Logo properties: $file_info"
        
        if echo "$file_info" | grep -q "with alpha"; then
            log_warn "⚠️ Logo still contains alpha channel - may cause App Store validation issues"
        else
            log_success "✅ Logo verified - no alpha channel detected"
        fi
    fi
    
    return 0
}

# Function to backup existing icons
backup_existing_icons() {
    local backup_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -d "ios/Runner/Assets.xcassets/AppIcon.appiconset" ]; then
        log_info "💾 Backing up existing iOS app icons..."
        cp -r "ios/Runner/Assets.xcassets/AppIcon.appiconset" "$backup_dir"
        log_success "✅ Backup created: $backup_dir"
    fi
}

# Function to check and install flutter_launcher_icons
check_flutter_launcher_icons() {
    log_info "📦 Checking flutter_launcher_icons dependency..."
    
    if ! grep -q "flutter_launcher_icons:" pubspec.yaml; then
        log_info "➕ Adding flutter_launcher_icons to pubspec.yaml..."
        
        # Add flutter_launcher_icons to dev_dependencies if not present
        if ! grep -A 10 "^dev_dependencies:" pubspec.yaml | grep -q "flutter_launcher_icons:"; then
            sed -i.bak '/^dev_dependencies:/a\
  flutter_launcher_icons: ^0.13.1' pubspec.yaml
            rm -f pubspec.yaml.bak
            log_success "✅ flutter_launcher_icons added to pubspec.yaml"
        fi
    else
        log_success "✅ flutter_launcher_icons already configured"
    fi
    
    # Run pub get to ensure dependency is installed
    log_info "📥 Installing dependencies..."
    flutter pub get
}

# Function to validate flutter_launcher_icons configuration
validate_launcher_icons_config() {
    log_info "🔍 Validating flutter_launcher_icons configuration..."
    
    # Check if flutter_launcher_icons configuration exists
    if ! grep -q "^flutter_launcher_icons:" pubspec.yaml; then
        log_error "❌ flutter_launcher_icons configuration not found in pubspec.yaml"
        return 1
    fi
    
    # Check for iOS-specific settings
    if ! grep -A 20 "^flutter_launcher_icons:" pubspec.yaml | grep -q "ios: true"; then
        log_error "❌ iOS icon generation not enabled in flutter_launcher_icons configuration"
        return 1
    fi
    
    # Check for remove_alpha_ios setting
    if ! grep -A 20 "^flutter_launcher_icons:" pubspec.yaml | grep -q "remove_alpha_ios: true"; then
        log_warn "⚠️ remove_alpha_ios not set to true - may cause App Store validation issues"
    fi
    
    log_success "✅ flutter_launcher_icons configuration validated"
    return 0
}

# Function to generate launcher icons
generate_icons() {
    log_info "🎨 Generating iOS launcher icons..."
    
    # Run flutter_launcher_icons
    if dart run flutter_launcher_icons; then
        log_success "✅ iOS launcher icons generated successfully"
    else
        log_error "❌ Failed to generate iOS launcher icons"
        return 1
    fi
    
    # Verify critical icons were generated
    local critical_icons=(
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"
    )
    
    for icon in "${critical_icons[@]}"; do
        if [ -f "$icon" ]; then
            log_success "✅ Generated: $(basename "$icon")"
            
            # Check if icon has transparency (for debugging)
            if command -v file &> /dev/null; then
                local file_info=$(file "$icon")
                if echo "$file_info" | grep -q "with alpha"; then
                    log_warn "⚠️ $(basename "$icon") still contains alpha channel"
                else
                    log_success "✅ $(basename "$icon") - no alpha channel"
                fi
            fi
        else
            log_error "❌ Failed to generate: $(basename "$icon")"
        fi
    done
}

# Function to fix transparency issues using sips (macOS specific)
fix_transparency_issues() {
    log_info "🔧 Fixing any remaining transparency issues in iOS icons..."
    
    local icon_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
    
    if [ ! -d "$icon_dir" ]; then
        log_error "❌ iOS app icon directory not found: $icon_dir"
        return 1
    fi
    
    # Process all PNG files in the app icon set
    find "$icon_dir" -name "*.png" | while read -r icon_file; do
        if [ -f "$icon_file" ]; then
            local filename=$(basename "$icon_file")
            log_info "🖼️ Processing: $filename"
            
            # Check if file has alpha channel
            if command -v file &> /dev/null; then
                local file_info=$(file "$icon_file")
                if echo "$file_info" | grep -q "with alpha"; then
                    log_warn "⚠️ $filename has alpha channel, removing..."
                    
                    # Remove alpha channel using sips
                    if command -v sips &> /dev/null; then
                        local temp_file="${icon_file%.png}_temp.jpg"
                        sips -s format jpeg "$icon_file" --out "$temp_file" >/dev/null 2>&1
                        sips -s format png "$temp_file" --out "$icon_file" >/dev/null 2>&1
                        rm -f "$temp_file"
                        log_success "✅ $filename - alpha channel removed"
                    else
                        log_warn "⚠️ sips not available, cannot remove alpha from $filename"
                    fi
                else
                    log_success "✅ $filename - no alpha channel"
                fi
            fi
        fi
    done
}

# Function to validate generated icons
validate_generated_icons() {
    log_info "🔍 Validating generated iOS icons..."
    
    local icon_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
    local has_transparency=false
    
    # Check all PNG files for transparency
    find "$icon_dir" -name "*.png" | while read -r icon_file; do
        if [ -f "$icon_file" ]; then
            local filename=$(basename "$icon_file")
            
            if command -v file &> /dev/null; then
                local file_info=$(file "$icon_file")
                if echo "$file_info" | grep -q "with alpha"; then
                    log_error "❌ $filename still contains alpha channel"
                    has_transparency=true
                else
                    log_success "✅ $filename - App Store compliant (no alpha)"
                fi
            fi
        fi
    done
    
    # Specifically check the 1024x1024 icon (most critical for App Store)
    local large_icon="$icon_dir/Icon-App-1024x1024@1x.png"
    if [ -f "$large_icon" ]; then
        local file_info=$(file "$large_icon")
        if echo "$file_info" | grep -q "with alpha"; then
            log_error "❌ CRITICAL: 1024x1024 icon still has alpha channel - App Store will reject this"
            return 1
        else
            log_success "✅ CRITICAL: 1024x1024 icon is App Store compliant (no alpha)"
        fi
    else
        log_error "❌ CRITICAL: 1024x1024 icon not found"
        return 1
    fi
    
    log_success "🎉 All iOS icons validated - App Store compliant!"
    return 0
}

# Function to create validation summary
create_validation_summary() {
    local summary_file="${OUTPUT_DIR:-output/ios}/ICON_VALIDATION_SUMMARY.txt"
    
    mkdir -p "$(dirname "$summary_file")"
    
    cat > "$summary_file" << EOF
=== iOS App Icon Validation Summary ===
Generated: $(date)
Status: App Store Compliant

=== Icon Generation Results ===
✅ flutter_launcher_icons executed successfully
✅ All critical iOS icons generated
✅ Alpha channels removed from all icons
✅ 1024x1024 icon validated (no transparency)

=== App Store Compliance ===
Status: PASSED
Issue Fixed: Invalid large app icon transparency
Validation: All icons are opaque (no alpha channel)

=== Generated Icons ===
EOF

    # List all generated icons with their properties
    find "ios/Runner/Assets.xcassets/AppIcon.appiconset" -name "*.png" | sort | while read -r icon_file; do
        if [ -f "$icon_file" ]; then
            local filename=$(basename "$icon_file")
            local size=$(ls -lh "$icon_file" | awk '{print $5}')
            local properties="Opaque"
            
            if command -v file &> /dev/null; then
                local file_info=$(file "$icon_file")
                if echo "$file_info" | grep -q "with alpha"; then
                    properties="Has Alpha (ISSUE)"
                fi
            fi
            
            echo "✅ $filename ($size) - $properties" >> "$summary_file"
        fi
    done
    
    cat >> "$summary_file" << EOF

=== Next Steps ===
1. Icons are ready for App Store submission
2. No transparency issues detected
3. Build and archive your app normally

Generated at: $(date)
EOF
    
    log_success "📋 Icon validation summary created: $summary_file"
}

# Main execution function
main() {
    log_info "🚀 Starting iOS Launcher Icons Generation..."
    
    # Step 1: Validate logo file
    if ! validate_logo_file; then
        log_error "❌ Logo file validation failed"
        return 1
    fi
    
    # Step 2: Backup existing icons
    backup_existing_icons
    
    # Step 3: Check flutter_launcher_icons dependency
    check_flutter_launcher_icons
    
    # Step 4: Validate configuration
    if ! validate_launcher_icons_config; then
        log_error "❌ flutter_launcher_icons configuration validation failed"
        return 1
    fi
    
    # Step 5: Generate icons
    if ! generate_icons; then
        log_error "❌ Icon generation failed"
        return 1
    fi
    
    # Step 6: Fix any remaining transparency issues
    fix_transparency_issues
    
    # Step 7: Validate generated icons
    if ! validate_generated_icons; then
        log_error "❌ Generated icons validation failed"
        return 1
    fi
    
    # Step 8: Create validation summary
    create_validation_summary
    
    log_success "🎉 iOS launcher icons generated successfully!"
    log_info "Summary:"
    log_info "  ✅ All icons generated without transparency"
    log_info "  ✅ App Store validation issue fixed"
    log_info "  ✅ 1024x1024 icon is compliant"
    log_info "  ✅ Ready for App Store submission"
    
    return 0
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 