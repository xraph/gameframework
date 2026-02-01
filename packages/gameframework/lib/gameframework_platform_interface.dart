import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'gameframework_method_channel.dart';

abstract class GameframeworkPlatform extends PlatformInterface {
  /// Constructs a GameframeworkPlatform.
  GameframeworkPlatform() : super(token: _token);

  static final Object _token = Object();

  static GameframeworkPlatform _instance = MethodChannelGameframework();

  /// The default instance of [GameframeworkPlatform] to use.
  ///
  /// Defaults to [MethodChannelGameframework].
  static GameframeworkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [GameframeworkPlatform] when
  /// they register themselves.
  static set instance(GameframeworkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
