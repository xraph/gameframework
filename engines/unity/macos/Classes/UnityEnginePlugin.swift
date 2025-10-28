import FlutterMacOS
import Foundation

/**
 * Unity Engine Plugin for macOS
 *
 * Registers the Unity engine factory with the game framework.
 */
public class UnityEnginePlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Register Unity engine factory
        let messenger = registrar.messenger
        let channelName = "gameframework_unity"

        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        let instance = UnityEnginePlugin()

        registrar.addMethodCallDelegate(instance, channel: channel)

        // Initialize Unity engine integration
        initializeUnityEngine(messenger: messenger)
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

    private static func initializeUnityEngine(messenger: FlutterBinaryMessenger) {
        // Register Unity engine with GameEngineRegistry
        // This would typically be done through method channel calls
        // to the core gameframework plugin
        print("Unity Engine Plugin initialized for macOS")
    }
}
