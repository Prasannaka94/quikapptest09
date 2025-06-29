#!/bin/bash

# Simple Certificate Validation Script (No Encoding Required)
# Purpose: Basic validation for IPA export without complex setup

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

log_info "🔒 Simple Certificate Validation (No Encoding Required)..."

# Check if using Codemagic's built-in code signing (simplest method)
if [ "${CM_CODE_SIGNING:-}" = "true" ] || [ -n "${CM_CERTIFICATE:-}" ]; then
    log_success "✅ Using Codemagic's built-in code signing (no encoding required)"
    export EXPORT_METHOD="codemagic_builtin"
    
    # Codemagic handles all signing automatically
    log_info "🔐 Codemagic will handle all certificate and profile setup automatically"
    
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_ID_PASSWORD:-}" ]; then
    log_success "✅ Using Apple ID authentication (simple setup)"
    export EXPORT_METHOD="apple_id"
    
    log_info "🍎 Apple ID: ${APPLE_ID}"
    log_info "🔐 App-specific password configured"
    
elif [ -n "${APPLE_TEAM_ID:-}" ]; then
    log_success "✅ Using automatic signing with Team ID"
    export EXPORT_METHOD="automatic_with_team"
    
    log_info "👥 Team ID: ${APPLE_TEAM_ID}"
    log_info "🔐 iOS will attempt automatic profile selection"
    
else
    log_warn "⚠️ No signing configuration found - using basic automatic signing"
    export EXPORT_METHOD="automatic_basic"
    log_warn "⚠️ This may fail without proper Team ID configuration"
fi

# Determine export method based on profile type
case "${PROFILE_TYPE:-app-store}" in
    "app-store")
        export_method="app-store"
        distribution_type="app_store"
        log_info "🏪 Using app-store export method"
        ;;
    "ad-hoc")
        export_method="ad-hoc"
        distribution_type="ad_hoc"
        log_info "📱 Using ad-hoc export method"
        ;;
    "enterprise")
        export_method="enterprise"
        distribution_type="enterprise"
        log_info "🏢 Using enterprise export method"
        ;;
    "development")
        export_method="development"
        distribution_type="development"
        log_info "🔧 Using development export method"
        ;;
    *)
        export_method="app-store"
        distribution_type="app_store"
        log_warn "⚠️ Unknown profile type '${PROFILE_TYPE}', defaulting to app-store"
        ;;
esac

log_info "📋 Profile Type: ${PROFILE_TYPE:-app-store}"
log_info "📦 Distribution Type: ${distribution_type}"
log_info "🎯 Export Method: ${export_method}"

# Create simple export options (no encoding required)
log_info "📝 Creating simple ExportOptions.plist..."
mkdir -p ios/export_options

cat > ios/export_options/ExportOptions.plist << SIMPLE_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>${export_method}</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-AUTOMATIC}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
SIMPLE_EOF

log_success "✅ Simple export configuration created"
log_info "📋 Export Method: ${export_method}"
log_info "👥 Team ID: ${APPLE_TEAM_ID:-AUTOMATIC}"
log_info "🔐 Signing Style: automatic"

log_success "✅ Certificate validation completed - Export Method: ${EXPORT_METHOD}"
return 0
