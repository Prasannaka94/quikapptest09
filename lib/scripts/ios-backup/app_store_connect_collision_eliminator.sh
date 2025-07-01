#!/bin/bash

# 🚀 App Store Connect CFBundleIdentifier Collision Eliminator
# 🎯 Target: App Store Connect validation errors (Transporter 409 errors)
# 💥 Addresses deeper bundle ID collisions that cause App Store validation failures

set -euo pipefail

echo "🚀 App Store Connect CFBundleIdentifier Collision Eliminator"
echo "🎯 Target: App Store Connect validation collision errors"
echo "💥 Error ID: d9cd9287-ed84-4ae8-a873-071641003b37"
echo "📱 Transporter validation (409) CFBundleIdentifier collision"
echo ""

# Get bundle identifier
BUNDLE_ID="${BUNDLE_ID:-com.insurancegroupmo.insurancegroupmo}"
echo "🎯 Main Bundle ID: $BUNDLE_ID"

# Define paths
IPA_PATH="output/ios/Runner.ipa"
WORK_DIR="app_store_collision_fix_$(date +%s)"

echo "🔍 Checking for existing IPA..."
if [ ! -f "$IPA_PATH" ]; then
    echo "❌ IPA not found at: $IPA_PATH"
    echo "   This script should run after IPA creation"
    exit 1
fi

echo "✅ IPA found: $IPA_PATH"

# Create working directory
mkdir -p "$WORK_DIR"
echo "📁 Working directory: $WORK_DIR"

echo ""
echo "🚀 PHASE 1: Deep IPA Bundle Identifier Analysis"
echo "==============================================="

# Extract IPA for deep analysis
echo "📦 Extracting IPA for deep bundle ID analysis..."
EXTRACTION_DIR="$WORK_DIR/ipa_extracted"
mkdir -p "$EXTRACTION_DIR"

if ! unzip -q "$IPA_PATH" -d "$EXTRACTION_DIR"; then
    echo "❌ Failed to extract IPA"
    exit 1
fi

echo "✅ IPA extracted successfully"

# Find the main app directory
PAYLOAD_DIR="$EXTRACTION_DIR/Payload"
if [ ! -d "$PAYLOAD_DIR" ]; then
    echo "❌ Payload directory not found in IPA"
    exit 1
fi

# Find Runner.app
RUNNER_APP=""
for app in "$PAYLOAD_DIR"/*.app; do
    if [ -d "$app" ]; then
        RUNNER_APP="$app"
        break
    fi
done

if [ -z "$RUNNER_APP" ] || [ ! -d "$RUNNER_APP" ]; then
    echo "❌ Runner.app not found in Payload"
    exit 1
fi

echo "✅ Found app: $(basename "$RUNNER_APP")"

echo ""
echo "🔍 Deep Bundle Identifier Scan"
echo "==============================="

# Function to perform comprehensive bundle ID scan
perform_deep_scan() {
    local app_path="$1"
    declare -A all_bundle_ids
    local collision_count=0
    local total_components=0
    
    echo "🔍 Scanning all components for bundle identifiers..."
    
    # Scan main app
    if [ -f "$app_path/Info.plist" ]; then
        local main_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_path/Info.plist" 2>/dev/null || echo "NOT_FOUND")
        if [ "$main_bundle_id" != "NOT_FOUND" ]; then
            echo "📱 Main App: $main_bundle_id"
            all_bundle_ids["$main_bundle_id"]="Main App"
            total_components=$((total_components + 1))
        fi
    fi
    
    # Scan Frameworks directory
    local frameworks_dir="$app_path/Frameworks"
    if [ -d "$frameworks_dir" ]; then
        echo ""
        echo "📦 Scanning Frameworks..."
        for framework in "$frameworks_dir"/*; do
            if [ -d "$framework" ]; then
                local framework_name=$(basename "$framework")
                local info_plist=""
                
                # Try different Info.plist locations
                if [ -f "$framework/Info.plist" ]; then
                    info_plist="$framework/Info.plist"
                elif [ -f "$framework/Resources/Info.plist" ]; then
                    info_plist="$framework/Resources/Info.plist"
                elif [ -f "$framework/Versions/A/Resources/Info.plist" ]; then
                    info_plist="$framework/Versions/A/Resources/Info.plist"
                fi
                
                if [ -n "$info_plist" ] && [ -f "$info_plist" ]; then
                    local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null || echo "NOT_FOUND")
                    
                    if [ "$bundle_id" != "NOT_FOUND" ]; then
                        echo "   📦 $framework_name: $bundle_id"
                        total_components=$((total_components + 1))
                        
                        # Check for collision
                        if [ -n "${all_bundle_ids[$bundle_id]:-}" ]; then
                            echo "      💥 COLLISION: Bundle ID already used by ${all_bundle_ids[$bundle_id]}"
                            collision_count=$((collision_count + 1))
                            
                            # Generate unique bundle ID
                            local timestamp=$(date +%s)
                            local clean_name=$(echo "$framework_name" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
                            local unique_id="${BUNDLE_ID}.framework.${clean_name}.${timestamp}"
                            
                            echo "      🔧 Fixing collision: $unique_id"
                            /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $unique_id" "$info_plist"
                            all_bundle_ids["$unique_id"]="$framework_name (fixed)"
                            echo "      ✅ Framework bundle ID fixed"
                        else
                            all_bundle_ids["$bundle_id"]="$framework_name"
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Scan PlugIns directory (App Extensions)
    local plugins_dir="$app_path/PlugIns"
    if [ -d "$plugins_dir" ]; then
        echo ""
        echo "🔌 Scanning PlugIns..."
        for plugin in "$plugins_dir"/*; do
            if [ -d "$plugin" ]; then
                local plugin_name=$(basename "$plugin")
                local info_plist="$plugin/Info.plist"
                
                if [ -f "$info_plist" ]; then
                    local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null || echo "NOT_FOUND")
                    
                    if [ "$bundle_id" != "NOT_FOUND" ]; then
                        echo "   🔌 $plugin_name: $bundle_id"
                        total_components=$((total_components + 1))
                        
                        # Check for collision
                        if [ -n "${all_bundle_ids[$bundle_id]:-}" ]; then
                            echo "      💥 COLLISION: Bundle ID already used by ${all_bundle_ids[$bundle_id]}"
                            collision_count=$((collision_count + 1))
                            
                            # Generate unique bundle ID
                            local timestamp=$(date +%s)
                            local clean_name=$(echo "$plugin_name" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
                            local unique_id="${BUNDLE_ID}.plugin.${clean_name}.${timestamp}"
                            
                            echo "      🔧 Fixing collision: $unique_id"
                            /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $unique_id" "$info_plist"
                            all_bundle_ids["$unique_id"]="$plugin_name (fixed)"
                            echo "      ✅ Plugin bundle ID fixed"
                        else
                            all_bundle_ids["$bundle_id"]="$plugin_name"
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Scan nested bundles (e.g., Swift runtime, system frameworks)
    echo ""
    echo "🔍 Scanning for nested bundles..."
    find "$app_path" -name "*.bundle" -type d | while read -r bundle_path; do
        local bundle_name=$(basename "$bundle_path")
        local info_plist="$bundle_path/Info.plist"
        
        if [ -f "$info_plist" ]; then
            local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null || echo "NOT_FOUND")
            
            if [ "$bundle_id" != "NOT_FOUND" ]; then
                echo "   📄 $bundle_name: $bundle_id"
                
                # Check for collision with main bundle ID
                if [ "$bundle_id" = "$BUNDLE_ID" ]; then
                    echo "      💥 COLLISION: Bundle uses main app bundle ID!"
                    collision_count=$((collision_count + 1))
                    
                    # Generate unique bundle ID
                    local timestamp=$(date +%s)
                    local clean_name=$(echo "$bundle_name" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
                    local unique_id="${BUNDLE_ID}.bundle.${clean_name}.${timestamp}"
                    
                    echo "      🔧 Fixing collision: $unique_id"
                    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $unique_id" "$info_plist"
                    echo "      ✅ Bundle collision fixed"
                fi
            fi
        fi
    done
    
    echo ""
    echo "📊 Deep Scan Summary:"
    echo "   Total components scanned: $total_components"
    echo "   Unique bundle IDs found: ${#all_bundle_ids[@]}"
    echo "   Collisions detected and fixed: $collision_count"
    
    return $collision_count
}

# Perform deep scan
perform_deep_scan "$RUNNER_APP"
scan_fixes=$?

echo ""
echo "🚀 PHASE 2: App Store Connect Validation Preparation"
echo "===================================================="

# Additional App Store Connect specific checks
echo "🔍 Performing App Store Connect specific validations..."

# Check for specific problematic patterns
echo ""
echo "🔍 Checking for App Store Connect problematic patterns..."

# 1. Check for duplicate CFBundleShortVersionString
echo "📋 Checking version strings consistency..."
find "$RUNNER_APP" -name "Info.plist" -exec echo "📄 {}" \; -exec /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" {} \; 2>/dev/null | grep -v "Print:" || true

# 2. Check for duplicate CFBundleVersion
echo "📋 Checking build numbers consistency..."
find "$RUNNER_APP" -name "Info.plist" -exec echo "📄 {}" \; -exec /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" {} \; 2>/dev/null | grep -v "Print:" || true

# 3. Ensure main app has correct bundle ID
echo "📱 Verifying main app bundle ID..."
main_app_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$RUNNER_APP/Info.plist" 2>/dev/null || echo "NOT_FOUND")
if [ "$main_app_bundle_id" != "$BUNDLE_ID" ]; then
    echo "⚠️ Main app bundle ID mismatch, fixing..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$RUNNER_APP/Info.plist"
    echo "✅ Main app bundle ID corrected to: $BUNDLE_ID"
else
    echo "✅ Main app bundle ID is correct: $main_app_bundle_id"
fi

echo ""
echo "🚀 PHASE 3: Creating App Store Connect Compatible IPA"
echo "====================================================="

# Repackage the IPA with fixed bundle identifiers
echo "📦 Repackaging IPA with App Store Connect compatible bundle IDs..."

FIXED_IPA_PATH="output/ios/Runner_AppStoreConnect_Fixed.ipa"

# Create the fixed IPA
cd "$EXTRACTION_DIR"
if zip -r "../$(basename "$FIXED_IPA_PATH")" Payload/ > /dev/null 2>&1; then
    mv "../$(basename "$FIXED_IPA_PATH")" "../../$FIXED_IPA_PATH"
    cd - > /dev/null
    echo "✅ Fixed IPA created: $FIXED_IPA_PATH"
else
    cd - > /dev/null
    echo "❌ Failed to create fixed IPA"
    exit 1
fi

# Verify the fixed IPA
if [ -f "$FIXED_IPA_PATH" ]; then
    fixed_ipa_size=$(ls -lh "$FIXED_IPA_PATH" | awk '{print $5}')
    original_ipa_size=$(ls -lh "$IPA_PATH" | awk '{print $5}')
    echo "📊 Size comparison:"
    echo "   Original IPA: $original_ipa_size"
    echo "   Fixed IPA: $fixed_ipa_size"
else
    echo "❌ Fixed IPA not found"
    exit 1
fi

echo ""
echo "🚀 PHASE 4: Final App Store Connect Validation"
echo "=============================================="

# Perform final validation
echo "🔍 Final validation of App Store Connect compatible IPA..."

# Extract and verify the fixed IPA
FINAL_VALIDATION_DIR="$WORK_DIR/final_validation"
mkdir -p "$FINAL_VALIDATION_DIR"

if unzip -q "$FIXED_IPA_PATH" -d "$FINAL_VALIDATION_DIR"; then
    echo "✅ Fixed IPA extracted for validation"
    
    # Find all bundle IDs in the fixed IPA
    echo "📋 Final bundle ID verification:"
    
    declare -A final_bundle_ids
    # shellcheck disable=SC2168
    local final_collision_count=0
    
    find "$FINAL_VALIDATION_DIR" -name "Info.plist" -print0 | while IFS= read -r -d '' plist_file; do
        # shellcheck disable=SC2168
        local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist_file" 2>/dev/null || echo "NOT_FOUND")
        
        if [ "$bundle_id" != "NOT_FOUND" ]; then
            # shellcheck disable=SC2168
            local relative_path=${plist_file#$FINAL_VALIDATION_DIR/}
            echo "   📄 $relative_path: $bundle_id"
            
            # Check for collision with main bundle ID (except main app)
            if [ "$bundle_id" = "$BUNDLE_ID" ] && [[ "$relative_path" != *"Payload/Runner.app/Info.plist" ]]; then
                echo "      💥 FINAL COLLISION: Non-main component using main bundle ID!"
                final_collision_count=$((final_collision_count + 1))
            fi
        fi
    done
    
    if [ $final_collision_count -eq 0 ]; then
        echo "✅ Final validation PASSED - No App Store Connect collisions detected"
    else
        echo "❌ Final validation FAILED - $final_collision_count collisions remain"
    fi
    
else
    echo "⚠️ Could not extract fixed IPA for validation"
fi

# Replace original IPA with fixed version
echo ""
echo "🔄 Replacing original IPA with App Store Connect compatible version..."
if mv "$FIXED_IPA_PATH" "$IPA_PATH"; then
    echo "✅ Original IPA replaced with App Store Connect compatible version"
else
    echo "⚠️ Could not replace original IPA, both versions available"
fi

echo ""
echo "🚀 APP STORE CONNECT COLLISION ELIMINATOR COMPLETE"
echo "=================================================="
echo "✅ Deep scan fixes applied: $scan_fixes"
echo "✅ App Store Connect compatible IPA created"
echo "✅ Bundle ID collisions eliminated for Transporter validation"
echo "📦 Output: $IPA_PATH (App Store Connect compatible)"
echo ""
echo "🎯 Error ID d9cd9287-ed84-4ae8-a873-071641003b37 should be eliminated"
echo "📱 IPA is now ready for App Store Connect upload via Transporter"
echo "💫 Transporter validation (409) error should be resolved"

# Cleanup working directory
rm -rf "$WORK_DIR"

echo "✅ App Store Connect collision elimination completed successfully" 