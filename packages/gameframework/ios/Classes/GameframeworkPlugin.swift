import Flutter
import UIKit

/**
 * GameframeworkPlugin - Main plugin for GameFramework
 *
 * This plugin provides the core infrastructure for embedding game engines.
 * Engine-specific plugins (Unity, Unreal) register their factories here.
 */
public class GameframeworkPlugin: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel?
    private let engineRegistry = GameEngineRegistry.shared
    private static weak var pluginRegistrar: FlutterPluginRegistrar?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Store registrar for lazy platform view registration
        pluginRegistrar = registrar
        
        let channel = FlutterMethodChannel(
            name: "gameframework",
            binaryMessenger: registrar.messenger()
        )
        let instance = GameframeworkPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Don't register platform views immediately - they'll be registered
        // when engine plugins call registerPlatformView after registering their factories
    }

    /// Called by engine plugins after they register their factory
    /// This allows lazy registration to work around plugin init order issues
    public static func registerPlatformView(engineType: String) {
        guard let registrar = pluginRegistrar else {
            print("⚠️ GameframeworkPlugin: No registrar available for platform view registration")
            return
        }
        
        let factory = GameEnginePlatformViewFactory(
            messenger: registrar.messenger(),
            engineType: engineType
        )

        registrar.register(
            factory,
            withId: "com.xraph.gameframework/\(engineType)"
        )
        
        print("✅ Registered platform view: com.xraph.gameframework/\(engineType)")
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
