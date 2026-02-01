#!/bin/bash

# Fix Unity Android Embedding Issues
# This script ensures Unity runs embedded in Flutter, not as a standalone app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UNITY_LIBRARY="$PROJECT_ROOT/example/android/unityLibrary"

echo "🔧 Fixing Unity Android Embedding..."
echo "Project root: $PROJECT_ROOT"
echo "Unity library: $UNITY_LIBRARY"

if [ ! -d "$UNITY_LIBRARY" ]; then
    echo "❌ Error: unityLibrary not found at $UNITY_LIBRARY"
    echo "   Please export Unity project first!"
    exit 1
fi

# 1. Fix AndroidManifest.xml - Remove launcher intent
echo ""
echo "📝 Step 1: Fixing AndroidManifest.xml..."
MANIFEST="$UNITY_LIBRARY/src/main/AndroidManifest.xml"

if [ -f "$MANIFEST" ]; then
    # Backup original
    cp "$MANIFEST" "$MANIFEST.backup"
    
    # Remove launcher intent filter using Python (more reliable than sed)
    python3 - <<EOF
import re
import sys

with open('$MANIFEST', 'r') as f:
    content = f.read()

# Remove intent-filter with MAIN/LAUNCHER
pattern = r'<intent-filter>.*?<action\s+android:name="android\.intent\.action\.MAIN".*?</intent-filter>'
content = re.sub(pattern, '', content, flags=re.DOTALL)

# Ensure exported="false" on UnityPlayerActivity if not present
if 'android:exported=' not in content:
    content = content.replace(
        '<activity\n            android:name="com.unity3d.player.UnityPlayerActivity"',
        '<activity\n            android:name="com.unity3d.player.UnityPlayerActivity"\n            android:exported="false"'
    )

with open('$MANIFEST', 'w') as f:
    f.write(content)

print("✅ AndroidManifest.xml fixed")
EOF
else
    echo "⚠️  Manifest not found at $MANIFEST"
fi

# 2. Fix build.gradle - Ensure it's a library, not application
echo ""
echo "📝 Step 2: Fixing build.gradle..."
BUILD_GRADLE="$UNITY_LIBRARY/build.gradle"

if [ -f "$BUILD_GRADLE" ]; then
    # Backup original
    cp "$BUILD_GRADLE" "$BUILD_GRADLE.backup"
    
    # Change application to library
    sed -i.tmp "s/apply plugin: 'com.android.application'/apply plugin: 'com.android.library'/g" "$BUILD_GRADLE"
    
    # Remove applicationId if present
    sed -i.tmp "/applicationId/d" "$BUILD_GRADLE"
    
    rm -f "$BUILD_GRADLE.tmp"
    
    echo "✅ build.gradle fixed (now a library module)"
else
    echo "⚠️  build.gradle not found at $BUILD_GRADLE"
fi

# 3. Verify settings.gradle includes unityLibrary
echo ""
echo "📝 Step 3: Verifying settings.gradle..."
SETTINGS_GRADLE="$PROJECT_ROOT/example/android/settings.gradle"

if [ -f "$SETTINGS_GRADLE" ]; then
    if ! grep -q "include ':unityLibrary'" "$SETTINGS_GRADLE"; then
        echo "include ':unityLibrary'" >> "$SETTINGS_GRADLE"
        echo "✅ Added unityLibrary to settings.gradle"
    else
        echo "✅ settings.gradle already includes unityLibrary"
    fi
else
    echo "⚠️  settings.gradle not found"
fi

# 4. Verify app build.gradle has unityLibrary dependency
echo ""
echo "📝 Step 4: Verifying app build.gradle..."
APP_BUILD_GRADLE="$PROJECT_ROOT/example/android/app/build.gradle"

if [ -f "$APP_BUILD_GRADLE" ]; then
    if ! grep -q "implementation project(':unityLibrary')" "$APP_BUILD_GRADLE"; then
        # Add dependency in dependencies block
        sed -i.tmp "/dependencies {/a\\
    implementation project(':unityLibrary')
" "$APP_BUILD_GRADLE"
        rm -f "$APP_BUILD_GRADLE.tmp"
        echo "✅ Added unityLibrary dependency to app build.gradle"
    else
        echo "✅ app build.gradle already has unityLibrary dependency"
    fi
else
    echo "⚠️  app build.gradle not found"
fi

# 5. Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Unity embedding fixes applied!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_ROOT/example"
echo "  2. flutter clean"
echo "  3. flutter pub get"
echo "  4. flutter run"
echo ""
echo "Expected behavior:"
echo "  ✅ App launches in Flutter"
echo "  ✅ Unity renders embedded in Flutter UI"
echo "  ❌ Unity does NOT launch as separate app"
echo ""
echo "Backups saved with .backup extension"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

