
import 'gameframework_platform_interface.dart';

class Gameframework {
  Future<String?> getPlatformVersion() {
    return GameframeworkPlatform.instance.getPlatformVersion();
  }
}
