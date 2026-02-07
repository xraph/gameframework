# Unity Engine Plugin for Game Framework

Unity Engine integration plugin for Game Framework. This plugin allows you to embed Unity games in your Flutter applications with a unified API.

## Features

- ✅ Unity 2022.3.x support
- ✅ Multi-platform: Android, iOS, Web, macOS, Windows, Linux
- ✅ Lifecycle management (pause, resume, destroy)
- ✅ Bidirectional communication between Flutter and Unity
- ✅ Scene load events
- ✅ Error handling
- ✅ WebGL support for Flutter Web
- ✅ AR Foundation support (ARCore/ARKit)
- ✅ Performance monitoring
- ✅ Desktop platform support (macOS, Windows, Linux)

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  gameframework:
    path: ../../../  # Path to core framework
  gameframework_unity:
    path: ../../../engines/unity/dart/
```

## Setup

### 1. Initialize the Plugin

In your `main.dart`:

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

### 2. Embed Unity in Your Widget Tree

```dart
class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameEngineController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        engineType: GameEngineType.unity,
        onEngineCreated: _onEngineCreated,
        onMessage: _onMessage,
        onSceneLoaded: _onSceneLoaded,
        config: GameEngineConfig(
          fullscreen: false,
          runImmediately: true,
          unloadOnDispose: true,
        ),
      ),
    );
  }

  void _onEngineCreated(GameEngineController controller) {
    setState(() {
      _controller = controller;
    });
    print('Unity engine created!');
  }

  void _onMessage(GameEngineMessage message) {
    print('Message from Unity: ${message.method} - ${message.data}');
  }

  void _onSceneLoaded(GameSceneLoaded scene) {
    print('Scene loaded: ${scene.name}');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

## Communication

### Send Messages to Unity

```dart
// Send a simple message
await controller.sendMessage(
  'GameManager',
  'StartGame',
  'level1',
);

// Send JSON data
await controller.sendJsonMessage(
  'GameManager',
  'UpdateScore',
  {'score': 100, 'stars': 3},
);
```

### Receive Messages from Unity

```dart
GameWidget(
  engineType: GameEngineType.unity,
  onMessage: (message) {
    // Handle message from Unity
    if (message.method == 'onGameOver') {
      // Parse the data
      final data = message.asJson();
      final score = data['score'];
      print('Game over! Score: $score');
    }
  },
)
```

## Unity Project Setup

### 1. Export Your Unity Project

1. In Unity, go to `File > Build Settings`
2. Select your target platform (Android or iOS)
3. Click `Build` and choose the export location

### 2. Android Integration

After building for Android:

1. Copy the exported Unity files to `android/unityLibrary/`
2. Add Unity library to your app's `build.gradle`:

```gradle
dependencies {
    implementation project(':unityLibrary')
}
```

### 3. iOS Integration

After building for iOS:

1. Copy `UnityFramework.framework` to `ios/UnityFramework.framework`
2. The framework will be automatically linked via the podspec

## Unity C# Bridge (Required)

Add this script to your Unity project to enable communication:

```csharp
using UnityEngine;

public class FlutterBridge : MonoBehaviour
{
    private static FlutterBridge instance;

    public static FlutterBridge Instance
    {
        get
        {
            if (instance == null)
            {
                instance = FindObjectOfType<FlutterBridge>();
                if (instance == null)
                {
                    GameObject go = new GameObject("FlutterBridge");
                    instance = go.AddComponent<FlutterBridge>();
                    DontDestroyOnLoad(go);
                }
            }
            return instance;
        }
    }

    // Called from Flutter
    public void ReceiveMessage(string message)
    {
        Debug.Log("Message from Flutter: " + message);
        // Handle message
    }

    // Send message to Flutter
    public void SendToFlutter(string target, string method, string data)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        {
            using (AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
            {
                currentActivity.Call("onUnityMessage", target, method, data);
            }
        }
#elif UNITY_IOS && !UNITY_EDITOR
        // iOS bridge implementation
        SendMessageToFlutter(target, method, data);
#endif
    }

#if UNITY_IOS && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void SendMessageToFlutter(string target, string method, string data);
#endif
}
```

## Lifecycle Management

The plugin automatically handles lifecycle events:

```dart
// Pause the game
await controller.pause();

// Resume the game
await controller.resume();

// Unload the game
await controller.unload();

// Quit and destroy
await controller.quit();
```

## Listen to Engine Events

```dart
// Listen to lifecycle events
controller.eventStream.listen((event) {
  switch (event.type) {
    case GameEngineEventType.created:
      print('Engine created');
      break;
    case GameEngineEventType.loaded:
      print('Engine loaded');
      break;
    case GameEngineEventType.paused:
      print('Engine paused');
      break;
    case GameEngineEventType.resumed:
      print('Engine resumed');
      break;
    case GameEngineEventType.error:
      print('Error: ${event.message}');
      break;
  }
});

// Listen to scene loads
controller.sceneLoadStream.listen((scene) {
  print('Scene ${scene.name} loaded at index ${scene.buildIndex}');
});
```

## Requirements

- Flutter 3.10.0 or higher
- Unity 2022.3.x or 2023.1.x

### Platform Requirements

- **Android:** minSdkVersion 21
- **iOS:** 12.0 or higher
- **Web:** Modern browser with WebGL 2.0 and WebAssembly support
- **macOS:** 10.14 (Mojave) or higher
- **Windows:** Windows 10 or later
- **Linux:** Ubuntu 20.04 LTS or equivalent

## Supported Unity Versions

| Unity Version | Plugin Version | Status |
|--------------|----------------|---------|
| 2022.3.x     | 2022.3.0      | ✅ Supported |
| 2023.1.x     | 2023.1.0      | 🚧 Coming Soon |

## Troubleshooting

### Unity not loading on Android

- Ensure Unity library is properly linked in `build.gradle`
- Check that all Unity .so files are included in the build
- Verify minSdkVersion is at least 21

### Unity not loading on iOS

- Ensure `UnityFramework.framework` is in the correct location
- Check that the framework is properly signed
- Verify iOS deployment target is at least 12.0

## Platform-Specific Guides

### Desktop Platforms

For detailed desktop integration instructions, see:
- **[Desktop Guide](DESKTOP_GUIDE.md)** - Complete guide for macOS, Windows, and Linux

### Web Platform

For WebGL integration, see:
- **[WebGL Guide](WEBGL_GUIDE.md)** - Complete guide for Flutter Web with Unity

### AR Foundation

For AR experiences, see:
- **[AR Foundation Guide](../../plugin/AR_FOUNDATION.md)** - ARCore and ARKit integration

## Examples

See the `example/` directory for a complete example application demonstrating:
- Unity integration on all platforms
- Bidirectional communication
- Lifecycle management
- Event handling

## License

MIT License - See the LICENSE file in the root of the repository.
