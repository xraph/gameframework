import Flutter
import UIKit

// Unreal will not start unless the app delegate descends from IOSAppDelegate.
// It says so as a Fatal. IOSAppDelegate is declared for us by
// UnrealAppDelegate.h, which Runner-Bridging-Header.h imports, so no engine
// headers are needed here.
//
// See engines/unreal/dart/ios/INTEGRATION.md. In particular: do not declare a
// 'window' property. Unreal's Window is filled in by UIKit calling setWindow:,
// and declaring your own takes that selector over.
@main
class AppDelegate: IOSAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Not calling super: in an embedded build that starts Unreal the
    // non-embedded way and fights with the pod, which starts it for us.
    if let controller = unrealWindow?.rootViewController as? FlutterViewController {
      GeneratedPluginRegistrant.register(with: controller)
    } else {
      NSLog("AppDelegate: no FlutterViewController to register plugins with")
    }
    return true
  }
}
