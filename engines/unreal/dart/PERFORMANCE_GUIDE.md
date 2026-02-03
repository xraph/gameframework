# Unreal Engine Performance Guide

This guide covers performance optimization techniques for Flutter-Unreal integration.

## Message Optimization

### Message Batching

When sending many messages per frame (e.g., position updates), use batching to reduce overhead:

```dart
// Create a batcher
final batcher = UnrealMessageBatcher(
  onFlush: (batch) async {
    // Send batch as JSON array
    await controller.sendJsonMessage('GameManager', 'batchUpdate', batch);
  },
);

// Configure for 60 FPS
batcher.configure(
  maxBatchSize: 100,      // Max messages before flush
  flushIntervalMs: 16,    // ~60 FPS flush rate
  enableCoalescing: true, // Combine duplicate target+method
);

// In your update loop
void onUpdate(GameState state) {
  batcher.queue('Player', 'position', jsonEncode(state.position));
  batcher.queue('Player', 'rotation', jsonEncode(state.rotation));
  // Messages are batched and sent efficiently
}
```

### Message Throttling

For high-frequency events, throttle to prevent flooding:

```dart
final throttler = UnrealMessageThrottler();

// Limit position updates to 30/second
throttler.setRateLimit('Player', 'updatePosition', 30,
  strategy: ThrottleStrategy.keepLatest);

// Limit network sync to 10/second
throttler.setRateLimit('Network', 'sync', 10,
  strategy: ThrottleStrategy.queue);

// Use throttled send
void onMouseMove(Offset position) {
  throttler.send(controller, 'Input', 'mouseMove', 
    '{"x": ${position.dx}, "y": ${position.dy}}');
}
```

### Delta Compression

For state synchronization, only send changes:

```dart
final compressor = UnrealDeltaCompressor();

// Full state (e.g., 50+ properties)
final gameState = {
  'player': {
    'x': 100, 'y': 200, 'z': 0,
    'health': 100, 'mana': 50,
    'inventory': [...],
  },
  'enemies': [...],
  'world': {...},
};

// Record baseline
compressor.recordState('game', gameState);

// After changes, compute delta
final newState = {...gameState};
newState['player']['x'] = 110; // Only position changed

final delta = compressor.computeDeltaFromHistory('game', newState);
// delta.delta = {'player': {'x': 110}}  // Much smaller!

if (delta.hasChanges) {
  controller.sendJsonMessage('GameSync', 'update', delta.delta);
}
```

## Binary Data Optimization

### Compression

For large binary data, use compression:

```dart
// Automatic compression for large messages
await controller.sendCompressedMessage(
  'AssetLoader',
  'loadTexture',
  largeTextureData,
);

// Manual compression control
final protocol = controller.binaryProtocol;
final compressed = protocol.compressGzip(data);
print('Compression ratio: ${compressed.length / data.length}');
```

### Chunked Transfers

For very large data (>64KB), use chunking:

```dart
// Automatic chunking
await controller.sendChunkedBinaryMessage(
  'AssetLoader',
  'loadModel',
  modelData,
  chunkSize: 32 * 1024, // 32KB chunks
);

// Monitor progress
controller.binaryProgressStream.listen((progress) {
  if (progress.direction == BinaryTransferDirection.outgoing) {
    updateProgressUI(progress.progress);
  }
});
```

## Asset Loading Optimization

### Preloading

Preload assets during loading screens:

```dart
final assetManager = UnrealAssetManager();

// Show loading screen
showLoadingScreen();

// Preload all needed assets
final assets = [
  '/Game/Maps/Level1',
  '/Game/Characters/Player',
  '/Game/Weapons/Sword',
  '/Game/Audio/BGM',
];

assetManager.startBatchLoad(assets);

// Update loading progress
Timer.periodic(Duration(milliseconds: 100), (timer) {
  updateLoadingProgress(assetManager.batchProgress);
  
  if (assetManager.isBatchComplete) {
    timer.cancel();
    hideLoadingScreen();
    startGame();
  }
});
```

### Cache Management

Configure cache for your use case:

```dart
// Set cache size based on device memory
final deviceMemory = await getDeviceMemory();
final cacheSize = deviceMemory > 4096 
  ? 512 * 1024 * 1024   // 512MB for high-end
  : 128 * 1024 * 1024;  // 128MB for low-end

assetManager.setCacheMaxSize(cacheSize);

// Monitor cache usage
final stats = assetManager.statistics;
print('Cache usage: ${stats.currentMemoryUsage / (1024*1024)} MB');
print('Hit rate: ${(stats.cacheHitRate * 100).toInt()}%');

// Clear cache when memory is low
if (memoryPressure > 0.8) {
  assetManager.clearCache();
}
```

## Quality Settings

### Dynamic Quality Adjustment

Adjust quality based on performance:

```dart
final qualityManager = QualityManager(controller);

// Monitor FPS and adjust
void onFrame(double fps) {
  if (fps < 25) {
    qualityManager.decreaseQuality();
  } else if (fps > 55) {
    qualityManager.increaseQuality();
  }
}

class QualityManager {
  int currentLevel = 3; // Start at high
  
  void decreaseQuality() {
    if (currentLevel > 0) {
      currentLevel--;
      applyLevel(currentLevel);
    }
  }
  
  void increaseQuality() {
    if (currentLevel < 4) {
      currentLevel++;
      applyLevel(currentLevel);
    }
  }
  
  void applyLevel(int level) {
    final presets = [
      UnrealQualitySettings.low(),
      UnrealQualitySettings.medium(),
      UnrealQualitySettings.high(),
      UnrealQualitySettings.epic(),
      UnrealQualitySettings.cinematic(),
    ];
    controller.applyQualitySettings(presets[level]);
  }
}
```

### Resolution Scaling

Adjust resolution for performance:

```dart
// Lower resolution for better performance
await controller.applyQualitySettings(
  UnrealQualitySettings(
    resolutionScale: 0.75, // 75% resolution
    targetFrameRate: 60,
  ),
);

// Or use console command
await controller.executeConsoleCommand('r.ScreenPercentage 75');
```

## Memory Management

### Cleanup Unused Resources

```dart
// Unload assets when leaving a level
void onLevelUnload(String levelName) {
  final levelAssets = assetRegistry[levelName];
  for (final asset in levelAssets) {
    assetManager.unloadAsset(asset);
  }
}

// Force garbage collection (Unreal side)
await controller.executeConsoleCommand('obj gc');
```

### Monitoring Memory

```dart
// Get memory stats
await controller.executeConsoleCommand('stat memory');
await controller.executeConsoleCommand('memreport -full');

// Dart-side monitoring
final stats = assetManager.statistics;
print('Asset memory: ${stats.currentMemoryUsage}');
```

## Profiling

### FPS Monitoring

```dart
// Enable FPS counter
await controller.executeConsoleCommand('stat fps');

// Get detailed frame stats
await controller.executeConsoleCommand('stat unit');
await controller.executeConsoleCommand('stat unitgraph');
```

### GPU Profiling

```dart
// GPU stats
await controller.executeConsoleCommand('stat gpu');
await controller.executeConsoleCommand('profilegpu');

// Shader complexity
await controller.executeConsoleCommand('viewmode shadercomplexity');
```

### Message Statistics

```dart
// Batcher stats
final batchStats = batcher.statistics;
print('Messages queued: ${batchStats.totalMessagesQueued}');
print('Batches flushed: ${batchStats.totalBatchesFlushed}');
print('Coalesced: ${batchStats.totalMessagesCoalesced}');

// Throttler stats
final throttleStats = throttler.statistics;
print('Messages dropped: ${throttleStats.messagesDropped}');
print('Messages queued: ${throttleStats.messagesQueued}');

// Delta compression stats
final deltaStats = compressor.statistics;
print('Compression ratio: ${deltaStats.averageCompressionRatio}');
```

## Best Practices

### 1. Batch Related Messages

```dart
// BAD: Individual messages
controller.sendMessage('Player', 'setX', '100');
controller.sendMessage('Player', 'setY', '200');
controller.sendMessage('Player', 'setZ', '0');

// GOOD: Single batched message
controller.sendJsonMessage('Player', 'setPosition', {
  'x': 100, 'y': 200, 'z': 0
});
```

### 2. Use Appropriate Strategies

```dart
// Input events: Keep latest value
throttler.setRateLimit('Input', 'cursor', 60,
  strategy: ThrottleStrategy.keepLatest);

// Critical events: Queue them
throttler.setRateLimit('Game', 'playerDeath', 5,
  strategy: ThrottleStrategy.queue);

// Non-critical: Drop if rate exceeded
throttler.setRateLimit('Debug', 'log', 10,
  strategy: ThrottleStrategy.drop);
```

### 3. Clean Up Resources

```dart
@override
void dispose() {
  batcher.dispose();
  throttler.dispose();
  compressor.dispose();
  assetManager.dispose();
  super.dispose();
}
```

### 4. Profile Before Optimizing

```dart
// Measure first
final startTime = DateTime.now();
await heavyOperation();
final elapsed = DateTime.now().difference(startTime);
print('Operation took: ${elapsed.inMilliseconds}ms');

// Then optimize if needed
```

## Platform-Specific Tips

### Android

- Use `VirtualDisplay` mode for better memory on older devices
- Lower quality settings on devices with < 4GB RAM
- Monitor thermal throttling with device sensors

### iOS

- Use Metal-optimized quality settings
- Enable `enableVSync: false` for lower latency
- Monitor memory pressure notifications

### Desktop

- Can use higher quality settings
- Enable ray tracing features if available
- Use larger cache sizes

## Troubleshooting Performance Issues

### Low FPS

1. Check quality settings
2. Monitor GPU load with `stat gpu`
3. Check for heavy Blueprint scripts
4. Verify message rate isn't too high

### Memory Leaks

1. Monitor asset cache size
2. Ensure proper cleanup on level change
3. Check for circular references in state

### Message Lag

1. Enable batching
2. Add throttling for high-frequency messages
3. Use delta compression for state sync
