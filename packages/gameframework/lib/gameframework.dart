/// Flutter Game Framework
///
/// A modular, unified framework for embedding game engines
/// (Unity, Unreal Engine, and potentially others) into Flutter applications.
///
/// ## Getting Started
///
/// 1. Initialize the engine plugin(s) you want to use:
/// ```dart
/// void main() {
///   UnityEnginePlugin.initialize(); // For Unity
///   // UnrealEnginePlugin.initialize(); // For Unreal
///   runApp(MyApp());
/// }
/// ```
///
/// 2. Use the GameWidget to embed the engine:
/// ```dart
/// GameWidget(
///   engineType: GameEngineType.unity,
///   onEngineCreated: (controller) {
///     // Engine is ready, you can send messages
///     controller.sendMessage('GameManager', 'Initialize', 'data');
///   },
///   onMessage: (message) {
///     // Receive messages from the engine
///     print('Engine says: ${message.data}');
///   },
///   config: GameEngineConfig(
///     fullscreen: false,
///     runImmediately: true,
///   ),
/// )
/// ```
library gameframework;

// Core classes
export 'src/core/game_widget.dart';
export 'src/core/game_engine_controller.dart';
export 'src/core/game_engine_registry.dart';
export 'src/core/game_engine_factory.dart';

// Models
export 'src/models/game_engine_type.dart';
export 'src/models/game_engine_config.dart';
export 'src/models/game_engine_message.dart';
export 'src/models/game_scene_loaded.dart';
export 'src/models/game_engine_event.dart';
export 'src/models/android_platform_view_mode.dart';

// Exceptions
export 'src/exceptions/game_engine_exception.dart';

// Utils
export 'src/utils/platform_info.dart';

/// Current version of the Flutter Game Framework
const String gameFrameworkVersion = '0.4.0';
