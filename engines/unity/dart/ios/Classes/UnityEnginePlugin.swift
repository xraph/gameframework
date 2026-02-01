import Flutter
import Foundation
import gameframework

/**
 * UnityEnginePlugin - Plugin for Unity Engine integration
 *
 * This plugin registers the Unity engine factory with the game framework,
 * allowing Unity engines to be embedded in Flutter applications on iOS.
 */
public class UnityEnginePlugin: NSObject, FlutterPlugin {

    private static let engineType = "unity"

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Auto-initialize Unity integration with command-line arguments
        // This eliminates the need for manual AppDelegate modification
        // Note: launchOptions is not available here, but Unity works without it for most use cases
        UnityPlayerUtils.shared.InitUnityIntegrationWithOptions(
            argc: CommandLine.argc,
            argv: CommandLine.unsafeArgv,
            nil
        )
        NSLog("UnityEnginePlugin: Auto-initialized Unity integration")
        
        // Register Unity factory with the game framework
        let factory = UnityEngineFactory()
        GameEngineRegistry.shared.registerFactory(
            engineType: engineType,
            factory: factory
        )
        
        // Trigger platform view registration (lazy registration pattern)
        GameframeworkPlugin.registerPlatformView(engineType: engineType)
    }

    /**
     * Manual registration method for early initialization
     *
     * Call this before the Flutter engine is fully initialized if needed.
     */
    public static func registerManually() {
        let factory = UnityEngineFactory()
        GameEngineRegistry.shared.registerFactory(
            engineType: engineType,
            factory: factory
        )
    }
}

/**
 * Factory for creating Unity engine controllers
 */
public class UnityEngineFactory: NSObject, GameEngineFactory {

    public func createController(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) -> GameEnginePlatformView {
        return UnityEngineController(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            config: config
        )
    }
}
