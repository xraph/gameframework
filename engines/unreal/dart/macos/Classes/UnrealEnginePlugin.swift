import Cocoa
import FlutterMacOS
import gameframework

/**
 * Registers the Unreal engine with the game framework on macOS.
 */
public class UnrealEnginePlugin: NSObject, FlutterPlugin {

    private static let engineType = "unreal"

    public static func register(with registrar: FlutterPluginRegistrar) {
        NSLog("UnrealEnginePlugin: Registering plugin...")

        GameEngineRegistry.shared.registerFactory(
            engineType: engineType,
            factory: UnrealEngineFactory()
        )
        NSLog("UnrealEnginePlugin: Registered factory for engine type '\(engineType)'")

        // The framework holds the registrar and registers the view for us, so
        // this works whatever order the plugins happen to load in.
        GameframeworkPlugin.registerPlatformView(engineType: engineType)
    }
}
