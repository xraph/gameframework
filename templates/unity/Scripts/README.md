# Game Framework Unity Templates

This directory contains example scripts demonstrating all features of the Flutter Game Framework Unity integration.

## Quick Start

1. Copy these scripts to your Unity project's `Assets/Scripts/` folder
2. Attach the desired scripts to GameObjects in your scene
3. Import the Game Framework Unity plugin scripts

## Scripts Overview

### GameManager.cs
Basic game manager demonstrating the core `FlutterMonoBehaviour` pattern.

**Features:**
- Inheriting from `FlutterMonoBehaviour`
- Using `[FlutterMethod]` attribute for message routing
- Sending typed messages to Flutter
- Game lifecycle management (start, pause, resume, stop)

**Flutter Usage:**
```dart
// Start game
await controller.sendJsonMessage('GameManager', 'startGame', {
  'level': 1,
  'difficulty': 'normal',
});

// Listen for events
controller.messageStream.listen((msg) {
  if (msg.method == 'onGameStarted') {
    // Game started
  }
});
```

### GameFrameworkDemo.cs
Comprehensive demo orchestrator testing all framework features.

**Features:**
- Complete feature demonstration
- Performance monitoring
- Binary data handling
- Scene management integration

### MessagingExample.cs
Demonstrates various messaging patterns.

**Features:**
- String messaging
- JSON/typed messaging with automatic deserialization
- Request-response pattern
- Event broadcasting

**Flutter Usage:**
```dart
// String message
await controller.sendMessage('Messaging', 'sendString', 'Hello Unity!');

// Typed message
await controller.sendJsonMessage('Messaging', 'sendTyped', {
  'action': 'greet',
  'value': 42,
  'enabled': true,
});

// Request-response
await controller.sendJsonMessage('Messaging', 'request', {
  'requestId': '123',
  'operation': 'add',
  'parameters': ['5', '3'],
});
```

### BinaryDataExample.cs
Demonstrates binary data transfer.

**Features:**
- Receiving binary data (images, files)
- Sending binary data to Flutter
- Screenshot capture
- Chunked transfer for large files
- Compression support

**Flutter Usage:**
```dart
// Send binary data
final bytes = await File('image.png').readAsBytes();
await controller.sendBinaryMessage('BinaryData', 'receiveImage', bytes);

// Request screenshot
await controller.sendJsonMessage('BinaryData', 'requestScreenshot', {});

// Listen for binary response
controller.messageStream.listen((msg) {
  if (msg.method == 'onScreenshot') {
    final data = jsonDecode(msg.data);
    final bytes = base64Decode(data['data']);
    // Save or display screenshot
  }
});
```

### StateManager.cs
Demonstrates state synchronization patterns.

**Features:**
- Full state synchronization
- Delta compression (only changed fields)
- Periodic state broadcasting
- State versioning
- Property-level updates

**Flutter Usage:**
```dart
// Subscribe to state updates with delta compression
await controller.sendJsonMessage('StateManager', 'subscribe', {
  'deltaOnly': true,
  'intervalMs': 100, // 10 updates per second
});

// Update state
await controller.sendJsonMessage('StateManager', 'setProperty', {
  'property': 'playerHealth',
  'value': '75',
});

// Listen for state changes
controller.messageStream.listen((msg) {
  if (msg.method == 'onStateDelta') {
    final delta = jsonDecode(msg.data)['delta'];
    // Apply only changed fields
  }
});
```

### SceneController.cs
Demonstrates scene management.

**Features:**
- Load/unload scenes
- Async loading with progress
- Scene events
- Multi-scene management

**Flutter Usage:**
```dart
// Load scene with progress
await controller.sendJsonMessage('SceneController', 'loadSceneAsync', {
  'sceneName': 'GameScene',
  'showProgress': true,
});

// Listen for progress
controller.messageStream.listen((msg) {
  if (msg.method == 'onSceneProgress') {
    final progress = jsonDecode(msg.data)['progress'];
    print('Loading: ${(progress * 100).toInt()}%');
  }
});
```

### HighFrequencyDemo.cs
Performance testing and high-frequency messaging.

**Features:**
- Stress testing throughput
- Latency measurement
- Batching effectiveness
- Throttling demonstration

**Flutter Usage:**
```dart
// Start performance test
await controller.sendJsonMessage('HighFrequency', 'startTest', {
  'messagesPerSecond': 1000,
  'durationSeconds': 10,
  'useBatching': true,
  'enableStreaming': true,
});

// Listen for results
controller.messageStream.listen((msg) {
  if (msg.method == 'onTestComplete') {
    final results = jsonDecode(msg.data);
    print('Throughput: ${results['actualMessagesPerSecond']} msg/s');
    print('Avg Latency: ${results['averageLatencyMs']} ms');
    print('P99 Latency: ${results['latencyP99']} ms');
  }
});
```

## Key Concepts

### FlutterMonoBehaviour Base Class

All communication scripts should inherit from `FlutterMonoBehaviour`:

```csharp
public class MyScript : FlutterMonoBehaviour
{
    // Target name for message routing
    protected override string TargetName => "MyScript";
    
    // Optional: singleton mode
    protected override bool IsSingleton => true;
    
    // Handle messages from Flutter
    [FlutterMethod("doSomething")]
    public void HandleDoSomething(MyData data)
    {
        // data is auto-deserialized from JSON
    }
    
    // Send messages to Flutter
    public void NotifyFlutter()
    {
        SendToFlutter("onEvent", new { status = "ok" });
    }
}
```

### FlutterMethod Attribute Options

```csharp
// Basic method
[FlutterMethod("methodName")]

// Binary data handler
[FlutterMethod("loadAsset", AcceptsBinary = true)]

// Throttled method (60 calls per second max)
[FlutterMethod("position", Throttle = 60)]

// Throttle with strategy
[FlutterMethod("input", Throttle = 120, ThrottleStrategy = ThrottleStrategy.KeepLatest)]

// High priority
[FlutterMethod("critical", Priority = MessagePriority.Critical)]
```

### Performance Features

Enable high-performance features in your script:

```csharp
protected override void Awake()
{
    base.Awake();
    
    // Enable message batching
    EnableBatching = true;
    
    // Enable delta compression
    EnableDeltaCompression = true;
    
    // Debug logging
    EnableDebugLogging = true;
}

// Use batched sending for high-frequency updates
void Update()
{
    SendToFlutterBatched("position", new PositionData { ... });
}
```

## Flutter Side Setup

```dart
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

// Initialize
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UnityEnginePlugin.initialize();
  runApp(MyApp());
}

// Use in widget
GameWidget(
  engineType: GameEngineType.unity,
  onEngineCreated: (controller) {
    // Setup message handling
    controller.messageStream.listen((msg) {
      print('Received: ${msg.target}:${msg.method}');
    });
    
    // For high-frequency messaging
    final batcher = controller.createBatcher(
      maxBatchSize: 50,
      flushIntervalMs: 16,
    );
    
    // Queue batched messages
    batcher.queue('Player', 'position', {'x': 1.0, 'y': 2.0});
  },
)
```

## Performance Tips

1. **Use batching** for high-frequency updates (position, input)
2. **Enable delta compression** for state synchronization
3. **Set appropriate throttle rates** to prevent overwhelming the channel
4. **Use binary format** for large data (images, files)
5. **Monitor with HighFrequencyDemo** to test your messaging patterns

## License

MIT License - See main project LICENSE file.
