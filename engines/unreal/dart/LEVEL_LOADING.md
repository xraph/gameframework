# Unreal Engine Level Loading Guide

Complete guide to loading and managing levels/maps in Unreal Engine from Flutter.

## Table of Contents

- [Overview](#overview)
- [Basic Level Loading](#basic-level-loading)
- [Level Loading Events](#level-loading-events)
- [Loading Screens](#loading-screens)
- [Streaming Levels](#streaming-levels)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

Unreal Engine uses "levels" (also called "maps") to organize game content. Each level is a separate world with its own actors, lighting, and geometry.

### Level Types

- **Persistent Level:** The main level that's always loaded
- **Sub-levels:** Additional levels that can be streamed in/out
- **Streaming Levels:** Levels loaded dynamically based on player location

---

## Basic Level Loading

### Load a Level

```dart
// Load a level by name
await controller.loadLevel('MainMenu');
await controller.loadLevel('Level_01');
await controller.loadLevel('Gameplay');

// Load with full path
await controller.loadLevel('/Game/Maps/Arena');
```

### Level Names

Unreal Engine accepts several level name formats:

**Short name:**
```dart
await controller.loadLevel('MainMenu');
```

**Full path:**
```dart
await controller.loadLevel('/Game/Maps/MainMenu');
```

**With extension:**
```dart
await controller.loadLevel('MainMenu.umap');
```

---

## Level Loading Events

### Listen for Level Loads

```dart
// Listen to scene load stream
controller.sceneLoads.listen((scene) {
  print('Level loaded: ${scene.name}');
  print('Build index: ${scene.buildIndex}');
  print('Is loaded: ${scene.isLoaded}');
  print('Is valid: ${scene.isValid}');

  // Handle level-specific logic
  if (scene.name == 'Gameplay') {
    _initializeGameplay();
  } else if (scene.name == 'MainMenu') {
    _initializeMainMenu();
  }
});
```

### Scene Object Properties

```dart
class GameEngineScene {
  final String name;           // Level name
  final int buildIndex;        // Level index (-1 if not set)
  final bool isLoaded;         // Is currently loaded
  final bool isValid;          // Is valid level
  final Map<String, dynamic> metadata;  // Additional data
}
```

---

## Loading Screens

### Simple Loading Screen

```dart
class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  UnrealController? _controller;
  bool _isLoading = false;
  String _loadingLevel = '';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Game view
        GameEngineWidget(
          engineType: GameEngineType.unreal,
          onControllerCreated: _onControllerCreated,
        ),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading $_loadingLevel...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _onControllerCreated(GameEngineController controller) {
    _controller = controller as UnrealController;

    // Listen for level loads
    _controller!.sceneLoads.listen((scene) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _loadLevel(String levelName) async {
    setState(() {
      _isLoading = true;
      _loadingLevel = levelName;
    });

    await _controller?.loadLevel(levelName);
  }
}
```

### Advanced Loading Screen with Progress

```dart
class AdvancedLoadingScreen extends StatefulWidget {
  final String levelName;
  final VoidCallback onComplete;

  AdvancedLoadingScreen({
    required this.levelName,
    required this.onComplete,
  });

  @override
  _AdvancedLoadingScreenState createState() => _AdvancedLoadingScreenState();
}

class _AdvancedLoadingScreenState extends State<AdvancedLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _progress = 0.0;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();

    _simulateProgress();
  }

  Future<void> _simulateProgress() async {
    // Simulate loading progress
    setState(() => _status = 'Loading assets...');
    await Future.delayed(Duration(milliseconds: 500));
    setState(() => _progress = 0.3);

    setState(() => _status = 'Building world...');
    await Future.delayed(Duration(milliseconds: 800));
    setState(() => _progress = 0.6);

    setState(() => _status = 'Initializing...');
    await Future.delayed(Duration(milliseconds: 500));
    setState(() => _progress = 0.9);

    setState(() => _status = 'Ready!');
    await Future.delayed(Duration(milliseconds: 300));
    setState(() => _progress = 1.0);

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            Text(
              widget.levelName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 40),

            // Animated spinner
            RotationTransition(
              turns: _animController,
              child: Icon(
                Icons.refresh,
                color: Colors.white,
                size: 60,
              ),
            ),

            SizedBox(height: 40),

            // Progress bar
            Container(
              width: 300,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Status text
            Text(
              _status,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
}
```

---

## Streaming Levels

### What are Streaming Levels?

Streaming levels are sub-levels that can be loaded/unloaded dynamically to:
- Reduce memory usage
- Improve performance
- Create large open worlds
- Enable seamless level transitions

### Load Streaming Level

In Unreal Engine, configure streaming levels in the Persistent Level.

**From Flutter:**
```dart
// Load a streaming sub-level
await controller.sendMessage(
  'LevelStreamingManager',
  'LoadStreamingLevel',
  '{"levelName": "SubLevel_01", "visible": true, "blockOnLoad": false}'
);
```

**In Unreal Blueprint:**
```blueprint
On Message From Flutter (Event)
  → Compare: Method == "LoadStreamingLevel"
  → Parse JSON (Data)
  → Load Stream Level
    Level Name: levelName
    Make Visible After Load: visible
    Should Block on Load: blockOnLoad
```

### Unload Streaming Level

```dart
await controller.sendMessage(
  'LevelStreamingManager',
  'UnloadStreamingLevel',
  '{"levelName": "SubLevel_01"}'
);
```

---

## Best Practices

### 1. Level Organization

**Organize levels by purpose:**
```
/Game/Maps/
├── MainMenu.umap          # Start screen
├── Gameplay/
│   ├── Level_01.umap      # First level
│   ├── Level_02.umap      # Second level
│   └── Level_03.umap      # Third level
├── Cutscenes/
│   ├── Intro.umap
│   └── Outro.umap
└── Testing/
    └── TestLevel.umap
```

### 2. Loading Screen Best Practices

**Always show loading indicator:**
```dart
Future<void> loadLevelWithFeedback(String levelName) async {
  setState(() => _isLoading = true);

  try {
    await controller.loadLevel(levelName);
  } catch (e) {
    _showError('Failed to load level: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### 3. Preload Assets

Preload frequently used assets in initial level:
```dart
// In your initial level setup
await controller.sendMessage(
  'AssetManager',
  'PreloadAssets',
  '{"assets": ["Player", "Enemies", "UI"]}'
);
```

### 4. Level Transitions

**Smooth transitions:**
```dart
Future<void> transitionToLevel(String levelName) async {
  // Fade out
  await _fadeOut();

  // Load level
  await controller.loadLevel(levelName);

  // Wait for level to be ready
  await Future.delayed(Duration(milliseconds: 500));

  // Fade in
  await _fadeIn();
}

Future<void> _fadeOut() async {
  // Implement fade animation
}

Future<void> _fadeIn() async {
  // Implement fade animation
}
```

### 5. Handle Loading Failures

```dart
Future<bool> safeLoadLevel(String levelName) async {
  try {
    await controller.loadLevel(levelName);
    return true;
  } catch (e) {
    print('Failed to load level $levelName: $e');

    // Fallback to safe level
    await controller.loadLevel('MainMenu');
    return false;
  }
}
```

### 6. Clean Up Before Loading

```dart
Future<void> loadLevelClean(String levelName) async {
  // Notify Unreal to clean up
  await controller.sendMessage(
    'GameManager',
    'PrepareForLevelChange',
    '{}'
  );

  // Wait for cleanup
  await Future.delayed(Duration(milliseconds: 100));

  // Load new level
  await controller.loadLevel(levelName);
}
```

---

## Level Management Patterns

### Level Navigation System

```dart
class LevelNavigator {
  final UnrealController controller;
  String? currentLevel;
  final List<String> levelHistory = [];

  LevelNavigator(this.controller) {
    controller.sceneLoads.listen((scene) {
      currentLevel = scene.name;
    });
  }

  Future<void> navigateTo(String levelName) async {
    if (currentLevel != null) {
      levelHistory.add(currentLevel!);
    }
    await controller.loadLevel(levelName);
  }

  Future<void> goBack() async {
    if (levelHistory.isNotEmpty) {
      final previousLevel = levelHistory.removeLast();
      await controller.loadLevel(previousLevel);
    }
  }

  bool canGoBack() => levelHistory.isNotEmpty;
}
```

### Level Preloader

```dart
class LevelPreloader {
  final UnrealController controller;
  final Set<String> preloadedLevels = {};

  LevelPreloader(this.controller);

  Future<void> preloadLevel(String levelName) async {
    if (preloadedLevels.contains(levelName)) {
      return;  // Already preloaded
    }

    // Tell Unreal to preload assets
    await controller.sendMessage(
      'LevelManager',
      'PreloadLevel',
      '{"levelName": "$levelName"}'
    );

    preloadedLevels.add(levelName);
  }

  Future<void> preloadLevels(List<String> levels) async {
    for (final level in levels) {
      await preloadLevel(level);
    }
  }
}
```

### Campaign Manager

```dart
class CampaignManager {
  final UnrealController controller;
  int currentLevelIndex = 0;

  final List<String> campaignLevels = [
    'Level_01',
    'Level_02',
    'Level_03',
    'Level_04',
    'Level_05',
  ];

  CampaignManager(this.controller);

  Future<void> startCampaign() async {
    currentLevelIndex = 0;
    await loadCurrentLevel();
  }

  Future<void> nextLevel() async {
    if (currentLevelIndex < campaignLevels.length - 1) {
      currentLevelIndex++;
      await loadCurrentLevel();
    } else {
      // Campaign complete
      await controller.loadLevel('Victory');
    }
  }

  Future<void> previousLevel() async {
    if (currentLevelIndex > 0) {
      currentLevelIndex--;
      await loadCurrentLevel();
    }
  }

  Future<void> restartLevel() async {
    await loadCurrentLevel();
  }

  Future<void> loadCurrentLevel() async {
    final levelName = campaignLevels[currentLevelIndex];
    await controller.loadLevel(levelName);
  }

  String getCurrentLevelName() {
    return campaignLevels[currentLevelIndex];
  }

  int getTotalLevels() => campaignLevels.length;

  double getProgress() {
    return (currentLevelIndex + 1) / campaignLevels.length;
  }
}
```

---

## Troubleshooting

### Level Not Loading

**Problem:** Level doesn't load or loads incorrectly.

**Solutions:**
1. Check level name spelling
2. Verify level exists in packaged build
3. Check Unreal logs for errors
4. Try loading with full path: `/Game/Maps/LevelName`

```dart
// Debug level loading
await controller.executeConsoleCommand('log LogStreaming Verbose');
await controller.loadLevel('YourLevel');
```

### Black Screen After Load

**Problem:** Level loads but shows black screen.

**Solutions:**
1. Check level has lighting
2. Verify quality settings aren't too low
3. Wait longer for level to initialize
4. Check for errors in Unreal logs

```dart
// Add delay after loading
await controller.loadLevel('Level_01');
await Future.delayed(Duration(seconds: 2));  // Wait for initialization
```

### Slow Level Loading

**Problem:** Levels take too long to load.

**Solutions:**
1. Reduce level complexity
2. Use streaming levels
3. Preload assets
4. Optimize textures and meshes

```dart
// Monitor loading time
final stopwatch = Stopwatch()..start();
await controller.loadLevel('Level_01');
stopwatch.stop();
print('Level loaded in ${stopwatch.elapsedMilliseconds}ms');
```

### Memory Issues

**Problem:** App crashes or runs out of memory.

**Solutions:**
1. Unload previous level properly
2. Use streaming levels
3. Reduce texture quality
4. Monitor memory usage

```dart
// Check memory before loading
await controller.executeConsoleCommand('stat memory');
await controller.loadLevel('Level_01');
```

---

## Advanced Techniques

### Level Pooling

Reuse levels instead of reloading:

```dart
class LevelPool {
  final UnrealController controller;
  final Map<String, bool> loadedLevels = {};

  Future<void> loadLevelPooled(String levelName) async {
    if (loadedLevels.containsKey(levelName)) {
      // Activate existing level
      await controller.sendMessage(
        'LevelManager',
        'ActivateLevel',
        '{"levelName": "$levelName"}'
      );
    } else {
      // Load new level
      await controller.loadLevel(levelName);
      loadedLevels[levelName] = true;
    }
  }
}
```

### Background Loading

Load levels in background:

```dart
Future<void> backgroundLoadLevel(String levelName) async {
  await controller.sendMessage(
    'LevelManager',
    'BackgroundLoadLevel',
    '{"levelName": "$levelName", "priority": "low"}'
  );
}
```

---

**Last Updated:** 2025-10-27
**Plugin Version:** 0.5.0

**See Also:**
- [README.md](README.md) - Main documentation
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Setup instructions
