# Unreal Engine Setup Guide

Complete setup instructions for integrating Unreal Engine 5.x with Flutter on all supported platforms.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Unreal Project Configuration](#unreal-project-configuration)
- [Android Setup](#android-setup)
- [iOS Setup](#ios-setup)
- [macOS Setup](#macos-setup)
- [Windows Setup](#windows-setup)
- [Linux Setup](#linux-setup)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

**For All Platforms:**
- Flutter 3.10.0 or later
- Dart 3.0.0 or later
- Unreal Engine 5.3.x or 5.4.x
- Git

**Platform-Specific:**
- **Android:** Android Studio, Android NDK r25+
- **iOS/macOS:** Xcode 14.0+ (macOS only)
- **Windows:** Visual Studio 2022 with C++ development tools
- **Linux:** GCC 9+, GTK 3.0+, CMake 3.20+

### Unreal Engine

Download and install Unreal Engine 5.3 or 5.4 from:
- Epic Games Launcher
- Or build from source: https://github.com/EpicGames/UnrealEngine

---

## Unreal Project Configuration

### 1. Create Unreal Project

Create a new Unreal Engine 5.x project or use an existing one:

```
File → New Project
→ Select Template (Game, First Person, Third Person, etc.)
→ Set Project Name
→ Create Project
```

### 2. Install Flutter Plugin

Copy the Flutter plugin to your Unreal project:

```bash
# From gameframework repository
cp -r engines/unreal/plugin YourUnrealProject/Plugins/FlutterPlugin
```

Your project structure should look like:

```
YourUnrealProject/
├── Content/
├── Plugins/
│   └── FlutterPlugin/
│       ├── FlutterPlugin.uplugin
│       ├── Source/
│       │   └── FlutterPlugin/
│       │       ├── FlutterPlugin.Build.cs
│       │       ├── Public/
│       │       │   └── FlutterBridge.h
│       │       └── Private/
│       │           ├── FlutterBridge.cpp
│       │           └── Android/
│       │               └── FlutterBridge_Android.cpp
│       └── ...
└── YourProject.uproject
```

### 3. Enable Plugin

1. Open your Unreal project
2. Go to **Edit → Plugins**
3. Search for "Flutter"
4. Check the box to enable **Flutter Plugin**
5. Restart Unreal Editor

### 4. Add FlutterBridge to Level

**Option A: Blueprint (Recommended for Beginners)**

1. In your level, search for "FlutterBridge" in the Place Actors panel
2. Drag `FlutterBridge` actor into your level
3. The actor will automatically initialize when the level loads

**Option B: GameMode C++**

```cpp
// YourGameMode.h
#include "FlutterBridge.h"

UCLASS()
class YOURPROJECT_API AYourGameMode : public AGameModeBase
{
    GENERATED_BODY()

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY()
    AFlutterBridge* FlutterBridge;
};

// YourGameMode.cpp
void AYourGameMode::BeginPlay()
{
    Super::BeginPlay();

    // Spawn FlutterBridge actor
    FlutterBridge = GetWorld()->SpawnActor<AFlutterBridge>();
}
```

### 5. Configure Build Settings

**Project Settings → Platforms → [Your Platform]:**

- Enable Mobile rendering features (for mobile platforms)
- Configure target API levels
- Set up signing certificates

---

## Android Setup

### 1. Build Unreal for Android

**In Unreal Editor:**

1. **File → Package Project → Android → Android (Multi:ASTC,DXT,ETC2)**
2. Select output directory
3. Wait for build to complete (may take 10-30 minutes)

The build will create:
```
YourUnrealProject/Binaries/Android/
├── YourProject-Android-Shipping.apk
└── lib/
    └── arm64-v8a/
        └── libUnrealFlutterBridge.so
```

### 2. Configure Flutter Project

**pubspec.yaml:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  gameframework: ^0.5.0
  gameframework_unreal: ^0.5.0
```

**android/app/build.gradle:**
```gradle
android {
    compileSdkVersion 33

    defaultConfig {
        applicationId "com.example.yourapp"
        minSdkVersion 21  // Minimum for Unreal
        targetSdkVersion 33

        ndk {
            abiFilters 'arm64-v8a'  // Match Unreal build
        }
    }

    buildTypes {
        release {
            // Unreal requires specific flags
            ndk {
                debugSymbolLevel 'FULL'
            }
        }
    }
}
```

### 3. Add Unreal Library

Copy Unreal native library to Flutter project:

```bash
# Create directory
mkdir -p android/app/src/main/jniLibs/arm64-v8a

# Copy Unreal library
cp YourUnrealProject/Binaries/Android/lib/arm64-v8a/libUnrealFlutterBridge.so \
   android/app/src/main/jniLibs/arm64-v8a/
```

### 4. Configure Permissions

**android/app/src/main/AndroidManifest.xml:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Unreal Engine permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

    <!-- OpenGL ES 3.0 -->
    <uses-feature android:glEsVersion="0x00030000" android:required="true" />

    <application
        android:label="Your App"
        android:hardwareAccelerated="true">
        <!-- Your activities -->
    </application>
</manifest>
```

### 5. Build and Run

```bash
flutter run --release  # Debug mode may be slow with Unreal
```

**Troubleshooting Android:**
- If library not found: Check `abiFilters` matches Unreal build
- If crashes on start: Check NDK version compatibility
- For logs: `adb logcat | grep Unreal`

---

## iOS Setup

### 1. Build Unreal for iOS

**In Unreal Editor:**

1. **File → Package Project → iOS**
2. Select output directory
3. Wait for build to complete

The build will create:
```
YourUnrealProject/Binaries/IOS/
└── Payload/
    └── YourProject.app/
        └── Frameworks/
            └── UnrealFramework.framework
```

### 2. Extract Unreal Framework

```bash
# Extract framework
cp -r YourUnrealProject/Binaries/IOS/Payload/YourProject.app/Frameworks/UnrealFramework.framework \
      ~/UnrealFramework.framework
```

### 3. Configure Flutter Project

**ios/Podfile:**
```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Add Unreal Framework
  pod 'UnrealFramework', :path => '~/UnrealFramework.framework'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      # Unreal requires these settings
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
    end
  end
end
```

### 4. Embed Framework in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** project → **Runner** target
3. Go to **General** tab
4. Under **Frameworks, Libraries, and Embedded Content**, click **+**
5. Choose **Add Other → Add Files...**
6. Navigate to `~/UnrealFramework.framework`
7. Set to **Embed & Sign**

### 5. Configure Build Settings

**In Xcode:**

**Build Settings → Search "Bitcode":**
- **Enable Bitcode:** NO

**Build Settings → Search "Architecture":**
- **Build Active Architecture Only:** YES (Debug), NO (Release)
- **Architectures:** arm64

**Build Settings → Search "Framework Search Paths":**
- Add: `$(PROJECT_DIR)/Frameworks`

### 6. Update Info.plist

**ios/Runner/Info.plist:**
```xml
<dict>
    <!-- Existing keys -->

    <!-- Unreal Engine requirements -->
    <key>UIRequiresFullScreen</key>
    <true/>

    <key>UIStatusBarHidden</key>
    <true/>

    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
</dict>
```

### 7. Build and Run

```bash
# Install pods
cd ios
pod install
cd ..

# Run
flutter run --release
```

**Troubleshooting iOS:**
- If framework not found: Check Framework Search Paths
- If "Unsupported Architecture": Verify arm64 only
- For logs: Xcode → Window → Devices and Simulators → View Device Logs

---

## macOS Setup

### 1. Build Unreal for macOS

**In Unreal Editor:**

1. **File → Package Project → Mac**
2. Select output directory
3. Wait for build to complete

The build will create:
```
YourUnrealProject/Binaries/Mac/
└── YourProject.app/
    └── Contents/
        └── Frameworks/
            └── UnrealFramework.framework
```

### 2. Extract Unreal Framework

```bash
# Extract framework
cp -r YourUnrealProject/Binaries/Mac/YourProject.app/Contents/Frameworks/UnrealFramework.framework \
      ~/UnrealFramework.framework
```

### 3. Configure Flutter Project

**macos/Podfile:**
```ruby
platform :osx, '10.14'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_macos_pods File.dirname(File.realpath(__FILE__))

  # Add Unreal Framework
  pod 'UnrealFramework', :path => '~/UnrealFramework.framework'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_macos_build_settings(target)
  end
end
```

### 4. Embed Framework in Xcode

1. Open `macos/Runner.xcworkspace` in Xcode
2. Follow same steps as iOS (see above)
3. Ensure framework is set to **Embed & Sign**

### 5. Configure Entitlements

**macos/Runner/DebugProfile.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing entitlements -->

    <!-- Unreal Engine requirements -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>

    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>

    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

Copy same settings to **Release.entitlements**.

### 6. Build and Run

```bash
flutter run -d macos --release
```

---

## Windows Setup

### 1. Build Unreal for Windows

**In Unreal Editor:**

1. **File → Package Project → Windows → Windows (64-bit)**
2. Select output directory
3. Wait for build to complete

The build will create:
```
YourUnrealProject/Binaries/Win64/
├── YourProject.exe
└── UnrealFlutterBridge.dll
```

### 2. Copy Unreal DLL

Copy Unreal DLL to Flutter project:

```powershell
# Create directory
New-Item -ItemType Directory -Path windows\runner\build\windows\runner\Release -Force

# Copy DLL
Copy-Item YourUnrealProject\Binaries\Win64\UnrealFlutterBridge.dll `
          windows\runner\build\windows\runner\Release\
```

### 3. Configure CMake

**windows/CMakeLists.txt:**

Add after `flutter_windows` target:

```cmake
# Unreal Engine integration
set(UNREAL_ENGINE_DIR "C:/Program Files/Epic Games/UE_5.3")

target_include_directories(${BINARY_NAME} PRIVATE
  "${UNREAL_ENGINE_DIR}/Engine/Source/Runtime/Core/Public"
  "${UNREAL_ENGINE_DIR}/Engine/Source/Runtime/Engine/Public"
)

target_link_libraries(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/build/windows/runner/Release/UnrealFlutterBridge.lib"
)

# Copy Unreal DLL to output
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/build/windows/runner/Release/UnrealFlutterBridge.dll"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>"
)
```

### 4. Build and Run

```powershell
flutter run -d windows --release
```

---

## Linux Setup

### 1. Build Unreal for Linux

**In Unreal Editor (or cross-compile):**

1. **File → Package Project → Linux**
2. Select output directory
3. Wait for build to complete

The build will create:
```
YourUnrealProject/Binaries/Linux/
├── YourProject
└── libUnrealFlutterBridge.so
```

### 2. Copy Unreal Library

```bash
# Create directory
mkdir -p linux/flutter/ephemeral/.plugin_symlinks/gameframework_unreal/linux

# Copy library
cp YourUnrealProject/Binaries/Linux/libUnrealFlutterBridge.so \
   linux/flutter/ephemeral/.plugin_symlinks/gameframework_unreal/linux/
```

### 3. Configure CMake

**linux/CMakeLists.txt:**

Add after `flutter_linux` target:

```cmake
# Unreal Engine integration
set(UNREAL_ENGINE_DIR "/opt/UnrealEngine")

target_include_directories(${BINARY_NAME} PRIVATE
  "${UNREAL_ENGINE_DIR}/Engine/Source/Runtime/Core/Public"
  "${UNREAL_ENGINE_DIR}/Engine/Source/Runtime/Engine/Public"
)

target_link_libraries(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/.plugin_symlinks/gameframework_unreal/linux/libUnrealFlutterBridge.so"
)
```

### 4. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install libgtk-3-dev libx11-dev pkg-config cmake ninja-build

# Fedora
sudo dnf install gtk3-devel libX11-devel cmake ninja-build
```

### 5. Build and Run

```bash
flutter run -d linux --release
```

---

## Testing

### Basic Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_unreal/gameframework_unreal.dart';

void main() {
  test('Unreal plugin initializes', () {
    UnrealEnginePlugin.initialize();
    // Plugin should initialize without errors
  });

  testWidgets('UnrealController creates successfully', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameEngineWidget(
          engineType: GameEngineType.unreal,
          onControllerCreated: (controller) {
            expect(controller, isA<UnrealController>());
          },
        ),
      ),
    );
  });
}
```

### Integration Test

Create `integration_test/unreal_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:your_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Unreal Engine integration test', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Wait for engine to initialize
    await Future.delayed(Duration(seconds: 5));

    // Test is running
    expect(find.byType(GameEngineWidget), findsOneWidget);
  });
}
```

Run:
```bash
flutter test integration_test/unreal_test.dart
```

---

## Troubleshooting

### Common Issues

**"Library not found" (Android)**
- Ensure `.so` file is in correct `jniLibs` folder
- Check `abiFilters` in `build.gradle` matches build
- Verify library name: `libUnrealFlutterBridge.so`

**"Framework not found" (iOS/macOS)**
- Check Framework Search Paths in Xcode
- Ensure framework is set to "Embed & Sign"
- Verify framework architecture matches device

**"DLL not found" (Windows)**
- Ensure DLL is copied to output directory
- Check DLL dependencies with Dependency Walker
- Verify CMake configuration

**Black Screen**
- Check Unreal view is attached
- Verify quality settings aren't too high
- Check device meets minimum requirements
- Look for errors in logs

**Crashes on Startup**
- Check Unreal Engine version compatibility
- Verify all dependencies are linked
- Check for conflicts in build settings
- Review platform-specific logs

### Platform Logs

**Android:**
```bash
adb logcat | grep -E "Unreal|Flutter"
```

**iOS:**
```bash
# In Xcode: Window → Devices and Simulators → View Device Logs
# Or use Console.app on macOS
```

**macOS:**
```bash
log stream --predicate 'subsystem contains "flutter"' --level debug
```

**Windows:**
```powershell
# Check Visual Studio Output window
# Or use DebugView from Sysinternals
```

**Linux:**
```bash
journalctl -f | grep flutter
```

### Getting Help

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Search [GitHub Issues](https://github.com/xraph/gameframework/issues)
3. Ask on [Discussions](https://github.com/xraph/gameframework/discussions)
4. Review Unreal Engine logs in `Saved/Logs/`

---

## Next Steps

- Read [QUALITY_SETTINGS_GUIDE.md](QUALITY_SETTINGS_GUIDE.md) for performance optimization
- See [CONSOLE_COMMANDS.md](CONSOLE_COMMANDS.md) for debugging commands
- Check [LEVEL_LOADING.md](LEVEL_LOADING.md) for advanced level management
- Review example projects in `/examples`

---

**Last Updated:** 2025-10-27
**Plugin Version:** 0.5.0
