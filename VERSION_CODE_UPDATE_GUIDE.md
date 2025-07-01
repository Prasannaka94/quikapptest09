# Version Code Update from Environment Variables - Enhanced Guide

## 🎯 Overview

The `branding_assets.sh` script now has **enhanced version updating capabilities** with detailed logging, validation, and comprehensive environment variable handling.

## 📋 Environment Variables

### Required Variables for Version Update:

```bash
VERSION_NAME="1.0.6"    # App version (format: X.Y.Z)
VERSION_CODE="51"       # Build number (integer)
```

### Optional Variables (for complete branding):

```bash
BUNDLE_ID="com.yourcompany.yourapp"
APP_NAME="Your App Name"
LOGO_URL="https://example.com/logo.png"
SPLASH_URL="https://example.com/splash.png"
```

## 🔧 Enhanced Features

### 1. Detailed Environment Variable Logging

```bash
🔍 Environment Variables Check:
   VERSION_NAME: 1.0.6
   VERSION_CODE: 51
```

### 2. Version Format Validation

- **VERSION_NAME**: Validates X.Y.Z format (e.g., 1.0.6)
- **VERSION_CODE**: Validates numeric format only
- **Error Handling**: Fails build if invalid format detected

### 3. Before/After Comparison

```bash
📋 Current pubspec.yaml version: 1.0.5+50
✅ Updated pubspec.yaml version
   From: 1.0.5+50
   To:   1.0.6+51
```

### 4. Multi-File Updates

- **pubspec.yaml**: Updates `version: X.Y.Z+BUILD`
- **iOS Info.plist**: Updates `CFBundleShortVersionString` and `CFBundleVersion`
- **Backup Creation**: Creates backups before modification

### 5. Comprehensive Verification

```bash
✅ Version update verified in pubspec.yaml
📋 iOS Version Updated:
   CFBundleShortVersionString: 1.0.6
   CFBundleVersion: 51
```

## 🚀 Usage Examples

### Basic Version Update:

```bash
export VERSION_NAME="1.0.6"
export VERSION_CODE="51"
./lib/scripts/ios/branding_assets.sh
```

### Complete Branding Update:

```bash
export VERSION_NAME="1.0.6"
export VERSION_CODE="51"
export BUNDLE_ID="com.yourcompany.yourapp"
export APP_NAME="Your App Name"
export LOGO_URL="https://example.com/logo.png"
./lib/scripts/ios/branding_assets.sh
```

### In Codemagic.yaml Workflow:

```yaml
environment:
  variables:
    VERSION_NAME: "1.0.6"
    VERSION_CODE: "51"
    BUNDLE_ID: "com.yourcompany.yourapp"
    APP_NAME: "Your App Name"
scripts:
  - name: Setup Branding Assets
    script: ./lib/scripts/ios/branding_assets.sh
```

## 📊 Expected Build Logs

### Successful Version Update:

```
📝 Updating App Version from Environment Variables...
🔍 Environment Variables Check:
   VERSION_NAME: 1.0.6
   VERSION_CODE: 51

📋 Current pubspec.yaml version: 1.0.5+50
✅ Updated pubspec.yaml version
   From: 1.0.5+50
   To:   1.0.6+51
✅ Version update verified in pubspec.yaml

📱 Updating iOS Info.plist version...
✅ iOS Info.plist updated using plutil
📋 iOS Version Updated:
   CFBundleShortVersionString: 1.0.6
   CFBundleVersion: 51

🎉 Version update completed successfully!
```

### When Environment Variables Not Set:

```
📝 Updating App Version from Environment Variables...
🔍 Environment Variables Check:
   VERSION_NAME: <not set>
   VERSION_CODE: <not set>

⚠️ VERSION_NAME or VERSION_CODE not provided
💡 Skipping version update - set environment variables to update version
   Example: VERSION_NAME=1.0.6 VERSION_CODE=51
```

### Enhanced Branding Summary:

```
📊 Branding Summary:
   Bundle ID: com.yourcompany.yourapp
   App Name: Your App Name
   Version (Environment): 1.0.6 (build 51)
   Version (pubspec.yaml): 1.0.6+51
   ✅ Version successfully updated from environment variables
   Logo: downloaded
   Splash: downloaded

📋 Environment Variables Used:
   BUNDLE_ID: com.yourcompany.yourapp
   APP_NAME: Your App Name
   VERSION_NAME: 1.0.6
   VERSION_CODE: 51
   LOGO_URL: https://example.com/logo.png
   SPLASH_URL: <not set>
```

## 🧪 Testing

### Quick Manual Test:

```bash
# Set test environment variables
export VERSION_NAME="1.2.3"
export VERSION_CODE="456"

# Run branding assets script
./lib/scripts/ios/branding_assets.sh

# Check results
grep "^version:" pubspec.yaml
# Should show: version: 1.2.3+456
```

### Comprehensive Test Suite:

```bash
# Run the complete test suite
./test_version_update.sh
```

## 🔍 Validation & Error Handling

### Version Format Validation:

- **Valid**: `1.0.6` (X.Y.Z format)
- **Invalid**: `v1.0.6`, `1.0`, `1.0.6.1`

### Build Number Validation:

- **Valid**: `51`, `123`, `1`
- **Invalid**: `51.0`, `abc`, `v51`

### Error Messages:

```bash
❌ VERSION_CODE must be a number: abc
⚠️ VERSION_NAME format may be invalid: v1.0.6
💡 Expected format: X.Y.Z (e.g., 1.0.6)
```

## 📁 Files Modified

### During Update:

1. **pubspec.yaml**: Version line updated
2. **ios/Runner/Info.plist**: iOS version info updated
3. **Backups Created**:
   - `pubspec.yaml.version.backup`
   - `ios/Runner/Info.plist.version.backup`

### Update Format:

- **pubspec.yaml**: `version: 1.0.6+51`
- **Info.plist**:
  - `CFBundleShortVersionString`: `1.0.6`
  - `CFBundleVersion`: `51`

## 🎯 Integration Points

### In ios-workflow (Codemagic):

```
Stage 4: Branding Assets Setup
  ↓ Reads VERSION_NAME and VERSION_CODE environment variables
  ↓ Updates pubspec.yaml version
  ↓ Updates iOS Info.plist version
  ↓ Validates and reports success
  ↓ Shows comprehensive branding summary
```

### Environment Variable Sources:

- **Codemagic**: Set in workflow environment variables
- **CI/CD**: Set in pipeline configuration
- **Manual**: Export in terminal before running script
- **Script**: Set inline with script execution

## ✅ Success Indicators

Look for these messages in build logs:

- ✅ `Version update verified in pubspec.yaml`
- ✅ `iOS Info.plist updated using plutil`
- ✅ `Version successfully updated from environment variables`
- 📋 Branding summary showing correct version info

## 🔧 Troubleshooting

### Common Issues:

#### Version Not Updating:

- **Check**: Environment variables are set correctly
- **Solution**: Verify `VERSION_NAME` and `VERSION_CODE` are exported

#### Invalid Format Error:

- **Check**: VERSION_NAME follows X.Y.Z format
- **Check**: VERSION_CODE is numeric only
- **Solution**: Fix format and try again

#### iOS Info.plist Not Updated:

- **Check**: File exists at `ios/Runner/Info.plist`
- **Check**: plutil command is available
- **Solution**: Script will fallback to manual update

## 📋 Files Enhanced

- ✅ `lib/scripts/ios/branding_assets.sh` - Enhanced version updating
- ✅ `test_version_update.sh` - Comprehensive test suite
- ✅ `VERSION_CODE_UPDATE_GUIDE.md` - This documentation

**Status**: ✅ **VERSION CODE UPDATING FULLY ENHANCED**  
**Features**: Detailed logging, validation, multi-file updates, comprehensive testing  
**Ready**: Production use with environment variables
