# Unreal Engine Troubleshooting Guide

Solutions to common issues when using Unreal Engine with Flutter.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Build Issues](#build-issues)
- [Runtime Issues](#runtime-issues)
- [Performance Issues](#performance-issues)
- [Platform-Specific Issues](#platform-specific-issues)
- [Communication Issues](#communication-issues)
- [FAQ](#faq)

---

## Installation Issues

### Plugin Not Found

**Problem:** Flutter can't find the gameframework_unreal plugin.

**Solution:**
```bash
# Clean and get dependencies
flutter clean
flutter pub get

# Verify plugin is installed
flutter pub deps | grep gameframework_unreal
```

### Version Conflicts

**Problem:** Dependency version conflicts.

**Solution:**
```yaml
# In pubspec.yaml, use compatible versions
dependencies:
  gameframework: ^0.5.0
  gameframework_unreal: ^0.5.0
```

```bash
flutter pub upgrade
```

---

## Build Issues

### Android Build Fails

#### Library Not Found

**Problem:** `libUnrealFlutterBridge.so not found`

**Solution:**
1. Verify library is in correct location:
```bash
ls android/app/src/main/jniLibs/arm64-v8a/libUnrealFlutterBridge.so
```

2. Check `build.gradle` has correct `abiFilters`:
```gradle
android {
    defaultConfig {
        ndk {
            abiFilters 'arm64-v8a'
        }
    }
}
```

3. Rebuild:
```bash
flutter clean
flutter build apk --release
```

#### NDK Version Mismatch

**Problem:** NDK version incompatible with Unreal.

**Solution:**
1. Install NDK r25 or later
2. Set in `local.properties`:
```properties
ndk.dir=/path/to/android-ndk-r25c
```

#### Missing Permissions

**Problem:** App crashes due to missing permissions.

**Solution:**
Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-feature android:glEsVersion="0x00030000" android:required="true" />
```

### iOS Build Fails

#### Framework Not Found

**Problem:** `UnrealFramework.framework not found`

**Solution:**
1. Verify framework is embedded in Xcode:
   - Open `ios/Runner.xcworkspace`
   - Select Runner target → General tab
   - Check Frameworks section for UnrealFramework
   - Ensure it's set to "Embed & Sign"

2. Check Framework Search Paths:
   - Build Settings → Search "Framework Search Paths"
   - Add: `$(PROJECT_DIR)/Frameworks`

#### Bitcode Error

**Problem:** `Bitcode is not supported`

**Solution:**
In Xcode Build Settings:
```
Enable Bitcode: NO
```

Or in Podfile:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
```

#### Code Signing Error

**Problem:** Code signing fails.

**Solution:**
1. Select valid development team in Xcode
2. Enable "Automatically manage signing"
3. Or configure manual signing with valid certificate

### macOS Build Fails

#### Entitlements Error

**Problem:** App crashes due to entitlements.

**Solution:**
Add to `macos/Runner/DebugProfile.entitlements`:
```xml
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

### Windows Build Fails

#### DLL Not Found

**Problem:** `UnrealFlutterBridge.dll not found`

**Solution:**
1. Copy DLL to build directory:
```powershell
Copy-Item UnrealFlutterBridge.dll build\windows\runner\Release\
```

2. Update CMakeLists.txt:
```cmake
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/UnrealFlutterBridge.dll"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>"
)
```

#### Visual Studio Version

**Problem:** Wrong Visual Studio version.

**Solution:**
Install Visual Studio 2022 with C++ development tools.

---

## Runtime Issues

### Black Screen

**Problem:** App shows black screen instead of Unreal content.

**Possible Causes & Solutions:**

1. **Engine Not Initialized:**
```dart
// Ensure create() is called
await controller.create();
```

2. **Level Not Loaded:**
```dart
// Load initial level
await controller.loadLevel('MainMenu');
```

3. **Quality Settings Too Low:**
```dart
// Try higher quality
await controller.applyQualitySettings(UnrealQualitySettings.medium());
```

4. **View Not Attached:**
```dart
// Check GameEngineWidget is properly rendered
GameEngineWidget(
  engineType: GameEngineType.unreal,
  onControllerCreated: (controller) {
    // Controller should be created
  },
)
```

5. **Lighting Issues:**
```dart
// Check level has proper lighting in Unreal Editor
```

### App Crashes on Start

**Problem:** App crashes immediately or shortly after launch.

**Solutions:**

1. **Check Logs:**

**Android:**
```bash
adb logcat | grep -E "Unreal|Flutter|FATAL"
```

**iOS:**
Xcode → Window → Devices and Simulators → View Device Logs

**macOS:**
```bash
log stream --predicate 'subsystem contains "flutter"' --level error
```

2. **Memory Issues:**
```dart
// Lower quality settings
await controller.applyQualitySettings(UnrealQualitySettings.low());
```

3. **Missing Dependencies:**
```bash
# Android: Check all .so files are included
# iOS: Check all frameworks are embedded
```

### Controller Not Created

**Problem:** `onControllerCreated` never called.

**Solution:**
```dart
// Ensure GameEngineWidget is properly in widget tree
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: GameEngineWidget(  // Must be rendered
      engineType: GameEngineType.unreal,
      onControllerCreated: (controller) {
        print('Controller created!');  // Add logging
        _controller = controller as UnrealController;
      },
    ),
  );
}
```

### Messages Not Received

**Problem:** Messages from Unreal not received in Flutter.

**Solution:**

1. **Check Stream Listener:**
```dart
// Ensure you're listening to messages
controller.messages.listen((message) {
  print('Received: ${message.method}');
});
```

2. **Verify FlutterBridge in Level:**
```
In Unreal Editor, check FlutterBridge actor exists in level
```

3. **Check Message Format:**
```dart
// In Unreal Blueprint:
FlutterBridge → SendToFlutter
  Target: "MyTarget"
  Method: "myMethod"
  Data: "{\"key\": \"value\"}"  // Valid JSON
```

4. **Enable Debug Logging:**
```dart
// Add logging to track messages
controller.messages.listen((message) {
  debugPrint('Target: ${message.target}');
  debugPrint('Method: ${message.method}');
  debugPrint('Data: ${message.data}');
});
```

---

## Performance Issues

### Low Frame Rate

**Problem:** Game runs at low FPS.

**Solutions:**

1. **Check Current FPS:**
```dart
await controller.executeConsoleCommand('stat fps');
await controller.executeConsoleCommand('stat unit');
```

2. **Lower Quality Settings:**
```dart
await controller.applyQualitySettings(UnrealQualitySettings.low());
```

3. **Reduce Resolution:**
```dart
await controller.applyQualitySettings(
  UnrealQualitySettings.medium().copyWith(
    resolutionScale: 0.75,  // 75% of native
  ),
);
```

4. **Disable Expensive Features:**
```dart
await controller.executeConsoleCommand('sg.ShadowQuality 0');
await controller.executeConsoleCommand('sg.EffectsQuality 0');
await controller.executeConsoleCommand('sg.FoliageQuality 0');
```

5. **Profile Performance:**
```dart
await controller.executeConsoleCommand('stat gpu');
await controller.executeConsoleCommand('stat scenerendering');
```

### Memory Issues

**Problem:** App uses too much memory or crashes with out-of-memory.

**Solutions:**

1. **Check Memory Usage:**
```dart
await controller.executeConsoleCommand('stat memory');
```

2. **Reduce Texture Quality:**
```dart
await controller.applyQualitySettings(
  UnrealQualitySettings.low().copyWith(
    textureQuality: 0,  // Lowest
  ),
);
```

3. **Unload Unused Levels:**
```dart
// Properly quit when done
await controller.quit();
```

4. **Use Streaming Levels:**
```
Configure Unreal to use level streaming for large worlds
```

### Stuttering

**Problem:** Game stutters or has frame drops.

**Solutions:**

1. **Enable VSync:**
```dart
await controller.executeConsoleCommand('r.VSync 1');
```

2. **Cap Frame Rate:**
```dart
await controller.executeConsoleCommand('t.MaxFPS 60');
```

3. **Check Background Processes:**
```
Close other apps running on device
```

4. **Preload Assets:**
```
Configure Unreal to preload frequently used assets
```

---

## Platform-Specific Issues

### Android

#### App Won't Install

**Problem:** APK installation fails.

**Solution:**
```bash
# Uninstall old version first
adb uninstall com.example.yourapp

# Install new version
flutter install
```

#### Texture Issues

**Problem:** Textures appear black or corrupted.

**Solution:**
1. Check Unreal project is built with correct texture compression (ASTC for Android)
2. Reduce texture quality:
```dart
await controller.executeConsoleCommand('sg.TextureQuality 0');
```

#### Touch Input Not Working

**Problem:** Touch input doesn't work in Unreal.

**Solution:**
Configure Unreal project to handle touch input:
```
Project Settings → Input → Mobile → Enable Touch Interface
```

### iOS

#### Frame Rate Capped

**Problem:** Frame rate stuck at 30 FPS.

**Solution:**
1. Disable VSync:
```dart
await controller.executeConsoleCommand('r.VSync 0');
```

2. Set target frame rate:
```dart
await controller.executeConsoleCommand('t.MaxFPS 60');
```

3. Check iOS settings:
```
Settings → Display → ProMotion (for 120Hz devices)
```

#### App Rejected

**Problem:** App Store rejection due to Unreal framework.

**Solution:**
1. Ensure framework is properly signed
2. Strip unused architectures
3. Check App Store requirements for game engines

### macOS

#### Gatekeeper Blocks App

**Problem:** "App is damaged and can't be opened"

**Solution:**
```bash
# Remove quarantine attribute
xattr -cr /path/to/YourApp.app

# Or allow in System Preferences:
# Security & Privacy → Allow apps from: App Store and identified developers
```

### Windows

#### Antivirus Blocks

**Problem:** Antivirus flags app.

**Solution:**
1. Add app to antivirus exclusions
2. Sign executable with valid certificate
3. Submit to antivirus vendors for whitelisting

---

## Communication Issues

### sendMessage Not Working

**Problem:** Messages from Flutter to Unreal don't work.

**Solution:**

1. **Check FlutterBridge Exists:**
```
Verify FlutterBridge actor is in the level
```

2. **Check Message Handler:**
```blueprint
// In Unreal Blueprint:
FlutterBridge → OnMessageFromFlutter (Event)
  → Print String (Target, Method, Data)  // Debug logging
```

3. **Verify Message Format:**
```dart
// Correct usage
await controller.sendMessage('Target', 'Method', 'data');

// For JSON
await controller.sendJsonMessage('Target', 'Method', {'key': 'value'});
```

### Console Commands Don't Work

**Problem:** Console commands have no effect.

**Solution:**

1. **Check Command Syntax:**
```dart
// Correct
await controller.executeConsoleCommand('stat fps');

// Incorrect (no await)
controller.executeConsoleCommand('stat fps');  // Won't work
```

2. **Verify Engine is Ready:**
```dart
// Wait for engine to be created
await controller.create();
await Future.delayed(Duration(seconds: 1));

// Now commands will work
await controller.executeConsoleCommand('stat fps');
```

3. **Check Console is Available:**
```
Some commands only work in development builds
```

---

## FAQ

### Q: Can I use Unreal Engine 4?

**A:** This plugin is designed for Unreal Engine 5.3+. UE4 is not officially supported, though it may work with modifications.

### Q: Does this work with Unreal Engine source builds?

**A:** Yes, as long as you build the FlutterPlugin for your Unreal version.

### Q: Can I use this in production?

**A:** Yes, the plugin is production-ready. Test thoroughly on your target platforms.

### Q: What's the minimum device requirements?

**A:**
- **Android:** API 21+, 2GB RAM minimum, OpenGL ES 3.0
- **iOS:** iOS 12.0+, iPhone 8 or newer recommended
- **Desktop:** Modern GPU, 8GB RAM minimum

### Q: Does this support multiplayer?

**A:** Yes, Unreal's networking features work normally. Configure networking in Unreal as usual.

### Q: Can I use Unreal Marketplace assets?

**A:** Yes, all Unreal Marketplace assets and plugins are compatible.

### Q: How do I debug Unreal code?

**A:**
- **Android:** Use Android Studio or `adb logcat`
- **iOS:** Use Xcode debugger
- **Desktop:** Use Visual Studio or native debuggers

### Q: Can I hot reload?

**A:** Flutter hot reload works for Flutter code. Unreal changes require rebuilding the Unreal project.

### Q: What about WebGL/web support?

**A:** Web support via Pixel Streaming is planned for future versions.

### Q: Can I use Blueprint only?

**A:** Yes! All features are accessible through Blueprints. C++ is optional.

### Q: How do I optimize for mobile?

**A:** Use `UnrealQualitySettings.low()`, reduce resolution scale, disable expensive features. See [QUALITY_SETTINGS_GUIDE.md](QUALITY_SETTINGS_GUIDE.md).

### Q: Can I use this with Unity too?

**A:** Yes! The GameFramework supports both Unity and Unreal in the same project (though not simultaneously in one screen).

---

## Getting Additional Help

### Check Logs

**Android:**
```bash
adb logcat -s "Unreal:* Flutter:* UnrealEngine:*"
```

**iOS:**
```
Xcode → Window → Devices and Simulators → Device → View Device Logs
```

**Desktop:**
Check console output in terminal/IDE

### Enable Verbose Logging

```dart
// In your app initialization
import 'package:flutter/foundation.dart';

void main() {
  debugPrint('Starting app...');

  // Your initialization
}
```

### Report Issues

If you encounter a bug:

1. Check existing issues: https://github.com/xraph/flutter-game-framework/issues
2. Create new issue with:
   - Flutter version (`flutter --version`)
   - Unreal Engine version
   - Platform and device
   - Complete error message and logs
   - Minimal reproduction steps

### Community Support

- GitHub Discussions: https://github.com/xraph/flutter-game-framework/discussions
- Stack Overflow: Tag with `flutter` and `unreal-engine`

---

**Last Updated:** 2025-10-27
**Plugin Version:** 0.5.0

**See Also:**
- [README.md](README.md) - Main documentation
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Setup instructions
- [QUALITY_SETTINGS_GUIDE.md](QUALITY_SETTINGS_GUIDE.md) - Performance optimization
