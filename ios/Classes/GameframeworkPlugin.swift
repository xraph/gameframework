import Flutter
import UIKit

/**
 * GameframeworkPlugin - Main plugin for Flutter Game Framework
 *
 * This plugin provides the core infrastructure for embedding game engines.
 * Engine-specific plugins (Unity, Unreal) register their factories here.
 */
public class GameframeworkPlugin: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel?
    private let engineRegistry = GameEngineRegistry.shared

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "gameframework",
            binaryMessenger: registrar.messenger()
        )
        let instance = GameframeworkPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Register platform view factories for each registered engine type
        // Engine plugins will have registered their factories by this point
        instance.registerPlatformViews(with: registrar)
    }

    private func registerPlatformViews(with registrar: FlutterPluginRegistrar) {
        let registeredEngines = engineRegistry.getRegisteredEngines()

        for engineType in registeredEngines {
            let factory = GameEnginePlatformViewFactory(
                messenger: registrar.messenger(),
                engineType: engineType
            )

            registrar.register(
                factory,
                withId: "com.xraph.gameframework/\(engineType)"
            )
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "getRegisteredEngines":
            result(engineRegistry.getRegisteredEngines())

        case "isEngineRegistered":
            guard let args = call.arguments as? [String: Any],
                  let engineType = args["engineType"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing engineType",
                    details: nil
                ))
                return
            }
            result(engineRegistry.isEngineRegistered(engineType))

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
