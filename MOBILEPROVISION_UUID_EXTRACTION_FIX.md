# Mobileprovision UUID Extraction Fix - Complete Solution

## Problem Identified

The iOS workflow was failing during IPA export with the error:

```
❌ No provisioning profile UUID available
❌ Comprehensive certificate validation should have extracted UUID
```

## Root Cause Analysis

The issue was that the `MOBILEPROVISION_UUID` environment variable was not being properly passed from the comprehensive certificate validation script back to the main workflow script. This happened because:

1. **Environment Variable Scope**: Variables exported within a subshell (called script) are not automatically available to the parent shell
2. **Missing UUID Capture**: The main workflow wasn't capturing the UUID output from the certificate validation script
3. **No Fallback Mechanism**: There was no fallback method to extract the UUID if the primary method failed

## Solution Implemented

### 1. Enhanced UUID Extraction in Main Workflow

**Added comprehensive UUID capture logic**:

```bash
# Run validation and capture output
if "${SCRIPT_DIR}/comprehensive_certificate_validation.sh" 2>&1 | tee /tmp/cert_validation.log; then
    # Extract UUID from the log
    local extracted_uuid
    extracted_uuid=$(grep -o "UUID: [A-F0-9-]*" /tmp/cert_validation.log | head -1 | cut -d' ' -f2)

    # If not found in log, try to extract from MOBILEPROVISION_UUID= format
    if [ -z "$extracted_uuid" ]; then
        extracted_uuid=$(grep -o "MOBILEPROVISION_UUID=[A-F0-9-]*" /tmp/cert_validation.log | head -1 | cut -d'=' -f2)
    fi
fi
```

### 2. Enhanced UUID Output in Certificate Validation Script

**Added multiple UUID output formats**:

```bash
# Output UUID in a format that can be captured by parent script
echo "UUID: $profile_uuid" >&2
echo "MOBILEPROVISION_UUID=$profile_uuid" >&2
```

### 3. Fallback UUID Extraction Method

**Added direct profile download and UUID extraction**:

```bash
# Fallback: try to extract UUID directly from the profile
log_info "🔄 Fallback: Extracting UUID directly from profile..."
local profile_file="/tmp/profile.mobileprovision"

if curl -fsSL -o "$profile_file" "${PROFILE_URL}" 2>/dev/null; then
    local fallback_uuid
    fallback_uuid=$(security cms -D -i "$profile_file" 2>/dev/null | plutil -extract UUID xml1 -o - - 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | head -1)

    if [ -n "$fallback_uuid" ]; then
        export MOBILEPROVISION_UUID="$fallback_uuid"
        log_success "✅ Extracted UUID via fallback method: $fallback_uuid"
    fi
fi
```

## Key Improvements

### 1. Multiple UUID Capture Methods

- **Primary**: Extract from certificate validation log output
- **Secondary**: Extract from MOBILEPROVISION_UUID= format
- **Fallback**: Direct profile download and UUID extraction

### 2. Robust Error Handling

- Graceful degradation if primary method fails
- Clear logging of which method succeeded
- Detailed error messages for troubleshooting

### 3. Enhanced Logging

- Captures all certificate validation output
- Logs UUID extraction attempts and results
- Provides clear status updates

## Benefits

### ✅ Reliable UUID Extraction

- Multiple capture methods ensure UUID is always extracted
- Fallback mechanism handles edge cases
- Clear logging for troubleshooting

### ✅ Improved Workflow Reliability

- No more "No provisioning profile UUID available" errors
- Consistent UUID availability for IPA export
- Better error handling and recovery

### ✅ Enhanced Debugging

- Detailed logs show exactly how UUID was extracted
- Clear indication of which method succeeded
- Easy troubleshooting if issues occur

## Usage

The fix is automatically applied when running the iOS workflow:

```bash
# Run the updated iOS workflow
./lib/scripts/ios/main.sh
```

The workflow will now:

1. ✅ Run comprehensive certificate validation
2. ✅ Capture UUID using multiple methods
3. ✅ Export UUID for IPA export stage
4. ✅ Provide detailed logging of the process

## Expected Output

With the fix applied, you should see:

```
🔒 Running comprehensive certificate validation...
✅ Comprehensive certificate validation completed successfully
🔍 Extracting provisioning profile UUID...
✅ Extracted UUID from validation log: 12345678-1234-1234-1234-123456789012
📋 Certificate Status:
   - Provisioning Profile UUID: 12345678-1234-1234-1234-123456789012
```

## Verification

To verify the fix is working:

1. **Check UUID Extraction**:

   ```bash
   echo "MOBILEPROVISION_UUID: ${MOBILEPROVISION_UUID:-not_set}"
   ```

2. **Check Certificate Validation Log**:

   ```bash
   cat /tmp/cert_validation.log
   ```

3. **Verify IPA Export Stage**:
   ```bash
   # The IPA export stage should now have access to MOBILEPROVISION_UUID
   ```

## Conclusion

This fix resolves the UUID extraction issue that was preventing successful IPA export. The workflow now reliably captures the provisioning profile UUID using multiple methods and ensures it's available for the IPA export stage.

**Status**: ✅ **COMPLETE** - Ready for production use
