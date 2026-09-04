#!/usr/bin/env bash
#
# Exercise UnrealBridge.mm on macOS, with and without UnrealFramework present.
#
# There is no Unreal build in CI, so the "present" case runs against
# MockUnrealFramework.c, which exports the same C ABI the plugin's
# Public/UnrealBridge.h declares. That covers the pod side and the ABI contract
# in both directions. It does NOT cover the engine-side implementation in
# Private/FlutterBridge_Apple.cpp, which needs a real engine to build.
#
# Unlike the iOS equivalent these run natively, so no simulator is involved.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLASSES="$HERE/../Classes"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

SDK="$(xcrun --sdk macosx --show-sdk-path)"

compile_mm() {
  xcrun --sdk macosx clang++ -fobjc-arc -x objective-c++ -std=c++17 \
    -Wall -Wextra -I"$CLASSES" -c "$1" -o "$2"
}

echo "Building bridge..."
compile_mm "$CLASSES/UnrealBridge.mm" "$BUILD/UnrealBridge.o"

echo "Building mock framework..."
xcrun --sdk macosx clang -dynamiclib -install_name @rpath/MockUnreal.dylib \
  "$HERE/MockUnrealFramework.c" -o "$BUILD/MockUnreal.dylib"

echo
echo "=== Swift sees the bridge with the expected signatures ==="
xcrun swiftc -typecheck -sdk "$SDK" \
  -import-objc-header "$CLASSES/UnrealBridge.h" \
  "$HERE/SwiftApiCheck.swift"
echo "PASS: every UnrealBridge call site in UnrealEngineController type-checks"

echo
echo "=== Framework absent ==="
compile_mm "$HERE/UnrealBridgeAbsentTests.mm" "$BUILD/absent.o"
xcrun --sdk macosx clang++ "$BUILD/UnrealBridge.o" "$BUILD/absent.o" \
  -framework Foundation -framework Cocoa -o "$BUILD/absent"
"$BUILD/absent"

echo
echo "=== Framework present (mock) ==="
compile_mm "$HERE/UnrealBridgeTests.mm" "$BUILD/live.o"
xcrun --sdk macosx clang++ "$BUILD/UnrealBridge.o" "$BUILD/live.o" \
  "$BUILD/MockUnreal.dylib" \
  -framework Foundation -framework Cocoa -rpath "$BUILD" -o "$BUILD/live"
"$BUILD/live"
