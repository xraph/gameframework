# Unity Plugin Package for Flutter Game Framework

This Unity package provides the C# scripts and native plugins needed to integrate Unity with the Flutter Game Framework.

## Contents

```
plugin/
├── Scripts/
│   ├── NativeAPI.cs               # Low-level platform bridge (NEW)
│   ├── UnityMessageManager.cs     # Message router with callbacks (NEW)
│   ├── MessageHandler.cs          # Type-safe message handling (NEW)
│   ├── FlutterBridge.cs           # Core bridge (backward compatible)
│   ├── FlutterSceneManager.cs     # Scene management integration
│   ├── FlutterGameManager.cs      # Example game manager
│   ├── FlutterUtilities.cs        # Helper utilities
│   ├── FlutterPerformanceMonitor.cs # Performance monitoring
│   └── Examples/
│       └── NativeAPIExample.cs    # Complete communication example
├── Plugins/
│   └── iOS/
│       └── FlutterBridge.mm       # iOS native bridge (enhanced)
├── NATIVE_API_GUIDE.md            # Complete communication guide
└── README.md                       # This file
```

### New Communication APIs

The plugin now includes three levels of Unity-Flutter communication based on the [flutter-unity-view-widget](https://github.com/juicycleff/flutter-unity-view-widget) pattern:

1. **NativeAPI.cs** - Low-level platform bridge (iOS/Android)
2. **UnityMessageManager.cs** - High-level message routing with callbacks
3. **MessageHandler.cs** - Type-safe message handling with generics

**See [NATIVE_API_GUIDE.md](NATIVE_API_GUIDE.md) for comprehensive documentation.**

---

## Installation

### Option 1: Manual Installation

1. Copy the entire `plugin` folder to your Unity project's `Assets/` directory
2. The scripts will be automatically compiled by Unity

### Option 2: Unity Package (Coming Soon)

1. Import the `.unitypackage` file via Unity menu:
   `Assets > Import Package > Custom Package...`

---

## Setup

### 1. Add FlutterBridge to Your Scene

1. Create an empty GameObject in your startup scene
2. Name it `FlutterBridge`
3. Add the `FlutterBridge` component to it
4. The component will persist across scenes automatically

### 2. (Optional) Add FlutterSceneManager

1. Create an empty GameObject in your startup scene
2. Name it `FlutterSceneManager`
3. Add the `FlutterSceneManager` component to it
4. Configure the settings in the Inspector:
   - ✓ Notify On Scene Load
   - ✓ Notify On Scene Unload

### 3. (Optional) Add FlutterGameManager

1. Create an empty GameObject in your scene
2. Name it `GameManager`
3. Add the `FlutterGameManager` component to it
4. Configure the settings:
   - ✓ Send Game State Updates
   - Update Interval: 1.0 (seconds)

---

## Quick Start (New NativeAPI)

### Modern Approach (Recommended)

```csharp
using Xraph.GameFramework.Unity;

public class GameBootstrap : MonoBehaviour
{
    private MessageHandler messageHandler;
    
    void Start()
    {
        // 1. Initialize NativeAPI
        NativeAPI.Initialize();
        
        // 2. Setup message handler
        messageHandler = gameObject.AddComponent<MessageHandler>();
        messageHandler.RegisterHandler<PlayerAction>("PlayerAction", HandleAction);
        
        // 3. Notify Flutter when ready
        NativeAPI.NotifyUnityReady();
    }
    
    void HandleAction(PlayerAction action)
    {
        Debug.Log($"Action: {action.type}");
        
        // Send response
        var response = new ActionResponse { success = true };
        messageHandler.SendMessage("Flutter", "onActionResponse", response);
    }
}

[System.Serializable]
public class PlayerAction { public string type; public float x, y, z; }

[System.Serializable]
public class ActionResponse { public bool success; public string result; }
```

**See [NATIVE_API_GUIDE.md](NATIVE_API_GUIDE.md) for complete documentation.**

---

## Usage (Classic FlutterBridge)

The classic FlutterBridge API is still fully supported for backward compatibility.

### Receiving Messages from Flutter

#### Using Events

```csharp
using Xraph.GameFramework.Unity;

public class MyGameScript : MonoBehaviour
{
    void OnEnable()
    {
        // Subscribe to all Flutter messages
        FlutterBridge.OnFlutterMessage += HandleFlutterMessage;
    }

    void OnDisable()
    {
        FlutterBridge.OnFlutterMessage -= HandleFlutterMessage;
    }

    private void HandleFlutterMessage(string target, string method, string data)
    {
        if (target == "MyGameObject")
        {
            switch (method)
            {
                case "StartLevel":
                    StartLevel(data);
                    break;
                case "UpdateSettings":
                    UpdateSettings(data);
                    break;
            }
        }
    }

    private void StartLevel(string levelData)
    {
        Debug.Log($"Starting level: {levelData}");
        // Your level start logic
    }
}
```

#### Using Unity Messages (Automatic Routing)

```csharp
using UnityEngine;

public class PlayerController : MonoBehaviour
{
    // This method will be called when Flutter sends a message
    // to GameObject named "Player" with method "Jump"
    public void Jump(string data)
    {
        Debug.Log($"Jump triggered from Flutter: {data}");
        // Your jump logic
    }

    // Flutter sends to "Player" -> "SetSpeed" -> this method is called
    public void SetSpeed(string speedData)
    {
        float speed = float.Parse(speedData);
        // Update player speed
    }
}
```

From Flutter:
```dart
controller.sendMessage('Player', 'Jump', '10.5');
controller.sendMessage('Player', 'SetSpeed', '5.0');
```

### Sending Messages to Flutter

#### Simple String Messages

```csharp
using Xraph.GameFramework.Unity;

public class MyGameScript : MonoBehaviour
{
    void Start()
    {
        // Send a simple message
        FlutterBridge.Instance.SendToFlutter(
            "GameManager",
            "onGameReady",
            "true"
        );
    }

    void OnPlayerScored(int score)
    {
        // Send score to Flutter
        FlutterBridge.Instance.SendToFlutter(
            "GameManager",
            "onScore",
            score.ToString()
        );
    }
}
```

#### JSON Messages

```csharp
using Xraph.GameFramework.Unity;

[System.Serializable]
public class PlayerData
{
    public string playerName;
    public int level;
    public float health;
    public int[] inventory;
}

public class MyGameScript : MonoBehaviour
{
    void SendPlayerData()
    {
        var playerData = new PlayerData
        {
            playerName = "Hero",
            level = 5,
            health = 85.5f,
            inventory = new int[] { 1, 2, 3 }
        };

        // Automatically serializes to JSON
        FlutterBridge.Instance.SendToFlutter(
            "GameManager",
            "onPlayerUpdate",
            playerData
        );
    }
}
```

#### Error Messages

```csharp
void OnError(string errorMessage)
{
    FlutterBridge.Instance.SendError(errorMessage);
}
```

### Scene Management

```csharp
using Xraph.GameFramework.Unity;

public class LevelManager : MonoBehaviour
{
    void LoadNextLevel()
    {
        // Scene load will automatically notify Flutter
        // via FlutterSceneManager
        SceneManager.LoadScene("Level2");
    }

    // Or manually notify
    void OnLevelComplete()
    {
        FlutterBridge.Instance.NotifySceneLoaded("Level2", 2);
    }
}
```

---

## API Reference

### FlutterBridge

The main bridge component for Unity-Flutter communication.

#### Static Properties

- `Instance` - Singleton instance of FlutterBridge
- `OnFlutterMessage` - Event triggered when receiving messages from Flutter

#### Methods

- `SendToFlutter(string target, string method, string data)` - Send string message to Flutter
- `SendToFlutter<T>(string target, string method, T data)` - Send JSON message to Flutter
- `SendError(string errorMessage)` - Send error message to Flutter
- `NotifySceneLoaded(string sceneName, int buildIndex)` - Notify Flutter of scene load

#### Receiving Messages (from Flutter)

The `ReceiveMessage(string message)` method is called automatically via Unity's `UnitySendMessage`.
You don't need to call this method directly.

### FlutterSceneManager

Manages scene events and notifications.

#### Inspector Properties

- `notifyOnSceneLoad` - Automatically notify Flutter on scene load
- `notifyOnSceneUnload` - Automatically notify Flutter on scene unload

#### Methods (Can be called from Flutter)

- `LoadScene(string sceneName)` - Load scene by name
- `LoadSceneByIndex(string indexStr)` - Load scene by index
- `LoadSceneAsync(string sceneName)` - Load scene asynchronously with progress updates

### FlutterGameManager

Example game manager showing Flutter integration patterns.

#### Inspector Properties

- `sendGameStateUpdates` - Send periodic game state updates to Flutter
- `updateInterval` - Update interval in seconds

#### Methods (Can be called from Flutter)

- `StartGame(string levelData)` - Start the game
- `PauseGame()` - Pause the game
- `ResumeGame()` - Resume the game
- `StopGame()` - Stop the game
- `UpdateScore(string scoreData)` - Update score
- `SetLevel(string levelData)` - Set current level
- `GameOver(int finalScore)` - Trigger game over
- `SendCustomEvent(string eventName, string eventData)` - Send custom events

---

## Message Flow

### Flutter → Unity

```
Flutter (Dart)
  ↓ controller.sendMessage('Player', 'Jump', '10')
Platform Channel
  ↓ engine#sendMessage
Native Bridge (Kotlin/Swift)
  ↓ UnityPlayer.UnitySendMessage('FlutterBridge', 'ReceiveMessage', ...)
Unity C#
  ↓ FlutterBridge.ReceiveMessage()
  ↓ OnFlutterMessage event OR GameObject.SendMessage()
Your Game Scripts
```

### Unity → Flutter

```
Your Game Scripts
  ↓ FlutterBridge.Instance.SendToFlutter(...)
Unity C#
  ↓ Platform-specific native call
Native Bridge (Kotlin/Swift)
  ↓ onUnityMessage() → sendEventToFlutter()
Platform Channel
  ↓ Event stream
Flutter (Dart)
  ↓ controller.messageStream
Your Flutter App
```

---

## Platform-Specific Notes

### Android

- Messages are sent via `AndroidJavaObject` calls to the Activity
- The `UnityEngineController.kt` must have a public `onUnityMessage` method
- All Unity operations must run on the main thread

### iOS

- Messages are sent via native Objective-C bridge (`FlutterBridge.mm`)
- The `UnityEngineController.swift` must have a public `onUnityMessage` method
- The Unity framework is loaded dynamically

---

## Examples

### Example 1: Simple Game Start/Stop

**Unity:**
```csharp
public class SimpleGame : MonoBehaviour
{
    void OnEnable()
    {
        FlutterBridge.OnFlutterMessage += HandleMessage;
    }

    void OnDisable()
    {
        FlutterBridge.OnFlutterMessage -= HandleMessage;
    }

    private void HandleMessage(string target, string method, string data)
    {
        if (target != "Game") return;

        if (method == "Start")
        {
            StartGame();
        }
        else if (method == "Stop")
        {
            StopGame();
        }
    }

    private void StartGame()
    {
        Debug.Log("Game started!");
        FlutterBridge.Instance.SendToFlutter("Game", "onStarted", "success");
    }

    private void StopGame()
    {
        Debug.Log("Game stopped!");
        FlutterBridge.Instance.SendToFlutter("Game", "onStopped", "success");
    }
}
```

**Flutter:**
```dart
// Start the game
await controller.sendMessage('Game', 'Start', '');

// Listen for response
controller.messageStream.listen((message) {
  if (message.method == 'onStarted') {
    print('Game started successfully!');
  }
});
```

### Example 2: Real-time Score Updates

**Unity:**
```csharp
public class ScoreManager : MonoBehaviour
{
    private int currentScore = 0;

    public void AddScore(int points)
    {
        currentScore += points;

        // Send update to Flutter
        FlutterBridge.Instance.SendToFlutter(
            "Score",
            "onScoreUpdate",
            currentScore.ToString()
        );
    }
}
```

**Flutter:**
```dart
int gameScore = 0;

controller.messageStream.listen((message) {
  if (message.method == 'onScoreUpdate') {
    setState(() {
      gameScore = int.parse(message.data);
    });
  }
});
```

### Example 3: Complex Data Exchange

**Unity:**
```csharp
[System.Serializable]
public class GameStats
{
    public int level;
    public int score;
    public float playTime;
    public string[] achievements;
}

public void SendStats()
{
    var stats = new GameStats
    {
        level = 5,
        score = 1000,
        playTime = 120.5f,
        achievements = new string[] { "first_win", "speed_run" }
    };

    FlutterBridge.Instance.SendToFlutter("Stats", "onUpdate", stats);
}
```

**Flutter:**
```dart
class GameStats {
  final int level;
  final int score;
  final double playTime;
  final List<String> achievements;

  GameStats.fromJson(Map<String, dynamic> json)
      : level = json['level'],
        score = json['score'],
        playTime = json['playTime'],
        achievements = List<String>.from(json['achievements']);
}

controller.messageStream.listen((message) {
  if (message.method == 'onUpdate') {
    final stats = GameStats.fromJson(message.asJson());
    print('Level: ${stats.level}, Score: ${stats.score}');
  }
});
```

---

## Troubleshooting

### Messages not being received in Unity

1. Ensure `FlutterBridge` GameObject exists in your scene
2. Check that the GameObject name matches the target in your Flutter code
3. Verify the method name matches a public method in your script
4. Check Unity console for error messages

### Messages not being sent to Flutter

1. Verify you're building for Android or iOS (not Editor)
2. Check native logs for bridge initialization
3. Ensure `UnityEngineController` is properly instantiated
4. Verify the platform channel is connected

### Scene notifications not working

1. Ensure `FlutterSceneManager` is in your scene
2. Check that notifications are enabled in the Inspector
3. Verify scene names are correct

---

## Best Practices

1. **Singleton Pattern**: Always use `FlutterBridge.Instance` - don't create multiple instances
2. **Error Handling**: Always wrap Flutter communication in try-catch blocks
3. **JSON Serialization**: Use `[System.Serializable]` for classes you want to send to Flutter
4. **Message Routing**: Use consistent target and method names across Unity and Flutter
5. **Lifecycle**: Subscribe to `OnFlutterMessage` in `OnEnable`, unsubscribe in `OnDisable`
6. **Threading**: All Unity API calls must be on the main thread
7. **Performance**: Avoid sending large messages or too frequent updates

---

## Advanced Topics

### Custom Message Handling

Override `HandleMessage` in FlutterBridge for custom routing:

```csharp
public class CustomFlutterBridge : FlutterBridge
{
    protected override void HandleMessage(string target, string method, string data)
    {
        // Your custom routing logic
        if (target.StartsWith("Custom"))
        {
            // Handle custom targets
        }
        else
        {
            // Fall back to default handling
            base.HandleMessage(target, method, data);
        }
    }
}
```

### Async Operations

```csharp
public class AsyncExample : MonoBehaviour
{
    private async void LoadDataFromFlutter()
    {
        // Request data
        FlutterBridge.Instance.SendToFlutter("Data", "requestPlayerData", "");

        // Wait for response (you'll need to implement the waiting logic)
        // This is just a conceptual example
    }
}
```

---

## License

See LICENSE file in the repository root.

---

## Support

For issues and questions:
- GitHub: https://github.com/xraph/gameframework/issues
- Documentation: See `engines/unity/dart/README.md` for Flutter-side usage
