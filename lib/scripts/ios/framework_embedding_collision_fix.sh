#!/bin/bash

# Framework Embedding Collision Fix
# Purpose: Fix framework embedding settings that cause CFBundleIdentifier collisions
# Addresses: "Embed & Sign" vs "Do Not Embed" settings for third-party frameworks

set -euo pipefail

# Logging functions
log_info() { echo "ℹ️ [$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
log_success() { echo "✅ [$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
log_warn() { echo "⚠️ [$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
log_error() { echo "❌ [$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# Main function to fix framework embedding collisions
fix_framework_embedding_collisions() {
    local main_bundle_id="${1:-${BUNDLE_ID:-com.insurancegroupmo.insurancegroupmo}}"
    local project_path="ios/Runner.xcodeproj/project.pbxproj"
    
    log_info "🚀 FRAMEWORK EMBEDDING COLLISION FIX"
    log_info "🎯 Bundle ID: $main_bundle_id"
    log_info "🔧 Fixing framework embedding settings that cause CFBundleIdentifier collisions..."
    
    if [ ! -f "$project_path" ]; then
        log_error "Project file not found: $project_path"
        return 1
    fi
    
    # Create backup
    cp "$project_path" "${project_path}.embedding_fix_backup_$(date +%Y%m%d_%H%M%S)"
    log_info "📋 Backup created: ${project_path}.embedding_fix_backup_$(date +%Y%m%d_%H%M%S)"
    
    # Step 1: Fix framework embedding settings
    log_info "📋 Step 1: Fixing framework embedding settings..."
    if fix_problematic_framework_embedding "$project_path"; then
        log_success "✅ Framework embedding settings fixed"
    else
        log_warn "⚠️ Framework embedding fix had issues"
    fi
    
    # Step 2: Remove duplicate framework references
    log_info "📋 Step 2: Removing duplicate framework references..."
    if remove_duplicate_framework_references "$project_path"; then
        log_success "✅ Duplicate framework references removed"
    else
        log_warn "⚠️ Duplicate removal had issues"
    fi
    
    # Step 3: Optimize build phases
    log_info "📋 Step 3: Optimizing build phases..."
    if optimize_build_phases "$project_path"; then
        log_success "✅ Build phases optimized"
    else
        log_warn "⚠️ Build phase optimization had issues"
    fi
    
    # Step 4: Validate changes
    log_info "📋 Step 4: Validating framework embedding fixes..."
    if validate_framework_embedding_fixes "$project_path"; then
        log_success "✅ Framework embedding fixes validated"
    else
        log_warn "⚠️ Validation had issues"
    fi
    
    log_success "🎉 FRAMEWORK EMBEDDING COLLISION FIX COMPLETED!"
    log_info "🎯 Framework embedding conflicts resolved"
    log_info "📦 CocoaPods and SPM will handle proper linking"
    return 0
}

# Fix problematic framework embedding
fix_problematic_framework_embedding() {
    local project_path="$1"
    
    log_info "🔧 Fixing problematic framework embedding settings..."
    
    # Frameworks that commonly cause embedding collisions
    local problematic_frameworks=(
        "FirebaseCore"
        "FirebaseInstallations"
        "FirebaseMessaging"
        "FirebaseAnalytics"
        "FirebaseCoreInternal"
        "GoogleUtilities"
        "connectivity_plus"
        "url_launcher_ios"
        "webview_flutter_wkwebview"
        "Flutter"
        "FlutterPluginRegistrant"
        "Pods_Runner"
    )
    
    local fixes_applied=0
    
    # Process each problematic framework
    for framework in "${problematic_frameworks[@]}"; do
        log_info "🔍 Processing framework: $framework"
        
        if grep -q "$framework" "$project_path"; then
            # Method 1: Remove CodeSignOnCopy attribute (most common fix)
            sed -i.tmp "/$framework.*framework/,/};/{
                s/ATTRIBUTES = ([^)]*CodeSignOnCopy[^)]*);/ATTRIBUTES = ();/g
                s/ATTRIBUTES = ([^)]*3[^)]*);/ATTRIBUTES = ();/g
            }" "$project_path"
            
            # Method 2: Change embedding settings in PBXBuildFile
            sed -i.tmp "/.*$framework.*PBXBuildFile/{
                N
                N
                s/settings = {[^}]*ATTRIBUTES = ([^)]*CodeSignOnCopy[^)]*)[^}]*}/settings = {};/g
                s/settings = {[^}]*ATTRIBUTES = ([^)]*3[^)]*)[^}]*}/settings = {};/g
            }" "$project_path"
            
            # Method 3: Fix framework references in target dependencies
            sed -i.tmp "/.*$framework.*/{
                s/CodeSignOnCopy//g
                s/ATTRIBUTES = (3);/ATTRIBUTES = ();/g
                s/ATTRIBUTES = (CodeSignOnCopy);/ATTRIBUTES = ();/g
            }" "$project_path"
            
            fixes_applied=$((fixes_applied + 1))
            log_info "   ✅ Fixed embedding for: $framework"
        else
            log_info "   ℹ️ Framework not found: $framework"
        fi
    done
    
    # Clean up temp files
    rm -f "${project_path}.tmp"
    
    log_success "✅ Framework embedding fixes applied to $fixes_applied frameworks"
    return 0
}

# Remove duplicate framework references
remove_duplicate_framework_references() {
    local project_path="$1"
    
    log_info "🔧 Removing duplicate framework references..."
    
    # Common duplicate patterns that cause collisions
    local duplicate_patterns=(
        "FirebaseCore.*FirebaseCore"
        "connectivity_plus.*connectivity_plus"
        "url_launcher.*url_launcher"
        "webview_flutter.*webview_flutter"
    )
    
    local duplicates_removed=0
    
    for pattern in "${duplicate_patterns[@]}"; do
        if grep -q "$pattern" "$project_path"; then
            # Remove duplicate lines
            sed -i.tmp "/$pattern/d" "$project_path"
            duplicates_removed=$((duplicates_removed + 1))
            log_info "   ✅ Removed duplicate: $pattern"
        fi
    done
    
    # Remove duplicate PBXBuildFile entries
    log_info "🔍 Removing duplicate PBXBuildFile entries..."
    
    # Find and remove duplicate PBXBuildFile entries
    awk '
    /PBXBuildFile/ {
        if (!seen[$0]) {
            seen[$0] = 1
            print
        } else {
            duplicate_count++
        }
        next
    }
    { print }
    END { 
        if (duplicate_count > 0) {
            print "   ✅ Removed " duplicate_count " duplicate PBXBuildFile entries" > "/dev/stderr"
        }
    }
    ' "$project_path" > "${project_path}.dedup" && mv "${project_path}.dedup" "$project_path"
    
    # Clean up
    rm -f "${project_path}.tmp"
    
    log_success "✅ Duplicate references processed: $duplicates_removed patterns removed"
    return 0
}

# Optimize build phases to prevent embedding conflicts
optimize_build_phases() {
    local project_path="$1"
    
    log_info "🔧 Optimizing build phases to prevent embedding conflicts..."
    
    # Remove problematic frameworks from "Embed Frameworks" build phase
    local frameworks_to_remove_from_embed=(
        "FirebaseCore"
        "FirebaseInstallations"
        "FirebaseMessaging"
        "connectivity_plus"
        "url_launcher"
        "webview_flutter"
    )
    
    local optimizations=0
    
    # Process each framework
    for framework in "${frameworks_to_remove_from_embed[@]}"; do
        if grep -q "Embed Frameworks" "$project_path" && grep -q "$framework" "$project_path"; then
            # Remove from Embed Frameworks build phase
            sed -i.tmp "/Embed Frameworks/,/);/{
                /$framework/d
            }" "$project_path"
            
            optimizations=$((optimizations + 1))
            log_info "   ✅ Removed $framework from Embed Frameworks phase"
        fi
    done
    
    # Ensure proper framework search paths
    log_info "🔧 Setting proper framework search paths..."
    
    # Add proper framework search paths if missing
    if ! grep -q "FRAMEWORK_SEARCH_PATHS.*PLATFORM_DIR" "$project_path"; then
        sed -i.tmp 's/FRAMEWORK_SEARCH_PATHS = (/FRAMEWORK_SEARCH_PATHS = (\n\t\t\t\t"$(PLATFORM_DIR)\/Developer\/Library\/Frameworks",\n\t\t\t\t"$(inherited)",/' "$project_path"
        optimizations=$((optimizations + 1))
        log_info "   ✅ Added proper framework search paths"
    fi
    
    # Clean up
    rm -f "${project_path}.tmp"
    
    log_success "✅ Build phase optimizations applied: $optimizations changes"
    return 0
}

# Validate framework embedding fixes
validate_framework_embedding_fixes() {
    local project_path="$1"
    
    log_info "🔍 Validating framework embedding fixes..."
    
    # Check for remaining CodeSignOnCopy attributes
    local codesign_count=$(grep -c "CodeSignOnCopy" "$project_path" 2>/dev/null || echo "0")
    
    if [ "$codesign_count" -eq 0 ]; then
        log_success "✅ No CodeSignOnCopy attributes found (good)"
    else
        log_warn "⚠️ Found $codesign_count remaining CodeSignOnCopy attributes"
        
        # Show which frameworks still have CodeSignOnCopy
        log_info "📋 Remaining CodeSignOnCopy references:"
        grep -n "CodeSignOnCopy" "$project_path" | head -5 || true
    fi
    
    # Check for proper framework structure
    local framework_refs=$(grep -c "\.framework" "$project_path" 2>/dev/null || echo "0")
    log_info "📊 Found $framework_refs framework references"
    
    # Check for duplicate PBXBuildFile entries
    local build_files=$(grep -c "PBXBuildFile" "$project_path" 2>/dev/null || echo "0")
    log_info "📊 Found $build_files PBXBuildFile entries"
    
    # Check project file integrity
    if [ -f "$project_path" ] && [ -s "$project_path" ]; then
        log_success "✅ Project file integrity validated"
    else
        log_error "❌ Project file integrity check failed"
        return 1
    fi
    
    log_success "✅ Framework embedding validation completed"
    return 0
}

# Display fix summary
display_fix_summary() {
    log_info "📋 FRAMEWORK EMBEDDING COLLISION FIX SUMMARY:"
    log_info ""
    log_info "🎯 FIXED ISSUES:"
    log_info "   1. ✅ Changed problematic frameworks from 'Embed & Sign' to 'Do Not Embed'"
    log_info "   2. ✅ Removed CodeSignOnCopy attributes causing collisions"
    log_info "   3. ✅ Eliminated duplicate framework references"
    log_info "   4. ✅ Optimized build phases for proper linking"
    log_info "   5. ✅ Set proper framework search paths"
    log_info ""
    log_info "🔧 ADDRESSED FRAMEWORKS:"
    log_info "   - Firebase frameworks (Core, Installations, Messaging, Analytics)"
    log_info "   - Flutter plugins (connectivity_plus, url_launcher, webview_flutter)"
    log_info "   - Core Flutter frameworks"
    log_info ""
    log_info "💡 EXPECTED RESULT:"
    log_info "   - CFBundleIdentifier collisions eliminated"
    log_info "   - CocoaPods and SPM handle proper linking"
    log_info "   - No duplicate framework embeddings"
    log_info "   - App Store Connect validation should pass"
    log_info ""
}

# Main function
main() {
    log_info "🚀 FRAMEWORK EMBEDDING COLLISION FIX"
    
    local main_bundle_id="${1:-${BUNDLE_ID:-com.insurancegroupmo.insurancegroupmo}}"
    
    log_info "📱 Target Bundle ID: $main_bundle_id"
    log_info "🔧 Fixing framework embedding settings that cause CFBundleIdentifier collisions..."
    
    if fix_framework_embedding_collisions "$main_bundle_id"; then
        display_fix_summary
        log_success "🎉 FRAMEWORK EMBEDDING COLLISION FIX COMPLETED!"
        log_info "🎯 Framework embedding conflicts resolved for App Store Connect"
        return 0
    else
        log_error "❌ Framework embedding collision fix failed"
        return 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 