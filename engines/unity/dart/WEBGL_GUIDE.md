# Unity WebGL Integration Guide

This guide explains how to integrate Unity WebGL builds with Flutter Web using the GameFramework.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Unity Project Setup](#unity-project-setup)
- [Building for WebGL](#building-for-webgl)
- [Flutter Integration](#flutter-integration)
- [Configuration](#configuration)
- [Communication](#communication)
- [Troubleshooting](#troubleshooting)

---

## Overview

The GameFramework supports Unity WebGL builds on Flutter Web, allowing you to embed Unity games directly in web browsers.

### Architecture

```
┌─────────────────────────────────────┐
│      Flutter Web Application        │
│                                     │
│  ┌───────────────────────────────┐ │
│  │   GameWidget (Web)            │ │
│  └─────────────┬─────────────────┘ │
│                │                    │
│  ┌─────────────▼─────────────────┐ │
│  │   UnityControllerWeb          │ │
│  └─────────────┬─────────────────┘ │
└────────────────┼───────────────────┘
                 │
        ┌────────▼────────┐
        │  JavaScript API  │
        └────────┬────────┘
                 │
        ┌────────▼────────┐
        │   Unity WebGL    │
        │    Instance      │
        └──────────────────┘
```

---

## Prerequisites

### Unity Requirements

- **Unity:** 2022.3.x or higher
- **WebGL Build Support** installed
- **IL2CPP** scripting backend (recommended)

### Flutter Requirements

- **Flutter:** 3.10.0 or higher
- **Web support** enabled: `flutter config --enable-web`
- **gameframework** and **gameframework_unity** packages

---

## Unity Project Setup

### 1. Add Flutter Bridge Scripts

Copy the Flutter bridge scripts to your Unity project:

```
Assets/
└── FlutterPlugins/
    ├── FlutterBridge.cs
    ├── FlutterSceneManager.cs
    └── FlutterGameManager.cs  (example)
```

### 2. Create WebGL Template (Optional)

For better integration, create a custom WebGL template:

**Assets/WebGLTemplates/Flutter/index.html:**
```html
<!DOCTYPE html>
<html lang="en-us">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Unity WebGL</title>
    <style>
        body { margin: 0; padding: 0; overflow: hidden; }
        #unity-container { width: 100%; height: 100vh; }
        #unity-canvas { width: 100%; height: 100%; display: block; }
    </style>
</head>
<body>
    <div id="unity-container">
        <canvas id="unity-canvas"></canvas>
    </div>
</body>
</html>
```

### 3. Configure Project Settings

**Edit > Project Settings:**

1. **Player Settings:**
   - **Company Name:** Your company name
   - **Product Name:** Your game name
   - **WebGL Template:** Flutter (if using custom template)

2. **Resolution and Presentation:**
   - **Run In Background:** Enabled
   - **WebGL Template:** Minimal or Flutter

3. **Publishing Settings:**
   - **Compression Format:** Gzip (recommended)
   - **Enable Exceptions:** None (for smaller builds)
   - **Data caching:** Enabled

### 4. Add JavaScript Communication

Update **FlutterBridge.cs** with WebGL support:

```csharp
using System.Runtime.InteropServices;
using UnityEngine;

public class FlutterBridge : MonoBehaviour
{
    [DllImport("__Internal")]
    private static extern void FlutterUnityReceiveMessage(
        string target,
        string method,
        string data
    );

    [DllImport("__Internal")]
    private static extern void FlutterUnitySceneLoaded(
        string name,
        int buildIndex
    );

    public void SendToFlutter(string target, string method, string data)
    {
        #if UNITY_WEBGL && !UNITY_EDITOR
            try
            {
                FlutterUnityReceiveMessage(target, method, data);
            }
            catch (System.Exception e)
            {
                Debug.LogError($"Failed to send message to Flutter: {e.Message}");
            }
        #else
            Debug.Log($"SendToFlutter: {target}.{method}({data})");
        #endif
    }

    public void NotifySceneLoaded(string name, int buildIndex)
    {
        #if UNITY_WEBGL && !UNITY_EDITOR
            try
            {
                FlutterUnitySceneLoaded(name, buildIndex);
            }
            catch (System.Exception e)
            {
                Debug.LogError($"Failed to notify scene load: {e.Message}");
            }
        #endif
    }

    // Receive messages from Flutter
    public void ReceiveFromFlutter(string message)
    {
        // Parse and handle message
        Debug.Log($"Received from Flutter: {message}");
    }
}
```

---

## Building for WebGL

### 1. Build Settings

1. **File > Build Settings**
2. Select **WebGL** platform
3. Click **Switch Platform**
4. **Add Open Scenes** you want to include
5. Click **Build** or **Build And Run**

### 2. Build Output

Unity will generate:

```
Build/
├── Build/
│   ├── Build.data.gz
│   ├── Build.framework.js.gz
│   ├── Build.wasm.gz
│   └── Build.loader.js
├── StreamingAssets/
└── index.html
```

### 3. Copy Build Files

Copy the build output to your Flutter web assets:

```bash
# From Unity project root
cp -r Build/Build path/to/flutter-project/web/unity/
cp -r Build/StreamingAssets path/to/flutter-project/web/unity/
```

---

## Flutter Integration

### 1. Add Dependencies

**pubspec.yaml:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  gameframework:
    path: ../gameframework
  gameframework_unity:
    path: ../gameframework/engines/unity/dart
```

### 2. Configure Web Assets

Update **web/index.html** to include Unity loader (if needed):

```html
<!DOCTYPE html>
<html>
<head>
    <!-- ... other head elements ... -->
    <script src="unity/Build/Build.loader.js" defer></script>
</head>
<body>
    <div id="app"></div>
    <script src="main.dart.js" type="application/javascript"></script>
</body>
</html>
```

### 3. Initialize Plugin

**lib/main.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UnityEnginePlugin.initialize();
  runApp(MyApp());
}
```

### 4. Use GameWidget

```dart
class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        engineType: GameEngineType.unity,
        config: GameEngineConfig(
          fullscreen: false,
          runImmediately: true,
          engineSpecificConfig: {
            // Unity WebGL specific config
            'buildUrl': '/unity',
            'loaderUrl': '/unity/Build/Build.loader.js',
            'dataUrl': '/unity/Build/Build.data.gz',
            'frameworkUrl': '/unity/Build/Build.framework.js.gz',
            'codeUrl': '/unity/Build/Build.wasm.gz',
            'companyName': 'YourCompany',
            'productName': 'YourGame',
            'productVersion': '1.0',
          },
        ),
        onEngineCreated: (controller) {
          print('Unity WebGL ready!');
          controller.sendMessage('GameManager', 'Start', 'level1');
        },
        onMessage: (message) {
          print('Message from Unity: ${message.data}');
        },
      ),
    );
  }
}
```

---

## Configuration

### Required Configuration

These fields are **required** in `engineSpecificConfig`:

```dart
'buildUrl': '/unity',              // Base URL for Unity build files
'loaderUrl': '/unity/Build/Build.loader.js',  // Unity loader script
```

### Optional Configuration

```dart
'dataUrl': '/unity/Build/Build.data.gz',          // Game data
'frameworkUrl': '/unity/Build/Build.framework.js.gz',  // Framework
'codeUrl': '/unity/Build/Build.wasm.gz',          // WebAssembly code
'companyName': 'DefaultCompany',                   // Company name
'productName': 'Unity Game',                       // Product name
'productVersion': '1.0',                           // Version
```

### Full Example

```dart
GameEngineConfig(
  fullscreen: true,
  runImmediately: true,
  enableDebugLogs: true,
  engineSpecificConfig: {
    // Unity WebGL build files
    'buildUrl': '/assets/unity',
    'loaderUrl': '/assets/unity/Build/Build.loader.js',
    'dataUrl': '/assets/unity/Build/Build.data.gz',
    'frameworkUrl': '/assets/unity/Build/Build.framework.js.gz',
    'codeUrl': '/assets/unity/Build/Build.wasm.gz',

    // Unity metadata
    'companyName': 'MyCompany',
    'productName': 'AwesomeGame',
    'productVersion': '1.2.0',
  },
)
```

---

## Communication

### Flutter → Unity

```dart
// Send simple message
await controller.sendMessage('GameManager', 'Jump', '10.5');

// Send JSON message
await controller.sendJsonMessage('GameManager', 'UpdatePlayer', {
  'health': 100,
  'position': {'x': 10.5, 'y': 0, 'z': 5.2},
});
```

### Unity → Flutter

**Unity C#:**
```csharp
public class GameManager : MonoBehaviour
{
    void SendScoreToFlutter(int score)
    {
        FlutterBridge.Instance.SendToFlutter(
            "GameManager",
            "onScoreUpdate",
            score.ToString()
        );
    }

    void SendPlayerDataToFlutter(Player player)
    {
        string json = JsonUtility.ToJson(player);
        FlutterBridge.Instance.SendToFlutter(
            "GameManager",
            "onPlayerUpdate",
            json
        );
    }
}
```

**Flutter:**
```dart
GameWidget(
  onMessage: (message) {
    final json = message.asJson();
    if (json != null) {
      // Handle JSON data
      print('Player health: ${json['health']}');
    } else {
      // Handle plain text
      print('Score: ${message.data}');
    }
  },
)
```

---

## Troubleshooting

### Build Issues

#### Issue: "Failed to load Unity loader"

**Solution:**
- Verify `loaderUrl` path is correct
- Check that `Build.loader.js` is accessible
- Ensure files are in `web/` directory or served correctly

#### Issue: "WebAssembly compilation failed"

**Solution:**
- Enable WebAssembly in browser settings
- Check browser compatibility (requires modern browser)
- Verify `.wasm.gz` file is not corrupted

### Runtime Issues

#### Issue: "Unity instance not created"

**Solution:**
```dart
// Add error handling
GameWidget(
  config: GameEngineConfig(
    enableDebugLogs: true,
    engineSpecificConfig: {
      // ... config ...
    },
  ),
  onEngineCreated: (controller) {
    print('✓ Unity created successfully');
  },
)
```

#### Issue: "Messages not received"

**Solution:**
- Verify FlutterBridge is in the scene
- Check JavaScript console for errors
- Ensure `FlutterUnityReceiveMessage` is defined:

```javascript
// In web/index.html
<script>
window.FlutterUnityReceiveMessage = function(target, method, data) {
  console.log('Unity message:', target, method, data);
};
</script>
```

### Performance Issues

#### Issue: Slow loading

**Solution:**
- Use **Gzip** compression in Unity build settings
- Enable **Data caching** in Unity
- Consider **lazy loading** Unity build:

```dart
// Load Unity only when needed
ElevatedButton(
  onPressed: () {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => GameScreen(),
    ));
  },
  child: Text('Play Game'),
)
```

#### Issue: Low frame rate

**Solution:**
- Reduce Unity quality settings
- Disable unnecessary effects
- Use **GPU Instancing**
- Profile in Unity Editor first

---

## Best Practices

### 1. Loading States

Show loading indicator while Unity loads:

```dart
class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GameWidget(
          engineType: GameEngineType.unity,
          config: unityConfig,
          onEngineCreated: (controller) {
            setState(() => _isLoading = false);
          },
        ),
        if (_isLoading)
          Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
```

### 2. Error Handling

```dart
GameWidget(
  onEngineCreated: (controller) {
    controller.eventStream.listen((event) {
      if (event.type == GameEngineEventType.error) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text(event.message ?? 'Unknown error'),
          ),
        );
      }
    });
  },
)
```

### 3. Cleanup

```dart
@override
void dispose() {
  controller?.dispose();
  super.dispose();
}
```

---

## Browser Compatibility

| Browser | Version | Status |
|---------|---------|--------|
| Chrome | 90+ | ✅ Fully supported |
| Firefox | 88+ | ✅ Fully supported |
| Safari | 14+ | ✅ Supported |
| Edge | 90+ | ✅ Fully supported |
| Opera | 76+ | ✅ Supported |

**Note:** WebGL 2.0 and WebAssembly support required.

---

## Examples

See the example app for complete integration:
- [example/lib/main.dart](../../example/lib/main.dart)
- [example/web/index.html](../../example/web/index.html)

---

## Resources

- [Unity WebGL Documentation](https://docs.unity3d.com/Manual/webgl.html)
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [WebAssembly Documentation](https://webassembly.org/)

---

**Framework Version:** 0.4.0
**Last Updated:** 2024-01
