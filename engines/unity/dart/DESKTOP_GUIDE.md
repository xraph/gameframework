# Unity Desktop Platform Guide

Complete guide for integrating Unity with Flutter on desktop platforms (macOS, Windows, Linux).

---

## Table of Contents

- [Overview](#overview)
- [Platform Support](#platform-support)
- [macOS Setup](#macos-setup)
- [Windows Setup](#windows-setup)
- [Linux Setup](#linux-setup)
- [Building Unity for Desktop](#building-unity-for-desktop)
- [Flutter Integration](#flutter-integration)
- [Troubleshooting](#troubleshooting)

---

## Overview

The GameFramework supports Unity integration on all major desktop platforms, allowing you to embed Unity games directly in Flutter desktop applications.

### Architecture

```
┌─────────────────────────────────────────┐
│   Flutter Desktop Application           │
│   (macOS / Windows / Linux)             │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │      GameWidget                   │ │
│  └─────────────┬─────────────────────┘ │
│                │                        │
│  ┌─────────────▼─────────────────────┐ │
│  │  UnityEngineController            │ │
│  └─────────────┬─────────────────────┘ │
└────────────────┼──────────────────────┘
                 │
        ┌────────▼────────┐
        │  Unity Framework │
        │  (Native Binary) │
        └──────────────────┘
```

---

## Platform Support

### Current Status

| Platform | Status | Unity Version | Notes |
|----------|--------|---------------|-------|
| **macOS** | ✅ Supported | 2022.3.x+ | Requires macOS 10.14+ |
| **Windows** | ✅ Supported | 2022.3.x+ | Requires Windows 10+ |
| **Linux** | ✅ Supported | 2022.3.x+ | Ubuntu 20.04+ recommended |

### Requirements

**macOS:**
- macOS 10.14 (Mojave) or higher
- Xcode 14.0 or later
- Unity 2022.3.x or 2023.1.x

**Windows:**
- Windows 10 or later
- Visual Studio 2019/2022 with C++ tools
- Unity 2022.3.x or 2023.1.x

**Linux:**
- Ubuntu 20.04 LTS or later (or equivalent)
- GCC 9.0 or later
- GTK 3.0+
- Unity 2022.3.x or 2023.1.x

---

## macOS Setup

### 1. Unity Project Configuration

**Player Settings** (Edit > Project Settings > Player):

```
Platform: macOS
Architecture: x86_64 and Apple Silicon (Universal)
Scripting Backend: IL2CPP (recommended)
API Compatibility Level: .NET Standard 2.1
Target minimum macOS version: 10.14
```

**Other Settings:**
- Enable **Strip Engine Code**: No (for development)
- Enable **Script Debugging**: Yes (for development)

### 2. Add Flutter Bridge Scripts

Copy Flutter bridge scripts to your Unity project:

```
Assets/
└── FlutterPlugins/
    ├── FlutterBridge.cs
    ├── FlutterSceneManager.cs
    └── FlutterGameManager.cs
```

### 3. Build for macOS

1. **File > Build Settings**
2. Select **macOS** platform
3. Click **Switch Platform**
4. Configure build:
   - Architecture: Universal
   - Create Xcode Project: No
5. Click **Build**

### 4. Integrate with Flutter

Place Unity build output in your Flutter project:

```bash
# Copy Unity macOS build
cp -r UnityBuild.app path/to/flutter-project/macos/UnityFramework.framework
```

---

## Windows Setup

### 1. Unity Project Configuration

**Player Settings** (Edit > Project Settings > Player):

```
Platform: Windows
Architecture: x86_64
Scripting Backend: IL2CPP (recommended)
API Compatibility Level: .NET Standard 2.1
```

**Other Settings:**
- Run In Background: Enabled
- Display Resolution Dialog: Disabled (for embedded use)
- Fullscreen Mode: Windowed

### 2. Add Flutter Bridge Scripts

Same as macOS setup - copy Flutter bridge scripts to Assets/FlutterPlugins/

### 3. Build for Windows

1. **File > Build Settings**
2. Select **Windows** platform
3. Click **Switch Platform**
4. Configure build:
   - Architecture: x86_64
   - Compression Method: Default
5. Click **Build**

### 4. Integrate with Flutter

Place Unity build output in your Flutter project:

```bash
# Copy Unity Windows build
cp -r UnityBuild_Data path/to/flutter-project/windows/
cp UnityBuild.exe path/to/flutter-project/windows/
```

---

## Linux Setup

### 1. Unity Project Configuration

**Player Settings** (Edit > Project Settings > Player):

```
Platform: Linux
Architecture: x86_64
Scripting Backend: IL2CPP
API Compatibility Level: .NET Standard 2.1
```

**Other Settings:**
- Run In Background: Enabled
- Fullscreen Mode: Windowed

### 2. Add Flutter Bridge Scripts

Same as other platforms - copy Flutter bridge scripts to Assets/FlutterPlugins/

### 3. Build for Linux

1. **File > Build Settings**
2. Select **Linux** platform
3. Click **Switch Platform**
4. Configure build:
   - Architecture: x86_64
   - Headless Mode: No
5. Click **Build**

### 4. Integrate with Flutter

Place Unity build output in your Flutter project:

```bash
# Copy Unity Linux build
cp -r UnityBuild_Data path/to/flutter-project/linux/
cp UnityBuild.x86_64 path/to/flutter-project/linux/
chmod +x path/to/flutter-project/linux/UnityBuild.x86_64
```

---

## Building Unity for Desktop

### Recommended Build Settings

**All Platforms:**

```csharp
// BuildSettings.cs
public static class UnityBuildSettings
{
    public static void ConfigureDesktopBuild()
    {
        // Graphics
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64, false);

        // Quality
        QualitySettings.vSyncCount = 1;
        QualitySettings.antiAliasing = 2;

        // Performance
        PlayerSettings.MTRendering = true;
        PlayerSettings.gpuSkinning = true;

        // Optimization
        PlayerSettings.stripEngineCode = false; // Keep for dev
        PlayerSettings.SetManagedStrippingLevel(
            BuildTargetGroup.Standalone,
            ManagedStrippingLevel.Disabled
        );
    }
}
```

### Export Script

Use Unity menu: **Flutter > Export for Flutter**

Or use this script:

```csharp
// In Unity Editor
using UnityEditor;

public class DesktopExporter
{
    [MenuItem("Flutter/Export for macOS")]
    public static void ExportMacOS()
    {
        BuildPipeline.BuildPlayer(
            EditorBuildSettings.scenes,
            "Build/macOS/UnityBuild.app",
            BuildTarget.StandaloneOSX,
            BuildOptions.None
        );
    }

    [MenuItem("Flutter/Export for Windows")]
    public static void ExportWindows()
    {
        BuildPipeline.BuildPlayer(
            EditorBuildSettings.scenes,
            "Build/Windows/UnityBuild.exe",
            BuildTarget.StandaloneWindows64,
            BuildOptions.None
        );
    }

    [MenuItem("Flutter/Export for Linux")]
    public static void ExportLinux()
    {
        BuildPipeline.BuildPlayer(
            EditorBuildSettings.scenes,
            "Build/Linux/UnityBuild.x86_64",
            BuildTarget.StandaloneLinux64,
            BuildOptions.None
        );
    }
}
```

---

## Flutter Integration

### 1. Add Dependencies

**pubspec.yaml:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  gameframework: ^0.4.0
  gameframework_unity: ^0.4.0
```

### 2. Initialize Plugin

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

### 3. Use GameWidget

```dart
class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Unity Game on Desktop')),
      body: GameWidget(
        engineType: GameEngineType.unity,
        config: GameEngineConfig(
          fullscreen: false,
          runImmediately: true,
        ),
        onEngineCreated: (controller) {
          print('Unity ready on desktop!');
          controller.sendMessage('GameManager', 'Start', 'desktop');
        },
        onMessage: (message) {
          print('Unity says: ${message.data}');
        },
      ),
    );
  }
}
```

### 4. Run on Desktop

**macOS:**
```bash
flutter run -d macos
```

**Windows:**
```bash
flutter run -d windows
```

**Linux:**
```bash
flutter run -d linux
```

---

## Troubleshooting

### macOS Issues

#### "UnityFramework.framework not found"

**Solution:**
```bash
# Verify framework location
ls -la macos/UnityFramework.framework

# Ensure it's in Podfile
# In macos/Podfile, add:
pod 'UnityFramework', :path => './UnityFramework.framework'
```

#### "Code signing error"

**Solution:**
1. Open Xcode: `open macos/Runner.xcworkspace`
2. Select Runner target
3. Signing & Capabilities tab
4. Select your development team
5. Clean and rebuild

### Windows Issues

#### "Unity DLL not found"

**Solution:**
```bash
# Verify Unity data folder
dir windows\UnityBuild_Data

# Ensure all DLLs are present:
# - UnityPlayer.dll
# - WinPixEventRuntime.dll
```

#### "Failed to load Unity Player"

**Solution:**
- Install Visual C++ Redistributable 2019
- Ensure all Unity dependencies are in windows/ folder
- Check Windows Event Viewer for detailed errors

### Linux Issues

#### "libUnityPlayer.so not found"

**Solution:**
```bash
# Check library path
ldd linux/UnityBuild.x86_64

# Install missing dependencies
sudo apt-get install libgl1-mesa-glx libglu1-mesa
```

#### "Permission denied"

**Solution:**
```bash
# Make Unity binary executable
chmod +x linux/UnityBuild.x86_64
chmod +x linux/UnityBuild_Data/Plugins/x86_64/*.so
```

### General Issues

#### "Engine not responding"

**Solution:**
1. Check Unity console for errors
2. Verify FlutterBridge is in scene
3. Enable debug logs:
   ```dart
   GameEngineConfig(
     enableDebugLogs: true,
   )
   ```

#### "Poor performance"

**Solution:**
- Reduce Unity quality settings
- Disable unnecessary post-processing
- Use GPU instancing
- Profile in Unity Editor first
- Consider using Build type: Release (not Debug)

---

## Best Practices

### 1. Development Workflow

```bash
# 1. Develop in Unity Editor
# 2. Test in Unity standalone
# 3. Build for Flutter integration
# 4. Test in Flutter app
# 5. Profile and optimize
```

### 2. Build Configuration

**Development Builds:**
- Enable development build
- Enable script debugging
- Don't strip engine code

**Release Builds:**
- Disable development build
- Strip engine code
- Enable code optimization
- Use IL2CPP backend

### 3. Resource Management

```dart
// Properly dispose Unity
@override
void dispose() {
  controller?.dispose();
  super.dispose();
}

// Handle window close
WindowManager.onWindowClose(() {
  controller?.dispose();
});
```

### 4. Platform-Specific Code

```dart
import 'dart:io' show Platform;

if (Platform.isMacOS) {
  // macOS-specific configuration
} else if (Platform.isWindows) {
  // Windows-specific configuration
} else if (Platform.isLinux) {
  // Linux-specific configuration
}
```

---

## Performance Tips

### macOS
- Use Metal graphics API
- Enable GPU instancing
- Reduce shadow quality for integrated GPUs

### Windows
- Use DirectX 11/12
- Enable multi-threaded rendering
- Optimize for target GPU (integrated vs dedicated)

### Linux
- Use Vulkan if available
- Test on target distribution
- Be mindful of different desktop environments

---

## Platform Differences

### Graphics APIs

| Platform | Default API | Alternatives |
|----------|-------------|--------------|
| macOS | Metal | OpenGL (deprecated) |
| Windows | DirectX 11 | DirectX 12, Vulkan |
| Linux | OpenGL | Vulkan |

### File Paths

```dart
// Platform-specific paths
String getUnityPath() {
  if (Platform.isMacOS) {
    return 'macos/UnityFramework.framework';
  } else if (Platform.isWindows) {
    return 'windows/UnityBuild.exe';
  } else if (Platform.isLinux) {
    return 'linux/UnityBuild.x86_64';
  }
  throw UnsupportedError('Platform not supported');
}
```

---

## Examples

See complete desktop examples:
- [macOS Example](../../../example/macos/)
- [Windows Example](../../../example/windows/)
- [Linux Example](../../../example/linux/)

---

## Resources

### Unity Documentation
- [macOS Build Settings](https://docs.unity3d.com/Manual/class-PlayerSettingsStandalone.html)
- [Windows Build Settings](https://docs.unity3d.com/Manual/class-PlayerSettingsStandalone.html)
- [Linux Build Settings](https://docs.unity3d.com/Manual/class-PlayerSettingsStandalone.html)

### Flutter Documentation
- [Desktop Support](https://docs.flutter.dev/desktop)
- [macOS Development](https://docs.flutter.dev/platform-integration/macos/building)
- [Windows Development](https://docs.flutter.dev/platform-integration/windows/building)
- [Linux Development](https://docs.flutter.dev/platform-integration/linux/building)

---

**Version:** 0.4.0
**Last Updated:** 2024-10-27
**Platforms:** macOS, Windows, Linux
