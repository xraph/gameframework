import Cocoa
import FlutterMacOS

public class GameframeworkPlugin: NSObject, FlutterPlugin {

  /// Kept so an engine plugin can register its platform view later.
  ///
  /// Plugin registration order is not something a plugin can rely on, and an
  /// engine cannot register a view for a factory it has not created yet. So the
  /// registrar is held here and engine plugins call back once they are ready.
  private static var pluginRegistrar: FlutterPluginRegistrar?

  public static func register(with registrar: FlutterPluginRegistrar) {
    pluginRegistrar = registrar

    let channel = FlutterMethodChannel(name: "gameframework", binaryMessenger: registrar.messenger)
    let instance = GameframeworkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  /// Called by engine plugins once they have registered their factory.
  public static func registerPlatformView(engineType: String) {
    guard let registrar = pluginRegistrar else {
      NSLog("GameframeworkPlugin: no registrar yet, cannot register a platform view for \(engineType)")
      return
    }

    let factory = GameEnginePlatformViewFactory(
      messenger: registrar.messenger,
      engineType: engineType
    )

    registrar.registerViewFactory(factory, withId: "com.xraph.gameframework/\(engineType)")
    NSLog("GameframeworkPlugin: registered platform view com.xraph.gameframework/\(engineType)")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
