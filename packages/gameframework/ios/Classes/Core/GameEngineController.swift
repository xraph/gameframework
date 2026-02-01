import Flutter
import UIKit

/**
 * Protocol defining the interface for game engine platform views
 *
 * All engine-specific controllers must implement this protocol.
 * Provides common functionality for lifecycle management and communication.
 */
public protocol GameEnginePlatformView: FlutterPlatformView {
    // MARK: - Engine Lifecycle

    /// Create and initialize the game engine
    func createEngine()

    /// Attach the engine view to the container
    func attachEngine()

    /// Detach the engine view from the container
    func detachEngine()

    /// Pause the engine execution
    func pauseEngine()

    /// Resume the engine execution
    func resumeEngine()

    /// Unload the engine
    func unloadEngine()

    /// Destroy the engine
    func destroyEngine()

    // MARK: - Communication

    /// Send a message to the engine
    func sendMessage(target: String, method: String, data: String)

    // MARK: - Properties

    /// Get the engine type identifier
    var engineType: String { get }

    /// Get the engine version
    var engineVersion: String { get }

    /// Check if engine is ready
    var isReady: Bool { get }

    /// Check if engine is paused
    var isPaused: Bool { get }
}

/**
 * Base class for game engine controllers
 *
 * Provides common implementation that engine-specific controllers can extend.
 * Handles method channel communication and basic view management.
 */
open class GameEngineController: NSObject, GameEnginePlatformView, FlutterStreamHandler {

    // MARK: - Properties

    private let viewId: Int64
    private let messenger: FlutterBinaryMessenger
    private let channel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    private let containerView: UIView
    private var engineView: UIView?

    open var _isReady = false
    open var _isPaused = false

    private let config: [String: Any]

    // MARK: - Initialization

    public init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) {
        self.viewId = viewId
        self.messenger = messenger
        self.config = config
        self.containerView = UIView(frame: frame)

        self.channel = FlutterMethodChannel(
            name: "com.xraph.gameframework/engine_\(viewId)",
            binaryMessenger: messenger
        )

        self.eventChannel = FlutterEventChannel(
            name: "com.xraph.gameframework/events_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        self.channel.setMethodCallHandler(handleMethodCall)
        self.eventChannel.setStreamHandler(self)
    }

    // MARK: - Abstract Methods (Override in subclasses)

    open func createEngine() {
        fatalError("createEngine() must be overridden")
    }

    open func attachEngine() {
        fatalError("attachEngine() must be overridden")
    }

    open func detachEngine() {
        fatalError("detachEngine() must be overridden")
    }

    open func pauseEngine() {
        fatalError("pauseEngine() must be overridden")
    }

    open func resumeEngine() {
        fatalError("resumeEngine() must be overridden")
    }

    open func unloadEngine() {
        fatalError("unloadEngine() must be overridden")
    }

    open func destroyEngine() {
        fatalError("destroyEngine() must be overridden")
    }

    open func sendMessage(target: String, method: String, data: String) {
        fatalError("sendMessage() must be overridden")
    }

    open var engineType: String {
        fatalError("engineType must be overridden")
    }

    open var engineVersion: String {
        fatalError("engineVersion must be overridden")
    }

    public var isReady: Bool { _isReady }
    public var isPaused: Bool { _isPaused }

    // MARK: - FlutterPlatformView

    public func view() -> UIView {
        return containerView
    }

    // MARK: - Method Channel Handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "engine#create":
            createEngine()
            result(true)

        case "engine#isReady":
            result(isReady)

        case "engine#isPaused":
            result(isPaused)

        case "engine#isLoaded":
            result(isReady)

        case "engine#isInBackground":
            result(isPaused)

        case "engine#sendMessage":
            guard let args = call.arguments as? [String: Any],
                  let target = args["target"] as? String,
                  let method = args["method"] as? String,
                  let data = args["data"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Invalid arguments",
                                   details: nil))
                return
            }
            sendMessage(target: target, method: method, data: data)
            result(nil)

        case "engine#pause":
            pauseEngine()
            _isPaused = true
            result(nil)

        case "engine#resume":
            resumeEngine()
            _isPaused = false
            result(nil)

        case "engine#unload":
            unloadEngine()
            result(nil)

        case "engine#quit":
            destroyEngine()
            result(nil)

        case "streaming#setCachePath":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Missing path argument",
                                   details: nil))
                return
            }
            setStreamingCachePath(path)
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Set streaming cache path - override in engine-specific controllers
    open func setStreamingCachePath(_ path: String) {
        // Default implementation does nothing
        NSLog("GameEngineController: setStreamingCachePath not implemented for this engine")
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - Utility Methods

    /// Send an event to Flutter
    public func sendEvent(name: String, data: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "event": name,
                "data": data ?? NSNull()
            ])
        }
    }

    /// Add engine view to container
    public func addEngineView(_ view: UIView) {
        view.frame = containerView.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(view)
        self.engineView = view
    }

    /// Remove engine view from container
    public func removeEngineView() {
        engineView?.removeFromSuperview()
        engineView = nil
    }

    /// Get configuration value
    public func getConfigValue<T>(_ key: String) -> T? {
        return config[key] as? T
    }

    /// Get configuration value with default
    public func getConfigValue<T>(_ key: String, default defaultValue: T) -> T {
        return config[key] as? T ?? defaultValue
    }
}
