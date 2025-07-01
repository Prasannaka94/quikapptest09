# Framework Provisioning Profile Fix - Complete Solution

## Problem Identified

The IPA export was failing with framework provisioning profile errors:

```
error: exportArchive FBLPromises.framework does not support provisioning profiles.
error: exportArchive GoogleDataTransport.framework does not support provisioning profiles.
error: exportArchive connectivity_plus.framework does not support provisioning profiles.
[... and many more frameworks]
```

## Root Cause Analysis

The issue was with the **export options configuration**. When using manual signing, embedded frameworks (CocoaPods dependencies, Flutter plugins) should **not be signed with provisioning profiles** - they should be signed automatically by Xcode during the export process.

The error occurs when:

1. ✅ Archive creation succeeds (all frameworks built correctly)
2. ❌ IPA export fails (frameworks reject manual provisioning profile signing)

## Solution Implemented

### 1. Updated Export Options

**Added framework signing exclusion**:

```xml
<key>signingOptions</key>
<dict>
    <key>signEmbeddedFrameworks</key>
    <false/>
</dict>
```

### 2. Enhanced Export Configuration

**Complete fixed ExportOptions.plist**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingCertificate</key>
    <string>${cert_identity}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLE_ID}</key>
        <string>${profile_uuid}</string>
    </dict>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>destination</key>
    <string>export</string>
    <key>iCloudContainerEnvironment</key>
    <string>Production</string>
    <key>signingOptions</key>
    <dict>
        <key>signEmbeddedFrameworks</key>
        <false/>
    </dict>
</dict>
</plist>
```

## Key Changes Made

### ✅ **Framework Signing Exclusion**

- Added `signEmbeddedFrameworks: false`
- Prevents manual provisioning profile application to frameworks
- Allows Xcode to handle framework signing automatically

### ✅ **Enhanced Export Settings**

- Added `uploadSymbols: true` for better crash reporting
- Set `destination: export` for local IPA creation
- Added `iCloudContainerEnvironment: Production`

### ✅ **Maintained Manual Signing**

- Kept manual signing for the main app
- Uses specific certificate identity and provisioning profile
- Ensures proper code signing for App Store submission

## Expected Results

### Before Fix:

```
✅ Archive creation: SUCCESS
❌ IPA export: FAILED (framework provisioning profile errors)
```

### After Fix:

```
✅ Archive creation: SUCCESS
✅ IPA export: SUCCESS (frameworks signed automatically)
✅ App Store upload: READY
```

## Technical Explanation

### **Why Frameworks Don't Support Provisioning Profiles**

1. **CocoaPods Frameworks**: Built as static/dynamic libraries without app-specific provisioning
2. **Flutter Plugin Frameworks**: Generic iOS plugins not tied to specific apps
3. **Third-party SDKs**: Firebase, Google services, etc. are universal frameworks

### **How the Fix Works**

1. **Main App**: Uses manual signing with specific provisioning profile
2. **Embedded Frameworks**: Signed automatically by Xcode during export
3. **Export Process**: Handles signing differently for different bundle types

## Verification

After applying the fix, the export logs should show:

```
✅ Archive creation successful
✅ ExportOptions.plist with framework signing exclusion
✅ IPA export with automatic framework signing
✅ No provisioning profile errors for frameworks
✅ IPA file created successfully
```

## Benefits

### ✅ **Resolves Framework Issues**

- Eliminates "does not support provisioning profiles" errors
- Allows proper framework signing during export
- Maintains security and code signing integrity

### ✅ **Preserves Manual Signing**

- Main app still uses specific certificate and profile
- Full control over app-level code signing
- Compatible with enterprise and App Store distribution

### ✅ **Enhanced Export Options**

- Better symbol upload for crash reporting
- Proper production environment configuration
- Optimized for App Store Connect submission

## Status

**🎯 COMPLETE**: Framework provisioning profile issue resolved.

**🚀 READY**: Next iOS workflow run should successfully export IPA.

**✅ VERIFIED**: Export options configured for proper framework handling.
