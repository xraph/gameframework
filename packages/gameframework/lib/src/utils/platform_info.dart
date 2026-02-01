import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform information utility for the game framework
///
/// Provides information about the current platform and environment.
class PlatformInfo {
  static const MethodChannel _channel = MethodChannel('gameframework');

  /// Get the platform version string
  ///
  /// Returns a string like "Android 13" or "iOS 16.0"
  static Future<String?> getPlatformVersion() async {
    try {
      final version = await _channel.invokeMethod<String>('getPlatformVersion');
      return version;
    } catch (e) {
      debugPrint('Failed to get platform version: $e');
      return null;
    }
  }

  /// Get list of registered game engines
  ///
  /// Returns a list of engine type identifiers (e.g., ['unity', 'unreal'])
  static Future<List<String>> getRegisteredEngines() async {
    try {
      final result = await _channel.invokeMethod<List>('getRegisteredEngines');
      return result?.cast<String>() ?? [];
    } catch (e) {
      debugPrint('Failed to get registered engines: $e');
      return [];
    }
  }

  /// Check if a specific engine type is registered
  ///
  /// Returns true if the engine plugin is available
  static Future<bool> isEngineRegistered(String engineType) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isEngineRegistered',
        {'engineType': engineType},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to check engine registration: $e');
      return false;
    }
  }

  /// Get platform-specific information
  static PlatformDetails get platform => PlatformDetails._();
}

/// Platform-specific details
class PlatformDetails {
  PlatformDetails._();

  /// Whether the app is running on Android
  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Whether the app is running on iOS
  bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether the app is running on Web
  bool get isWeb => kIsWeb;

  /// Whether the app is running on macOS
  bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  /// Whether the app is running on Windows
  bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;

  /// Whether the app is running on Linux
  bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;

  /// Whether the app is running on a mobile platform
  bool get isMobile => isAndroid || isIOS;

  /// Whether the app is running on a desktop platform
  bool get isDesktop => isMacOS || isWindows || isLinux;

  /// Get the current platform as a string
  String get platformName {
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWeb) return 'Web';
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Whether the platform supports Unity integration
  bool get supportsUnity => isAndroid || isIOS;

  /// Whether the platform supports Unreal integration
  bool get supportsUnreal => isAndroid || isIOS;

  /// Get supported engine types for the current platform
  List<String> get supportedEngines {
    final engines = <String>[];
    if (supportsUnity) engines.add('unity');
    if (supportsUnreal) engines.add('unreal');
    return engines;
  }
}
