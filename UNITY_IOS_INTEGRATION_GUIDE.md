# Unity iOS Integration Guide

## Overview

Integrating Unity into a Flutter iOS app requires building the UnityFramework and embedding it in your app. This guide provides step-by-step instructions.

## Current Issue

The Unity export creates an Xcode project, but you need to build the `UnityFramework.framework` from it manually due to Xcode/Unity version compatibility.

**Error you're seeing:**
```
Unable to find module dependency: 'UnityFramework'
```

This means the framework hasn't been built yet.

## Solution: Manual Framework Build (Recommended)

### Step 1: Export Unity Project

```bash
cd /path/to/your/flutter/app
game export unity -p ios
```

This creates: `unity/demo/Exports/iOS/Unity-iPhone.xcodeproj`

### Step 2: Build UnityFramework

**Option A: Using Xcode GUI**

1. Open `unity/demo/Exports/iOS/Unity-iPhone.xcodeproj` in Xcode
2. Select "UnityFramework" scheme (top bar, next to the play button)
3. Select "Any iOS Device (arm64)" as the destination
4. Product → Build (⌘B)
5. The framework will be in `DerivedData`

**Option B: Using Command Line**

```bash
cd unity/demo/Exports/iOS

xcodebuild -project Unity-iPhone.xcodeproj \
  -scheme UnityFramework \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath ./Build \
  ONLY_ACTIVE_ARCH=NO \
  build
```

The built framework will be at:
```
unity/demo/Exports/iOS/Build/Build/Products/Release-iphoneos/UnityFramework.framework
```

### Step 3: Copy Framework to Plugin

Copy the built framework to the Unity plugin's iOS directory:

```bash
# From your Flutter app root
cp -R unity/demo/Exports/iOS/Build/Build/Products/Release-iphoneos/UnityFramework.framework \
  .flutter-plugins-dependencies

# Find the gameframework_unity plugin path (it's in the file above)
# Then copy to: <plugin_path>/ios/UnityFramework.framework
```

**Or** copy to your app's iOS folder:

```bash
cp -R unity/demo/Exports/iOS/Build/Build/Products/Release-iphoneos/UnityFramework.framework \
  ios/Frameworks/
```

### Step 4: Update Podfile (if copying to app's iOS folder)

Edit `ios/Podfile` and add after the `target 'Runner' do` line:

```ruby
target 'Runner' do
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Unity Framework
  pod 'UnityFramework', :path => 'Frameworks/UnityFramework.framework'
  
  target 'RunnerTests' do
    inherit! :search_paths
  end
end
```

### Step 5: Install Pods and Build

```bash
cd ios
pod install
cd ..
flutter run
```

## Troubleshooting

### Issue: Xcode Build Fails with Atomic Header Errors

**Problem:** Unity 2022.3.x may have compilation issues with Xcode 15+

**Solutions:**

1. **Update Unity Version** (Recommended)
   - Use Unity 2022.3.40f1 or later which has Xcode 15/16 fixes
   
2. **Downgrade Xcode**
   - Use Xcode 14.x which is more compatible
   
3. **Apply Unity Patch**
   - Unity has patches for IL2CPP atomic issues
   - Download from Unity's support site

4. **Use Pre-built Framework**
   - If you have a Mac with older Xcode, build there
   - Copy the .framework to your development machine

### Issue: Architecture Mismatch

**Problem:** Building for wrong architecture (simulator vs device)

**Solution:**

Build for **device** (arm64):
```bash
xcodebuild -sdk iphoneos ...
```

Build for **simulator** (x86_64, arm64-sim):
```bash
xcodebuild -sdk iphonesimulator ...
```

For **universal** (both device and simulator), create an XCFramework:
```bash
# Build for device
xcodebuild -project Unity-iPhone.xcodeproj \
  -scheme UnityFramework -sdk iphoneos \
  -configuration Release \
  -derivedDataPath ./Build-Device \
  ONLY_ACTIVE_ARCH=NO build

# Build for simulator  
xcodebuild -project Unity-iPhone.xcodeproj \
  -scheme UnityFramework -sdk iphonesimulator \
  -configuration Release \
  -derivedDataPath ./Build-Simulator \
  ONLY_ACTIVE_ARCH=NO build

# Create XCFramework
xcodebuild -create-xcframework \
  -framework ./Build-Device/Build/Products/Release-iphoneos/UnityFramework.framework \
  -framework ./Build-Simulator/Build/Products/Release-iphonesimulator/UnityFramework.framework \
  -output ./UnityFramework.xcframework
```

Then use the `.xcframework` instead of `.framework`.

### Issue: Module Not Found

**Problem:** Swift can't find `import UnityFramework`

**Checklist:**
1. ✅ Framework is in the correct location
2. ✅ Podfile references the framework
3. ✅ Run `pod install` after copying framework
4. ✅ Clean build folder (Product → Clean Build Folder in Xcode)
5. ✅ Framework is for correct architecture (device/simulator)

### Issue: Deployment Target Mismatch

**Problem:** "iOS deployment target is set to 11.0, but the range is 12.0 to 26.0"

**Solution:**

Edit `Unity-iPhone.xcodeproj` before building:
1. Open project in Xcode
2. Select "UnityFramework" target
3. Build Settings → Deployment → iOS Deployment Target → Set to 12.0 or higher
4. Rebuild

Or use command line:
```bash
xcodebuild ... IPHONEOS_DEPLOYMENT_TARGET=12.0
```

## Alternative: Using Unity Cloud Build

If local building is problematic, use Unity Cloud Build:

1. Push your Unity project to Git
2. Set up Unity Cloud Build
3. Configure iOS build
4. Download the built .framework
5. Add to your Flutter project

## Automated Solution (Future)

The CLI will eventually support automatic framework building, but currently requires manual build due to Xcode compatibility issues.

Track progress: [Add automatic iOS framework building to CLI]

## Quick Reference

### File Locations

- **Unity Export**: `unity/demo/Exports/iOS/`
- **Xcode Project**: `unity/demo/Exports/iOS/Unity-iPhone.xcodeproj`
- **Built Framework**: `unity/demo/Exports/iOS/Build/Build/Products/Release-iphoneos/UnityFramework.framework`
- **Plugin iOS**: `<gameframework_unity_plugin>/ios/UnityFramework.framework`
- **App iOS**: `ios/Frameworks/UnityFramework.framework`

### Commands

```bash
# Export Unity
game export unity -p ios

# Build Framework (from export directory)
xcodebuild -project Unity-iPhone.xcodeproj \
  -scheme UnityFramework -sdk iphoneos \
  -configuration Release build

# Install Pods
cd ios && pod install && cd ..

# Run App
flutter run
```

## Need Help?

- Unity Forums: https://forum.unity.com/
- Unity-as-a-Library Documentation: https://docs.unity3d.com/Manual/UnityasaLibrary.html
- Flutter Game Framework Issues: https://github.com/xraph/flutter-game-framework/issues

