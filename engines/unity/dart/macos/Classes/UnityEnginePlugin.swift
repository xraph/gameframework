import FlutterMacOS
import Foundation

/**
 * Unity Engine Plugin for macOS
 *
 * Registers the Unity engine factory with the game framework.
 * Creates UnityEngineController instances for each platform view.
 */
public class UnityEnginePlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger

        // Register the platform view factory for Unity
        let factory = UnityEngineViewFactory(messenger: messenger)
        registrar.register(factory, withId: "com.xraph.gameframework/unity")

        // Register method channel for plugin-level queries
        let channelName = "gameframework_unity"
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        let instance = UnityEnginePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        NSLog("Unity Engine Plugin initialized for macOS")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        case "getEngineType":
            result("unity")
        case "getEngineVersion":
            result("2022.3.0")
        case "isEngineSupported":
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Platform View Factory

/**
 * Factory for creating UnityEngineController platform views
 */
class UnityEngineViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withViewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> NSView {
        let config = args as? [String: Any] ?? [:]
        let controller = UnityEngineController(
            frame: CGRect(x: 0, y: 0, width: 300, height: 300),
            viewId: viewId,
            messenger: messenger,
            config: config
        )
        return controller.view()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
