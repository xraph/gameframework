# NativeAPI Communication Guide

This guide explains how to use the NativeAPI pattern for Unity-Flutter communication in the Game Framework.

## Overview

The NativeAPI system provides three levels of abstraction for Unity-Flutter communication:

1. **NativeAPI.cs** - Low-level platform bridge (similar to flutter-unity-view-widget)
2. **UnityMessageManager.cs** - High-level message routing with callbacks
3. **MessageHandler.cs** - Type-safe message handling

## Architecture

```
Flutter (Dart)
    ↕
Native Bridge (Kotlin/Swift)
    ↕
Unity C# Scripts
    ├── NativeAPI.cs (Low-level)
    ├── UnityMessageManager.cs (Manager)
    └── MessageHandler.cs (Type-safe)
```

## 1. NativeAPI - Low-Level Bridge

### Purpose
Direct platform-specific communication with minimal overhead. Based on Unity as a Library pattern.

### Key Features
- Platform-specific native calls (iOS/Android)
- Lifecycle event management
- Direct message passing
- Unity player control (pause, quit, unload)

### Usage Examples

#### Initialize and Notify Ready
```csharp
using Xraph.GameFramework.Unity;

public class GameBootstrap : MonoBehaviour
{
    void Start()
    {
        // Initialize NativeAPI (call once)
        NativeAPI.Initialize();
        
        // Notify Flutter when ready
        NativeAPI.NotifyUnityReady();
    }
}
```

#### Send Messages to Flutter
```csharp
// Simple message
NativeAPI.SendMessageToFlutter(
    "Flutter", 
    "onGameEvent", 
    "{\"event\":\"levelComplete\",\"score\":1000}"
);

// Structured message
NativeAPI.SendMessageToFlutter(
    target: "GameManager",
    method: "onPlayerAction",
    data: JsonUtility.ToJson(actionData)
);
```

#### Receive Messages from Flutter
```csharp
void Start()
{
    // Subscribe to messages
    NativeAPI.OnMessageReceived += HandleMessage;
}

void HandleMessage(string message)
{
    Debug.Log($"Received from Flutter: {message}");
    
    // Parse and handle message
    var msg = JsonUtility.FromJson<MessageData>(message);
    // ... process message
}

void OnDestroy()
{
    // Unsubscribe
    NativeAPI.OnMessageReceived -= HandleMessage;
}
```

#### Lifecycle Management
```csharp
// Subscribe to lifecycle events
NativeAPI.OnUnityReady += () => Debug.Log("Unity ready!");
NativeAPI.OnUnityPaused += (paused) => Debug.Log($"Unity paused: {paused}");
NativeAPI.OnSceneLoaded += (name, index) => Debug.Log($"Scene loaded: {name}");

// Control Unity
NativeAPI.Pause(true);  // Pause Unity
NativeAPI.Pause(false); // Resume Unity
NativeAPI.ShowHostMainWindow(); // Show Flutter window (iOS)
NativeAPI.QuitUnity(); // Quit Unity
```

### Platform-Specific Implementation

#### iOS (FlutterBridge.mm)
```objc
// Called from Unity C#
extern "C" {
    void _sendMessageToFlutter(const char* message);
    void _notifyUnityReady();
    void _showHostMainWindow();
    void _unloadUnity();
    void _quitUnity();
}
```

#### Android (UnityEngineController.kt)
```kotlin
// Called via JNI from Unity
fun onUnityMessage(target: String, method: String, data: String) {
    sendEventToFlutter("onMessage", mapOf(
        "target" to target,
        "method" to method,
        "data" to data
    ))
}
```

## 2. UnityMessageManager - High-Level Manager

### Purpose
Provides message routing, callbacks, event system, and thread-safe queuing.

### Key Features
- Singleton pattern for centralized communication
- Request-response pattern with callbacks
- Event listener system
- Thread-safe message queuing
- Automatic JSON serialization

### Usage Examples

#### Basic Messaging
```csharp
using Xraph.GameFramework.Unity;

public class GameController : MonoBehaviour
{
    void Start()
    {
        // Send message to Flutter
        UnityMessageManager.Instance.SendToFlutter(
            "Flutter",
            "onGameStart",
            "Level 1"
        );
        
        // Send typed object
        var gameState = new GameState { score = 100, level = 1 };
        UnityMessageManager.Instance.SendToFlutter(
            "Flutter",
            "onGameState",
            gameState
        );
    }
}
```

#### Request-Response Pattern
```csharp
// Send message and wait for response
int callbackId = UnityMessageManager.Instance.SendToFlutterWithCallback(
    "Flutter",
    "getPlayerData",
    "{\"playerId\":\"123\"}",
    (response) =>
    {
        Debug.Log($"Received response: {response}");
        var playerData = JsonUtility.FromJson<PlayerData>(response);
        // Process player data
    }
);
```

#### Event Listener System
```csharp
void Start()
{
    // Register event listener
    UnityMessageManager.Instance.AddEventListener(
        "Flutter:Command",
        HandleFlutterCommand
    );
    
    // Listen to Unity events
    UnityMessageManager.Instance.AddEventListener(
        "Unity:Ready",
        (data) => Debug.Log("Unity ready!")
    );
}

void HandleFlutterCommand(string data)
{
    Debug.Log($"Command from Flutter: {data}");
}

void OnDestroy()
{
    // Unregister listener
    UnityMessageManager.Instance.RemoveEventListener(
        "Flutter:Command",
        HandleFlutterCommand
    );
}
```

#### Trigger Events
```csharp
// Trigger event to all listeners
UnityMessageManager.Instance.TriggerEvent(
    "Game:LevelComplete",
    "{\"level\":1,\"score\":1000}"
);
```

## 3. MessageHandler - Type-Safe Handling

### Purpose
Type-safe message handling with automatic deserialization and validation.

### Key Features
- Generic type handlers
- Automatic JSON deserialization
- Message queuing and throttling
- Built-in message types
- Request-response with types

### Usage Examples

#### Register Type-Safe Handlers
```csharp
using Xraph.GameFramework.Unity;

public class GameManager : MonoBehaviour
{
    private MessageHandler messageHandler;
    
    void Start()
    {
        messageHandler = gameObject.AddComponent<MessageHandler>();
        messageHandler.enableDebugLogging = true;
        
        // Register typed handlers
        messageHandler.RegisterHandler<PlayerAction>("PlayerAction", HandlePlayerAction);
        messageHandler.RegisterHandler<GameConfig>("Config", HandleConfig);
        messageHandler.RegisterHandler<string>("SimpleMessage", HandleSimpleMessage);
    }
    
    void HandlePlayerAction(PlayerAction action)
    {
        Debug.Log($"Player action: {action.type} at {action.position}");
        
        // Respond with typed object
        var response = new ActionResponse
        {
            success = true,
            result = $"Action '{action.type}' executed"
        };
        messageHandler.SendMessage("Flutter", "onActionResponse", response);
    }
    
    void HandleConfig(GameConfig config)
    {
        QualitySettings.SetQualityLevel(config.quality);
        AudioListener.volume = config.volume;
    }
    
    void HandleSimpleMessage(string message)
    {
        Debug.Log($"Message: {message}");
    }
}

[Serializable]
public class PlayerAction
{
    public string type;
    public Vector3 position;
    public float timestamp;
}

[Serializable]
public class GameConfig
{
    public int quality;
    public float volume;
}

[Serializable]
public class ActionResponse
{
    public bool success;
    public string result;
}
```

#### Send Typed Messages
```csharp
// Send typed message
var gameState = new GameState
{
    score = 1000,
    level = 5,
    health = 75.0f
};

messageHandler.SendMessage("Flutter", "onGameState", gameState);
```

#### Request-Response with Types
```csharp
var request = new DataRequest
{
    requestId = Guid.NewGuid().ToString(),
    dataType = "playerStats"
};

messageHandler.SendMessageWithResponse<DataRequest, DataResponse>(
    "Flutter",
    "requestData",
    request,
    (response) =>
    {
        if (response.success)
        {
            Debug.Log($"Data: {response.data}");
        }
        else
        {
            Debug.LogError($"Error: {response.error}");
        }
    }
);
```

#### Built-In Message Types
```csharp
// Game state message
var gameState = new MessageHandler.GameStateMessage
{
    isPlaying = true,
    isPaused = false,
    score = 100,
    level = 1,
    health = 100.0f
};

// Event message
var eventMsg = new MessageHandler.EventMessage
{
    eventType = "achievement",
    eventName = "first_win",
    timestamp = Time.time,
    data = "{\"achievementId\":\"001\"}"
};

// Response message
var response = new MessageHandler.ResponseMessage
{
    success = true,
    message = "Operation completed",
    data = JsonUtility.ToJson(resultData)
};
```

## Complete Example

See `NativeAPIExample.cs` for a comprehensive example demonstrating all three levels:

```csharp
using Xraph.GameFramework.Unity;
using Xraph.GameFramework.Unity.Examples;

public class MyGame : MonoBehaviour
{
    private MessageHandler messageHandler;
    
    void Start()
    {
        // Level 1: NativeAPI - Initialize and notify ready
        NativeAPI.Initialize();
        NativeAPI.NotifyUnityReady();
        
        // Level 2: UnityMessageManager - Event listeners
        UnityMessageManager.Instance.AddEventListener(
            "Flutter:Command",
            HandleCommand
        );
        
        // Level 3: MessageHandler - Type-safe handling
        messageHandler = gameObject.AddComponent<MessageHandler>();
        messageHandler.RegisterHandler<PlayerAction>(
            "PlayerAction",
            HandlePlayerAction
        );
    }
    
    void HandleCommand(string data)
    {
        // Process command
    }
    
    void HandlePlayerAction(PlayerAction action)
    {
        // Handle player action
    }
    
    void SendGameState()
    {
        // Send to Flutter
        var state = new GameState { score = 100 };
        messageHandler.SendMessage("Flutter", "onGameState", state);
    }
}
```

## Integration with Flutter

### From Flutter to Unity

```dart
// Send message to Unity
await controller.sendMessage(
  target: 'GameManager',
  method: 'StartGame',
  data: '{"level": 1}',
);
```

### From Unity to Flutter

```dart
// Listen for Unity messages
controller.onMessage.listen((message) {
  print('Target: ${message.target}');
  print('Method: ${message.method}');
  print('Data: ${message.data}');
});
```

## Best Practices

### 1. Choose the Right Level
- **NativeAPI**: Low-level control, platform-specific features
- **UnityMessageManager**: Callbacks, event system, general messaging
- **MessageHandler**: Type-safe business logic, complex data structures

### 2. Initialize Once
```csharp
void Awake()
{
    if (FindObjectsOfType<MyManager>().Length > 1)
    {
        Destroy(gameObject);
        return;
    }
    
    DontDestroyOnLoad(gameObject);
    NativeAPI.Initialize();
}
```

### 3. Clean Up Resources
```csharp
void OnDestroy()
{
    // Unsubscribe from events
    NativeAPI.OnMessageReceived -= HandleMessage;
    UnityMessageManager.Instance.RemoveEventListener("Event", Handler);
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
    Debug.LogError($"Failed to send message: {e.Message}");
    // Send error to Flutter
    NativeAPI.SendMessageToFlutter(
        "Unity",
        "onError",
        $"{{\"error\":\"{e.Message}\"}}"
    );
}
```

### 5. Threading
All three systems handle threading automatically:
- NativeAPI: Platform-specific threading
- UnityMessageManager: Queues actions for main thread
- MessageHandler: Processes queue on main thread

## Performance Considerations

1. **Message Size**: Keep messages small, use references instead of embedding large data
2. **Frequency**: Batch updates when possible (e.g., game state every 100ms, not every frame)
3. **Serialization**: Cache serialized data if sending repeatedly
4. **Callbacks**: Clean up callbacks when no longer needed

## Troubleshooting

### Messages Not Received
1. Check NativeAPI is initialized: `NativeAPI.Initialize()`
2. Verify Unity is ready: `NativeAPI.IsReady()`
3. Check event subscriptions are active
4. Enable debug logging: `messageHandler.enableDebugLogging = true`

### Platform-Specific Issues

#### iOS
- Ensure `SetFlutterBridgeController` is called from Swift
- Check FlutterBridge.mm is included in build

#### Android
- Verify Activity is available
- Check UnityEngineController is accessible
- Ensure proper lifecycle management

## References

- [Unity as a Library Documentation](https://docs.unity3d.com/Manual/UnityasaLibrary.html)
- [flutter-unity-view-widget](https://github.com/juicycleff/flutter-unity-view-widget)
- Game Framework Documentation

