# 🔄 Multi-Profile Reusable Project Guide

## 🎯 Overview

This project template supports **multiple apps/profiles** with different bundle identifiers, allowing you to use the same codebase for multiple applications without bundle identifier collisions.

## 🚀 Quick Start

### **Method 1: Environment Variable (Recommended)**

```bash
# For App 1
export BUNDLE_ID="com.yourcompany.app1"
export APP_NAME="My First App"
export VERSION_NAME="1.0.0"

# Run dynamic injection
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh

# Run iOS workflow
# Your ios-workflow will now build with com.yourcompany.app1
```

```bash
# For App 2
export BUNDLE_ID="com.yourcompany.app2"
export APP_NAME="My Second App"
export VERSION_NAME="2.0.0"

# Run dynamic injection
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh

# Run iOS workflow
# Your ios-workflow will now build with com.yourcompany.app2
```

### **Method 2: Direct Script Integration**

The dynamic injection is **automatically integrated** into your iOS workflow. Just set the environment variables before running ios-workflow:

```bash
export BUNDLE_ID="com.example.myapp"
# Run your normal ios-workflow
```

## 📊 Bundle Identifier Management

### **Automatic Bundle ID Assignment:**

| Target       | Bundle Identifier Pattern | Example                             |
| ------------ | ------------------------- | ----------------------------------- |
| **Main App** | `$BUNDLE_ID`              | `com.yourcompany.app1`              |
| **Tests**    | `$BUNDLE_ID.tests`        | `com.yourcompany.app1.tests`        |
| **Pods**     | `$BUNDLE_ID.pod.{name}`   | `com.yourcompany.app1.pod.firebase` |

### **Collision Prevention:**

- ✅ **Zero collisions** between main app and tests
- ✅ **Unique pod identifiers** for each configuration
- ✅ **Multi-profile safety** - each app gets unique identifiers
- ✅ **App Store compliance** - passes all validation checks

## 🎨 Supported Environment Variables

### **Required:**

```bash
BUNDLE_ID="com.yourcompany.appname"    # Main bundle identifier
```

### **Optional:**

```bash
APP_NAME="Your App Name"               # Display name
VERSION_NAME="1.0.0"                   # Version string
VERSION_CODE="1"                       # Build number
APP_ID="com.yourcompany.appname"       # Alternative to BUNDLE_ID
PRODUCT_BUNDLE_IDENTIFIER="..."        # Alternative to BUNDLE_ID
```

## 🔧 Advanced Usage

### **Profile-Based Configuration:**

```bash
# profiles/app1.env
export BUNDLE_ID="com.company.retailapp"
export APP_NAME="Retail Store App"
export VERSION_NAME="1.0.0"
export LOGO_URL="https://example.com/retail-logo.png"

# profiles/app2.env
export BUNDLE_ID="com.company.restaurantapp"
export APP_NAME="Restaurant App"
export VERSION_NAME="1.0.0"
export LOGO_URL="https://example.com/restaurant-logo.png"
```

```bash
# Load profile and build
source profiles/app1.env
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
# Run ios-workflow

source profiles/app2.env
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
# Run ios-workflow
```

### **CI/CD Integration:**

```yaml
# Example GitHub Actions
jobs:
  build-app1:
    runs-on: macos-latest
    env:
      BUNDLE_ID: "com.company.app1"
      APP_NAME: "First App"
    steps:
      - uses: actions/checkout@v3
      - name: Dynamic Bundle ID Injection
        run: ./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
      - name: Build iOS
        run: # Your ios-workflow command

  build-app2:
    runs-on: macos-latest
    env:
      BUNDLE_ID: "com.company.app2"
      APP_NAME: "Second App"
    steps:
      - uses: actions/checkout@v3
      - name: Dynamic Bundle ID Injection
        run: ./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
      - name: Build iOS
        run: # Your ios-workflow command
```

## 🛡️ Error Prevention

### **Common Issues & Solutions:**

#### ❌ **Issue: Bundle ID Collision**

```
CFBundleIdentifier Collision. There is more than one bundle with the CFBundleIdentifier value
```

✅ **Solution:**

```bash
# Run dynamic injection before each build
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
```

#### ❌ **Issue: Missing Bundle ID**

```
No bundle identifier specified, using default: com.example.app
```

✅ **Solution:**

```bash
export BUNDLE_ID="com.yourcompany.yourapp"
```

#### ❌ **Issue: Project File Corruption**

```
The project 'Runner' is damaged and cannot be opened
```

✅ **Solution:**
The dynamic injection creates automatic backups:

```bash
# Restore from backup if needed
ls ios/Runner.xcodeproj/project.pbxproj.dynamic_backup_*
```

## 📱 Real-World Examples

### **Example 1: Multiple Client Apps**

```bash
# Client A
export BUNDLE_ID="com.clienta.mobileapp"
export APP_NAME="Client A Mobile"
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
# Build for Client A

# Client B
export BUNDLE_ID="com.clientb.mobileapp"
export APP_NAME="Client B Mobile"
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
# Build for Client B
```

### **Example 2: Development vs Production**

```bash
# Development
export BUNDLE_ID="com.company.app.dev"
export APP_NAME="MyApp Development"
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh

# Production
export BUNDLE_ID="com.company.app"
export APP_NAME="MyApp"
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
```

### **Example 3: White-Label Apps**

```bash
# Brand A
export BUNDLE_ID="com.branda.app"
export APP_NAME="Brand A App"
export LOGO_URL="https://branda.com/logo.png"

# Brand B
export BUNDLE_ID="com.brandb.app"
export APP_NAME="Brand B App"
export LOGO_URL="https://brandb.com/logo.png"
```

## 🔍 Validation & Testing

### **Verify Current Configuration:**

```bash
# Check current bundle identifiers
grep -n "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
```

### **Test Different Profiles:**

```bash
# Test profile switching
export BUNDLE_ID="com.test.app1"
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
grep "com.test.app1" ios/Runner.xcodeproj/project.pbxproj

export BUNDLE_ID="com.test.app2"
./lib/scripts/ios/dynamic_bundle_identifier_injection.sh
grep "com.test.app2" ios/Runner.xcodeproj/project.pbxproj
```

## 🎯 Best Practices

### **DO:**

- ✅ Always set `BUNDLE_ID` before building
- ✅ Use descriptive bundle identifiers (`com.company.product`)
- ✅ Run dynamic injection before each new app build
- ✅ Keep environment variables in profile files
- ✅ Use consistent naming patterns

### **DON'T:**

- ❌ Commit project file changes with specific bundle IDs
- ❌ Use the same bundle ID for different apps
- ❌ Skip dynamic injection between builds
- ❌ Use spaces or special characters in bundle IDs
- ❌ Forget to update APP_NAME for different profiles

## 🚀 Summary

**This reusable project template gives you:**

1. **🔄 Dynamic Bundle ID Injection** - Change bundle identifiers without code changes
2. **🛡️ Collision Prevention** - Automatic protection against bundle ID conflicts
3. **📱 Multi-Profile Support** - Build multiple apps from the same codebase
4. **🎯 App Store Ready** - All builds pass App Store validation
5. **⚡ CI/CD Friendly** - Easy integration with build pipelines
6. **🔧 Error Recovery** - Automatic backups and recovery mechanisms

**Perfect for:**

- App development agencies
- White-label applications
- Multi-tenant solutions
- Development/staging/production environments
- Client-specific customizations

**Your iOS workflow now supports unlimited apps with zero bundle identifier collisions!** 🎉
