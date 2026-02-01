import Flutter
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

    // MARK: - Singleton

    public static let shared = GameEngineRegistry()

    private init() {}

    // MARK: - Properties

    private var factories: [String: GameEngineFactory] = [:]
    private var controllers: [GameEnginePlatformView] = []

    // MARK: - Factory Management

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

    // MARK: - Controller Management

    /// Register a controller instance
    public func registerController(_ controller: GameEnginePlatformView) {
        controllers.append(controller)
    }

    /// Unregister a controller instance
    public func unregisterController(_ controller: GameEnginePlatformView) {
        controllers.removeAll { $0 === controller as AnyObject }
    }

    /// Get all active controllers
    public func getControllers() -> [GameEnginePlatformView] {
        return controllers
    }

    // MARK: - Lifecycle Management

    /// Called when app becomes active
    public func onAppBecameActive() {
        // Notify controllers if needed
    }

    /// Called when app will resign active
    public func onAppWillResignActive() {
        // Notify controllers if needed
    }

    // MARK: - Cleanup

    /// Clear all registrations (mainly for testing)
    public func clear() {
        factories.removeAll()
        controllers.removeAll()
    }
}

/**
 * Platform view factory for game engines
 *
 * Wraps the GameEngineFactory protocol for Flutter's platform view system.
 */
public class GameEnginePlatformViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger
    private let engineType: String

    public init(messenger: FlutterBinaryMessenger, engineType: String) {
        self.messenger = messenger
        self.engineType = engineType
        super.init()
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let config = args as? [String: Any] ?? [:]

        guard let factory = GameEngineRegistry.shared.getFactory(engineType) else {
            fatalError("Engine \(engineType) is not registered")
        }

        let controller = factory.createController(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            config: config
        )

        GameEngineRegistry.shared.registerController(controller)
        return controller
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
