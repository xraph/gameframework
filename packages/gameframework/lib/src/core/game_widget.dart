import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/android_platform_view_mode.dart';
import 'game_engine_controller.dart';
import 'game_engine_registry.dart';
import '../models/game_engine_config.dart';
import '../models/game_engine_type.dart';
import '../models/game_engine_event.dart';

/// Main widget for embedding game engines in Flutter
///
/// This widget provides a unified interface for embedding any supported
/// game engine (Unity, Unreal, etc.) into a Flutter application.
///
/// Example:
/// ```dart
/// GameWidget(
///   engineType: GameEngineType.unity,
///   onEngineCreated: (controller) {
///     controller.sendMessage('GameManager', 'Initialize', 'data');
///   },
///   config: GameEngineConfig(
///     fullscreen: false,
///     runImmediately: true,
///   ),
/// )
/// ```
class GameWidget extends StatefulWidget {
  const GameWidget({
    super.key,
    required this.engineType,
    required this.onEngineCreated,
    this.onMessage,
    this.onSceneLoaded,
    this.onEngineUnloaded,
    this.config = const GameEngineConfig(),
    this.gestureRecognizers,
    this.placeholder,
    this.enablePlaceholder = false,
    this.borderRadius = BorderRadius.zero,
    this.layoutDirection,
  });

  /// The type of game engine to use (Unity, Unreal, etc.)
  final GameEngineType engineType;

  /// Callback when the engine is created and ready
  final GameEngineCreatedCallback onEngineCreated;

  /// Callback when receiving messages from the engine
  final GameEngineMessageCallback? onMessage;

  /// Callback when a new scene is loaded in the engine
  final GameEngineSceneLoadedCallback? onSceneLoaded;

  /// Callback when the engine is unloaded
  final GameEngineUnloadCallback? onEngineUnloaded;

  /// Configuration for the game engine
  final GameEngineConfig config;

  /// Gesture recognizers for the embedded view
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// Placeholder widget shown before engine is ready
  final Widget? placeholder;

  /// Whether to show placeholder
  final bool enablePlaceholder;

  /// Border radius for the game view
  final BorderRadius borderRadius;

  /// Text direction for the embedded view
  ///
  /// If this is null, the ambient [Directionality] is used instead.
  /// If there is no ambient [Directionality], [TextDirection.ltr] is used.
  final TextDirection? layoutDirection;

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> {
  GameEngineController? _controller;
  bool _isEngineReady = false;
  static int _viewIdCounter = 0;
  late final int _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = _viewIdCounter++;
    // Delay engine initialization until after the first frame
    // This ensures the platform view (UiKitView/AndroidView) is created first
    // and the native method channel handler is ready before we try to communicate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeEngine();
      }
    });
  }

  Future<void> _initializeEngine() async {
    try {
      // Create the controller through the registry
      final controller = await GameEngineRegistry.instance.createController(
        widget.engineType,
        _viewId,
        widget.config,
      );

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _isEngineReady = true;
      });

      // Set up message listeners
      _setupListeners();

      // Notify the app that engine is created
      widget.onEngineCreated(controller);

      // Auto-start engine if configured
      if (widget.config.runImmediately) {
        debugPrint(
            'Auto-starting ${widget.engineType.engineName} engine (runImmediately: true)');
        try {
          await controller.create();
        } catch (e) {
          debugPrint('Failed to auto-start engine: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize ${widget.engineType.engineName}: $e');
      // You might want to show an error widget here
    }
  }

  void _setupListeners() {
    final controller = _controller;
    if (controller == null) return;

    // Listen to messages from engine
    controller.messageStream.listen(
      (message) {
        if (mounted && widget.onMessage != null) {
          widget.onMessage!(message);
        }
      },
      onError: (error) {
        debugPrint('Engine message stream error: $error');
      },
    );

    // Listen to scene load events
    controller.sceneLoadStream.listen(
      (scene) {
        if (mounted && widget.onSceneLoaded != null) {
          widget.onSceneLoaded!(scene);
        }
      },
      onError: (error) {
        debugPrint('Scene load stream error: $error');
      },
    );

    // Listen to lifecycle events
    controller.eventStream.listen(
      (event) {
        debugPrint('Engine event: ${event.type.name}');
        // Handle unload event
        if (event.type == GameEngineEventType.unloaded) {
          if (mounted && widget.onEngineUnloaded != null) {
            widget.onEngineUnloaded!();
          }
        }
      },
      onError: (error) {
        debugPrint('Engine event stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder if enabled and engine not ready
    if (widget.enablePlaceholder && !_isEngineReady) {
      return widget.placeholder ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading ${widget.engineType.engineName}...'),
              ],
            ),
          );
    }

    // Build the platform view for the engine
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: _buildPlatformView(),
    );
  }

  Widget _buildPlatformView() {
    final viewType = 'com.xraph.gameframework/${widget.engineType.identifier}';

    // Platform-specific view creation
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _buildAndroidPlatformView(viewType);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        layoutDirection: widget.layoutDirection ?? TextDirection.ltr,
        creationParams: widget.config.toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: widget.gestureRecognizers,
      );
    } else if (kIsWeb) {
      // Web implementation would use HtmlElementView
      return Center(
        child:
            Text('Web support for ${widget.engineType.engineName} coming soon'),
      );
    } else {
      // Unsupported platform
      return Center(
        child: Text(
          '${defaultTargetPlatform.name} is not yet supported by ${widget.engineType.engineName}',
        ),
      );
    }
  }

  /// Build Android platform view with the selected rendering mode
  Widget _buildAndroidPlatformView(String viewType) {
    // Choose rendering mode based on configuration
    switch (widget.config.androidPlatformViewMode) {
      case AndroidPlatformViewMode.hybridComposition:
        return _buildHybridCompositionView(viewType);
      case AndroidPlatformViewMode.virtualDisplay:
        return _buildVirtualDisplayView(viewType);
    }
  }

  /// Build Android platform view using Hybrid Composition (recommended)
  ///
  /// Hybrid Composition provides better performance on Android 10+ and more
  /// accurate input handling. This is the default mode.
  ///
  /// Minimum SDK: Android 19 (API level 19)
  Widget _buildHybridCompositionView(String viewType) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: widget.gestureRecognizers ??
              const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: widget.layoutDirection ?? TextDirection.ltr,
          creationParams: widget.config.toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () {
            params.onFocusChanged(true);
          },
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }

  /// Build Android platform view using Virtual Display (Texture Layer)
  ///
  /// Virtual Display renders the view to a texture, which can be better for
  /// complex animations but has higher memory usage.
  ///
  /// Minimum SDK: Android 20 (API level 20)
  Widget _buildVirtualDisplayView(String viewType) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: widget.gestureRecognizers ??
              const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: widget.layoutDirection ?? TextDirection.ltr,
          creationParams: widget.config.toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () {
            params.onFocusChanged(true);
          },
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
