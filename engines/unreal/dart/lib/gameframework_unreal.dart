/// Unreal Engine plugin for Flutter Game Framework
///
/// Provides Unreal Engine integration for the Flutter Game Framework,
/// enabling bidirectional communication, lifecycle management, and
/// quality settings control.
///
/// ## Features
/// - Full lifecycle management (create, pause, resume, unload, quit)
/// - Bidirectional communication (string, JSON, binary)
/// - Binary messaging with compression and chunking
/// - Message batching and throttling for performance
/// - Quality settings with presets (low, medium, high, epic, cinematic)
/// - Console command execution
/// - Level loading support
///
/// ## Quick Start
/// ```dart
/// import 'package:gameframework_unreal/gameframework_unreal.dart';
///
/// final controller = UnrealController(viewId);
/// await controller.create();
/// await controller.sendMessage('GameManager', 'startGame', '{}');
/// ```
library gameframework_unreal;

// Core controller
export 'src/unreal_controller.dart';
export 'src/unreal_engine_plugin.dart';
export 'src/unreal_quality_settings.dart';

// Binary protocol
export 'src/unreal_binary_protocol.dart';

// Performance utilities
export 'src/unreal_message_batcher.dart';
export 'src/unreal_message_throttler.dart';
export 'src/unreal_delta_compressor.dart';

// Asset management
export 'src/unreal_asset_manager.dart';
