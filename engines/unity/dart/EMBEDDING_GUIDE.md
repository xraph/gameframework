# Unity Game Embedding Guide

Complete guide to exporting your Unity game and embedding it in a Flutter application.

## Table of Contents

- [Overview](#overview)
- [Unity Export Process](#unity-export-process)
- [Android Integration](#android-integration)
- [iOS Integration](#ios-integration)
- [Desktop Integration](#desktop-integration)
- [Flutter Code Integration](#flutter-code-integration)
- [Complete Example](#complete-example)
- [Troubleshooting](#troubleshooting)

---

## Overview

This guide shows you how to:
1. Export your Unity game for each platform
2. Integrate the exported game into your Flutter project
3. Load and control the game from Flutter code

### What You Need

- **Unity 2022.3 or later** (LTS recommended)
- **Flutter 3.10 or later**
- Platform-specific tools (Xcode for iOS/macOS, Android Studio for Android)

---

## Unity Export Process

### Step 1: Install Unity Export Package

1. Open your Unity project
2. Download the Flutter Unity integration package
3. Import via `Assets → Import Package → Custom Package`

### Step 2: Configure Build Settings

#### For All Platforms:

**File → Build Settings:**
- Add your scenes to "Scenes In Build"
- Note the scene names and build indices

**Player Settings (Edit → Project Settings → Player):**
- Set appropriate target API levels
- Configure graphics APIs
- Set scripting backend

---

## Android Integration

### Unity Export (Android)

#### 1. Configure Unity for Android

**Build Settings:**
```
Platform: Android
Build System: Gradle
Export Project: ✓ (CHECKED - Important!)
```

**Player Settings:**
```
Company Name: com.yourcompany
Product Name: YourGame
Package Name: com.yourcompany.yourgame

Other Settings:
  Minimum API Level: Android 5.1 (API Level 22)
  Target API Level: Android 13 (API Level 33)
  Scripting Backend: IL2CPP
  Target Architectures: ✓ ARM64 (ARMv8)

  Auto Graphics API: ✗ (UNCHECK)
  Graphics APIs: OpenGLES3, Vulkan

  Write Permission: External (SDCard)
  Internet Access: Require
```

#### 2. Export Unity Project

**Build Settings → Export:**
```
1. Click "Export" (NOT "Build")
2. Choose export location: YourUnityProject/Exports/Android
3. Wait for export to complete
```

**What You Get:**
```
Exports/Android/
├── launcher/           # Main launcher module
├── unityLibrary/       # Unity game library
├── build.gradle
└── settings.gradle
```

### Flutter Integration (Android)

#### 1. Copy Unity Library

Copy the exported `unityLibrary` folder:

```bash
# From your Unity export location
cp -r YourUnityProject/Exports/Android/unityLibrary \
      YourFlutterApp/android/unityLibrary
```

**Result:**
```
YourFlutterApp/
└── android/
    ├── app/
    ├── unityLibrary/          ← Unity game here
    │   ├── src/
    │   ├── libs/
    │   └── build.gradle
    └── settings.gradle
```

#### 2. Update Flutter Android Configuration

**android/settings.gradle:**
```gradle
// Add at the bottom
include ':unityLibrary'
project(':unityLibrary').projectDir = file('./unityLibrary')
```

**android/app/build.gradle:**
```gradle
android {
    // ... existing config

    // Add this
    aaptOptions {
        noCompress 'unity3d'
        ignoreAssetsPattern = "!.svn:!.git:!.ds_store:!*.scc:.*:!CVS:!thumbs.db:!picasa.ini:!*~"
    }
}

dependencies {
    // ... existing dependencies

    // Add Unity library
    implementation project(':unityLibrary')
}
```

**android/gradle.properties:**
```properties
# Add these
unityStreamingAssets=.unity3d
android.useAndroidX=true
android.enableJetifier=true
```

#### 3. Update AndroidManifest.xml

**android/app/src/main/AndroidManifest.xml:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Add permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <!-- OpenGL ES 3.0 requirement -->
    <uses-feature
        android:glEsVersion="0x00030000"
        android:required="true" />

    <application
        android:label="Your App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true"
        android:usesCleartextTraffic="true">

        <!-- Your existing activities -->

    </application>
</manifest>
```

---

## iOS Integration

### Unity Export (iOS)

#### 1. Configure Unity for iOS

**Build Settings:**
```
Platform: iOS
Run in Xcode as: Release
Symlink Unity libraries: ✓ (CHECKED)
```

**Player Settings:**
```
Company Name: com.yourcompany
Product Name: YourGame
Bundle Identifier: com.yourcompany.yourgame

Other Settings:
  Target minimum iOS Version: 12.0
  Architecture: ARM64

  Auto Graphics API: ✗ (UNCHECK)
  Graphics APIs: Metal

  Camera Usage Description: "Camera access for AR features"
  Microphone Usage Description: "Microphone access for voice features"
```

#### 2. Build Unity for iOS

**Build Settings:**
```
1. Click "Build" (not Export on iOS)
2. Choose build location: YourUnityProject/Builds/iOS
3. Wait for Xcode project to be generated
```

**What You Get:**
```
Builds/iOS/
├── Unity-iPhone.xcodeproj
├── Classes/
├── Data/
├── Libraries/
├── MapFileParser/
└── UnityFramework/        ← This is what we need
```

#### 3. Create UnityFramework.framework

**In Xcode:**

1. Open the generated `Unity-iPhone.xcodeproj`
2. Select the `UnityFramework` target (not Unity-iPhone)
3. Product → Archive
4. After archive completes, Organizer opens
5. Select your archive → Distribute App → Custom → Next
6. Choose "Copy App" → Export
7. Save to: `YourUnityProject/Builds/iOS/UnityFramework.framework`

### Flutter Integration (iOS)

#### 1. Copy UnityFramework

```bash
# Copy the framework
cp -r YourUnityProject/Builds/iOS/UnityFramework.framework \
      YourFlutterApp/ios/UnityFramework.framework

# Copy Unity Data folder
cp -r YourUnityProject/Builds/iOS/Data \
      YourFlutterApp/ios/UnityFramework.framework/Data
```

**Result:**
```
YourFlutterApp/
└── ios/
    ├── Runner/
    ├── Runner.xcworkspace/
    └── UnityFramework.framework/    ← Unity game here
        ├── UnityFramework (binary)
        ├── Data/                    ← Game assets
        ├── Headers/
        └── Info.plist
```

#### 2. Update Xcode Project

**Open in Xcode:**
```bash
open ios/Runner.xcworkspace
```

**Add Framework:**
1. Select `Runner` project in navigator
2. Select `Runner` target → General tab
3. Scroll to "Frameworks, Libraries, and Embedded Content"
4. Click `+` button
5. Click "Add Other..." → "Add Files..."
6. Navigate to `ios/` folder
7. Select `UnityFramework.framework`
8. Make sure "Embed & Sign" is selected

**Framework Search Paths:**
1. Select `Runner` target → Build Settings
2. Search for "Framework Search Paths"
3. Add: `$(PROJECT_DIR)` (non-recursive)

**Other Linker Flags:**
1. Build Settings → "Other Linker Flags"
2. Add: `-weak_framework UnityFramework`

#### 3. Update Info.plist

**ios/Runner/Info.plist:**
```xml
<dict>
    <!-- Existing keys -->

    <!-- Add these if using camera/AR -->
    <key>NSCameraUsageDescription</key>
    <string>Camera access for AR features</string>

    <key>NSMicrophoneUsageDescription</key>
    <string>Microphone access for voice features</string>

    <!-- Status bar hidden (optional) -->
    <key>UIStatusBarHidden</key>
    <true/>
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
</dict>
```

#### 4. Disable Bitcode

**Build Settings:**
```
Enable Bitcode: NO
```

---

## Desktop Integration

### macOS

#### Unity Export:

**Build Settings:**
```
Platform: macOS
Architecture: Intel 64-bit + Apple Silicon
Create Xcode Project: ✓ (if you want framework)
```

Build to: `YourUnityProject/Builds/macOS/YourGame.app`

#### Flutter Integration:

**Option 1: App Bundle (Recommended)**

Copy the entire `.app`:
```bash
cp -r YourUnityProject/Builds/macOS/YourGame.app \
      YourFlutterApp/macos/UnityApp.app
```

**Option 2: Framework**

If you created Xcode project:
1. Open in Xcode
2. Build the UnityFramework target
3. Copy `UnityFramework.framework` to `macos/` folder

### Windows

#### Unity Export:

**Build Settings:**
```
Platform: Windows
Architecture: x86_64
Development Build: ✗ (uncheck for production)
```

Build to: `YourUnityProject/Builds/Windows/`

#### Flutter Integration:

```bash
# Copy Unity build
cp -r YourUnityProject/Builds/Windows/* \
      YourFlutterApp/windows/unity_build/
```

**windows/CMakeLists.txt:**
```cmake
# Add Unity library path
set(UNITY_BUILD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/unity_build")

# Link Unity libraries
target_link_directories(${BINARY_NAME} PRIVATE ${UNITY_BUILD_DIR})
```

### Linux

#### Unity Export:

**Build Settings:**
```
Platform: Linux
Architecture: x86_64
```

Build to: `YourUnityProject/Builds/Linux/`

#### Flutter Integration:

```bash
# Copy Unity build
cp -r YourUnityProject/Builds/Linux/* \
      YourFlutterApp/linux/unity_build/
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
  gameframework_unity: ^0.4.0
```

```bash
flutter pub get
```

### 2. Initialize Unity Plugin

**lib/main.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Unity plugin
  UnityEnginePlugin.initialize();

  runApp(MyApp());
}
```

### 3. Embed Unity Game in Your UI

**Basic Example:**
```dart
class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Unity Game')),
      body: GameEngineWidget(
        engineType: GameEngineType.unity,
        onControllerCreated: (controller) {
          print('Unity game loaded!');
          // Controller ready - you can send messages here
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
  UnityController? _controller;
  bool _isGameLoaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Unity Game'),
        actions: [
          if (_isGameLoaded)
            IconButton(
              icon: Icon(Icons.pause),
              onPressed: _pauseGame,
            ),
        ],
      ),
      body: GameEngineWidget(
        engineType: GameEngineType.unity,
        config: GameEngineConfig(
          runImmediately: true,
          enableDebugConsole: true,
        ),
        onControllerCreated: _onUnityCreated,
      ),
    );
  }

  void _onUnityCreated(GameEngineController controller) {
    _controller = controller as UnityController;

    setState(() {
      _isGameLoaded = true;
    });

    // Listen for messages from Unity
    _controller!.messageStream.listen((message) {
      print('Message from Unity: ${message.data}');
    });

    // Listen for scene loads
    _controller!.sceneLoadStream.listen((scene) {
      print('Scene loaded: ${scene.name}');
    });
  }

  Future<void> _pauseGame() async {
    if (_controller != null) {
      await _controller!.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

### 4. Communication Between Flutter and Unity

#### Send Message to Unity:

**Flutter → Unity:**
```dart
// Send string message
await controller.sendMessage(
  'GameManager',      // Target GameObject in Unity
  'SetDifficulty',    // Method name
  'Hard',             // Data
);

// Send JSON message
await controller.sendJsonMessage(
  'GameManager',
  'LoadLevel',
  {
    'levelId': 3,
    'difficulty': 'hard',
    'playerName': 'John',
  },
);
```

**Unity C# Script:**
```csharp
using UnityEngine;

public class GameManager : MonoBehaviour
{
    // Called from Flutter
    public void SetDifficulty(string difficulty)
    {
        Debug.Log($"Difficulty set to: {difficulty}");
        // Your game logic here
    }

    // Called from Flutter with JSON
    public void LoadLevel(string jsonData)
    {
        // Parse JSON
        var data = JsonUtility.FromJson<LevelData>(jsonData);
        Debug.Log($"Loading level {data.levelId}");
        // Your level loading logic here
    }
}

[System.Serializable]
public class LevelData
{
    public int levelId;
    public string difficulty;
    public string playerName;
}
```

#### Send Message to Flutter:

**Unity → Flutter:**
```csharp
using UnityEngine;

public class GameManager : MonoBehaviour
{
    void Start()
    {
        // Find the Flutter bridge
        var bridge = FindObjectOfType<FlutterBridge>();

        if (bridge != null)
        {
            // Send message to Flutter
            bridge.SendToFlutter(
                "GameState",           // Target
                "OnPlayerReady",       // Method
                "Player initialized"   // Data
            );

            // Send JSON
            var data = new { score = 100, level = 1 };
            bridge.SendToFlutter(
                "GameState",
                "OnScoreUpdate",
                JsonUtility.ToJson(data)
            );
        }
    }
}
```

**Flutter Side:**
```dart
void _onUnityCreated(GameEngineController controller) {
  _controller = controller as UnityController;

  // Listen for messages
  _controller!.messageStream.listen((message) {
    if (message.metadata?['target'] == 'GameState') {
      if (message.metadata?['method'] == 'OnPlayerReady') {
        print('Player is ready: ${message.data}');
      } else if (message.metadata?['method'] == 'OnScoreUpdate') {
        var json = message.asJson();
        print('Score: ${json?['score']}, Level: ${json?['level']}');
      }
    }
  });
}
```

---

## Complete Example

### Complete Flutter App with Unity Game

**pubspec.yaml:**
```yaml
name: my_unity_app
description: Flutter app with Unity game
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  gameframework: ^0.5.0
  gameframework_unity: ^0.4.0
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

**lib/main.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UnityEnginePlugin.initialize();
  runApp(MyUnityApp());
}

class MyUnityApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unity Game in Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unity Game Demo'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GameScreen()),
            );
          },
          child: Text('Start Game'),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  UnityController? _controller;
  bool _isLoaded = false;
  bool _isPaused = false;
  String _currentScene = 'Loading...';
  int _messageCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Playing: $_currentScene'),
        actions: [
          if (_isLoaded) ...[
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _togglePause,
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _restartGame,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Unity Game View
          GameEngineWidget(
            engineType: GameEngineType.unity,
            config: GameEngineConfig(
              runImmediately: true,
              enableDebugConsole: true,
            ),
            onControllerCreated: _onUnityCreated,
          ),

          // Loading indicator
          if (!_isLoaded)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Debug overlay
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Messages: $_messageCount',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isLoaded
          ? FloatingActionButton(
              onPressed: _sendTestMessage,
              child: Icon(Icons.send),
              tooltip: 'Send test message',
            )
          : null,
    );
  }

  void _onUnityCreated(GameEngineController controller) async {
    _controller = controller as UnityController;

    // Listen for lifecycle events
    _controller!.eventStream.listen((event) {
      print('Unity Event: ${event.type}');
      if (event.type == GameEngineEventType.loaded) {
        setState(() {
          _isLoaded = true;
        });
      }
    });

    // Listen for messages from Unity
    _controller!.messageStream.listen((message) {
      setState(() {
        _messageCount++;
      });
      print('Unity Message: ${message.data}');
      _handleUnityMessage(message);
    });

    // Listen for scene loads
    _controller!.sceneLoadStream.listen((scene) {
      setState(() {
        _currentScene = scene.name;
      });
      print('Scene loaded: ${scene.name} (index: ${scene.buildIndex})');
    });

    // Wait for Unity to be ready
    if (await _controller!.isReady()) {
      setState(() {
        _isLoaded = true;
      });
    }
  }

  void _handleUnityMessage(GameEngineMessage message) {
    // Handle specific messages from Unity
    final target = message.metadata?['target'];
    final method = message.metadata?['method'];

    if (target == 'GameManager') {
      if (method == 'OnLevelComplete') {
        _showDialog('Level Complete!', message.data);
      } else if (method == 'OnGameOver') {
        _showDialog('Game Over', message.data);
      }
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePause() async {
    if (_controller == null) return;

    if (_isPaused) {
      await _controller!.resume();
    } else {
      await _controller!.pause();
    }

    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _restartGame() async {
    if (_controller == null) return;

    // Unload and recreate
    await _controller!.unload();
    await Future.delayed(Duration(milliseconds: 500));
    await _controller!.create();
  }

  Future<void> _sendTestMessage() async {
    if (_controller == null) return;

    await _controller!.sendJsonMessage(
      'GameManager',
      'TestMessage',
      {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'source': 'Flutter',
        'count': _messageCount,
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

---

## Troubleshooting

### Android

**Problem:** Black screen
- **Solution:** Check `AndroidManifest.xml` has correct permissions
- Verify `unityLibrary` is properly included in `settings.gradle`
- Check logcat for Unity initialization errors

**Problem:** Build fails with "Duplicate classes"
- **Solution:** Add to `gradle.properties`:
  ```properties
  android.enableJetifier=true
  ```

**Problem:** App crashes on launch
- **Solution:** Ensure minimum API level is 22 or higher
- Check that ARM64 architecture is built

### iOS

**Problem:** Framework not found
- **Solution:** Verify framework is in `ios/` folder
- Check "Embed & Sign" is selected in Xcode
- Clean build folder: Product → Clean Build Folder

**Problem:** App crashes on device
- **Solution:** Disable bitcode in Build Settings
- Check framework architectures match (ARM64)

**Problem:** Black screen
- **Solution:** Verify `Data` folder is inside framework
- Check Info.plist has required permissions

### General

**Problem:** Controller not created
- **Solution:** Ensure `UnityEnginePlugin.initialize()` is called in `main()`
- Check `GameEngineWidget` is properly rendered

**Problem:** Messages not received
- **Solution:** Verify `FlutterBridge` GameObject exists in Unity scene
- Check message format matches expected structure

---

**Last Updated:** 2025-10-27
**Plugin Version:** 0.4.0

**See Also:**
- [Unity Plugin README](README.md)
- [Setup Guide](SETUP_GUIDE.md)
- [API Reference](API_REFERENCE.md)
