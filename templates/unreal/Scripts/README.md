# Unreal Engine Flutter Integration Templates

This directory contains ready-to-use C++ classes and Blueprints for integrating Unreal Engine with Flutter.

## Quick Start

1. Copy the template files to your Unreal project's Source folder
2. Add the FlutterPlugin module to your project's Build.cs
3. Create subclasses or use directly in Blueprints

## Template Files

### FlutterActor.h/.cpp

Base class for any Actor that needs to communicate with Flutter.

**Features:**
- Auto-registration with Flutter message router
- Convenient SendToFlutter() methods
- Overridable message handlers
- Singleton support

**Usage:**
```cpp
UCLASS()
class AMyGameActor : public AFlutterActor
{
    GENERATED_BODY()

protected:
    virtual FString GetFlutterTargetName() const override 
    { 
        return TEXT("MyGameActor"); 
    }

    virtual void HandleFlutterMessage_Implementation(
        const FString& Method, 
        const FString& Data) override
    {
        if (Method == TEXT("doSomething"))
        {
            // Handle the message
            DoSomething();
            
            // Send response
            SendToFlutter(TEXT("somethingDone"), TEXT("{\"success\": true}"));
        }
    }
};
```

### FlutterGameMode.h/.cpp

Full-featured GameMode with Flutter integration for game state management.

**Features:**
- Game lifecycle (start, pause, resume, stop, game over)
- Score tracking and updates
- Level management
- Automatic state synchronization
- Blueprint events for all state changes

**Usage (Blueprint):**
1. Create a Blueprint subclass of FlutterGameMode
2. Set it as your project's default GameMode
3. Use the provided functions:
   - `StartGame()` - Begin the game
   - `PauseGame()` / `ResumeGame()` - Control game state
   - `AddScore(Points)` - Update score
   - `NextLevel()` - Advance level
   - `GameOver(Reason)` - End the game

**Usage (C++):**
```cpp
// Get the GameMode
AFlutterGameMode* GameMode = Cast<AFlutterGameMode>(GetWorld()->GetAuthGameMode());
if (GameMode)
{
    GameMode->AddScore(100);
    GameMode->SendGameEvent(TEXT("powerUp"), TEXT("{\"type\": \"speed\"}"));
}
```

## Flutter Side Integration

### Receiving Messages from Unreal

```dart
// Listen for messages from Unreal
controller.messageStream.listen((message) {
  final metadata = message.metadata;
  final target = metadata['target'] as String?;
  final method = metadata['method'] as String?;
  
  if (target == 'GameMode') {
    switch (method) {
      case 'scoreChanged':
        final data = jsonDecode(message.data);
        updateScore(data['score']);
        break;
      case 'gameOver':
        final data = jsonDecode(message.data);
        showGameOverScreen(data['reason']);
        break;
    }
  }
});
```

### Sending Messages to Unreal

```dart
// Send player action
await controller.sendJsonMessage('GameMode', 'playerAction', {
  'action': 'jump',
  'data': '{}',
});

// Request current game state
await controller.sendMessage('GameMode', 'requestState', '{}');
```

## Message Protocol

### Standard Messages

All messages follow this format:
- **Target**: The registered target name (e.g., "GameMode", "Player")
- **Method**: The action to perform (e.g., "playerAction", "scoreChanged")
- **Data**: JSON string with parameters

### Game State Messages (from Unreal)

| Method | Data | Description |
|--------|------|-------------|
| gameStarted | {} | Game has started |
| gamePaused | {} | Game is paused |
| gameResumed | {} | Game resumed |
| gameStopped | {} | Game stopped |
| gameOver | {reason, finalScore, finalLevel} | Game over |
| scoreChanged | {score, delta} | Score updated |
| levelChanged | {level} | Level changed |
| stateSync | {isRunning, isPaused, score, level} | Full state sync |

### Player Actions (to Unreal)

| Method | Data | Description |
|--------|------|-------------|
| playerAction | {action, data} | Player performed action |
| requestState | {} | Request state sync |
| setLevel | {level} | Set current level |

## Blueprint Setup

### Creating a Flutter-Enabled GameMode

1. Create new Blueprint Class based on FlutterGameMode
2. Configure settings:
   - **Flutter Target Name**: Name to register with (default: "GameMode")
   - **Auto Sync State**: Enable periodic state sync
   - **State Sync Interval**: Seconds between syncs
3. Override events as needed:
   - **OnGameStarted** - Called when game starts
   - **OnScoreChanged** - Called when score updates
   - **OnPlayerAction** - Handle player input from Flutter

### Creating a Flutter-Enabled Actor

1. Create new Blueprint Class based on FlutterActor
2. Override `Get Flutter Target Name` to return your target name
3. Override `Handle Flutter Message` to process incoming messages
4. Use `Send To Flutter` to send responses

## Best Practices

1. **Use JSON for complex data**: Always send structured data as JSON strings
2. **Keep messages small**: Send only changed data, use delta compression for large states
3. **Handle missing data gracefully**: Check for null/missing fields in JSON
4. **Use meaningful target names**: Make them descriptive and unique
5. **Register early**: Targets should register in BeginPlay
6. **Unregister on destroy**: Clean up in EndPlay to avoid memory leaks

## Troubleshooting

### Messages not received

1. Check that FlutterBridge is in the level
2. Verify target name matches between Unreal and Flutter
3. Check the message router is initialized
4. Look for registration errors in the output log

### Score not updating

1. Verify the GameMode is correctly set
2. Check that the Flutter listener is subscribed to messageStream
3. Ensure JSON parsing handles the correct field names

### Performance issues

1. Reduce state sync frequency if not needed
2. Use binary messaging for large data transfers
3. Consider message batching for high-frequency updates

## Example Project Structure

```
Source/
  MyGame/
    MyGame.Build.cs
    MyGameMode.h          # Subclass of FlutterGameMode
    MyGameMode.cpp
    Player/
      MyPlayerActor.h     # Subclass of FlutterActor
      MyPlayerActor.cpp
    UI/
      ScoreActor.h
      ScoreActor.cpp
```

## License

These templates are part of the GameFramework and are provided under the same license.
