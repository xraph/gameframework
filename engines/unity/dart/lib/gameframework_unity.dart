/// Unity Engine plugin for Flutter Game Framework
///
/// This plugin provides Unity-specific implementation of the game framework,
/// allowing Flutter apps to embed and control Unity game engines.
///
/// ## Usage
///
/// ```dart
/// import 'package:gameframework/gameframework.dart';
/// import 'package:gameframework_unity/gameframework_unity.dart';
///
/// // Initialize Unity plugin
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   UnityEnginePlugin.initialize();
///   runApp(MyApp());
/// }
///
/// // Use Unity in your widget tree
/// GameWidget(
///   engineType: GameEngineType.unity,
///   onEngineCreated: (controller) {
///     print('Unity engine ready!');
///   },
/// )
/// ```
library gameframework_unity;

export 'src/unity_controller.dart';
export 'src/unity_engine_plugin.dart';
