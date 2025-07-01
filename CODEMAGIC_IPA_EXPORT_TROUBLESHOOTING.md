# Codemagic IPA Export Troubleshooting Guide

## 🚨 **Current Issue Analysis**

Based on your build log, there are **two critical problems** preventing successful IPA export:

### Issue 1: Invalid Provisioning Profile UUID

```
📱 Using profile UUID: 2
error: exportArchive No "iOS App Store" profiles for team '9H2AD7NQ49' matching '2' are installed.
```

### Issue 2: Missing Apple Developer Account

```
error: exportArchive No Accounts
error: exportArchive No profiles for 'com.insurancegroupmo.insurancegroupmo' were found
```

## 🎯 **Immediate Solutions**

### **Solution A: Add Manual Certificates (Recommended)**

#### 1. Set Required Environment Variables in Codemagic

```yaml
# Essential Certificate Variables
CERT_P12_URL: https://your-secure-repo/ios_distribution_certificate.p12
CERT_PASSWORD: YourP12Password
PROFILE_URL: https://your-secure-repo/app_store_provisioning_profile.mobileprovision

# Already configured (verify these exist)
BUNDLE_ID: com.insurancegroupmo.insurancegroupmo
APPLE_TEAM_ID: 9H2AD7NQ49
PROFILE_TYPE: app-store
```

#### 2. How to Get These Files

**P12 Certificate:**

1. Open Keychain Access on Mac
2. Find "iPhone Distribution: Pixaware Technology Solutions Private Limited"
3. Right-click → Export → Save as .p12 file
4. Set a password (this becomes CERT_PASSWORD)
5. Upload to secure location (GitHub private repo, etc.)

**Provisioning Profile:**

1. Go to Apple Developer Portal
2. Certificates, Identifiers & Profiles
3. Profiles → Distribution
4. Find/Create profile for `com.insurancegroupmo.insurancegroupmo`
5. Download .mobileprovision file
6. Upload to secure location

### **Solution B: Use App Store Connect API Only**

#### Set These Variables in Codemagic

```yaml
# App Store Connect API (Already configured)
APP_STORE_CONNECT_KEY_IDENTIFIER: ZFD9GRMS7R
APP_STORE_CONNECT_API_KEY_PATH: https://raw.githubusercontent.com/prasanna91/QuikApp/main/AuthKey_ZFD9GRMS7R.p8
APP_STORE_CONNECT_ISSUER_ID: a99a2ebd-ed3e-4117-9f97-f195823774a7

# Enable automatic certificate management
USE_AUTOMATIC_SIGNING: true
```

## 🔧 **Step-by-Step Fix**

### Step 1: Immediate Fix - Add Certificate Variables

In your Codemagic `ios-workflow`, add these environment variables:

```yaml
environment:
  vars:
    # ... existing variables ...

    # Add these for manual certificate approach
    CERT_P12_URL: $CERT_P12_URL
    CERT_PASSWORD: $CERT_PASSWORD
    PROFILE_URL: $PROFILE_URL

    # OR enable automatic signing (if you prefer API-only approach)
    USE_AUTOMATIC_SIGNING: true
```

### Step 2: Set the Variables in Codemagic UI

1. Go to your Codemagic project
2. Click on `ios-workflow`
3. Environment variables section
4. Add:
   - `CERT_P12_URL`: Your P12 certificate URL
   - `CERT_PASSWORD`: Your P12 password
   - `PROFILE_URL`: Your provisioning profile URL

### Step 3: Re-run the Build

The enhanced framework export script will now:

- ✅ Validate UUID format properly
- ✅ Try Method 1 with manual certificates
- ✅ Fallback to Method 4 with App Store Connect API
- ✅ Handle framework provisioning profile issues

## 📋 **Expected Success Output**

After adding the variables, you should see:

```
🎯 Method 1: Manual signing with framework-safe export options...
✅ Using extracted UUID: f62f712b-b4a1-47e1-90f9-db7093485ec4
✅ Method 1 successful - Manual signing with framework-safe options
✅ IPA created successfully: 45.2M
```

OR if Method 1 fails:

```
⚠️ Method 1 failed - Manual signing with framework-safe options
🎯 Method 4: App Store Connect API with automatic certificate management...
✅ Method 4 successful - App Store Connect API with automatic certificate management
✅ IPA created successfully: 45.2M
```

## 🔍 **Validation Checklist**

Before running the build, verify:

### ✅ **Certificate Requirements**

- [ ] P12 file contains "iPhone Distribution" certificate
- [ ] P12 password is correct
- [ ] Certificate is valid and not expired
- [ ] Team ID matches: `9H2AD7NQ49`

### ✅ **Provisioning Profile Requirements**

- [ ] Profile is for App Store distribution
- [ ] Bundle ID matches exactly: `com.insurancegroupmo.insurancegroupmo`
- [ ] Profile includes the distribution certificate
- [ ] Profile is not expired

### ✅ **Environment Variables**

- [ ] `CERT_P12_URL` points to accessible P12 file
- [ ] `CERT_PASSWORD` matches P12 password
- [ ] `PROFILE_URL` points to accessible .mobileprovision file
- [ ] `BUNDLE_ID` is exactly: `com.insurancegroupmo.insurancegroupmo`
- [ ] `APPLE_TEAM_ID` is: `9H2AD7NQ49`

## 🚀 **Alternative Quick Fixes**

### Option 1: Generate New Certificates

If you can't find existing certificates:

1. **Apple Developer Portal**:

   - Create new iOS Distribution certificate
   - Create new App Store provisioning profile
   - Download both files

2. **Upload to GitHub** (private repo):
   ```
   https://raw.githubusercontent.com/yourusername/certificates/main/ios_distribution.p12
   https://raw.githubusercontent.com/yourusername/certificates/main/app_store_profile.mobileprovision
   ```

### Option 2: Use Codemagic Certificate Management

1. Go to Codemagic → Teams → Code signing
2. Upload your certificates there
3. Reference them in workflow:
   ```yaml
   ios_signing:
     distribution_type: app_store
     bundle_identifier: com.insurancegroupmo.insurancegroupmo
   ```

## 🔧 **Debug Commands**

If you want to debug locally, add this to a Codemagic script step:

```bash
# Debug certificate and profile information
echo "🔍 Certificate Debug Information:"
echo "CERT_P12_URL: ${CERT_P12_URL:-NOT_SET}"
echo "CERT_PASSWORD: ${CERT_PASSWORD:+SET (${#CERT_PASSWORD} chars)}${CERT_PASSWORD:-NOT_SET}"
echo "PROFILE_URL: ${PROFILE_URL:-NOT_SET}"

# Test URL accessibility
if [ -n "${CERT_P12_URL:-}" ]; then
  echo "🔍 Testing P12 URL accessibility..."
  curl -I "${CERT_P12_URL}" || echo "❌ P12 URL not accessible"
fi

if [ -n "${PROFILE_URL:-}" ]; then
  echo "🔍 Testing Profile URL accessibility..."
  curl -I "${PROFILE_URL}" || echo "❌ Profile URL not accessible"
fi
```

## 📞 **Support Steps**

If the issue persists:

1. **Check Variables**: Ensure all environment variables are set correctly
2. **Verify Files**: Download P12 and .mobileprovision files manually to verify they work
3. **Test Locally**: Try the same export command on a local Mac with Xcode
4. **Check Logs**: Look for detailed error messages in export_method\*.log files

## 🎉 **Expected Final Result**

With proper certificates configured, your build should complete with:

```
✅ iOS build workflow completed successfully with framework fix!
✅ IPA file found: output/ios/Runner.ipa (45.2M)
🎯 Framework provisioning profile issues resolved
📦 Distribution Status: READY
```

**The key is adding the missing certificate variables to resolve the UUID and account issues!** 🚀
