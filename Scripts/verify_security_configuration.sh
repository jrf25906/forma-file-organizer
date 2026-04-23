#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-/tmp/forma-security-configuration-release}"
UI_TESTS_DERIVED_DATA="${UI_TESTS_DERIVED_DATA:-${DERIVED_DATA}-uitests-guard}"
PROJECT="${ROOT_DIR}/Forma File Organizing.xcodeproj"
SCHEME="Forma File Organizing"
BINARY="${DERIVED_DATA}/Build/Products/Release/Forma File Organizing.app/Contents/MacOS/Forma File Organizing"
GUARD_LOG="${DERIVED_DATA}/ui-tests-guard.log"

rm -rf "$DERIVED_DATA"
rm -rf "$UI_TESTS_DERIVED_DATA"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

if [[ ! -x "$BINARY" ]]; then
  echo "error: release binary not found at $BINARY" >&2
  exit 1
fi

assert_binary_absent() {
  local needle="$1"
  local label="$2"

  if LC_ALL=C grep -a -F -q -- "$needle" "$BINARY"; then
    echo "error: release binary still contains $label ($needle)" >&2
    exit 1
  fi
}

assert_binary_absent "FORMA_UI_TEST_ACCESSIBLE_FOLDERS" "UI test folder environment override"
assert_binary_absent "FORMA_UI_TEST_SHOW_ONBOARDING" "UI test onboarding environment override"
assert_binary_absent "/tmp/thumbnail_debug.log" "legacy thumbnail debug log path"

if xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$UI_TESTS_DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  OTHER_SWIFT_FLAGS="-D UI_TESTS" \
  >"$GUARD_LOG" 2>&1; then
  echo "error: Release build unexpectedly succeeded with UI_TESTS defined" >&2
  exit 1
fi

if ! grep -F -q "UI_TESTS must not be defined for Release app builds" "$GUARD_LOG"; then
  echo "error: Release UI_TESTS guard did not emit the expected diagnostic" >&2
  tail -80 "$GUARD_LOG" >&2
  exit 1
fi

echo "Release security configuration verified: $BINARY"
