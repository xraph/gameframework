# Unreal Engine Quality Settings Guide

Complete guide to Unreal Engine quality settings, presets, and performance optimization.

## Table of Contents

- [Overview](#overview)
- [Quality Presets](#quality-presets)
- [Individual Settings](#individual-settings)
- [Performance Optimization](#performance-optimization)
- [Platform-Specific Recommendations](#platform-specific-recommendations)
- [Runtime Adjustments](#runtime-adjustments)
- [Advanced Techniques](#advanced-techniques)

---

## Overview

Unreal Engine quality settings control the visual fidelity and performance of your game. The GameFramework provides easy-to-use APIs for managing these settings dynamically.

### Quality Levels

Unreal Engine uses a 0-4 scale for quality settings:
- **0:** Low - Minimum quality, maximum performance
- **1:** Medium - Balanced for mid-range devices
- **2:** High - Good quality for high-end devices
- **3:** Epic - Very high quality
- **4:** Cinematic - Maximum quality, for powerful hardware

---

## Quality Presets

### Low

Optimized for mobile devices and low-end hardware.

```dart
await controller.applyQualitySettings(UnrealQualitySettings.low());
```

**Settings:**
- Overall Quality: 0
- Anti-Aliasing: 0 (Disabled)
- Shadows: 0 (Simple/blob shadows)
- Post-Processing: 0 (Minimal effects)
- Textures: 0 (Low resolution)
- Effects: 0 (Simplified particles)
- Foliage: 0 (Reduced density)
- View Distance: 0 (Short draw distance)
- Target FPS: 30
- VSync: Disabled
- Resolution Scale: 0.75 (75% of native)

**Use Cases:**
- Mobile devices (phones, tablets)
- Older Android devices (API 21-23)
- Low-end hardware
- Battery-saving mode

### Medium

Balanced quality for mainstream devices.

```dart
await controller.applyQualitySettings(UnrealQualitySettings.medium());
```

**Settings:**
- Overall Quality: 1
- Anti-Aliasing: 1 (FXAA)
- Shadows: 1 (Medium quality shadows)
- Post-Processing: 1 (Basic bloom, DOF)
- Textures: 2 (Medium resolution)
- Effects: 1 (Standard particles)
- Foliage: 1 (Normal density)
- View Distance: 1 (Medium draw distance)
- Target FPS: 60
- VSync: Disabled
- Resolution Scale: 1.0 (Native)

**Use Cases:**
- Modern mid-range smartphones
- Tablets
- Mainstream laptops
- Default quality setting

### High

High quality for powerful devices.

```dart
await controller.applyQualitySettings(UnrealQualitySettings.high());
```

**Settings:**
- Overall Quality: 2
- Anti-Aliasing: 2 (TAA)
- Shadows: 2 (High quality shadows)
- Post-Processing: 2 (Bloom, DOF, motion blur)
- Textures: 3 (High resolution)
- Effects: 2 (Detailed particles)
- Foliage: 2 (High density)
- View Distance: 2 (Long draw distance)
- Target FPS: 60
- VSync: Enabled
- Resolution Scale: 1.0 (Native)

**Use Cases:**
- High-end smartphones (iPhone 13+, Galaxy S21+)
- Gaming laptops
- Desktop PCs
- Recommended for most desktop games

### Epic

Very high quality for enthusiast hardware.

```dart
await controller.applyQualitySettings(UnrealQualitySettings.epic());
```

**Settings:**
- Overall Quality: 3
- Anti-Aliasing: 3 (High-quality TAA)
- Shadows: 3 (Ultra shadows with soft edges)
- Post-Processing: 3 (All effects enabled)
- Textures: 4 (Ultra-high resolution)
- Effects: 3 (Maximum particles)
- Foliage: 3 (Very high density)
- View Distance: 3 (Very long draw distance)
- Target FPS: 60
- VSync: Enabled
- Resolution Scale: 1.25 (125% supersampling)

**Use Cases:**
- High-end gaming PCs
- RTX 3070+ GPUs
- 16GB+ RAM systems
- Showcasing visual quality

### Cinematic

Maximum quality for screenshots and demos.

```dart
await controller.applyQualitySettings(UnrealQualitySettings.cinematic());
```

**Settings:**
- Overall Quality: 4
- Anti-Aliasing: 4 (Maximum quality TAA)
- Shadows: 4 (Ray-traced or highest quality)
- Post-Processing: 4 (All effects at maximum)
- Textures: 4 (Highest resolution)
- Effects: 4 (Maximum detail)
- Foliage: 4 (Maximum density)
- View Distance: 4 (Unlimited draw distance)
- Target FPS: 30 (quality over performance)
- VSync: Enabled
- Resolution Scale: 1.5 (150% supersampling)

**Use Cases:**
- Screenshots
- Trailers and marketing materials
- RTX 4080+ GPUs
- Not recommended for gameplay

---

## Individual Settings

### Custom Configuration

Create custom quality settings for specific needs:

```dart
await controller.applyQualitySettings(
  UnrealQualitySettings(
    qualityLevel: 2,              // Overall level
    antiAliasingQuality: 3,       // Custom AA
    shadowQuality: 2,             // Custom shadows
    postProcessQuality: 3,        // Custom post-processing
    textureQuality: 3,            // Custom textures
    effectsQuality: 2,            // Custom effects
    foliageQuality: 1,            // Custom foliage
    viewDistanceQuality: 2,       // Custom view distance
    targetFrameRate: 60,          // Target FPS
    enableVSync: false,           // VSync control
    resolutionScale: 1.0,         // Resolution multiplier
  ),
);
```

### Anti-Aliasing Quality

Controls edge smoothing and temporal artifacts.

- **0:** Disabled - No anti-aliasing (jagged edges, maximum performance)
- **1:** FXAA - Fast approximation (slight blur, good performance)
- **2:** TAA - Temporal anti-aliasing (smooth edges, slight ghosting)
- **3:** TAA High - Enhanced TAA (very smooth, minimal ghosting)
- **4:** TAA Ultra - Maximum quality TAA (perfect edges, performance cost)

**Performance Impact:** Medium
**Visual Impact:** High

```dart
UnrealQualitySettings(antiAliasingQuality: 2)  // TAA for most cases
```

### Shadow Quality

Controls shadow resolution and filtering.

- **0:** Blob - Simple circular shadows (mobile-friendly)
- **1:** Low - Hard shadows, low resolution
- **2:** Medium - Soft shadows, medium resolution
- **3:** High - Very soft shadows, high resolution
- **4:** Ultra - Ray-traced or highest quality shadows

**Performance Impact:** Very High
**Visual Impact:** High

```dart
UnrealQualitySettings(shadowQuality: 2)  // Good balance
```

**Tips:**
- Shadows are expensive on mobile
- Consider dynamic shadow distance
- Use static lighting when possible

### Post-Processing Quality

Controls bloom, depth of field, motion blur, and other effects.

- **0:** Minimal - Only essential effects
- **1:** Low - Basic bloom and tone mapping
- **2:** Medium - Bloom, DOF, lens flares
- **3:** High - All effects with good quality
- **4:** Ultra - Maximum quality effects

**Performance Impact:** Medium
**Visual Impact:** Medium

```dart
UnrealQualitySettings(postProcessQuality: 2)
```

**Effects Controlled:**
- Bloom
- Depth of Field
- Motion Blur
- Lens Flares
- Color Grading
- Screen Space Reflections

### Texture Quality

Controls texture resolution and streaming.

- **0:** Low - Highly compressed, low resolution
- **1:** Medium - Moderate compression
- **2:** High - Good resolution
- **3:** Very High - High resolution
- **4:** Ultra - Maximum resolution, no compression

**Performance Impact:** Medium (mostly VRAM)
**Visual Impact:** High

```dart
UnrealQualitySettings(textureQuality: 3)
```

**Considerations:**
- Higher = More VRAM usage
- Mobile devices: Use 0-1
- Desktop: Use 3-4
- Affects loading times

### Effects Quality

Controls particle systems and visual effects.

- **0:** Low - Simplified particles, reduced count
- **1:** Medium - Standard particles
- **2:** High - Detailed particles
- **3:** Very High - Maximum detail particles
- **4:** Ultra - Cinematic particle quality

**Performance Impact:** High
**Visual Impact:** Medium

```dart
UnrealQualitySettings(effectsQuality: 2)
```

### Foliage Quality

Controls grass, trees, and vegetation density.

- **0:** Low - Minimal foliage
- **1:** Medium - Moderate density
- **2:** High - High density
- **3:** Very High - Very dense foliage
- **4:** Ultra - Maximum density

**Performance Impact:** Very High
**Visual Impact:** High (in outdoor scenes)

```dart
UnrealQualitySettings(foliageQuality: 1)  // Big performance save
```

**Tips:**
- Foliage is very expensive
- Use LODs aggressively
- Consider culling distance

### View Distance Quality

Controls how far objects are rendered.

- **0:** Near - Short draw distance
- **1:** Medium - Moderate draw distance
- **2:** Far - Long draw distance
- **3:** Very Far - Very long draw distance
- **4:** Epic - Maximum draw distance

**Performance Impact:** Very High
**Visual Impact:** High (in open areas)

```dart
UnrealQualitySettings(viewDistanceQuality: 2)
```

### Target Frame Rate

Sets the maximum frame rate.

```dart
UnrealQualitySettings(targetFrameRate: 60)  // 30, 60, 90, 120, or unlimited
```

**Recommendations:**
- Mobile: 30 or 60 FPS
- Desktop: 60+ FPS
- VR: 90 or 120 FPS

### VSync

Controls vertical synchronization.

```dart
UnrealQualitySettings(enableVSync: true)
```

**Enabled (true):**
- Eliminates screen tearing
- May introduce input lag
- Locks to display refresh rate

**Disabled (false):**
- No screen tearing prevention
- Lower input latency
- Unlocked frame rate

**Recommendation:** Disabled for mobile, enabled for desktop

### Resolution Scale

Render at different resolution than display.

```dart
UnrealQualitySettings(resolutionScale: 0.75)  // 75% of native resolution
```

**Values:**
- **< 1.0:** Lower resolution (performance boost)
- **1.0:** Native resolution
- **> 1.0:** Supersampling (better quality, worse performance)

**Common Values:**
- 0.5 - 50% (major performance boost, blurry)
- 0.75 - 75% (good balance)
- 1.0 - Native (default)
- 1.25 - 125% (supersampling, slight improvement)
- 1.5 - 150% (maximum supersampling, expensive)

---

## Performance Optimization

### Mobile Optimization

For best mobile performance:

```dart
final mobileSettings = UnrealQualitySettings(
  qualityLevel: 0,
  antiAliasingQuality: 0,      // Disable AA
  shadowQuality: 0,            // Blob shadows only
  postProcessQuality: 0,       // Minimal effects
  textureQuality: 0,           // Low-res textures
  effectsQuality: 0,           // Simplified particles
  foliageQuality: 0,           // Minimal foliage
  viewDistanceQuality: 0,      // Short draw distance
  targetFrameRate: 30,         // 30 FPS target
  enableVSync: false,          // Disable VSync
  resolutionScale: 0.75,       // 75% resolution
);

await controller.applyQualitySettings(mobileSettings);
```

**Additional Tips:**
- Use static lighting
- Bake shadows when possible
- Limit dynamic lights
- Use mobile-specific materials
- Reduce draw calls

### Desktop Optimization

For good desktop performance:

```dart
final desktopSettings = UnrealQualitySettings(
  qualityLevel: 2,
  antiAliasingQuality: 2,      // TAA
  shadowQuality: 2,            // Medium shadows
  postProcessQuality: 2,       // Standard effects
  textureQuality: 3,           // High-res textures
  effectsQuality: 2,           // Detailed particles
  foliageQuality: 2,           // High density
  viewDistanceQuality: 2,      // Long draw distance
  targetFrameRate: 60,         // 60 FPS target
  enableVSync: true,           // Enable VSync
  resolutionScale: 1.0,        // Native resolution
);

await controller.applyQualitySettings(desktopSettings);
```

### Dynamic Quality Adjustment

Adjust quality based on performance:

```dart
class AdaptiveQuality {
  UnrealController controller;
  double currentFPS = 60.0;
  int currentQualityLevel = 2;

  Future<void> adjustQuality() async {
    // Measure FPS (using console command)
    await controller.executeConsoleCommand('stat fps');

    // Get FPS from Unreal (you'd need to implement message handling)
    // For example purposes:
    if (currentFPS < 30 && currentQualityLevel > 0) {
      // Lower quality
      currentQualityLevel--;
      await _applyQualityLevel(currentQualityLevel);
    } else if (currentFPS > 50 && currentQualityLevel < 4) {
      // Raise quality
      currentQualityLevel++;
      await _applyQualityLevel(currentQualityLevel);
    }
  }

  Future<void> _applyQualityLevel(int level) async {
    switch (level) {
      case 0:
        await controller.applyQualitySettings(UnrealQualitySettings.low());
        break;
      case 1:
        await controller.applyQualitySettings(UnrealQualitySettings.medium());
        break;
      case 2:
        await controller.applyQualitySettings(UnrealQualitySettings.high());
        break;
      case 3:
        await controller.applyQualitySettings(UnrealQualitySettings.epic());
        break;
      case 4:
        await controller.applyQualitySettings(UnrealQualitySettings.cinematic());
        break;
    }
  }
}
```

---

## Platform-Specific Recommendations

### Android

**Low-End (< 2GB RAM):**
```dart
UnrealQualitySettings.low().copyWith(
  resolutionScale: 0.5,  // Further reduce resolution
  targetFrameRate: 30,
)
```

**Mid-Range (2-4GB RAM):**
```dart
UnrealQualitySettings.low().copyWith(
  resolutionScale: 0.75,
  textureQuality: 1,
)
```

**High-End (4GB+ RAM):**
```dart
UnrealQualitySettings.medium()
```

### iOS

**iPhone 11 and older:**
```dart
UnrealQualitySettings.medium().copyWith(
  shadowQuality: 1,
  effectsQuality: 1,
)
```

**iPhone 12-13:**
```dart
UnrealQualitySettings.high().copyWith(
  shadowQuality: 2,
)
```

**iPhone 14+ / iPad Pro:**
```dart
UnrealQualitySettings.high()
```

### macOS

**MacBook Air / Mac Mini (M1):**
```dart
UnrealQualitySettings.medium()
```

**MacBook Pro (M1 Pro/Max):**
```dart
UnrealQualitySettings.high()
```

**Mac Studio / Mac Pro:**
```dart
UnrealQualitySettings.epic()
```

### Windows

**Integrated Graphics:**
```dart
UnrealQualitySettings.medium().copyWith(
  shadowQuality: 1,
  foliageQuality: 1,
)
```

**GTX 1060 / RTX 2060:**
```dart
UnrealQualitySettings.high()
```

**RTX 3070+:**
```dart
UnrealQualitySettings.epic()
```

**RTX 4080+:**
```dart
UnrealQualitySettings.cinematic().copyWith(
  targetFrameRate: 60,  // Maintain 60 FPS
)
```

### Linux

Similar to Windows recommendations based on GPU.

---

## Runtime Adjustments

### User Settings Menu

Create a settings menu for users to adjust quality:

```dart
class QualitySettingsMenu extends StatefulWidget {
  final UnrealController controller;

  QualitySettingsMenu({required this.controller});

  @override
  _QualitySettingsMenuState createState() => _QualitySettingsMenuState();
}

class _QualitySettingsMenuState extends State<QualitySettingsMenu> {
  int _qualityLevel = 2;
  int _antiAliasing = 2;
  int _shadows = 2;
  int _textures = 3;
  bool _vSync = true;
  double _resolutionScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Preset selector
        DropdownButton<String>(
          value: 'Custom',
          items: ['Low', 'Medium', 'High', 'Epic', 'Custom']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) => _applyPreset(value!),
        ),

        // Individual sliders
        _buildSlider('Overall Quality', 0, 4, _qualityLevel.toDouble(),
            (v) => setState(() => _qualityLevel = v.toInt())),
        _buildSlider('Anti-Aliasing', 0, 4, _antiAliasing.toDouble(),
            (v) => setState(() => _antiAliasing = v.toInt())),
        _buildSlider('Shadows', 0, 4, _shadows.toDouble(),
            (v) => setState(() => _shadows = v.toInt())),
        _buildSlider('Textures', 0, 4, _textures.toDouble(),
            (v) => setState(() => _textures = v.toInt())),

        // Resolution scale
        _buildSlider('Resolution Scale', 0.5, 1.5, _resolutionScale,
            (v) => setState(() => _resolutionScale = v)),

        // VSync toggle
        SwitchListTile(
          title: Text('VSync'),
          value: _vSync,
          onChanged: (v) => setState(() => _vSync = v),
        ),

        // Apply button
        ElevatedButton(
          onPressed: _applySettings,
          child: Text('Apply Settings'),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double min, double max, double value,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: ((max - min) / (min == 0.5 ? 0.1 : 1)).toInt(),
            value: value,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(value.toStringAsFixed(min == 0.5 ? 1 : 0)),
        ),
      ],
    );
  }

  Future<void> _applyPreset(String preset) async {
    UnrealQualitySettings settings;
    switch (preset) {
      case 'Low':
        settings = UnrealQualitySettings.low();
        break;
      case 'Medium':
        settings = UnrealQualitySettings.medium();
        break;
      case 'High':
        settings = UnrealQualitySettings.high();
        break;
      case 'Epic':
        settings = UnrealQualitySettings.epic();
        break;
      default:
        return;
    }
    await widget.controller.applyQualitySettings(settings);
    _loadCurrentSettings();
  }

  Future<void> _applySettings() async {
    final settings = UnrealQualitySettings(
      qualityLevel: _qualityLevel,
      antiAliasingQuality: _antiAliasing,
      shadowQuality: _shadows,
      textureQuality: _textures,
      enableVSync: _vSync,
      resolutionScale: _resolutionScale,
    );
    await widget.controller.applyQualitySettings(settings);
  }

  Future<void> _loadCurrentSettings() async {
    final current = await widget.controller.getQualitySettings();
    setState(() {
      _qualityLevel = current.qualityLevel ?? 2;
      _antiAliasing = current.antiAliasingQuality ?? 2;
      _shadows = current.shadowQuality ?? 2;
      _textures = current.textureQuality ?? 3;
      _vSync = current.enableVSync ?? true;
      _resolutionScale = current.resolutionScale ?? 1.0;
    });
  }
}
```

### Auto-Detect Quality

Detect device capabilities and set appropriate quality:

```dart
Future<UnrealQualitySettings> detectOptimalQuality() async {
  final deviceInfo = await DeviceInfoPlugin().deviceInfo;

  if (Platform.isAndroid) {
    final androidInfo = deviceInfo as AndroidDeviceInfo;
    final ram = androidInfo.systemFeatures.contains('android.hardware.ram.normal');

    if (ram < 2) {
      return UnrealQualitySettings.low();
    } else if (ram < 4) {
      return UnrealQualitySettings.medium();
    } else {
      return UnrealQualitySettings.high();
    }
  } else if (Platform.isIOS) {
    final iosInfo = deviceInfo as IosDeviceInfo;
    final model = iosInfo.utsname.machine;

    // iPhone 13+ or iPad Pro
    if (model.contains('iPhone14') || model.contains('iPad13')) {
      return UnrealQualitySettings.high();
    } else {
      return UnrealQualitySettings.medium();
    }
  }

  // Desktop: default to high
  return UnrealQualitySettings.high();
}
```

---

## Advanced Techniques

### Console Command Overrides

Use console commands for fine-grained control:

```dart
// Resolution
await controller.executeConsoleCommand('r.SetRes 1920x1080');

// Specific scalability groups
await controller.executeConsoleCommand('sg.ViewDistanceQuality 3');
await controller.executeConsoleCommand('sg.AntiAliasingQuality 2');
await controller.executeConsoleCommand('sg.ShadowQuality 2');
await controller.executeConsoleCommand('sg.PostProcessQuality 3');
await controller.executeConsoleCommand('sg.TextureQuality 3');
await controller.executeConsoleCommand('sg.EffectsQuality 2');
await controller.executeConsoleCommand('sg.FoliageQuality 1');

// VSync
await controller.executeConsoleCommand('r.VSync 0');  // 0=off, 1=on

// Frame rate limit
await controller.executeConsoleCommand('t.MaxFPS 60');

// Resolution scale
await controller.executeConsoleCommand('r.ScreenPercentage 75');

// Dynamic resolution
await controller.executeConsoleCommand('r.DynamicRes.OperationMode 1');
```

### Performance Profiling

Profile performance to identify bottlenecks:

```dart
// Show FPS
await controller.executeConsoleCommand('stat fps');

// Show detailed stats
await controller.executeConsoleCommand('stat unit');  // CPU/GPU times
await controller.executeConsoleCommand('stat gpu');   // GPU breakdown
await controller.executeConsoleCommand('stat scenerendering');

// Show memory
await controller.executeConsoleCommand('stat memory');
```

---

## Best Practices

1. **Start Conservative:** Begin with lower settings and increase
2. **Test on Target Hardware:** Always test on actual devices
3. **Provide User Control:** Let users adjust settings
4. **Monitor Performance:** Track FPS and adjust dynamically
5. **Save Settings:** Persist user preferences
6. **Use Presets:** Offer quick preset options
7. **Document Requirements:** Clearly state minimum specs

---

**Last Updated:** 2025-10-27
**Plugin Version:** 0.5.0
