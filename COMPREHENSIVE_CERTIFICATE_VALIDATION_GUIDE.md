# 🔒 Comprehensive Certificate Validation and Code Signing Guide

## 📋 Overview

This guide provides a complete solution for handling certificate validation and code signing for iOS IPA export. The system supports both P12 files and CER+KEY combinations, with automatic App Store Connect API validation and UUID extraction from mobileprovision files.

## 🎯 What This System Solves

### ✅ **Certificate Management**

- **P12 File Support**: Direct use of .p12 certificate files with password validation
- **CER+KEY Conversion**: Automatic conversion of .cer and .key files to P12 format
- **Default Password**: Uses `Password@1234` when generating P12 from CER+KEY
- **Secure Keychain**: Dedicated iOS build keychain with proper permissions

### ✅ **App Store Connect Integration**

- **API Key Validation**: Downloads and validates .p8 API key files
- **Credential Verification**: Tests Key ID, Issuer ID, and API key compatibility
- **Upload Ready**: Prepares for App Store Connect upload with proper authentication

### ✅ **Provisioning Profile Handling**

- **UUID Extraction**: Automatically extracts UUID from mobileprovision files
- **Profile Installation**: Installs profiles in the correct system location
- **ExportOptions Integration**: Creates ExportOptions.plist with UUID for manual signing

### ✅ **Code Signing Validation**

- **Identity Verification**: Confirms code signing identities are properly installed
- **Distribution Certificate Check**: Validates iOS distribution certificates
- **Signing Capability**: Ensures the system is ready for IPA export

## 🚀 Quick Start

### **Step 1: Set Environment Variables**

Choose **ONE** certificate option:

#### **Option A: P12 File**

```bash
export CERT_P12_URL="https://your-domain.com/certificate.p12"
export CERT_PASSWORD="your_p12_password"
```

#### **Option B: CER + KEY Files**

```bash
export CERT_CER_URL="https://your-domain.com/certificate.cer"
export CERT_KEY_URL="https://your-domain.com/private.key"
# Will generate P12 with default password: Password@1234
```

### **Step 2: Set App Store Connect API Variables**

```bash
export APP_STORE_CONNECT_API_KEY_PATH="https://your-domain.com/AuthKey.p8"
export APP_STORE_CONNECT_KEY_IDENTIFIER="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"
```

### **Step 3: Set App Configuration**

```bash
export PROFILE_URL="https://your-domain.com/profile.mobileprovision"
export BUNDLE_ID="com.yourcompany.yourapp"
export PROFILE_TYPE="app-store"  # or "ad-hoc", "enterprise", "development"
```

### **Step 4: Run the Workflow**

#### **Certificate Validation Only**

```bash
./lib/scripts/ios/comprehensive_certificate_validation.sh
```

#### **Full IPA Export with Certificate Validation**

```bash
./lib/scripts/ios/ipa_export_with_certificate_validation.sh
```

## 📊 Workflow Logic

### **Certificate Validation Flow**

```
1. Check Certificate Variables
   ├── If CERT_P12_URL exists with CERT_PASSWORD
   │   ├── Download P12 file
   │   ├── Validate with provided password
   │   └── Install in keychain
   │
   ├── If CERT_CER_URL + CERT_KEY_URL exist
   │   ├── Download CER and KEY files
   │   ├── Generate P12 with Password@1234
   │   └── Install in keychain
   │
   └── If neither exists
       └── Exit with error: "No code signing data provided"

2. Validate App Store Connect API
   ├── Download .p8 API key
   ├── Validate format and permissions
   └── Prepare for upload

3. Process Provisioning Profile
   ├── Download mobileprovision file
   ├── Extract UUID using security + plutil
   └── Install in ~/Library/MobileDevice/Provisioning Profiles/

4. Validate Code Signing
   ├── Check keychain for identities
   ├── Verify iOS distribution certificates
   └── Confirm signing capability

5. Create Export Configuration
   ├── Generate ExportOptions.plist with UUID
   ├── Configure for profile type
   └── Set up manual signing
```

### **IPA Export Flow**

```
1. Environment Validation
   ├── Check all required variables
   └── Set defaults where needed

2. Certificate Validation
   └── Run comprehensive certificate validation

3. Export Configuration
   ├── Create ExportOptions.plist with UUID
   └── Configure for specified profile type

4. Build and Archive
   ├── Clean and build Flutter app
   ├── Create Xcode archive
   └── Prepare for IPA export

5. Export IPA
   ├── Export from archive using UUID
   ├── Create final IPA file
   └── Validate export success

6. Upload (Optional)
   ├── Upload to App Store Connect
   ├── Use API key authentication
   └── Handle upload verification
```

## 🔧 Scripts Overview

### **1. `comprehensive_certificate_validation.sh`**

- **Purpose**: Core certificate validation and installation
- **Input**: Environment variables for certificates and API credentials
- **Output**: Validated certificates, extracted UUID, ready for signing

### **2. `ipa_export_with_certificate_validation.sh`**

- **Purpose**: Complete IPA export workflow with certificate validation
- **Input**: All certificate variables + app configuration
- **Output**: Signed IPA file ready for distribution

### **3. `example_certificate_workflow.sh`**

- **Purpose**: Documentation and examples
- **Usage**: `./lib/scripts/ios/example_certificate_workflow.sh [option]`
- **Options**: `help`, `p12-example`, `cer-key-example`, `validation-steps`, `troubleshooting`

## 📝 Environment Variables Reference

### **Certificate Variables (Required - Choose One)**

| Variable        | Description                  | Example                           |
| --------------- | ---------------------------- | --------------------------------- |
| `CERT_P12_URL`  | URL to .p12 certificate file | `https://example.com/cert.p12`    |
| `CERT_PASSWORD` | Password for .p12 file       | `your_password`                   |
| `CERT_CER_URL`  | URL to .cer certificate file | `https://example.com/cert.cer`    |
| `CERT_KEY_URL`  | URL to .key private key file | `https://example.com/private.key` |

### **App Store Connect API Variables (Required)**

| Variable                           | Description             | Example                                |
| ---------------------------------- | ----------------------- | -------------------------------------- |
| `APP_STORE_CONNECT_API_KEY_PATH`   | URL to .p8 API key file | `https://example.com/AuthKey.p8`       |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Your API key ID         | `ZFD9GRMS7R`                           |
| `APP_STORE_CONNECT_ISSUER_ID`      | Your issuer ID          | `a99a2ebd-ed3e-4117-9f97-f195823774a7` |

### **App Configuration Variables (Required)**

| Variable       | Description                  | Example                                            |
| -------------- | ---------------------------- | -------------------------------------------------- |
| `PROFILE_URL`  | URL to .mobileprovision file | `https://example.com/profile.mobileprovision`      |
| `BUNDLE_ID`    | Your app's bundle identifier | `com.example.app`                                  |
| `PROFILE_TYPE` | Distribution type            | `app-store`, `ad-hoc`, `enterprise`, `development` |

### **Optional Variables**

| Variable            | Description                 | Default     |
| ------------------- | --------------------------- | ----------- |
| `KEYCHAIN_PASSWORD` | Password for build keychain | `build123`  |
| `APPLE_TEAM_ID`     | Your Apple Team ID          | `AUTOMATIC` |

## 🚨 Error Handling

### **Common Error Scenarios**

#### **1. "No code signing data provided"**

```bash
❌ Error: No code signing data provided
   Please provide either:
   - CERT_P12_URL with CERT_PASSWORD, or
   - CERT_CER_URL and CERT_KEY_URL
```

**Solution**: Set the required certificate variables

#### **2. "P12 certificate validation failed"**

```bash
❌ P12 certificate validation failed with provided password
```

**Solution**:

- Verify `CERT_PASSWORD` is correct
- Check P12 file is not corrupted
- Ensure P12 file is for iOS distribution

#### **3. "Failed to convert CER+KEY to P12"**

```bash
❌ Failed to convert CER+KEY to P12 format
```

**Solution**:

- Verify CER and KEY files are valid
- Check file permissions
- Ensure OpenSSL is installed

#### **4. "Failed to download API key"**

```bash
❌ Failed to download API key
```

**Solution**:

- Check `APP_STORE_CONNECT_API_KEY_PATH` URL
- Verify network connectivity
- Ensure API key file exists at URL

#### **5. "Failed to extract UUID from mobileprovision"**

```bash
❌ Failed to extract UUID from provisioning profile
```

**Solution**:

- Check `PROFILE_URL` is accessible
- Verify mobileprovision file is valid
- Ensure `security` and `plutil` tools are available

## 🔍 Debug Commands

### **Certificate Validation**

```bash
# Check certificate installation
security find-identity -v -p codesigning ios-build.keychain

# Validate P12 file
openssl pkcs12 -in certificate.p12 -noout -passin pass:your_password

# Check keychain status
security list-keychains
security default-keychain
```

### **Provisioning Profile**

```bash
# Extract mobileprovision UUID
security cms -D -i profile.mobileprovision | plutil -extract UUID xml1 -o - -

# Check installed profiles
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/

# Validate mobileprovision file
security cms -D -i profile.mobileprovision
```

### **Export Configuration**

```bash
# Validate ExportOptions.plist
plutil -lint ios/export_options/ExportOptions.plist

# View ExportOptions.plist content
cat ios/export_options/ExportOptions.plist
```

### **Build and Archive**

```bash
# Check Xcode project
xcodebuild -list -workspace ios/Runner.xcworkspace

# Validate archive
xcodebuild -showBuildSettings -workspace ios/Runner.xcworkspace -scheme Runner
```

## 📋 Usage Examples

### **Example 1: P12 File with App Store Distribution**

```bash
#!/bin/bash

# Set environment variables
export CERT_P12_URL="https://your-domain.com/distribution.p12"
export CERT_PASSWORD="your_secure_password"
export APP_STORE_CONNECT_API_KEY_PATH="https://your-domain.com/AuthKey.p8"
export APP_STORE_CONNECT_KEY_IDENTIFIER="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"
export PROFILE_URL="https://your-domain.com/appstore.mobileprovision"
export BUNDLE_ID="com.yourcompany.yourapp"
export PROFILE_TYPE="app-store"

# Run certificate validation
./lib/scripts/ios/comprehensive_certificate_validation.sh

# Run full IPA export
./lib/scripts/ios/ipa_export_with_certificate_validation.sh
```

### **Example 2: CER+KEY Files with Ad Hoc Distribution**

```bash
#!/bin/bash

# Set environment variables
export CERT_CER_URL="https://your-domain.com/certificate.cer"
export CERT_KEY_URL="https://your-domain.com/private.key"
export APP_STORE_CONNECT_API_KEY_PATH="https://your-domain.com/AuthKey.p8"
export APP_STORE_CONNECT_KEY_IDENTIFIER="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"
export PROFILE_URL="https://your-domain.com/adhoc.mobileprovision"
export BUNDLE_ID="com.yourcompany.yourapp"
export PROFILE_TYPE="ad-hoc"

# Run certificate validation (will generate P12 with Password@1234)
./lib/scripts/ios/comprehensive_certificate_validation.sh

# Run full IPA export
./lib/scripts/ios/ipa_export_with_certificate_validation.sh
```

### **Example 3: Enterprise Distribution**

```bash
#!/bin/bash

# Set environment variables
export CERT_P12_URL="https://your-domain.com/enterprise.p12"
export CERT_PASSWORD="enterprise_password"
export APP_STORE_CONNECT_API_KEY_PATH="https://your-domain.com/AuthKey.p8"
export APP_STORE_CONNECT_KEY_IDENTIFIER="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"
export PROFILE_URL="https://your-domain.com/enterprise.mobileprovision"
export BUNDLE_ID="com.yourcompany.yourapp"
export PROFILE_TYPE="enterprise"

# Run full workflow
./lib/scripts/ios/ipa_export_with_certificate_validation.sh
```

## 🎯 Success Criteria

### **Certificate Validation Success**

```
✅ Certificate: Installed and validated
✅ Code Signing: Ready for distribution
✅ Provisioning Profile: UUID: 12345678-1234-1234-1234-123456789012
✅ App Store Connect API: Ready for upload
```

### **IPA Export Success**

```
✅ App archived successfully: ios/build/archive.xcarchive
✅ IPA exported successfully
✅ IPA file found: ios/build/export/Runner.ipa
✅ IPA copied to: ios/build/app.ipa
✅ App uploaded to App Store Connect successfully
```

## 🔧 Integration with Existing Workflows

### **Codemagic Integration**

```yaml
# Add to your codemagic.yaml
environment:
  vars:
    CERT_P12_URL: $CERT_P12_URL
    CERT_PASSWORD: $CERT_PASSWORD
    APP_STORE_CONNECT_API_KEY_PATH: $APP_STORE_CONNECT_API_KEY_PATH
    APP_STORE_CONNECT_KEY_IDENTIFIER: $APP_STORE_CONNECT_KEY_IDENTIFIER
    APP_STORE_CONNECT_ISSUER_ID: $APP_STORE_CONNECT_ISSUER_ID
    PROFILE_URL: $PROFILE_URL
    BUNDLE_ID: $BUNDLE_ID
    PROFILE_TYPE: $PROFILE_TYPE

scripts:
  - name: Certificate Validation and IPA Export
    script: |
      chmod +x lib/scripts/ios/*.sh
      ./lib/scripts/ios/ipa_export_with_certificate_validation.sh
```

### **GitHub Actions Integration**

```yaml
# Add to your .github/workflows/ios.yml
- name: Certificate Validation and IPA Export
  env:
    CERT_P12_URL: ${{ secrets.CERT_P12_URL }}
    CERT_PASSWORD: ${{ secrets.CERT_PASSWORD }}
    APP_STORE_CONNECT_API_KEY_PATH: ${{ secrets.APP_STORE_CONNECT_API_KEY_PATH }}
    APP_STORE_CONNECT_KEY_IDENTIFIER: ${{ secrets.APP_STORE_CONNECT_KEY_IDENTIFIER }}
    APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
    PROFILE_URL: ${{ secrets.PROFILE_URL }}
    BUNDLE_ID: ${{ secrets.BUNDLE_ID }}
    PROFILE_TYPE: ${{ secrets.PROFILE_TYPE }}
  run: |
    chmod +x lib/scripts/ios/*.sh
    ./lib/scripts/ios/ipa_export_with_certificate_validation.sh
```

## 🏆 Best Practices

### **Security**

1. **Use HTTPS URLs**: Always use HTTPS for certificate and profile URLs
2. **Secure Passwords**: Use strong passwords for P12 files
3. **API Key Protection**: Keep API keys secure and rotate regularly
4. **Keychain Isolation**: Use dedicated keychain for builds

### **Reliability**

1. **URL Validation**: Ensure all URLs are accessible before running
2. **File Validation**: Validate certificate files before use
3. **Error Handling**: Always check script exit codes
4. **Logging**: Monitor logs for any issues

### **Performance**

1. **Caching**: Consider caching certificates for repeated builds
2. **Parallel Processing**: Run validation steps in parallel where possible
3. **Cleanup**: Clean up temporary files after use

## 📞 Support

### **Getting Help**

1. **Check Examples**: Run `./lib/scripts/ios/example_certificate_workflow.sh help`
2. **View Steps**: Run `./lib/scripts/ios/example_certificate_workflow.sh validation-steps`
3. **Troubleshooting**: Run `./lib/scripts/ios/example_certificate_workflow.sh troubleshooting`

### **Common Issues**

- **Network Issues**: Check URL accessibility and network connectivity
- **Permission Issues**: Ensure scripts are executable (`chmod +x`)
- **Certificate Issues**: Verify certificate validity and password
- **Profile Issues**: Check mobileprovision file and bundle identifier match

---

## 🎉 Conclusion

This comprehensive certificate validation system provides a robust, secure, and reliable solution for iOS IPA export. It handles all aspects of certificate management, from validation to installation, and integrates seamlessly with App Store Connect for distribution.

The system is designed to be:

- **Secure**: Proper keychain management and API key handling
- **Reliable**: Comprehensive error handling and validation
- **Flexible**: Support for multiple certificate formats and distribution types
- **User-Friendly**: Clear error messages and comprehensive documentation

Follow this guide to implement secure, automated iOS builds with proper certificate validation and code signing! 🚀
