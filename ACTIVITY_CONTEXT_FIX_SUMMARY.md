# Activity Context Architecture Fix - FUW Pattern Alignment

**Date:** October 31, 2025  
**Issue:** Improper Activity context handling  
**Solution:** Implement FUW's proven pattern for Activity acquisition

## Problem Discovered

User identified critical architectural flaw by comparing our code to [flutter-unity-view-widget (FUW)](https://github.com/juicycleff/flutter-unity-view-widget):

### What We Were Doing Wrong

```kotlin
// ❌ WRONG: Trying to extract Activity from Context
class UnityEngineController(context: Context, ...) {
    val activityContext = (context as? Activity) ?: context  // Fragile!
    unityPlayer = UnityPlayer(activityContext, callbacks)
}
```

**Problems:**
- Assuming Context passed to factory is an Activity (not guaranteed)
- Unsafe casting with fallback to non-Activity Context
- Unity requires Activity for proper window management and rendering
- Ignores Flutter's `ActivityAware` interface pattern

### What FUW Does Right

[Source: FlutterUnityWidgetPlugin.kt](https://github.com/juicycleff/flutter-unity-view-widget/blob/master/android/src/main/kotlin/com/xraph/plugin/flutter_unity_widget/FlutterUnityWidgetPlugin.kt)

```kotlin
class FlutterUnityWidgetPlugin : FlutterPlugin, ActivityAware {
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        // THE ONLY PROPER WAY TO GET ACTIVITY
        UnityPlayerUtils.activity = binding.activity
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
    }
}
```

**Key Insights:**
1. Activity comes from `onAttachedToActivity` - the ONLY reliable source
2. Activity is stored in singleton for global access
3. Activity is passed separately, never extracted from Context
4. All initialization waits for Activity availability

## Solution Implemented

### Architecture Changes

#### 1. Updated GameEngineController Constructor

**File:** `android/src/main/kotlin/.../core/GameEngineController.kt`

```kotlin
// Before:
abstract class GameEngineController(
    protected val context: Context,
    protected val viewId: Int,
    ...
)

// After:
abstract class GameEngineController(
    protected val context: Context,      // General Android operations
    protected val activity: Activity?,   // Engine-specific operations
    protected val viewId: Int,
    ...
)
```

**Rationale:** Separate Context (for resources) from Activity (for engines).

#### 2. Updated GameEngineFactory

**File:** `android/src/main/kotlin/.../core/GameEngineFactory.kt`

```kotlin
override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    // Get Activity from registry (from onAttachedToActivity)
    val activity = GameEngineRegistry.instance.getCurrentActivity()
        ?: throw IllegalStateException("Activity not available")
    
    val lifecycle = GameEngineRegistry.instance.getCurrentLifecycle()
        ?: throw IllegalStateException("Lifecycle not available")

    // Pass BOTH Context and Activity
    val controller = createController(context, activity, viewId, messenger, lifecycle, config)
    return controller
}

abstract fun createController(
    context: Context,
    activity: Activity,  // Now explicit parameter!
    viewId: Int,
    messenger: BinaryMessenger,
    lifecycle: Lifecycle,
    config: Map<String, Any?>
): GameEngineController
```

**Changes:**
- ✅ Retrieve Activity from registry (populated by onAttachedToActivity)
- ✅ Pass Activity as explicit parameter
- ✅ Fail fast with clear error if Activity not available

#### 3. Updated UnityEngineController

**File:** `engines/unity/dart/android/.../UnityEngineController.kt`

```kotlin
// Before:
class UnityEngineController(
    context: Context,
    viewId: Int,
    ...
) {
    val activityContext = (context as? Activity) ?: context  // ❌
    unityPlayer = UnityPlayer(activityContext, callbacks)
}

// After:
class UnityEngineController(
    context: Context,
    activity: Activity?,  // Explicit parameter!
    viewId: Int,
    ...
) {
    if (activity == null) {
        throw IllegalStateException("Unity requires Activity")
    }
    unityPlayer = UnityPlayer(activity, callbacks)  // Type-safe!
}
```

**Changes:**
- ✅ Receive Activity as explicit parameter
- ✅ Validate Activity availability
- ✅ Use Activity directly (no casting)
- ✅ Clear error messages

#### 4. Updated UnityEngineFactory

**File:** `engines/unity/dart/android/.../UnityEnginePlugin.kt`

```kotlin
class UnityEngineFactory(
    messenger: BinaryMessenger
) : GameEngineFactory(messenger) {

    override fun createController(
        context: Context,
        activity: Activity,  // New parameter!
        viewId: Int,
        messenger: BinaryMessenger,
        lifecycle: Lifecycle,
        config: Map<String, Any?>
    ): GameEngineController {
        return UnityEngineController(
            context,
            activity,  // Pass explicitly
            viewId,
            messenger,
            lifecycle,
            config
        )
    }
}
```

## Files Modified

1. **android/src/main/kotlin/.../core/GameEngineFactory.kt**
   - Added Activity import
   - Updated create() to retrieve Activity from registry
   - Updated createController() signature to include Activity parameter

2. **android/src/main/kotlin/.../core/GameEngineController.kt**
   - Added Activity import
   - Updated constructor to include Activity parameter
   - Added comprehensive documentation on FUW pattern

3. **engines/unity/dart/android/.../UnityEngineController.kt**
   - Updated constructor signature
   - Removed Activity extraction from Context
   - Added Activity null check with clear error
   - Updated helper method documentation

4. **engines/unity/dart/android/.../UnityEnginePlugin.kt**
   - Updated UnityEngineFactory.createController() signature
   - Added Activity parameter to UnityEngineController instantiation

5. **UNITY_CONTEXT_ARCHITECTURE.md** (New)
   - Comprehensive documentation of architecture
   - FUW pattern explanation
   - Implementation details and best practices

6. **ACTIVITY_CONTEXT_FIX_SUMMARY.md** (This file)
   - Summary of changes and rationale

## Verification

### Build Status
✅ All files compile without errors  
✅ No linter warnings  
✅ Type-safe Activity usage throughout

### Pattern Verification

```kotlin
// ✅ Activity Source
onAttachedToActivity(binding) → binding.activity

// ✅ Storage
GameEngineRegistry.onActivityAttached(activity, lifecycle)

// ✅ Retrieval
GameEngineRegistry.instance.getCurrentActivity()

// ✅ Usage
unityPlayer = UnityPlayer(activity, callbacks)
```

## Benefits of This Architecture

### 1. Reliability
- Activity always comes from proper Flutter source
- No fragile Context casting
- Clear error messages when Activity unavailable

### 2. Type Safety
```kotlin
// Before: Unsafe
val activity = context as? Activity  // Might be null!

// After: Type-safe
val activity: Activity  // Guaranteed non-null or error thrown
```

### 3. Testability
```kotlin
@Test
fun testUnityInit() {
    val mockActivity = mock<Activity>()
    val controller = UnityEngineController(
        context = mockContext,
        activity = mockActivity,  // Easy to mock!
        ...
    )
}
```

### 4. Maintainability
- Clear separation: Context for resources, Activity for engines
- Explicit parameters show dependencies
- Follows established Flutter patterns

### 5. Production Safety
- Fails fast with clear errors
- No silent fallbacks that could cause issues later
- Proper lifecycle management

## Comparison with FUW

| Aspect | FUW | Our Implementation | Match |
|--------|-----|-------------------|-------|
| Activity Source | onAttachedToActivity | onAttachedToActivity | ✅ |
| Storage Pattern | UnityPlayerUtils.activity | GameEngineRegistry | ✅ |
| Passing Method | Singleton access | Explicit parameter | ✅ Better |
| Validation | Runtime | Compile + Runtime | ✅ Better |
| Separation | Single param | Context + Activity | ✅ Better |

## Migration Notes

### For Future Engine Implementations

When adding new engines (Godot, Unreal, etc.):

```kotlin
class NewEngineController(
    context: Context,      // Use for: Resources, LayoutInflater, Preferences
    activity: Activity?,   // Use for: Window, Input, Lifecycle, Rendering
    viewId: Int,
    messenger: BinaryMessenger,
    lifecycle: Lifecycle,
    config: Map<String, Any?>
) : GameEngineController(context, activity, viewId, messenger, lifecycle, config) {
    
    override fun createEngine() {
        // Always validate Activity first!
        if (activity == null) {
            throw IllegalStateException("Engine requires Activity context")
        }
        
        // Use Activity for engine initialization
        engine = EnginePlayer(activity, callbacks)
    }
}
```

### For Tests

```kotlin
// Mock both Context and Activity separately
val mockContext = mock<Context>()
val mockActivity = mock<Activity>()

val controller = EngineController(
    context = mockContext,
    activity = mockActivity,
    ...
)

// Can verify Activity-specific operations
verify(mockActivity).window
verify(mockActivity, never()).finish()
```

## Best Practices Established

### ✅ DO
1. Get Activity from `onAttachedToActivity`
2. Store in singleton/registry
3. Pass as explicit parameter
4. Validate before use
5. Fail fast with clear errors

### ❌ DON'T
1. Extract Activity from Context
2. Assume Context is Activity
3. Use Application context for engines
4. Silent fallbacks
5. Late initialization without validation

## References

- [FUW Plugin Source](https://github.com/juicycleff/flutter-unity-view-widget/blob/master/android/src/main/kotlin/com/xraph/plugin/flutter_unity_widget/FlutterUnityWidgetPlugin.kt)
- [Flutter ActivityAware](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/plugins/activity/ActivityAware.html)
- [Unity Android Integration](https://docs.unity3d.com/Manual/UnityasaLibrary.html)

## Acknowledgments

This fix was identified by careful comparison with FUW's battle-tested implementation. The user correctly identified that:

1. FUW passes controller/Activity context to Unity utilities
2. Activity comes from `onAttachedToActivity` exclusively
3. Context casting is unreliable and should be avoided
4. Explicit Activity parameter is the correct pattern

## Conclusion

This architectural fix aligns our implementation with FUW's proven production pattern. The key learning:

> **Never extract Activity from Context. Always get it from onAttachedToActivity via ActivityPluginBinding.**

This ensures:
- ✅ Reliable Activity access
- ✅ Proper lifecycle management
- ✅ Type-safe engine initialization
- ✅ Production-ready error handling
- ✅ Alignment with Flutter best practices

The implementation now correctly follows the pattern used by FUW, which has been proven in production across thousands of apps.

