import Flutter
import UIKit

public class UnityEnginePlugin: NSObject, FlutterPlugin {
    private static var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name: "com.xraph.gameframework.unity",
            binaryMessenger: registrar.messenger()
        )

        let instance = UnityEnginePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel!)

        // Register Unity platform view factory
        let factory = UnityViewFactory(messenger: registrar.messenger())
        registrar.register(
            factory,
            withId: "com.xraph.gameframework/unity"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isUnityReady":
            result(UnityPlayerManager.shared.isInitialized())

        case "getUnityVersion":
            result(UnityPlayerManager.shared.getUnityVersion())

        case "pauseUnity":
            UnityPlayerManager.shared.pause()
            result(nil)

        case "resumeUnity":
            UnityPlayerManager.shared.resume()
            result(nil)

        case "unloadUnity":
            UnityPlayerManager.shared.unload()
            result(nil)

        case "sendMessage":
            guard let args = call.arguments as? [String: Any],
                  let gameObject = args["gameObject"] as? String,
                  let methodName = args["methodName"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing gameObject or methodName",
                    details: nil
                ))
                return
            }

            let message = args["message"] as? String ?? ""
            UnityPlayerManager.shared.sendMessage(
                gameObject: gameObject,
                methodName: methodName,
                message: message
            )
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
