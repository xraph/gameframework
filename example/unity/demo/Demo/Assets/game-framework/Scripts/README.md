# Unity Plugin Scripts

Communication scripts for Unity-Flutter integration in the Game Framework.

## Overview

This directory contains C# scripts that enable bidirectional communication between Unity and Flutter using the Unity as a Library pattern.

## Core Communication Scripts

### 1. NativeAPI.cs
**Low-level platform bridge**

- Direct platform-specific communication (iOS/Android)
- Lifecycle event management
- Unity player control (pause, quit, unload)
- Based on flutter-unity-view-widget pattern

**Usage:**
```csharp
NativeAPI.Initialize();
NativeAPI.NotifyUnityReady();
NativeAPI.SendMessageToFlutter("target", "method", data);
```

### 2. UnityMessageManager.cs (Singleton)
**High-level message router**

- Singleton message manager
- Request-response pattern with callbacks
- Event listener system
- Thread-safe message queuing

**Usage:**
```csharp
UnityMessageManager.Instance.SendToFlutter("target", "method", data);
UnityMessageManager.Instance.AddEventListener("eventName", handler);
```

### 3. MessageHandler.cs
**Type-safe message handling**

- Generic type handlers
- Automatic JSON deserialization
- Message validation and queuing
- Built-in common message types

**Usage:**
```csharp
messageHandler.RegisterHandler<PlayerAction>("PlayerAction", HandleAction);
messageHandler.SendMessage("target", "method", typedData);
```

### 4. SingletonMonoBehaviour.cs
**Generic singleton pattern base class**

- Ensures single instance across scenes
- Thread-safe instance access
- Automatic DontDestroyOnLoad
- Based on flutter-unity-view-widget pattern

**Usage:**
```csharp
public class MyManager : SingletonMonoBehaviour<MyManager>
{
    protected override void SingletonAwake()
    {
        base.SingletonAwake();
        // Your initialization
    }
}

// Access anywhere
MyManager.Instance.DoSomething();
```

## Utility Scripts

### FlutterBridge.cs
Original bridge implementation with backward compatibility.

### FlutterGameManager.cs (Singleton)
Example game manager demonstrating Flutter integration patterns.
- Uses SingletonMonoBehaviour pattern
- Global game state management
- Persists across scenes

### FlutterSceneManager.cs (Singleton)
Scene management with Flutter synchronization.
- Uses SingletonMonoBehaviour pattern
- Automatic scene event notifications
- Consistent scene management

### FlutterUtilities.cs
Helper utilities for Unity-Flutter integration.

### FlutterPerformanceMonitor.cs
Performance monitoring and metrics reporting to Flutter.

## Examples

### Examples/NativeAPIExample.cs
Comprehensive example demonstrating:
- All three communication levels
- Message sending and receiving
- Callback patterns
- Event handling
- UI integration

## Quick Start

### 1. Basic Setup
```csharp
using Xraph.GameFramework.Unity;

public class GameBootstrap : MonoBehaviour
{
    void Start()
    {
        // Initialize communication
        NativeAPI.Initialize();
        NativeAPI.NotifyUnityReady();
    }
}
```

### 2. Send Messages
```csharp
// Simple message
NativeAPI.SendMessageToFlutter("Flutter", "onEvent", data);

// Typed message
var state = new GameState { score = 100 };
UnityMessageManager.Instance.SendToFlutter("Flutter", "onGameState", state);
```

### 3. Receive Messages
```csharp
void Start()
{
    // Option 1: NativeAPI events
    NativeAPI.OnMessageReceived += HandleMessage;
    
    // Option 2: UnityMessageManager listeners
    UnityMessageManager.Instance.AddEventListener("Flutter:Command", HandleCommand);
    
    // Option 3: MessageHandler type-safe
    messageHandler.RegisterHandler<PlayerAction>("PlayerAction", HandleAction);
}
```

## Architecture

```
Unity Scripts
├── NativeAPI.cs          → Platform bridge (iOS/Android)
├── UnityMessageManager.cs → Message router + callbacks
└── MessageHandler.cs      → Type-safe handlers

                ↕

Native Bridge (Kotlin/Swift)

                ↕

Flutter (Dart)
```

## Communication Flow

### Unity → Flutter
1. Unity script calls `NativeAPI.SendMessageToFlutter()`
2. Platform-specific bridge (Kotlin/Swift) receives message
3. Native bridge forwards to Flutter via MethodChannel
4. Flutter receives message in `onMessage` stream

### Flutter → Unity
1. Flutter calls `controller.sendMessage()`
2. Native bridge receives via MethodChannel
3. Native calls `UnitySendMessage()` with target GameObject
4. Unity script's message handler receives data

## Platform-Specific Implementation

### iOS (FlutterBridge.mm)
Objective-C++ bridge implementing:
- `SendMessageToFlutter()` - Unity → Flutter
- `_sendMessageToFlutter()` - NativeAPI variant
- `_notifyUnityReady()` - Ready notification
- `_showHostMainWindow()` - Window control
- `_unloadUnity()` - Cleanup

### Android (UnityEngineController.kt)
Kotlin bridge implementing:
- `onUnityMessage()` - Receives from Unity
- `sendMessage()` - Flutter → Unity
- Lifecycle management

## Best Practices

### 1. Initialize Once
```csharp
void Awake()
{
    if (instance != null && instance != this)
    {
        Destroy(gameObject);
        return;
    }
    
    instance = this;
    DontDestroyOnLoad(gameObject);
    NativeAPI.Initialize();
}
```

### 2. Choose Appropriate Level
- **Low-level** (NativeAPI): Platform-specific, lifecycle, performance-critical
- **Mid-level** (UnityMessageManager): Callbacks, events, general messaging
- **High-level** (MessageHandler): Type-safe business logic, complex data

### 3. Clean Up
```csharp
void OnDestroy()
{
    NativeAPI.OnMessageReceived -= HandleMessage;
    UnityMessageManager.Instance.RemoveEventListener("event", handler);
    messageHandler.ClearHandlers();
}
```

### 4. Error Handling
```csharp
try
{
    NativeAPI.SendMessageToFlutter("target", "method", data);
}
catch (Exception e)
{
    Debug.LogError($"Failed to send: {e.Message}");
    NativeAPI.SendMessageToFlutter("Unity", "onError", 
        $"{{\"error\":\"{e.Message}\"}}");
}
```

## Performance Tips

1. **Batch Updates**: Don't send on every frame
   ```csharp
   void Update()
   {
       if (Time.time - lastUpdate > 0.1f) // 10 times per second max
       {
           SendGameState();
           lastUpdate = Time.time;
       }
   }
   ```

2. **Message Size**: Keep messages compact
   ```csharp
   // Bad: Sending entire list
   SendList(allItems);
   
   // Good: Send only IDs
   SendIds(itemIds);
   ```

3. **Cache Serialization**: For repeated sends
   ```csharp
   string cachedJson = JsonUtility.ToJson(staticData);
   ```

## Documentation

- **[NATIVE_API_GUIDE.md](../NATIVE_API_GUIDE.md)** - Complete communication guide
- **[Unity README](../../README.md)** - Unity engine plugin overview
- **[Dart Plugin](../../dart/README.md)** - Flutter/Dart integration

## Examples in Action

See the example project:
- `/example/unity/` - Unity project with integration
- `/example/lib/` - Flutter app demonstrating communication

## Troubleshooting

### Messages Not Received
1. Verify `NativeAPI.Initialize()` is called
2. Check `NativeAPI.IsReady()` returns true
3. Enable debug logging: `messageHandler.enableDebugLogging = true`
4. Check Unity logs for errors

### Platform-Specific Issues

**iOS:**
- Ensure `SetFlutterBridgeController()` is called from Swift
- Verify FlutterBridge.mm is in Xcode project
- Check Unity framework is properly linked

**Android:**
- Verify Activity context is available
- Check UnityPlayer initialization
- Ensure proper lifecycle management

## References

- [Unity as a Library](https://docs.unity3d.com/Manual/UnityasaLibrary.html)
- [flutter-unity-view-widget](https://github.com/juicycleff/flutter-unity-view-widget)
- [UnitySendMessage](https://docs.unity3d.com/ScriptReference/GameObject.SendMessage.html)

