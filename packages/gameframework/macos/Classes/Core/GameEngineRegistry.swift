import FlutterMacOS
import Foundation

/**
 * Protocol for engine factories
 *
 * Engine plugins must provide a factory that creates their specific controller.
 */
public protocol GameEngineFactory {
    /// Create an engine controller
    func createController(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) -> GameEnginePlatformView
}

/**
 * Singleton registry for game engine implementations
 *
 * Manages the registration and lifecycle of engine controllers and factories.
 */
public class GameEngineRegistry {

    public static let shared = GameEngineRegistry()

    private init() {}

    private var factories: [String: GameEngineFactory] = [:]
    private var controllers: [GameEnginePlatformView] = []

    /// Register an engine factory
    public func registerFactory(engineType: String, factory: GameEngineFactory) {
        factories[engineType] = factory
    }

    /// Unregister an engine factory
    public func unregisterFactory(engineType: String) {
        factories.removeValue(forKey: engineType)
    }

    /// Check if an engine is registered
    public func isEngineRegistered(_ engineType: String) -> Bool {
        return factories[engineType] != nil
    }

    /// Get all registered engine types
    public func getRegisteredEngines() -> [String] {
        return Array(factories.keys)
    }

    /// Get factory for a specific engine type
    public func getFactory(_ engineType: String) -> GameEngineFactory? {
        return factories[engineType]
    }

    /// Keep a controller alive for as long as its platform view exists
    public func registerController(_ controller: GameEnginePlatformView) {
        controllers.append(controller)
    }

    /// Drop a controller once its platform view is gone
    public func unregisterController(_ controller: GameEnginePlatformView) {
        controllers.removeAll { $0 === controller }
    }
}

/**
 * Platform view factory for game engines
 *
 * Wraps the GameEngineFactory protocol for Flutter's platform view system.
 *
 * The macOS protocol differs from the iOS one: it hands over a view identifier
 * and arguments but no frame, because AppKit sizes the view from its container
 * afterwards. The controller is built with a zero frame and laid out on the
 * first pass, which is what the iOS side ends up doing anyway.
 */
public class GameEnginePlatformViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger
    private let engineType: String

    public init(messenger: FlutterBinaryMessenger, engineType: String) {
        self.messenger = messenger
        self.engineType = engineType
        super.init()
    }

    public func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let config = args as? [String: Any] ?? [:]

        guard let factory = GameEngineRegistry.shared.getFactory(engineType) else {
            // Not fatal, unlike iOS. A missing engine should show an empty view
            // and say why, rather than take the whole app down: on desktop this
            // is usually a plugin that failed to register, and killing the app
            // hides the one message that would tell you so.
            NSLog("GameEngineRegistry: no factory for \(engineType); showing an empty view")
            return NSView(frame: .zero)
        }

        let controller = factory.createController(
            frame: .zero,
            viewId: viewId,
            messenger: messenger,
            config: config
        )

        GameEngineRegistry.shared.registerController(controller)
        return controller.view()
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
