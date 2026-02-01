#!/bin/bash

# Test Unity Embedding - Comprehensive Test Script
# This script runs all tests and diagnostics for Unity embedding

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_DIR="$PROJECT_ROOT/example"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Unity Embedding Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

# Function to run command and capture result
run_test() {
    local test_name="$1"
    shift
    echo ""
    echo -e "${BLUE}▶ Testing:${NC} $test_name"
    
    if "$@"; then
        test_result 0 "$test_name"
        return 0
    else
        test_result 1 "$test_name"
        return 1
    fi
}

cd "$EXAMPLE_DIR"

echo "📍 Working directory: $EXAMPLE_DIR"
echo ""

# ==================================================
# 1. PRE-FLIGHT CHECKS
# ==================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Pre-Flight Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Flutter
run_test "Flutter installed" flutter --version > /dev/null 2>&1

# Check Android device/emulator
if adb devices | grep -q "device$"; then
    test_result 0 "Android device connected"
    DEVICE_CONNECTED=true
else
    test_result 1 "Android device connected (optional for some tests)"
    DEVICE_CONNECTED=false
fi

# Check Unity export
if [ -d "android/unityLibrary" ]; then
    test_result 0 "Unity export exists"
    UNITY_EXPORTED=true
else
    test_result 1 "Unity export exists (required for device tests)"
    UNITY_EXPORTED=false
fi

# ==================================================
# 2. STATIC CHECKS
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Static Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check AndroidManifest for launcher intent
if [ "$UNITY_EXPORTED" = true ]; then
    echo ""
    echo -e "${BLUE}▶ Checking:${NC} AndroidManifest launcher intent"
    
    if grep -q "android.intent.category.LAUNCHER" android/unityLibrary/src/main/AndroidManifest.xml; then
        test_result 1 "No LAUNCHER intent in Unity manifest (CRITICAL)"
        echo -e "${YELLOW}⚠️  Run: ./scripts/fix_unity_embedding.sh${NC}"
    else
        test_result 0 "No LAUNCHER intent in Unity manifest"
    fi
    
    # Check exported flag
    echo ""
    echo -e "${BLUE}▶ Checking:${NC} Unity activity exported flag"
    
    if grep -q 'android:exported="false"' android/unityLibrary/src/main/AndroidManifest.xml; then
        test_result 0 "Unity activity not exported"
    else
        test_result 1 "Unity activity should not be exported"
    fi
    
    # Check build.gradle
    echo ""
    echo -e "${BLUE}▶ Checking:${NC} Unity library configuration"
    
    if grep -q "apply plugin: 'com.android.library'" android/unityLibrary/build.gradle; then
        test_result 0 "Unity configured as library"
    else
        test_result 1 "Unity should be library, not application"
    fi
fi

# ==================================================
# 3. UNIT TESTS
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Unit Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$PROJECT_ROOT"
run_test "Core framework unit tests" flutter test

# ==================================================
# 4. INTEGRATION TESTS (if device available)
# ==================================================
if [ "$DEVICE_CONNECTED" = true ] && [ "$UNITY_EXPORTED" = true ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 Integration Tests (on device)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    cd "$EXAMPLE_DIR"
    
    # Clean build
    echo ""
    echo -e "${BLUE}▶ Cleaning:${NC} Flutter build cache"
    flutter clean > /dev/null 2>&1
    flutter pub get > /dev/null 2>&1
    
    # Run integration tests
    run_test "Unity embedding integration tests" \
        flutter test integration_test/unity_embedding_test.dart \
        --timeout=5m
    
else
    echo ""
    echo -e "${YELLOW}⚠️  Skipping integration tests:${NC}"
    [ "$DEVICE_CONNECTED" = false ] && echo "   - No Android device connected"
    [ "$UNITY_EXPORTED" = false ] && echo "   - Unity not exported"
    echo ""
    echo "To run integration tests:"
    echo "  1. Connect Android device: adb devices"
    echo "  2. Export Unity: In Unity → Flutter → Export for Flutter"
    echo "  3. Run: flutter test integration_test/"
fi

# ==================================================
# 5. LOGCAT DIAGNOSTICS (if device available)
# ==================================================
if [ "$DEVICE_CONNECTED" = true ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 Logcat Diagnostics"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    echo "💡 To watch Unity logs in real-time:"
    echo "   adb logcat | grep -E '(Unity|GameEngine)'"
    echo ""
    echo "💡 To check for errors:"
    echo "   adb logcat | grep -E '(ERROR|FATAL)'"
fi

# ==================================================
# 6. BUILD TEST (if device available)
# ==================================================
if [ "$DEVICE_CONNECTED" = true ] && [ "$UNITY_EXPORTED" = true ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏗️  Build Test"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    cd "$EXAMPLE_DIR"
    
    echo ""
    echo -e "${BLUE}▶ Building:${NC} Debug APK"
    if flutter build apk --debug > /tmp/build_log.txt 2>&1; then
        test_result 0 "Debug APK builds successfully"
        
        # Check APK size
        APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
        if [ -f "$APK_PATH" ]; then
            APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
            echo "   APK size: $APK_SIZE"
        fi
    else
        test_result 1 "Debug APK build"
        echo "   See: /tmp/build_log.txt for details"
    fi
fi

# ==================================================
# 7. VISUAL TEST INSTRUCTIONS
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👁️  Manual Visual Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To perform visual test:"
echo ""
echo "  1. Run app: cd $EXAMPLE_DIR && flutter run"
echo "  2. Tap 'Unity Example' button"
echo "  3. Verify:"
echo "     ✅ Flutter UI visible (top bar, buttons)"
echo "     ✅ Unity content visible (NOT black screen)"
echo "     ✅ Can interact with Unity"
echo "     ✅ Back button returns to Flutter"
echo ""
echo "  4. Test lifecycle:"
echo "     - Press home button (should pause Unity)"
echo "     - Return to app (should resume Unity)"
echo "     - Press back (should dispose Unity cleanly)"
echo ""

# ==================================================
# SUMMARY
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run visual test (see instructions above)"
    echo "  2. Test on multiple devices"
    echo "  3. Test different Unity scenes"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check: engines/unity/TROUBLESHOOTING.md"
    echo "  2. Check: engines/unity/BLACK_SCREEN_FIX.md"
    echo "  3. Run fix: ./scripts/fix_unity_embedding.sh"
    exit 1
fi

