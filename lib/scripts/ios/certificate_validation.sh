#!/bin/bash

# Simple Certificate Validation Script
# Purpose: Basic validation for IPA export credentials

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(dirname "$0")"

# Source utilities if available
if [ -f "${SCRIPT_DIR}/utils.sh" ]; then
    source "${SCRIPT_DIR}/utils.sh"
else
    # Basic logging functions if utils not available
    log_info() { echo "ℹ️ $1"; }
    log_success() { echo "✅ $1"; }
    log_warn() { echo "⚠️ $1"; }
    log_error() { echo "❌ $1"; }
fi

log_info "🔒 Starting Certificate Validation..."

# Check App Store Connect API credentials
if [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ] && [ -n "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ] && [ -n "${APP_STORE_CONNECT_PRIVATE_KEY:-}" ]; then
    log_success "✅ App Store Connect API credentials available"
    export EXPORT_METHOD="api"
    
    # Create API-based export options
    mkdir -p ios/export_options
    cat > ios/export_options/ExportOptions.plist << 'API_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>app-store-connect</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>teamID</key>
    <string>AUTOMATIC</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key>
    <true/>
</dict>
</plist>
API_EOF
    log_success "✅ API-based ExportOptions.plist created"
    
elif [ -n "${CERTIFICATE:-}" ] && [ -n "${PROVISIONING_PROFILE:-}" ]; then
    log_success "✅ Manual signing credentials available"
    export EXPORT_METHOD="manual"
    
    # Create manual signing export options
    mkdir -p ios/export_options
    cat > ios/export_options/ExportOptions.plist << 'MANUAL_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
MANUAL_EOF
    log_success "✅ Manual signing ExportOptions.plist created"
    
else
    log_warn "⚠️ No signing credentials found - using automatic signing"
    export EXPORT_METHOD="automatic"
    
    # Create automatic signing export options  
    mkdir -p ios/export_options
    cat > ios/export_options/ExportOptions.plist << 'AUTO_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>development</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
AUTO_EOF
    log_success "✅ Automatic signing ExportOptions.plist created"
fi

log_success "✅ Certificate validation completed - Export Method: ${EXPORT_METHOD}"
return 0
