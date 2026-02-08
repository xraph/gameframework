# Unity WebGL Integration Guide

This guide explains how to integrate Unity WebGL builds into Flutter web applications using the Game Framework.

## Architecture Overview

Unity WebGL builds run in the browser via WebAssembly. The integration uses:

- **JavaScript interop** (`dart:html`, `dart:js`) for Flutter-Unity communication
- **`HtmlElementView`** to embed the Unity canvas in the Flutter widget tree
- **Global JS functions** (`FlutterUnityReceiveMessage`, `FlutterUnitySceneLoaded`) for Unity-to-Flutter messaging
- **`createUnityInstance` API** to bootstrap the Unity WebGL player

### Distribution Model

WebGL builds are treated as **artifacts**, NOT bundled in the Flutter package:

| Component | Where it lives | Published to |
|-----------|---------------|-------------|
| Dart code (controller, widget) | `gameframework_unity` package | pub.dev |
| WebGL build (wasm, data, framework) | Separate artifact | CDN via artifacts API |

This separation is necessary because WebGL builds are large (50MB+) and would exceed pub.dev size limits.

## Prerequisites

- Flutter 3.10.0 or higher
- Unity 2022.3.x with WebGL Build Support module
- `game-cli` installed (`dart pub global activate game_cli`)
- Modern browser with WebGL 2.0 and WebAssembly support

## Setup

### 1. Configure `.game.yml`

```yaml
engines:
  unity:
    projectPath: ./unity_project
    platforms:
      web:
        enabled: true
```

### 2. Export Unity WebGL Build

```bash
game export unity --platform web
```

This runs Unity in batch mode with the `BuildWebGL` method from `FlutterBuildScript.cs`, which:
- Enables Brotli compression (release) or no compression (development)
- Sets Wasm linker target
- Configures IL2CPP scripting backend
- Uses minimal template (no Unity loading bar)

### 3. Sync for Local Development

```bash
game sync unity --platform web
```

This copies the WebGL build to `web/unity_webgl/` in your Flutter project and generates an `asset_manifest.json`.

### 4. Configure Flutter Web App

In your Flutter web app, configure the `GameEngineConfig` to point to the WebGL build:

```dart
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UnityEnginePlugin.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GameWidget(
        engineType: GameEngineType.unity,
        config: const GameEngineConfig(
          runImmediately: true,
          engineSpecificConfig: {
            // For local development:
            'buildUrl': '/unity_webgl/Build',
            'loaderUrl': '/unity_webgl/Build/Build.loader.js',
            // For production CDN:
            // 'buildUrl': 'https://cdn.example.com/games/mygame/1.0.0',
            // 'loaderUrl': 'https://cdn.example.com/games/mygame/1.0.0/Build.loader.js',
          },
        ),
        onEngineCreated: (controller) {
          print('Unity WebGL ready!');
        },
        onMessage: (message) {
          print('Unity message: ${message.data}');
        },
      ),
    );
  }
}
```

## Publishing

### Package Publishing (pub.dev)

The package is published without WebGL artifacts:

```bash
game publish
```

### Artifact Publishing (CDN)

WebGL builds are published separately as artifacts:

```bash
game publish --platform web --artifacts
```

This uploads the WebGL build to the CDN via the artifacts API. The artifact URL is then used in production configs.

## Communication

### Flutter to Unity

```dart
// Send message to a Unity GameObject
await controller.sendMessage('GameManager', 'StartLevel', '3');

// Send JSON data
await controller.sendJsonMessage('Player', 'SetStats', {
  'health': 100,
  'score': 500,
});
```

### Unity to Flutter

In Unity C#, the `FlutterBridge.jslib` plugin handles communication:

```csharp
// Using FlutterBridge.cs
FlutterBridge.Instance.SendToFlutter("ScoreManager", "onScoreUpdate", "1000");

// Using NativeAPI.cs
NativeAPI.SendMessageToFlutter("Hello from Unity!");
```

Messages arrive on the Flutter side via `onMessage` callback or `messageStream`.

## Message Queuing

Messages sent to Unity before the WebGL player is fully loaded are automatically queued (up to 100 messages). They are flushed in order once Unity is ready. This prevents message loss during initialization.

## Loading Progress

Monitor WebGL loading progress:

```dart
final webController = controller as UnityControllerWeb;
webController.progressStream.listen((progress) {
  print('Loading: ${(progress * 100).toStringAsFixed(0)}%');
});
```

## Retry Logic

If the WebGL build fails to load (network error, etc.), the controller automatically retries up to 3 times with exponential backoff (1s, 2s, 4s).

## Troubleshooting

### Build fails with "Unity loader not found"
- Ensure `loaderUrl` points to the correct `Build.loader.js` file
- Check browser console for 404 errors
- Verify the WebGL build was exported successfully

### Messages not received
- Ensure `FlutterBridge` GameObject exists in your Unity scene
- Check that `FlutterBridge.jslib` is in `Assets/Plugins/WebGL/`
- Verify the global JS functions are registered (check browser console)

### Large build size
- Use Brotli compression (enabled by default for release builds)
- Strip unused engine code in Unity Player Settings
- Consider using Addressables for asset streaming

### CORS errors
- When loading from CDN, ensure CORS headers are configured
- For local development, use the sync command to serve from the same origin
