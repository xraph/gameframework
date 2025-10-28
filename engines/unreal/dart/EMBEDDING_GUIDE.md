# Unreal Engine Game Embedding Guide

Complete guide to packaging your Unreal Engine game and embedding it in a Flutter application.

## Table of Contents

- [Overview](#overview)
- [Unreal Export Process](#unreal-export-process)
- [Android Integration](#android-integration)
- [iOS Integration](#ios-integration)
- [Desktop Integration](#desktop-integration)
- [Flutter Code Integration](#flutter-code-integration)
- [Complete Example](#complete-example)
- [Troubleshooting](#troubleshooting)

---

## Overview

This guide shows you how to:
1. Package your Unreal Engine game for each platform
2. Integrate the packaged game into your Flutter project
3. Load and control the game from Flutter code

### What You Need

- **Unreal Engine 5.3 or later**
- **Flutter 3.10 or later**
- **FlutterPlugin for Unreal** (from this package)
- Platform-specific tools (Xcode for iOS/macOS, Android Studio for Android)

---

## Unreal Export Process

### Step 1: Install FlutterPlugin in Unreal

1. Copy the `FlutterPlugin` folder to your Unreal project:
   ```
   YourUnrealProject/Plugins/FlutterPlugin/
   ```

2. Add to your project's `.uproject` file:
   ```json
   {
     "Plugins": [
       {
         "Name": "FlutterPlugin",
         "Enabled": true
       }
     ]
   }
   ```

3. Regenerate project files:
   - Right-click `.uproject` → "Generate Visual Studio project files" (Windows)
   - Right-click `.uproject` → "Generate Xcode project" (macOS)

4. Compile the plugin in your IDE

### Step 2: Add FlutterBridge to Your Level

**In Unreal Editor:**

1. Open your main level
2. Place Actors → All Classes → Search "FlutterBridge"
3. Drag `FlutterBridge` actor into your level
4. The bridge will be available as a singleton

**Blueprint Usage:**

```
Get Flutter Bridge → Send To Flutter
  Target: "GameManager"
  Method: "OnScoreUpdate"
  Data: {"score": 100, "level": 5}
```

### Step 3: Configure Project Settings

**Edit → Project Settings:**

**Project:**
- Description: Your game description
- Project Name: YourGame
- Company Name: Your Company
- Homepage: Your URL

**Maps & Modes:**
- Default Maps → Game Default Map: Select your starting level
- Server Default Map: Select your server map

**Supported Platforms:**
- Check platforms you want to support (Android, iOS, Windows, Mac, Linux)

---

## Android Integration

### Unreal Package (Android)

#### 1. Configure Android Settings

**Project Settings → Platforms → Android:**

```
APK Packaging:
  Package game data inside .apk: ✓ (For testing)
  OR
  Package game data inside .apk: ✗ (For production with OBB)

Build:
  Minimum SDK Version: 22
  Target SDK Version: 33
  Enable FullScreen Immersive on KitKat: ✓
  Package for Oculus Mobile: ✗
  Remove Oculus Signature Files: ✓

Build Configuration:
  Support armv7: ✗ (Uncheck)
  Support arm64: ✓ (Check)
  Support x86: ✗
  Support x86_64: ✗

Advanced APKPackaging:
  Configure the AndroidManifest for deployment: ✓

Google Play Services:
  Enable Google Play Support: ✗ (unless you need it)
```

**Project Settings → Android SDK:**
```
Location of Android SDK: /path/to/Android/SDK
Location of Android NDK: /path/to/Android/SDK/ndk/25.x.x
Location of JAVA: /path/to/jdk
```

#### 2. Build for Android

**Platforms → Android → Package Project (ETC2):**

1. Choose: "Package Project"
2. Select output directory: `YourUnrealProject/Packaged/Android`
3. Wait for packaging (can take 15-30 minutes first time)

**What You Get:**
```
Packaged/Android/
├── YourGame-arm64.apk       # If packaging inside APK
└── YourGame/                # Folder structure
    ├── YourGame-arm64.apk
    ├── YourGame.obb          # Game data (if using OBB)
    └── Manifest/
```

#### 3. Extract Game Library

The APK contains the Unreal Engine library we need:

```bash
# Unzip the APK
unzip YourGame-arm64.apk -d extracted/

# The library is at:
# extracted/lib/arm64-v8a/libUnrealFlutterBridge.so
```

### Flutter Integration (Android)

#### 1. Copy Unreal Library

Create the native library directory structure:

```bash
mkdir -p YourFlutterApp/android/app/src/main/jniLibs/arm64-v8a

# Copy the Unreal library
cp extracted/lib/arm64-v8a/libUnreal*.so \
   YourFlutterApp/android/app/src/main/jniLibs/arm64-v8a/
```

**Result:**
```
YourFlutterApp/
└── android/
    └── app/
        └── src/
            └── main/
                └── jniLibs/
                    └── arm64-v8a/
                        ├── libUnrealFlutterBridge.so
                        └── libUE5.so  (and other Unreal libraries)
```

#### 2. Copy Game Assets

```bash
# Copy game data
mkdir -p YourFlutterApp/android/app/src/main/assets/UnrealGame

# Copy from extracted APK
cp -r extracted/assets/* \
      YourFlutterApp/android/app/src/main/assets/UnrealGame/
```

#### 3. Update Flutter Android Configuration

**android/app/build.gradle:**
```gradle
android {
    compileSdkVersion 33

    defaultConfig {
        minSdkVersion 22
        targetSdkVersion 33

        ndk {
            abiFilters 'arm64-v8a'
        }
    }

    buildTypes {
        release {
            // Unreal needs these
            minifyEnabled false
            shrinkResources false
        }
    }

    // Important for Unreal assets
    aaptOptions {
        noCompress 'pak', 'uasset', 'umap', 'upk'
        ignoreAssetsPattern "!.svn:!.git:!.ds_store:!*.scc:.*:!CVS:!thumbs.db:!picasa.ini:!*~"
    }

    packagingOptions {
        // Prevent duplicate libraries
        pickFirst 'lib/arm64-v8a/libc++_shared.so'
    }
}
```

**android/gradle.properties:**
```properties
android.useAndroidX=true
android.enableJetifier=true

# Unreal needs more memory
org.gradle.jvmargs=-Xmx4096m
```

#### 4. Update AndroidManifest.xml

**android/app/src/main/AndroidManifest.xml:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

    <!-- OpenGL ES 3.0 required -->
    <uses-feature
        android:glEsVersion="0x00030000"
        android:required="true" />

    <!-- Vulkan support (optional but recommended) -->
    <uses-feature
        android:name="android.hardware.vulkan.version"
        android:version="0x400003"
        android:required="false" />

    <application
        android:label="Your App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true"
        android:usesCleartextTraffic="true"
        android:hardwareAccelerated="true">

        <!-- Your activities -->

    </application>
</manifest>
```

---

## iOS Integration

### Unreal Package (iOS)

#### 1. Configure iOS Settings

**Project Settings → Platforms → iOS:**

```
Build:
  Support Universal Links: ✗
  Supports ITunes File Sharing: ✗
  Supports IPad: ✓

Minimum iOS Version: 12.0

Bundle Information:
  Bundle Display Name: Your Game
  Bundle Name: YourGame
  Bundle Identifier: com.yourcompany.yourgame

Rendering:
  Support Combined Metal/GLES: ✗
  Support Metal: ✓
  Support OpenGL ES: ✗

Icons:
  (Set your app icons)
```

**Engine → Rendering:**
```
Mobile:
  Mobile HDR: ✓
  Mobile MSAA: 4x

Vulkan Mobile:
  Support Vulkan Mobile Preview: ✗
```

#### 2. Package for iOS

**Platforms → iOS → Package Project:**

1. Choose: "Package Project"
2. Select output directory: `YourUnrealProject/Packaged/iOS`
3. Wait for packaging

**What You Get:**
```
Packaged/iOS/
└── YourGame.ipa          # iOS package
```

#### 3. Create UnrealFramework

The IPA contains the Unreal framework:

```bash
# Unzip IPA
unzip YourGame.ipa -d extracted/

# Framework is at:
# extracted/Payload/YourGame.app/Frameworks/UnrealFramework.framework
```

### Flutter Integration (iOS)

#### 1. Copy UnrealFramework

```bash
# Copy framework
cp -r extracted/Payload/YourGame.app/Frameworks/UnrealFramework.framework \
      YourFlutterApp/ios/

# Copy game content
cp -r extracted/Payload/YourGame.app/YourGame/Content \
      YourFlutterApp/ios/UnrealFramework.framework/Content
```

**Result:**
```
YourFlutterApp/
└── ios/
    ├── Runner/
    ├── Runner.xcworkspace/
    └── UnrealFramework.framework/
        ├── UnrealFramework (binary)
        ├── Content/              ← Game assets
        ├── Headers/
        └── Info.plist
```

#### 2. Update Xcode Project

**Open in Xcode:**
```bash
open ios/Runner.xcworkspace
```

**Add Framework:**
1. Select `Runner` project
2. Select `Runner` target → General
3. Frameworks, Libraries, and Embedded Content → `+`
4. Add Other... → Add Files
5. Select `UnrealFramework.framework`
6. Set to "Embed & Sign"

**Build Settings:**
```
Framework Search Paths: $(PROJECT_DIR)
Other Linker Flags: -weak_framework UnrealFramework
Enable Bitcode: NO
Dead Code Stripping: NO
Strip Debug Symbols During Copy: NO (for Debug)
```

**Build Phases:**

Add Run Script (after "Embed Frameworks"):
```bash
# Strip unused architectures from framework
bash "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/UnrealFramework.framework/strip-frameworks.sh"
```

#### 3. Update Info.plist

**ios/Runner/Info.plist:**
```xml
<dict>
    <!-- Existing keys -->

    <!-- Status bar -->
    <key>UIStatusBarHidden</key>
    <true/>
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>

    <!-- Orientation (adjust as needed) -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeRight</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
    </array>

    <!-- Privacy descriptions -->
    <key>NSCameraUsageDescription</key>
    <string>Camera access for AR features</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Microphone access</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Photo library access</string>
</dict>
```

#### 4. Entitlements

**ios/Runner/Runner.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
```

---

## Desktop Integration

### macOS

#### Unreal Package:

**Platforms → Mac → Package Project:**
```
Package to: YourUnrealProject/Packaged/Mac
```

**What You Get:**
```
Packaged/Mac/
└── YourGame.app
    └── Contents/
        ├── MacOS/
        │   └── YourGame (executable)
        ├── Resources/
        │   └── YourGame/Content/
        └── Frameworks/
            └── UnrealFramework.framework
```

#### Flutter Integration:

**Option 1: Embed Entire App**
```bash
cp -r YourUnrealProject/Packaged/Mac/YourGame.app \
      YourFlutterApp/macos/UnrealGame.app
```

**Option 2: Extract Framework**
```bash
cp -r YourUnrealProject/Packaged/Mac/YourGame.app/Contents/Frameworks/UnrealFramework.framework \
      YourFlutterApp/macos/
```

### Windows

#### Unreal Package:

**Platforms → Windows → Package Project:**
```
Package to: YourUnrealProject/Packaged/Windows
```

**What You Get:**
```
Packaged/Windows/
├── YourGame.exe
├── YourGame/
│   └── Content/
├── Engine/
│   └── Binaries/
└── *.dll files
```

#### Flutter Integration:

```bash
# Copy entire build
cp -r YourUnrealProject/Packaged/Windows/* \
      YourFlutterApp/windows/unreal_build/
```

**windows/CMakeLists.txt:**
```cmake
# Set Unreal build directory
set(UNREAL_BUILD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/unreal_build")

# Copy Unreal DLLs to output
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${UNREAL_BUILD_DIR}"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>"
)
```

### Linux

#### Unreal Package:

**Platforms → Linux → Package Project:**
```
Package to: YourUnrealProject/Packaged/Linux
```

#### Flutter Integration:

```bash
cp -r YourUnrealProject/Packaged/Linux/* \
      YourFlutterApp/linux/unreal_build/
```

---

## Flutter Code Integration

### 1. Add Dependencies

**pubspec.yaml:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  gameframework: ^0.5.0
  gameframework_unreal: ^0.5.0
```

```bash
flutter pub get
```

### 2. Initialize Unreal Plugin

**lib/main.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unreal/gameframework_unreal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Unreal plugin
  UnrealEnginePlugin.initialize();

  runApp(MyApp());
}
```

### 3. Embed Unreal Game in Your UI

**Basic Example:**
```dart
class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Unreal Game')),
      body: GameEngineWidget(
        engineType: GameEngineType.unreal,
        onControllerCreated: (controller) {
          print('Unreal game loaded!');
        },
      ),
    );
  }
}
```

**Advanced Example with Controller:**
```dart
class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  UnrealController? _controller;
  bool _isGameLoaded = false;
  String _currentLevel = 'MainMenu';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Level: $_currentLevel'),
        actions: [
          if (_isGameLoaded)
            PopupMenuButton<String>(
              icon: Icon(Icons.settings),
              onSelected: _changeQuality,
              itemBuilder: (context) => [
                PopupMenuItem(value: 'low', child: Text('Low Quality')),
                PopupMenuItem(value: 'medium', child: Text('Medium Quality')),
                PopupMenuItem(value: 'high', child: Text('High Quality')),
                PopupMenuItem(value: 'epic', child: Text('Epic Quality')),
              ],
            ),
        ],
      ),
      body: GameEngineWidget(
        engineType: GameEngineType.unreal,
        config: GameEngineConfig(
          runImmediately: true,
          enableDebugConsole: true,
        ),
        onControllerCreated: _onUnrealCreated,
      ),
    );
  }

  void _onUnrealCreated(GameEngineController controller) {
    _controller = controller as UnrealController;

    setState(() {
      _isGameLoaded = true;
    });

    // Listen for messages from Unreal
    _controller!.messageStream.listen((message) {
      print('Message from Unreal: ${message.data}');
    });

    // Listen for level loads
    _controller!.sceneLoadStream.listen((scene) {
      setState(() {
        _currentLevel = scene.name;
      });
    });

    // Set initial quality
    _setQuality(UnrealQualitySettings.medium());
  }

  Future<void> _changeQuality(String quality) async {
    if (_controller == null) return;

    UnrealQualitySettings settings;
    switch (quality) {
      case 'low':
        settings = UnrealQualitySettings.low();
        break;
      case 'medium':
        settings = UnrealQualitySettings.medium();
        break;
      case 'high':
        settings = UnrealQualitySettings.high();
        break;
      case 'epic':
        settings = UnrealQualitySettings.epic();
        break;
      default:
        settings = UnrealQualitySettings.medium();
    }

    await _controller!.applyQualitySettings(settings);
  }

  Future<void> _setQuality(UnrealQualitySettings settings) async {
    if (_controller == null) return;
    await _controller!.applyQualitySettings(settings);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

### 4. Communication Between Flutter and Unreal

#### Send Message to Unreal:

**Flutter → Unreal:**
```dart
// Send string message
await controller.sendMessage(
  'GameMode',         // Target actor in Unreal
  'SetDifficulty',    // Function name
  'Hard',             // Data
);

// Send JSON message
await controller.sendJsonMessage(
  'GameMode',
  'LoadLevel',
  {
    'levelName': 'Level_02',
    'difficulty': 'hard',
    'checkpoint': 3,
  },
);
```

**Unreal C++ Code:**
```cpp
// GameMode.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "MyGameMode.generated.h"

UCLASS()
class YOURGAME_API AMyGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    // Called from Flutter
    UFUNCTION(BlueprintCallable, Category = "Flutter")
    void SetDifficulty(const FString& Difficulty);

    UFUNCTION(BlueprintCallable, Category = "Flutter")
    void LoadLevel(const FString& JsonData);
};
```

```cpp
// GameMode.cpp
#include "MyGameMode.h"
#include "FlutterBridge.h"
#include "JsonObjectConverter.h"

void AMyGameMode::SetDifficulty(const FString& Difficulty)
{
    UE_LOG(LogTemp, Log, TEXT("Difficulty set to: %s"), *Difficulty);
    // Your game logic here
}

void AMyGameMode::LoadLevel(const FString& JsonData)
{
    // Parse JSON
    TSharedPtr<FJsonObject> JsonObject;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonData);

    if (FJsonSerializer::Deserialize(Reader, JsonObject))
    {
        FString LevelName = JsonObject->GetStringField("levelName");
        FString Difficulty = JsonObject->GetStringField("difficulty");
        int32 Checkpoint = JsonObject->GetIntegerField("checkpoint");

        UE_LOG(LogTemp, Log, TEXT("Loading level: %s"), *LevelName);

        // Load the level
        UGameplayStatics::OpenLevel(this, FName(*LevelName));
    }
}
```

**Unreal Blueprint:**

You can also use Blueprints to receive messages:

1. Get Flutter Bridge actor
2. Bind to "On Message From Flutter" event
3. Parse the message data
4. Execute your game logic

```
Event BeginPlay
  → Get Flutter Bridge
  → Bind Event to OnMessageFromFlutter

OnMessageFromFlutter
  → Branch (Target == "GameMode")
    → Branch (Method == "SetDifficulty")
      → [Your difficulty logic]
```

#### Send Message to Flutter:

**Unreal → Flutter (C++):**
```cpp
#include "FlutterBridge.h"

void AMyGameMode::OnPlayerScored(int32 Score)
{
    // Get Flutter Bridge
    AFlutterBridge* Bridge = AFlutterBridge::GetInstance(GetWorld());

    if (Bridge)
    {
        // Create JSON data
        TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
        JsonObject->SetNumberField("score", Score);
        JsonObject->SetStringField("player", "Player1");

        FString JsonString;
        TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
        FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

        // Send to Flutter
        Bridge->SendToFlutter(
            TEXT("GameState"),
            TEXT("OnScoreUpdate"),
            JsonString
        );
    }
}
```

**Unreal → Flutter (Blueprint):**
```
Get Flutter Bridge
  → Send To Flutter
      Target: "GameState"
      Method: "OnLevelComplete"
      Data: "{\"stars\": 3, \"time\": 120}"
```

**Flutter Side:**
```dart
void _onUnrealCreated(GameEngineController controller) {
  _controller = controller as UnrealController;

  // Listen for messages
  _controller!.messageStream.listen((message) {
    final target = message.metadata?['target'];
    final method = message.metadata?['method'];

    if (target == 'GameState') {
      if (method == 'OnScoreUpdate') {
        var json = message.asJson();
        int score = json?['score'] ?? 0;
        print('Score updated: $score');
        _updateScore(score);
      } else if (method == 'OnLevelComplete') {
        var json = message.asJson();
        int stars = json?['stars'] ?? 0;
        _showLevelComplete(stars);
      }
    }
  });
}
```

### 5. Quality Settings Control

**Dynamic Quality Adjustment:**
```dart
class QualityManager {
  final UnrealController controller;

  QualityManager(this.controller);

  // Auto-detect best quality for device
  Future<void> autoDetectQuality() async {
    // Check device capabilities
    final isHighEnd = await _isHighEndDevice();

    if (isHighEnd) {
      await controller.applyQualitySettings(UnrealQualitySettings.epic());
    } else {
      await controller.applyQualitySettings(UnrealQualitySettings.medium());
    }
  }

  // Custom quality settings
  Future<void> applyCustomQuality({
    required int viewDistance,
    required int shadows,
    required int antiAliasing,
  }) async {
    final settings = UnrealQualitySettings(
      qualityLevel: 2,
      viewDistanceQuality: viewDistance,
      shadowQuality: shadows,
      antiAliasingQuality: antiAliasing,
      postProcessQuality: 2,
      textureQuality: 3,
      effectsQuality: 2,
      foliageQuality: 1,
    );

    await controller.applyQualitySettings(settings);
  }

  // Get current settings
  Future<UnrealQualitySettings> getCurrentQuality() async {
    return await controller.getQualitySettings();
  }

  Future<bool> _isHighEndDevice() async {
    // Implement device capability check
    return false; // Placeholder
  }
}
```

### 6. Console Commands

**Execute Console Commands:**
```dart
class DebugPanel extends StatelessWidget {
  final UnrealController controller;

  DebugPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => controller.executeConsoleCommand('stat fps'),
          child: Text('Show FPS'),
        ),
        ElevatedButton(
          onPressed: () => controller.executeConsoleCommand('stat unit'),
          child: Text('Show Unit Stats'),
        ),
        ElevatedButton(
          onPressed: () => controller.executeConsoleCommand('r.VSync 0'),
          child: Text('Disable VSync'),
        ),
        ElevatedButton(
          onPressed: () => controller.executeConsoleCommand('t.MaxFPS 60'),
          child: Text('Cap to 60 FPS'),
        ),
      ],
    );
  }
}
```

---

## Complete Example

See [EMBEDDING_GUIDE.md](../unity/dart/EMBEDDING_GUIDE.md) Unity example and adapt for Unreal-specific features like quality presets and console commands.

**Key Differences from Unity:**

1. **Quality Settings:** Unreal has 5 presets (low, medium, high, epic, cinematic)
2. **Console Commands:** Direct access to Unreal's powerful console system
3. **Level Loading:** Use Unreal's level streaming for better performance
4. **Graphics:** Metal/Vulkan/DirectX support instead of OpenGL

---

## Troubleshooting

### Android

**Problem:** Library not found
- **Solution:** Verify `.so` files are in `jniLibs/arm64-v8a/`
- Check `build.gradle` has correct `abiFilters`
- Ensure you built for ARM64 in Unreal

**Problem:** Crash on launch
- **Solution:** Check minimum SDK is 22+
- Verify all Unreal libraries are included
- Check logcat for native crash logs

**Problem:** Black screen
- **Solution:** Ensure game assets are in `assets/UnrealGame/`
- Check OpenGL ES 3.0 is supported
- Verify AndroidManifest.xml permissions

### iOS

**Problem:** Framework not loaded
- **Solution:** Check framework is "Embed & Sign" in Xcode
- Verify framework path in Build Settings
- Clean build folder and rebuild

**Problem:** Crash with code signing
- **Solution:** Disable bitcode
- Check framework is signed correctly
- Verify entitlements are configured

**Problem:** App rejected
- **Solution:** Strip unused architectures
- Remove simulator slices for App Store
- Check Info.plist has all required keys

### Desktop

**Problem:** Missing DLLs (Windows)
- **Solution:** Copy all DLL files from Unreal build
- Include Visual C++ redistributables
- Check Windows Defender isn't blocking

**Problem:** Library not found (macOS/Linux)
- **Solution:** Check library search paths
- Set `DYLD_LIBRARY_PATH` (macOS) or `LD_LIBRARY_PATH` (Linux)
- Verify file permissions

### General

**Problem:** Low performance
- **Solution:** Use `UnrealQualitySettings.low()` for mobile
- Execute `stat fps` to see bottlenecks
- Reduce resolution with console commands
- Check Device → Profile GPU in Unreal Editor

**Problem:** Messages not working
- **Solution:** Ensure FlutterBridge actor is in level
- Check message format matches (target, method, data)
- Verify plugin is compiled in Unreal project

**Problem:** Quality settings not applied
- **Solution:** Wait for engine to be ready before applying
- Check console output for errors
- Use `getQualitySettings()` to verify current settings

---

**Last Updated:** 2025-10-27
**Plugin Version:** 0.5.0

**See Also:**
- [Unreal Plugin README](README.md)
- [Setup Guide](SETUP_GUIDE.md)
- [Quality Settings Guide](QUALITY_SETTINGS_GUIDE.md)
- [Console Commands Reference](CONSOLE_COMMANDS.md)
