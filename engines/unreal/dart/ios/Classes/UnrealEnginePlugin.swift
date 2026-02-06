import Flutter
import Foundation
import gameframework

/**
 * UnrealEnginePlugin - Plugin for Unreal Engine integration
 *
 * This plugin registers the Unreal engine factory with the game framework,
 * allowing Unreal Engine to be embedded in Flutter applications on iOS.
 */
public class UnrealEnginePlugin: NSObject, FlutterPlugin {

    private static let engineType = "unreal"

    public static func register(with registrar: FlutterPluginRegistrar) {
        NSLog("UnrealEnginePlugin: Registering plugin...")
        
        // Register Unreal factory with the game framework
        let factory = UnrealEngineFactory()
        GameEngineRegistry.shared.registerFactory(
            engineType: engineType,
            factory: factory
        )
        NSLog("UnrealEnginePlugin: Registered factory for engine type '\(engineType)'")
        
        // Trigger platform view registration (lazy registration pattern)
        // This registers the platform view factory with Flutter
        GameframeworkPlugin.registerPlatformView(engineType: engineType)
        NSLog("UnrealEnginePlugin: Registered platform view 'com.xraph.gameframework/\(engineType)'")
    }

    /**
     * Manual registration method for early initialization
     *
     * Call this before the Flutter engine is fully initialized if needed.
     */
    public static func registerManually() {
        let factory = UnrealEngineFactory()
        GameEngineRegistry.shared.registerFactory(
            engineType: engineType,
            factory: factory
        )
        NSLog("UnrealEnginePlugin: Manually registered factory")
    }
}

/**
 * Factory for creating Unreal engine controllers
 */
public class UnrealEngineFactory: NSObject, GameEngineFactory {

    public func createController(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) -> GameEnginePlatformView {
        NSLog("UnrealEngineFactory: Creating controller with viewId \(viewId)")
        return UnrealEngineController(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            config: config
        )
    }
}
