import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'gameframework_platform_interface.dart';

/// An implementation of [GameframeworkPlatform] that uses method channels.
class MethodChannelGameframework extends GameframeworkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('gameframework');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
