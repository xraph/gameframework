import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework/gameframework_platform_interface.dart';
import 'package:gameframework/gameframework_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGameframeworkPlatform
    with MockPlatformInterfaceMixin
    implements GameframeworkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final GameframeworkPlatform initialPlatform = GameframeworkPlatform.instance;

  test('$MethodChannelGameframework is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGameframework>());
  });

  test('getPlatformVersion', () async {
    Gameframework gameframeworkPlugin = Gameframework();
    MockGameframeworkPlatform fakePlatform = MockGameframeworkPlatform();
    GameframeworkPlatform.instance = fakePlatform;

    expect(await gameframeworkPlugin.getPlatformVersion(), '42');
  });
}
