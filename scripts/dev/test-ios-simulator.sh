#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="$ROOT/App/CellarApp"
PROJECT="$PROJECT_DIR/CellarApp.xcodeproj"
DERIVED_ROOT="/Volumes/mac-mini-ex/DeveloperBuilds/CellarKit-iOS/DerivedData"
RESULT_BUNDLE_ROOT="/Volumes/mac-mini-ex/DeveloperBuilds/CellarKit-iOS/TestResults"
DEVICE_NAME="CellarKit iPhone 16 Pro"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"
RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.iOS-18-5"

mkdir -p "$DERIVED_ROOT" "$RESULT_BUNDLE_ROOT"
"$ROOT/scripts/dev/generate-ios-project.sh"

DEVICE_LINE="$(xcrun simctl list devices available | awk '/CellarKit iPhone 16 Pro/ {print; exit}')"
DEVICE_ID=""
if [[ -n "$DEVICE_LINE" ]]; then
  DEVICE_ID="$(sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' <<<"$DEVICE_LINE")"
fi
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME_ID")"
  DEVICE_LINE="$(xcrun simctl list devices available | awk '/CellarKit iPhone 16 Pro/ {print; exit}')"
fi

if ! grep -q '(Booted)' <<<"$DEVICE_LINE"; then
  xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b

RESULT_BUNDLE="$RESULT_BUNDLE_ROOT/CellarApp-$(date +%Y%m%d-%H%M%S).xcresult"
XCPRETTY="$HOME/.gem/ruby/2.6.0/bin/xcpretty"

CMD=(
  xcodebuild test
  -project "$PROJECT"
  -scheme CellarApp
  -destination "id=$DEVICE_ID"
  -derivedDataPath "$DERIVED_ROOT"
  -resultBundlePath "$RESULT_BUNDLE"
  CODE_SIGNING_ALLOWED=NO
)

if [[ -x "$XCPRETTY" ]]; then
  "${CMD[@]}" | "$XCPRETTY"
else
  "${CMD[@]}"
fi

echo "UI test result bundle: $RESULT_BUNDLE"
