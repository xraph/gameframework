#!/usr/bin/env bash
#
# Exercise UnrealBridge.mm in the iOS Simulator, both with and without
# UnrealFramework present.
#
# There is no Unreal build in CI, so the "present" case runs against
# MockUnrealFramework.c, which exports the same C ABI the plugin's
# Public/UnrealBridge.h declares. That covers the pod side and the ABI contract
# in both directions. It does NOT cover the engine-side implementation in
# FlutterBridge_IOS.cpp, which needs a real engine to build.
#
# Usage: ./run_bridge_tests.sh [simulator-udid]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../Classes/UnrealBridge.mm"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

TARGET="arm64-apple-ios15.0-simulator"
SDK="iphonesimulator"

UDID="${1:-}"
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices available \
    | grep -oE '\(([0-9A-F-]{36})\)' | head -1 | tr -d '()')
fi
if [ -z "$UDID" ]; then
  echo "No iOS simulator available" >&2
  exit 1
fi

BOOTED_HERE=0
if ! xcrun simctl list devices booted | grep -q "$UDID"; then
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  BOOTED_HERE=1
fi
cleanup_sim() {
  [ "$BOOTED_HERE" -eq 1 ] && xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
}
trap 'cleanup_sim; rm -rf "$BUILD"' EXIT

compile_mm() {
  xcrun --sdk "$SDK" clang++ -target "$TARGET" -fobjc-arc \
    -x objective-c++ -std=c++17 -Wall -Wextra -c "$1" -o "$2"
}

echo "Building bridge..."
compile_mm "$SRC" "$BUILD/UnrealBridge.o"

echo "Building mock framework..."
xcrun --sdk "$SDK" clang -target "$TARGET" -dynamiclib \
  -install_name @rpath/MockUnreal.dylib \
  "$HERE/MockUnrealFramework.c" -o "$BUILD/MockUnreal.dylib"

echo
echo "=== Framework absent ==="
compile_mm "$HERE/UnrealBridgeAbsentTests.mm" "$BUILD/absent.o"
xcrun --sdk "$SDK" clang++ -target "$TARGET" \
  "$BUILD/UnrealBridge.o" "$BUILD/absent.o" \
  -framework Foundation -framework UIKit -framework QuartzCore -o "$BUILD/absent"
xcrun simctl spawn "$UDID" "$BUILD/absent" 2>&1 | grep -v '^20[0-9][0-9]-'

echo
echo "=== Framework present (mock) ==="
compile_mm "$HERE/UnrealBridgeTests.mm" "$BUILD/live.o"
xcrun --sdk "$SDK" clang++ -target "$TARGET" \
  "$BUILD/UnrealBridge.o" "$BUILD/live.o" "$BUILD/MockUnreal.dylib" \
  -framework Foundation -framework UIKit -framework QuartzCore -rpath "$BUILD" -o "$BUILD/live"
xcrun simctl spawn "$UDID" "$BUILD/live" 2>&1 | grep -v '^20[0-9][0-9]-'
