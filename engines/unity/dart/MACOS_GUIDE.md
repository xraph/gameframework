# Unity macOS Integration Guide

This guide explains how to integrate Unity builds into Flutter macOS applications using the Game Framework.

## Architecture Overview

Unity macOS integration follows the same model as iOS:

- **UnityFramework.framework** is integrated directly into the Flutter app bundle
- **Swift bridge** provides bidirectional communication via method channels and event channels
- **FlutterBridgeRegistry** enables Unity-to-Flutter messaging via Objective-C runtime
- **`@_cdecl` bridge functions** provide C-level interop for Unity's `DllImport`

### Distribution Model

macOS follows the **integrated framework model** (same as iOS):

| Component | Where it lives | Published to |
|-----------|---------------|-------------|
| Dart code (controller, plugin) | `gameframework_unity` package | pub.dev |
| Swift bridge code | `gameframework_unity/macos/` | pub.dev |
| UnityFramework.framework | Consumer plugin's `macos/` directory | Bundled with app |

The framework is **NOT** published as a separate artifact. It is included in the app bundle, just like iOS.

## Prerequisites

- Flutter 3.10.0 or higher
- Unity 2022.3.x with macOS Build Support module
- Xcode 14+ with macOS SDK
- `game-cli` installed (`dart pub global activate game_cli`)
- macOS 10.14 (Mojave) or higher

## Setup

### 1. Configure `.game.yml`

```yaml
engines:
  unity:
    projectPath: ./unity_project
    platforms:
      macos:
        enabled: true
```

### 2. Export Unity macOS Build

```bash
game export unity --platform macos
```

This runs Unity in batch mode with the `BuildMacos` method, which:
- **Requires IL2CPP** scripting backend (Mono is not supported; the build will fail with clear instructions if IL2CPP is missing)
- Exports an **Xcode project** (source) only; binary `.app` export is not used
- Requires "Create Xcode Project" to be enabled (e.g. in Build Profiles) so Unity outputs an Xcode project

Then `game-cli`:
1. Builds the Xcode project using **GameFrameworkProject** scheme (macOS has no UnityFramework scheme like iOS)
2. Locates the built `.app` in the project’s build products
3. **Assembles** `UnityFramework.framework` from the `.app`: copies `UnityPlayer.dylib` as the framework binary, `GameAssembly.dylib` into `Libraries/`, and game `Data/`, then generates `Info.plist`, `Headers`, and `Modules`

The framework is produced in the export directory under `Framework/UnityFramework.framework`, ready for sync.

### 3. Sync Framework to Flutter Project

```bash
game sync unity --platform macos
```

This copies `UnityFramework.framework` to your Flutter plugin's `macos/` directory. The sync command handles three scenarios:

- **Plugin mode**: Copies to your plugin's `macos/` directory for publishing
- **Monorepo mode**: Copies to `engines/unity/dart/macos/` in the gameframework repo
- **Standalone app mode**: Copies to your app's `macos/` directory

### 4. Configure Flutter macOS App

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
        ),
        onEngineCreated: (controller) {
          print('Unity macOS ready!');
        },
        onMessage: (message) {
          print('Unity message: ${message.data}');
        },
      ),
    );
  }
}
```

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

In Unity C#, the bridge handles communication transparently:

```csharp
// Using FlutterBridge.cs
FlutterBridge.Instance.SendToFlutter("ScoreManager", "onScoreUpdate", "1000");

// Using NativeAPI.cs
NativeAPI.SendMessageToFlutter("Hello from Unity!");
NativeAPI.NotifyUnityReady();
```

The macOS bridge uses `@_cdecl` Swift functions that are linked into the main binary, making them available to Unity's `[DllImport("__Internal")]`.

## Message Queuing

Messages sent from Unity before Flutter's event channel is ready are automatically queued (up to 100 messages). They are flushed in order once the channel is established. This prevents message loss during initialization.

## Publishing

### For Plugin Developers

When publishing a plugin that includes a Unity game:

1. Sync the framework: `game sync unity --platform macos`
2. Ensure your podspec vendors the framework:

```ruby
Pod::Spec.new do |s|
  # ...
  s.osx.vendored_frameworks = 'UnityFramework.framework'
end
```

3. Publish: `game publish`

The framework is included in the package and bundled with the consumer app.

### For App Developers

If you're building an app (not a plugin), the framework is synced directly to your `macos/` directory and included in the app bundle automatically.

## Podspec Configuration

The `gameframework_unity` macOS podspec is configured to find `UnityFramework` from sibling pods:

```ruby
s.pod_target_xcconfig = { 
  'DEFINES_MODULE' => 'YES',
  'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}" "${PODS_CONFIGURATION_BUILD_DIR}"',
  'OTHER_LDFLAGS' => '$(inherited) -ObjC'
}
```

This allows the Swift code to compile even when the framework is vendored by a different pod.

## Troubleshooting

### Unity build produced .app instead of Xcode project
- Enable **Create Xcode Project** in Build Profiles (Edit > Project Settings > Build) for macOS
- Ensure **IL2CPP** scripting backend is set (Edit > Project Settings > Player > macOS > Other Settings)
- Install **Mac Build Support (IL2CPP)** via Unity Hub > Installs > your version > Add Modules

### "UnityFramework not found" at runtime
- Ensure `UnityFramework.framework` is in the app's `Contents/Frameworks/` directory
- Verify the framework was exported from a macOS Unity build (not iOS)
- Run `game sync unity --platform macos` to re-sync

### Build errors in Xcode
- Check that the macOS deployment target matches (10.14+)
- Ensure the framework architecture matches (arm64 for Apple Silicon, x86_64 for Intel)
- Clean build folder: Product > Clean Build Folder

### Messages not received
- Ensure `FlutterBridge` GameObject exists in your Unity scene
- Check that `FlutterBridgeRegistry` is being found (check console logs)
- Verify that `registerAsActive()` is called during controller creation

### Unity view not rendering
- Check that the `NSView` is properly added to the container
- Verify Unity's `appController().rootViewController` is not nil
- Ensure the Unity window is shown via `showUnityWindow()`

## Assembled Framework Structure

Unlike iOS, Unity does not produce a `UnityFramework.framework` for macOS. The CLI assembles one from the Xcode build:

```
UnityFramework.framework/
  UnityFramework          # UnityPlayer.dylib (main framework binary)
  Libraries/
    GameAssembly.dylib     # IL2CPP code
  Data/                    # Game data (levels, assets, etc.)
  Headers/
    UnityFramework.h
  Modules/
    module.modulemap
  Info.plist
```

The Swift controller pre-loads `Libraries/GameAssembly.dylib` before loading the framework bundle so the Unity runtime can resolve IL2CPP symbols.

## Comparison with iOS

| Feature | iOS | macOS |
|---------|-----|-------|
| Unity export | Xcode project | Xcode project (IL2CPP required) |
| Framework build | xcodebuild archive (UnityFramework scheme) | xcodebuild build (GameFrameworkProject) then assemble from .app |
| Framework | UnityFramework.framework (single dylib) | UnityFramework.framework (assembled: UnityPlayer + GameAssembly + Data) |
| View type | UIView (UiKitView) | NSView (AppKitView) |
| Bridge | FlutterBridge.mm + Swift | Swift @_cdecl functions |
| Registry | FlutterBridgeRegistry | FlutterBridgeRegistry |
| Distribution | Integrated in package | Integrated in package |
| Deployment target | iOS 15.0+ | macOS 10.14+ |
