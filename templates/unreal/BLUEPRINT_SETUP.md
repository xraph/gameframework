# Unreal Engine Blueprint Setup Guide

This guide explains how to set up Blueprint templates for Flutter-Unreal integration.

## Prerequisites

1. Copy all C++ files from `Scripts/` to your Unreal project's `Source/` folder
2. Regenerate project files
3. Compile the project

## Creating Blueprint Templates

### 1. BP_RotatingCube (Blueprint)

Create a Blueprint from the `RotatingCube` C++ class:

1. In Content Browser, right-click → **Blueprint Class**
2. Search for **RotatingCube** in the parent class list
3. Name it **BP_RotatingCube**
4. Open the Blueprint

**Configure the Blueprint:**

In the Details panel:
- **Flutter Target Name**: `GameFrameworkDemo`
- **Rotation Speed**: `50.0`
- **Rotation Axis**: `(0, 1, 0)` (Y-axis)
- **Cube Color**: Blue `(0.5, 0.5, 1.0, 1.0)`

**Event Graph:**

Add these events in the Event Graph:

```blueprint
Event OnSpeedChanged_Blueprint
├─ Print String ("Speed changed to: " + NewSpeed)
└─ [Optional: Add visual feedback]

Event OnAxisChanged_Blueprint  
├─ Print String ("Axis changed to: " + NewAxis)
└─ [Optional: Update rotation indicator]

Event OnColorChanged_Blueprint
├─ Print String ("Color changed to: " + NewColor)
└─ [Material update happens automatically]

Event OnReset_Blueprint
├─ Print String ("Cube reset")
└─ [Optional: Play reset animation]
```

### 2. BP_GameManager (Blueprint)

Create a game manager Blueprint:

1. Create new Blueprint with **FlutterGameMode** as parent
2. Name it **BP_GameManager**

**Configure:**

- **Flutter Target Name**: `GameMode`
- **Default Pawn Class**: None (or your game's pawn)

**Event Graph:**

```blueprint
Event BeginPlay
├─ Call "RegisterWithFlutter"
└─ Call "SendToFlutter" (Target: "GameMode", Method: "onReady", Data: "true")

Event OnGameStarted
└─ [Start your game logic]

Event OnGamePaused  
└─ [Handle pause state]

Event OnScoreChanged
└─ [Update score display]
```

### 3. FlutterDemoMap (Level)

Create the demo level:

1. **File → New Level → Empty Level**
2. Save as **FlutterDemoMap** in `/Content/Maps/`

**Add to Level:**

1. Drag **BP_RotatingCube** into the level at position `(0, 0, 0)`
2. Add a **Directional Light** for illumination
3. Add a **Sky Sphere** or solid background
4. Position camera to view the cube

**Camera Setup:**

1. Add a **Camera Actor** at position `(0, -500, 100)`
2. Rotate to face the cube: `(0, 0, 0)` pitch/yaw/roll
3. Set as default view (optional)

**Lighting:**

1. Add **Directional Light** with rotation `(-45, -45, 0)`
2. Intensity: `3.0`
3. Enable shadows

## Project Configuration

### DefaultEngine.ini

Add to your project's `Config/DefaultEngine.ini`:

```ini
[/Script/EngineSettings.GameMapsSettings]
GameDefaultMap=/Game/Maps/FlutterDemoMap.FlutterDemoMap
```

### DefaultGame.ini

Add to `Config/DefaultGame.ini`:

```ini
[/Script/UnrealEd.ProjectPackagingSettings]
+MapsToCook=(FilePath="/Game/Maps/FlutterDemoMap")
```

## Flutter-Side Integration

Use this Dart code to communicate with the rotating cube:

```dart
// Set rotation speed
controller.sendMessage('GameFrameworkDemo', 'setSpeed', '100');

// Set rotation axis (Y-axis)
controller.sendJsonMessage('GameFrameworkDemo', 'setAxis', {
  'x': 0.0,
  'y': 1.0,
  'z': 0.0,
});

// Set cube color
controller.sendJsonMessage('GameFrameworkDemo', 'setColor', {
  'r': 1.0,
  'g': 0.5,
  'b': 0.0,
  'a': 1.0,
});

// Reset cube
controller.sendMessage('GameFrameworkDemo', 'reset', '');

// Get current state
controller.sendMessage('GameFrameworkDemo', 'getState', '');

// Listen for responses
controller.messages.listen((message) {
  switch (message.method) {
    case 'onSpeedChanged':
      final data = jsonDecode(message.data!);
      print('Speed: ${data['speed']}, RPM: ${data['rpm']}');
      break;
    case 'onState':
      final state = jsonDecode(message.data!);
      print('Cube state: $state');
      break;
    case 'onReset':
      print('Cube was reset');
      break;
  }
});
```

## Message Protocol

### Flutter → Unreal Commands

| Method | Data | Description |
|--------|------|-------------|
| `setSpeed` | `"50.0"` | Set rotation speed (degrees/sec) |
| `setAxis` | `{"x":0,"y":1,"z":0}` | Set rotation axis |
| `setColor` | `{"r":1,"g":0.5,"b":0,"a":1}` | Set cube color |
| `reset` | `""` | Reset to defaults |
| `getState` | `""` | Request current state |
| `setRotating` | `"true"` | Start/stop rotation |

### Unreal → Flutter Events

| Method | Data | Description |
|--------|------|-------------|
| `onReady` | `"true"` | Cube is ready |
| `onSpeedChanged` | `{"speed":50,"rpm":8.3}` | Speed was changed |
| `onAxisChanged` | `{"x":0,"y":1,"z":0}` | Axis was changed |
| `onColorChanged` | `{"r":1,"g":0.5,"b":0,"a":1}` | Color was changed |
| `onState` | `{...full state...}` | Current state |
| `onReset` | `{...state after reset...}` | Cube was reset |

## Packaging for Flutter

### Android

1. **File → Package Project → Android**
2. Select build configuration (Development/Shipping)
3. Use `game export unreal --platform android` to extract

### iOS

1. **File → Package Project → iOS**
2. Build with Xcode for device
3. Use `game export unreal --platform ios` to extract

## Troubleshooting

### Cube not rotating
- Check `bIsRotating` is true
- Verify `RotationSpeed` is not 0
- Ensure Tick is enabled in Blueprint

### Messages not received
- Check `FlutterBridge` actor is in level
- Verify `bAutoRegister` is true on RotatingCube
- Check Flutter target name matches

### Material not changing color
- Ensure `DynamicMaterial` is created in BeginPlay
- Check material has `BaseColor` parameter
- Use material with vector parameter support

## See Also

- [ROTATING_CUBE_DEMO.md](Scripts/ROTATING_CUBE_DEMO.md) - Detailed demo guide
- [README.md](Scripts/README.md) - C++ template documentation
- [../../engines/unreal/dart/README.md](../../engines/unreal/dart/README.md) - Dart API reference
