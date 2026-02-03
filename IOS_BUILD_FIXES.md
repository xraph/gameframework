# iOS Build Fixes for Unreal Engine Plugin

## Summary
Fixed multiple compilation issues preventing the `gameframework_unreal` plugin from building on iOS.

## Issues Fixed

### 1. **iOS Deployment Target Mismatch**
**Error:**
```
Error: The plugin "gameframework_unreal" requires a higher minimum iOS deployment version than your application is targeting.
To build, increase your application's deployment target to at least 15.0
```

**Fix:**
Updated the consuming app's `Podfile` to specify iOS 15.0:
```ruby
platform :ios, '15.0'
```

**Location:** `/path/to/example/ios/Podfile`

---

### 2. **Swift @objc Method with Non-Representable Parameters**
**Error:**
```
Swift Compiler Error: Method cannot be marked '@objc' because the type of the parameter cannot be represented in Objective-C
```

**Issue:** Methods `onBinaryChunkFromUnreal` and `notifyBinaryChunk` were marked `@objc` but had optional parameters (`Int?`, `Data?`) that can't be represented in Objective-C.

**Fix:** Removed `@objc` attribute from both methods since they're only called from Swift:
- Line 536: `onBinaryChunkFromUnreal` in `UnrealEngineController`
- Line 941: `notifyBinaryChunk` in `UnrealBridge`

**Location:** `engines/unreal/dart/ios/Classes/UnrealEngineController.swift`

---

### 3. **Swift Exclusive Memory Access Violations**
**Error:**
```
Swift Compiler Error: Overlapping accesses to 'compressed', but modification requires exclusive access
```

**Issue:** The `compressGzip` and `decompressGzip` methods had overlapping access to mutable variables within nested closures.

**Fix:** Refactored to extract only the size from the closure, then perform the slicing operation outside:
```swift
let totalOut: Int? = data.withUnsafeBytes { ... }
guard let size = totalOut else { return nil }
return compressed.prefix(size)
```

**Location:** `engines/unreal/dart/ios/Classes/UnrealEngineController.swift`, lines 300-365

---

### 4. **Missing Unreal Engine Headers During Compilation**
**Error:**
```
Lexical or Preprocessor Issue: 'FlutterBridge.h' file not found
```

**Issue:** `UnrealBridge.mm` was trying to include Unreal Engine C++ headers that don't exist during plugin development (only available when integrated with actual Unreal Engine export).

**Fix:** Added conditional compilation with stub implementations:
```objc
#if __has_include("FlutterBridge.h")
// Real implementation with Unreal Engine
#else
// Stub implementation for development/testing
#endif
```

**Location:** `engines/unreal/dart/ios/Classes/UnrealBridge.mm`

**Benefits:**
- Plugin can compile and be tested without Unreal Engine framework
- Real implementation activates when UnrealFramework.framework is present
- Maintains clean separation between plugin and game code

---

### 5. **Invalid Dart Icon Reference**
**Error:**
```
Error: Expected ',' before this.
Icons.360,
```

**Issue:** Icon identifier `Icons.360` is invalid because Dart identifiers can't start with numbers.

**Fix:** Changed to valid icon:
```dart
Icons.rotate_right  // instead of Icons.360
```

**Location:** Example app's `lib/main.dart`, line 243

---

## Build Results

### Before Fixes
```
Command PhaseScriptExecution failed with a nonzero exit code
```

### After Fixes
```
✓ Built build/ios/iphoneos/Runner.app (14.0MB)
```

---

## Architecture Notes

### Unreal Framework Integration Strategy

The `gameframework_unreal` plugin is designed to work in two modes:

1. **Development Mode** (without UnrealFramework)
   - Uses stub implementations in `UnrealBridge.mm`
   - Allows plugin development and testing
   - Can be imported by Flutter apps that don't have Unreal Engine yet

2. **Production Mode** (with UnrealFramework)
   - Full Unreal Engine integration
   - Real implementations of all bridge methods
   - Requires `UnrealFramework.framework` to be vendored by consuming plugin

### File Structure

```
engines/unreal/dart/ios/
├── Classes/
│   ├── UnrealEnginePlugin.swift      # Flutter plugin registration
│   ├── UnrealEngineController.swift  # Main controller logic
│   └── UnrealBridge.mm              # Obj-C++ bridge (conditional)
└── gameframework_unreal.podspec     # CocoaPods spec (iOS 15.0+)
```

### Key Design Decisions

1. **Conditional Compilation:** Use `#if __has_include()` to detect Unreal availability
2. **Weak Linking:** Framework search paths allow finding Unreal from sibling pods
3. **Stub Implementations:** Graceful fallback when Unreal isn't present
4. **Memory Safety:** Avoid overlapping access in Swift closures
5. **Objective-C Compatibility:** Remove @objc from methods with non-representable types

---

## Testing

### Build Verification
```bash
cd /path/to/example
flutter clean
flutter pub get
flutter build ios --no-codesign
```

Should complete successfully with:
```
✓ Built build/ios/iphoneos/Runner.app
```

### Next Steps for Integration

1. Export Unreal Engine project for iOS
2. Place `UnrealFramework.framework` in consuming plugin's `ios/` directory
3. Update consuming plugin's podspec to vendor the framework
4. Real Unreal integration will activate automatically

---

## Related Files Modified

### gameframework_unreal plugin:
- `engines/unreal/dart/ios/Classes/UnrealEngineController.swift`
- `engines/unreal/dart/ios/Classes/UnrealBridge.mm`

### Example app:
- `/path/to/ozone/unreal/example/ios/Podfile`
- `/path/to/ozone/unreal/example/lib/main.dart`

---

## Lessons Learned

1. **Deployment Targets:** Always check minimum deployment target requirements across all dependencies
2. **@objc Compatibility:** Not all Swift types can be represented in Objective-C
3. **Memory Safety:** Swift's exclusive access rules require careful handling of mutable captures
4. **Conditional Compilation:** Use `#if __has_include()` for optional dependencies
5. **Plugin Architecture:** Design plugins to work standalone during development
