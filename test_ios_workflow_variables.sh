#!/bin/bash

# Test script to verify iOS workflow environment variables
# Purpose: Debug environment variable issues in iOS workflow

set -euo pipefail

echo "🔍 Testing iOS Workflow Environment Variables"
echo "=============================================="

# Test essential variables
echo "📋 Essential Variables:"
echo "  BUNDLE_ID: ${BUNDLE_ID:-NOT_SET}"
echo "  PROFILE_TYPE: ${PROFILE_TYPE:-NOT_SET}"
echo "  APP_NAME: ${APP_NAME:-NOT_SET}"
echo "  VERSION_NAME: ${VERSION_NAME:-NOT_SET}"
echo "  VERSION_CODE: ${VERSION_CODE:-NOT_SET}"

echo ""
echo "🔐 Certificate Variables:"
echo "  CERT_P12_URL: ${CERT_P12_URL:-NOT_SET}"
echo "  CERT_CER_URL: ${CERT_CER_URL:-NOT_SET}"
echo "  CERT_KEY_URL: ${CERT_KEY_URL:-NOT_SET}"
echo "  CERT_PASSWORD: ${CERT_PASSWORD:+SET}"
echo "  CERT_P12_PASSWORD: ${CERT_P12_PASSWORD:+SET}"
echo "  KEYCHAIN_PASSWORD: ${KEYCHAIN_PASSWORD:+SET}"

echo ""
echo "📱 Provisioning Profile:"
echo "  PROFILE_URL: ${PROFILE_URL:-NOT_SET}"

echo ""
echo "🍎 Apple Developer:"
echo "  APPLE_TEAM_ID: ${APPLE_TEAM_ID:-NOT_SET}"
echo "  APPLE_ID: ${APPLE_ID:-NOT_SET}"
echo "  APPLE_ID_PASSWORD: ${APPLE_ID_PASSWORD:+SET}"

echo ""
echo "🔐 App Store Connect:"
echo "  APP_STORE_CONNECT_KEY_IDENTIFIER: ${APP_STORE_CONNECT_KEY_IDENTIFIER:-NOT_SET}"
echo "  APP_STORE_CONNECT_API_KEY: ${APP_STORE_CONNECT_API_KEY:-NOT_SET}"
echo "  APP_STORE_CONNECT_API_KEY_PATH: ${APP_STORE_CONNECT_API_KEY_PATH:-NOT_SET}"
echo "  APP_STORE_CONNECT_ISSUER_ID: ${APP_STORE_CONNECT_ISSUER_ID:-NOT_SET}"

echo ""
echo "📧 Email Configuration:"
echo "  ENABLE_EMAIL_NOTIFICATIONS: ${ENABLE_EMAIL_NOTIFICATIONS:-NOT_SET}"
echo "  EMAIL_SMTP_SERVER: ${EMAIL_SMTP_SERVER:-NOT_SET}"
echo "  EMAIL_SMTP_PORT: ${EMAIL_SMTP_PORT:-NOT_SET}"
echo "  EMAIL_SMTP_USER: ${EMAIL_SMTP_USER:-NOT_SET}"
echo "  EMAIL_SMTP_PASS: ${EMAIL_SMTP_PASS:+SET}"
echo "  EMAIL_ID: ${EMAIL_ID:-NOT_SET}"

echo ""
echo "🔧 Build Environment:"
echo "  CM_BUILD_ID: ${CM_BUILD_ID:-NOT_SET}"
echo "  CM_BUILD_DIR: ${CM_BUILD_DIR:-NOT_SET}"
echo "  OUTPUT_DIR: ${OUTPUT_DIR:-NOT_SET}"

echo ""
echo "🔍 URL Validation Tests:"
if [ -n "${CERT_P12_URL:-}" ]; then
    echo "  CERT_P12_URL format: $CERT_P12_URL"
    if [[ "$CERT_P12_URL" =~ ^https?:// ]]; then
        echo "  ✅ CERT_P12_URL has valid format"
    else
        echo "  ❌ CERT_P12_URL has invalid format"
    fi
fi

if [ -n "${CERT_CER_URL:-}" ]; then
    echo "  CERT_CER_URL format: $CERT_CER_URL"
    if [[ "$CERT_CER_URL" =~ ^https?:// ]]; then
        echo "  ✅ CERT_CER_URL has valid format"
    else
        echo "  ❌ CERT_CER_URL has invalid format"
    fi
fi

if [ -n "${PROFILE_URL:-}" ]; then
    echo "  PROFILE_URL format: $PROFILE_URL"
    if [[ "$PROFILE_URL" =~ ^https?:// ]]; then
        echo "  ✅ PROFILE_URL has valid format"
    else
        echo "  ❌ PROFILE_URL has invalid format"
    fi
fi

echo ""
echo "📊 Summary:"
if [ -n "${BUNDLE_ID:-}" ] && [ -n "${APP_NAME:-}" ]; then
    echo "  ✅ Essential variables are set"
else
    echo "  ❌ Essential variables are missing"
fi

if [ -n "${CERT_P12_URL:-}" ] || [ -n "${CERT_CER_URL:-}" ]; then
    echo "  ✅ Certificate configuration found"
else
    echo "  ❌ No certificate configuration found"
fi

if [ -n "${PROFILE_URL:-}" ]; then
    echo "  ✅ Provisioning profile URL is set"
else
    echo "  ❌ Provisioning profile URL is missing"
fi

echo ""
echo "🎯 Recommendations:"
if [ -z "${BUNDLE_ID:-}" ]; then
    echo "  - Set BUNDLE_ID environment variable"
fi
if [ -z "${APP_NAME:-}" ]; then
    echo "  - Set APP_NAME environment variable"
fi
if [ -z "${CERT_P12_URL:-}" ] && [ -z "${CERT_CER_URL:-}" ]; then
    echo "  - Set either CERT_P12_URL or CERT_CER_URL+CERT_KEY_URL"
fi
if [ -z "${PROFILE_URL:-}" ]; then
    echo "  - Set PROFILE_URL environment variable"
fi

echo ""
echo "✅ Environment variable test completed" 