# Unreal Engine Console Commands Reference

Complete reference for Unreal Engine console commands accessible through Flutter.

## Table of Contents

- [Overview](#overview)
- [Performance Monitoring](#performance-monitoring)
- [Quality Settings](#quality-settings)
- [Rendering](#rendering)
- [Debugging](#debugging)
- [Profiling](#profiling)
- [Useful Commands](#useful-commands)

---

## Overview

Execute Unreal Engine console commands from Flutter:

```dart
await controller.executeConsoleCommand('stat fps');
```

Console commands provide low-level control over Unreal Engine settings and debugging tools.

---

## Performance Monitoring

### FPS Display

```dart
// Show FPS counter
await controller.executeConsoleCommand('stat fps');

// Hide FPS counter
await controller.executeConsoleCommand('stat fps');  // Toggle off
```

**Output:** On-screen FPS counter in top-right corner

### Unit Stats

```dart
// Show frame time breakdown
await controller.executeConsoleCommand('stat unit');
```

**Output:**
- **Frame:** Total frame time
- **Game:** Game logic time
- **Draw:** Rendering time
- **GPU:** GPU time

**Useful for:** Identifying CPU vs GPU bottlenecks

### GPU Stats

```dart
// Show detailed GPU stats
await controller.executeConsoleCommand('stat gpu');
```

**Output:** GPU time breakdown by rendering passes

### Scene Rendering Stats

```dart
// Show rendering statistics
await controller.executeConsoleCommand('stat scenerendering');
```

**Output:**
- Draw calls
- Primitives
- Triangles
- Shadow maps

---

## Quality Settings

### Scalability Groups

Set overall quality level (0-4):

```dart
// Set all quality settings at once
await controller.executeConsoleCommand('sg.ResolutionQuality 3');
await controller.executeConsoleCommand('sg.ViewDistanceQuality 3');
await controller.executeConsoleCommand('sg.AntiAliasingQuality 2');
await controller.executeConsoleCommand('sg.ShadowQuality 2');
await controller.executeConsoleCommand('sg.PostProcessQuality 3');
await controller.executeConsoleCommand('sg.TextureQuality 3');
await controller.executeConsoleCommand('sg.EffectsQuality 2');
await controller.executeConsoleCommand('sg.FoliageQuality 1');
```

**Levels:** 0 (Low) to 4 (Cinematic)

### View Distance

```dart
// Control how far objects render
await controller.executeConsoleCommand('sg.ViewDistanceQuality 0');  // Near
await controller.executeConsoleCommand('sg.ViewDistanceQuality 1');  // Medium
await controller.executeConsoleCommand('sg.ViewDistanceQuality 2');  // Far
await controller.executeConsoleCommand('sg.ViewDistanceQuality 3');  // Very Far
await controller.executeConsoleCommand('sg.ViewDistanceQuality 4');  // Epic
```

### Anti-Aliasing

```dart
// AA quality (0-4)
await controller.executeConsoleCommand('sg.AntiAliasingQuality 0');  // Off
await controller.executeConsoleCommand('sg.AntiAliasingQuality 1');  // FXAA
await controller.executeConsoleCommand('sg.AntiAliasingQuality 2');  // TAA
await controller.executeConsoleCommand('sg.AntiAliasingQuality 3');  // TAA High
await controller.executeConsoleCommand('sg.AntiAliasingQuality 4');  // TAA Ultra
```

### Shadows

```dart
// Shadow quality (0-4)
await controller.executeConsoleCommand('sg.ShadowQuality 0');  // Blob shadows
await controller.executeConsoleCommand('sg.ShadowQuality 1');  // Low
await controller.executeConsoleCommand('sg.ShadowQuality 2');  // Medium
await controller.executeConsoleCommand('sg.ShadowQuality 3');  // High
await controller.executeConsoleCommand('sg.ShadowQuality 4');  // Ultra
```

### Post-Processing

```dart
// Post-processing quality (0-4)
await controller.executeConsoleCommand('sg.PostProcessQuality 0');  // Minimal
await controller.executeConsoleCommand('sg.PostProcessQuality 1');  // Low
await controller.executeConsoleCommand('sg.PostProcessQuality 2');  // Medium
await controller.executeConsoleCommand('sg.PostProcessQuality 3');  // High
await controller.executeConsoleCommand('sg.PostProcessQuality 4');  // Ultra
```

### Textures

```dart
// Texture quality (0-4)
await controller.executeConsoleCommand('sg.TextureQuality 0');  // Low
await controller.executeConsoleCommand('sg.TextureQuality 1');  // Medium
await controller.executeConsoleCommand('sg.TextureQuality 2');  // High
await controller.executeConsoleCommand('sg.TextureQuality 3');  // Very High
await controller.executeConsoleCommand('sg.TextureQuality 4');  // Ultra
```

### Effects

```dart
// Effects quality (0-4)
await controller.executeConsoleCommand('sg.EffectsQuality 0');  // Low
await controller.executeConsoleCommand('sg.EffectsQuality 1');  // Medium
await controller.executeConsoleCommand('sg.EffectsQuality 2');  // High
await controller.executeConsoleCommand('sg.EffectsQuality 3');  // Very High
await controller.executeConsoleCommand('sg.EffectsQuality 4');  // Ultra
```

### Foliage

```dart
// Foliage quality (0-4)
await controller.executeConsoleCommand('sg.FoliageQuality 0');  // Minimal
await controller.executeConsoleCommand('sg.FoliageQuality 1');  // Low
await controller.executeConsoleCommand('sg.FoliageQuality 2');  // Medium
await controller.executeConsoleCommand('sg.FoliageQuality 3');  // High
await controller.executeConsoleCommand('sg.FoliageQuality 4');  // Ultra
```

---

## Rendering

### Resolution

```dart
// Set resolution
await controller.executeConsoleCommand('r.SetRes 1920x1080');
await controller.executeConsoleCommand('r.SetRes 2560x1440');
await controller.executeConsoleCommand('r.SetRes 3840x2160');

// Fullscreen modes
await controller.executeConsoleCommand('r.SetRes 1920x1080f');   // Fullscreen
await controller.executeConsoleCommand('r.SetRes 1920x1080w');   // Windowed
await controller.executeConsoleCommand('r.SetRes 1920x1080wf');  // Windowed fullscreen
```

### Resolution Scale

```dart
// Screen percentage (dynamic resolution)
await controller.executeConsoleCommand('r.ScreenPercentage 50');   // 50%
await controller.executeConsoleCommand('r.ScreenPercentage 75');   // 75%
await controller.executeConsoleCommand('r.ScreenPercentage 100');  // 100% (native)
await controller.executeConsoleCommand('r.ScreenPercentage 125');  // 125% (supersampling)
await controller.executeConsoleCommand('r.ScreenPercentage 150');  // 150%
```

### VSync

```dart
// Vertical sync
await controller.executeConsoleCommand('r.VSync 0');  // Off
await controller.executeConsoleCommand('r.VSync 1');  // On
```

### Frame Rate Limit

```dart
// Cap frame rate
await controller.executeConsoleCommand('t.MaxFPS 30');
await controller.executeConsoleCommand('t.MaxFPS 60');
await controller.executeConsoleCommand('t.MaxFPS 120');
await controller.executeConsoleCommand('t.MaxFPS 0');  // Unlimited
```

### Dynamic Resolution

```dart
// Enable/disable dynamic resolution
await controller.executeConsoleCommand('r.DynamicRes.OperationMode 0');  // Disabled
await controller.executeConsoleCommand('r.DynamicRes.OperationMode 1');  // Enabled

// Target frame rate for dynamic resolution
await controller.executeConsoleCommand('r.DynamicRes.TargetFrameRate 60');

// Min/Max screen percentage
await controller.executeConsoleCommand('r.DynamicRes.MinScreenPercentage 50');
await controller.executeConsoleCommand('r.DynamicRes.MaxScreenPercentage 100');
```

### Shadow Settings

```dart
// Shadow distance
await controller.executeConsoleCommand('r.Shadow.MaxResolution 2048');  // Resolution
await controller.executeConsoleCommand('r.Shadow.DistanceScale 0.5');   // Scale distance

// Dynamic shadows
await controller.executeConsoleCommand('r.Shadow.CSM.MaxCascades 4');   // Cascade count
```

### Lighting

```dart
// Disable dynamic lighting (performance)
await controller.executeConsoleCommand('r.AllowStaticLighting 1');

// Light quality
await controller.executeConsoleCommand('r.LightQuality 0');  // Low
await controller.executeConsoleCommand('r.LightQuality 1');  // High
```

---

## Debugging

### Show Debug Info

```dart
// Show debug information
await controller.executeConsoleCommand('showdebug');

// Show specific debug categories
await controller.executeConsoleCommand('showdebug collision');
await controller.executeConsoleCommand('showdebug physics');
await controller.executeConsoleCommand('showdebug ai');
await controller.executeConsoleCommand('showdebug camera');
```

### Show Flags

```dart
// Toggle various rendering features
await controller.executeConsoleCommand('show Bloom');           // Toggle bloom
await controller.executeConsoleCommand('show MotionBlur');      // Toggle motion blur
await controller.executeConsoleCommand('show DepthOfField');    // Toggle DOF
await controller.executeConsoleCommand('show Fog');             // Toggle fog
await controller.executeConsoleCommand('show Particles');       // Toggle particles
await controller.executeConsoleCommand('show PostProcessing'); // Toggle post-processing
await controller.executeConsoleCommand('show Shadows');         // Toggle shadows
await controller.executeConsoleCommand('show Decals');          // Toggle decals
await controller.executeConsoleCommand('show Translucency');    // Toggle transparency
```

### Wireframe

```dart
// Toggle wireframe mode
await controller.executeConsoleCommand('viewmode wireframe');
await controller.executeConsoleCommand('viewmode lit');  // Back to normal
```

### Collision

```dart
// Show collision
await controller.executeConsoleCommand('show collision');
```

### Bounds

```dart
// Show bounding boxes
await controller.executeConsoleCommand('show bounds');
```

### Freeze Rendering

```dart
// Freeze rendering (for debugging)
await controller.executeConsoleCommand('freezerendering');
await controller.executeConsoleCommand('freezerendering');  // Toggle off
```

---

## Profiling

### Memory Stats

```dart
// Show memory usage
await controller.executeConsoleCommand('stat memory');

// Show streaming stats
await controller.executeConsoleCommand('stat streaming');
await controller.executeConsoleCommand('stat streamingdetails');
```

### CPU Profiling

```dart
// CPU stats
await controller.executeConsoleCommand('stat game');
await controller.executeConsoleCommand('stat gamethread');
await controller.executeConsoleCommand('stat renderthread');
```

### GPU Profiling

```dart
// Detailed GPU profiling
await controller.executeConsoleCommand('stat gpu');
await controller.executeConsoleCommand('profilegpu');
```

### Level Stats

```dart
// Level statistics
await controller.executeConsoleCommand('stat levels');
await controller.executeConsoleCommand('stat levelmap');
```

### Network Stats

```dart
// Network statistics (if using networking)
await controller.executeConsoleCommand('stat net');
```

---

## Useful Commands

### Screenshots

```dart
// Take a screenshot
await controller.executeConsoleCommand('shot');

// High-resolution screenshot
await controller.executeConsoleCommand('highresshot 2');  // 2x resolution
await controller.executeConsoleCommand('highresshot 4');  // 4x resolution
```

### Time Dilation

```dart
// Slow motion
await controller.executeConsoleCommand('slomo 0.5');  // 50% speed
await controller.executeConsoleCommand('slomo 0.1');  // 10% speed
await controller.executeConsoleCommand('slomo 1.0');  // Normal speed
await controller.executeConsoleCommand('slomo 2.0');  // 2x speed
```

### Camera

```dart
// Toggle free camera
await controller.executeConsoleCommand('toggledebugcamera');

// Camera speed
await controller.executeConsoleCommand('cameramode freecam');
await controller.executeConsoleCommand('cameramode default');
```

### Pause

```dart
// Pause game
await controller.executeConsoleCommand('pause');
```

### Quit

```dart
// Quit application
await controller.executeConsoleCommand('quit');
```

---

## Command Categories by Use Case

### Quick Performance Check

```dart
// Basic performance monitoring
await controller.executeConsoleCommand('stat fps');
await controller.executeConsoleCommand('stat unit');
```

### Optimize for Mobile

```dart
// Mobile optimization commands
await controller.executeConsoleCommand('sg.ViewDistanceQuality 0');
await controller.executeConsoleCommand('sg.ShadowQuality 0');
await controller.executeConsoleCommand('sg.EffectsQuality 0');
await controller.executeConsoleCommand('sg.FoliageQuality 0');
await controller.executeConsoleCommand('r.ScreenPercentage 75');
await controller.executeConsoleCommand('r.VSync 0');
```

### Debug Visual Issues

```dart
// Visual debugging
await controller.executeConsoleCommand('viewmode lit');         // Normal
await controller.executeConsoleCommand('viewmode unlit');       // No lighting
await controller.executeConsoleCommand('viewmode wireframe');   // Wireframe
await controller.executeConsoleCommand('show Bloom');           // Toggle bloom
await controller.executeConsoleCommand('show PostProcessing'); // Toggle PP
```

### Find Performance Bottleneck

```dart
// Profiling workflow
await controller.executeConsoleCommand('stat unit');   // CPU vs GPU
await controller.executeConsoleCommand('stat gpu');    // GPU breakdown
await controller.executeConsoleCommand('stat game');   // Game thread
await controller.executeConsoleCommand('stat scenerendering');  // Draw calls
```

---

## Tips

1. **Toggle Commands:** Many commands toggle on/off when called repeatedly
2. **Case Insensitive:** Commands are case-insensitive
3. **Autocomplete:** In Unreal Editor, console has autocomplete (not in Flutter)
4. **Help:** Use `help <command>` in Unreal Editor for command details
5. **Persistence:** Most console commands reset on restart

---

## Common Command Patterns

### Quality Ladder Test

Test different quality levels:

```dart
final qualityLevels = [0, 1, 2, 3, 4];
for (final level in qualityLevels) {
  await controller.executeConsoleCommand('sg.ViewDistanceQuality $level');
  await controller.executeConsoleCommand('sg.ShadowQuality $level');
  await Future.delayed(Duration(seconds: 2));  // Wait to observe
}
```

### Performance Test Suite

```dart
Future<void> runPerformanceTest() async {
  // Show stats
  await controller.executeConsoleCommand('stat fps');
  await controller.executeConsoleCommand('stat unit');

  // Wait for measurement
  await Future.delayed(Duration(seconds: 5));

  // Hide stats
  await controller.executeConsoleCommand('stat fps');
  await controller.executeConsoleCommand('stat unit');
}
```

---

**Last Updated:** 2025-10-27
**Plugin Version:** 0.5.0

**See Also:**
- [QUALITY_SETTINGS_GUIDE.md](QUALITY_SETTINGS_GUIDE.md) - Quality settings reference
- [Official Unreal Console Commands](https://docs.unrealengine.com/5.3/en-US/console-commands-in-unreal-engine/)
