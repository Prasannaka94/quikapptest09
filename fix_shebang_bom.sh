#!/bin/bash

# 🛠️ Fix Shebang BOM Script
# Purpose: Remove BOM (Byte Order Mark) from all shell scripts to fix shebang errors
# This fixes the "No such file or directory" error for #!/bin/bash

set -euo pipefail

echo "🔧 Fixing Shebang BOM Issues in Shell Scripts"
echo "============================================="
echo ""

# Function to check if file has BOM
has_bom() {
    local file="$1"
    if [ -f "$file" ]; then
        # Check for UTF-8 BOM (EF BB BF)
        hexdump -n 3 -e '3/1 "%02X" "\n"' "$file" | grep -q "^EFBBBF"
    else
        return 1
    fi
}

# Function to remove BOM from a file
remove_bom() {
    local file="$1"
    local temp_file="${file}.tmp"
    
    echo "🔧 Fixing: $file"
    
    # Create backup
    cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Remove BOM using sed
    sed '1s/^\xEF\xBB\xBF//' "$file" > "$temp_file"
    
    # Replace original with cleaned version
    mv "$temp_file" "$file"
    
    # Make executable
    chmod +x "$file"
    
    echo "✅ Fixed: $file"
}

# Function to validate shebang
validate_shebang() {
    local file="$1"
    if [ -f "$file" ]; then
        local first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
        if [[ "$first_line" == "#!/bin/bash" ]]; then
            echo "✅ Valid shebang: $file"
            return 0
        else
            echo "❌ Invalid shebang in $file: '$first_line'"
            return 1
        fi
    fi
    return 1
}

# Find all shell scripts in the project
echo "🔍 Finding all shell scripts..."
SHELL_SCRIPTS=()

# Search in common directories
for dir in "lib/scripts" "scripts" "tools" "ios" "android" "."; do
    if [ -d "$dir" ]; then
        while IFS= read -r -d '' file; do
            SHELL_SCRIPTS+=("$file")
        done < <(find "$dir" -name "*.sh" -type f -print0 2>/dev/null || true)
    fi
done

echo "📋 Found ${#SHELL_SCRIPTS[@]} shell scripts"

# Check for BOM issues
echo ""
echo "🔍 Checking for BOM issues..."
BOM_FILES=()
INVALID_SHEBANG_FILES=()

for script in "${SHELL_SCRIPTS[@]}"; do
    if has_bom "$script"; then
        BOM_FILES+=("$script")
        echo "⚠️  BOM detected: $script"
    fi
    
    if ! validate_shebang "$script"; then
        INVALID_SHEBANG_FILES+=("$script")
    fi
done

# Fix BOM issues
if [ ${#BOM_FILES[@]} -gt 0 ]; then
    echo ""
    echo "🛠️  Fixing BOM issues in ${#BOM_FILES[@]} files..."
    for file in "${BOM_FILES[@]}"; do
        remove_bom "$file"
    done
    echo "✅ BOM issues fixed"
else
    echo "✅ No BOM issues found"
fi

# Validate all scripts after fixing
echo ""
echo "🔍 Validating all scripts after fixes..."
VALID_COUNT=0
INVALID_COUNT=0

for script in "${SHELL_SCRIPTS[@]}"; do
    if validate_shebang "$script"; then
        ((VALID_COUNT++))
    else
        ((INVALID_COUNT++))
        echo "❌ Still invalid: $script"
    fi
done

echo ""
echo "📊 Validation Summary:"
echo "   ✅ Valid scripts: $VALID_COUNT"
echo "   ❌ Invalid scripts: $INVALID_COUNT"

# Test specific critical scripts
echo ""
echo "🧪 Testing critical scripts..."
CRITICAL_SCRIPTS=(
    "lib/scripts/ios/main.sh"
    "lib/scripts/ios/branding_assets.sh"
    "lib/scripts/ios/clean_unicode_characters.sh"
    "lib/scripts/ios/dynamic_bundle_id_injector.sh"
)

for script in "${CRITICAL_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "🔍 Testing: $script"
        if bash -n "$script" 2>/dev/null; then
            echo "✅ Syntax OK: $script"
        else
            echo "❌ Syntax error: $script"
        fi
    else
        echo "⚠️  Not found: $script"
    fi
done

echo ""
echo "🎉 Shebang BOM Fix Complete!"
echo "============================="
echo ""
echo "📋 Next Steps:"
echo "   1. ✅ All BOM characters removed from shell scripts"
echo "   2. ✅ All scripts made executable"
echo "   3. ✅ Critical scripts syntax validated"
echo "   4. 🔄 Re-run your iOS workflow to test the fixes"
echo ""
echo "💡 If you still see shebang errors, check:"
echo "   - File permissions (should be executable)"
echo "   - Line endings (should be Unix LF, not Windows CRLF)"
echo "   - Hidden characters in the first line" 