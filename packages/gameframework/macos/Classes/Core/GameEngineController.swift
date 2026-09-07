import FlutterMacOS
import Foundation

/**
 * Container view that resizes the engine's view to match its own bounds.
 *
 * AppKit does not resize subviews for you the way autoresizing hints imply, so
 * this does it in layout, and tells whoever is interested that the size
 * changed. An engine rendering into its own surface has to be told: stretching
 * the view alone leaves it drawing at whatever size it started at.
 */
class GameEngineContainerView: NSView {
    weak var engineView: NSView?

    /// Fires after the engine view has been stretched to match the container.
    var onEngineViewResized: ((CGSize) -> Void)?

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()

        if let engineView = engineView, !bounds.isEmpty {
            engineView.frame = bounds
            onEngineViewResized?(bounds.size)
        }
    }
}

/**
 * Protocol defining the interface for game engine platform views on macOS.
 */
public protocol GameEnginePlatformView: AnyObject {
    func createEngine()
    func attachEngine()
    func detachEngine()
    func pauseEngine()
    func resumeEngine()
    func unloadEngine()
    func destroyEngine()
    func sendMessage(target: String, method: String, data: String)

    var engineType: String { get }
    var engineVersion: String { get }

    func view() -> NSView
}

/**
 * Base controller for an embedded engine on macOS.
 *
 * The same shape as the iOS one, and deliberately so: it answers the same
 * method channel and sends the same events, so the Dart side does not need to
 * know which platform it is talking to. What differs is only what AppKit
 * forces, which is the container's layout and the platform view protocol.
 */
open class GameEngineController: NSObject, GameEnginePlatformView, FlutterStreamHandler {

    public let viewId: Int64
    public let messenger: FlutterBinaryMessenger
    public let channel: FlutterMethodChannel
    public let eventChannel: FlutterEventChannel

    private var eventSink: FlutterEventSink?

    /// Events raised before Flutter subscribed.
    ///
    /// The engine is created and reports itself ready well before the Dart side
    /// has listened, and an event sent to nobody is simply lost. Queued here and
    /// flushed on subscribe, because the one that goes missing is onCreated,
    /// without which the controller never believes the engine exists.
    private var pendingEvents: [[String: Any]] = []
    private let eventQueueLock = NSLock()

    private let containerView: GameEngineContainerView
    private var engineView: NSView?

    open var _isReady = false
    open var _isPaused = false

    private let config: [String: Any]

    public init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) {
        self.viewId = viewId
        self.messenger = messenger
        self.config = config
        self.containerView = GameEngineContainerView(frame: frame)

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

        // Weakly, because the controller owns the container.
        self.containerView.onEngineViewResized = { [weak self] size in
            self?.engineViewDidResize(to: size)
        }
    }

    // MARK: - Abstract

    open func createEngine() { fatalError("createEngine() must be overridden") }
    open func attachEngine() { fatalError("attachEngine() must be overridden") }
    open func detachEngine() { fatalError("detachEngine() must be overridden") }
    open func pauseEngine() { fatalError("pauseEngine() must be overridden") }
    open func resumeEngine() { fatalError("resumeEngine() must be overridden") }
    open func unloadEngine() { fatalError("unloadEngine() must be overridden") }
    open func destroyEngine() { fatalError("destroyEngine() must be overridden") }
    open func sendMessage(target: String, method: String, data: String) {
        fatalError("sendMessage() must be overridden")
    }

    open var engineType: String { fatalError("engineType must be overridden") }
    open var engineVersion: String { fatalError("engineVersion must be overridden") }

    /// Undo unloadEngine. Default does nothing, for an engine that cannot.
    open func reloadEngine() {}

    /// Called when the container resized the engine view. Override to tell the
    /// engine its new surface size.
    open func engineViewDidResize(to size: CGSize) {}

    public var isReady: Bool { _isReady }
    public var isPaused: Bool { _isPaused }

    // MARK: - Platform view

    public func view() -> NSView {
        return containerView
    }

    /// Put the engine's view inside the container, where Flutter composites it.
    public func addEngineView(_ view: NSView) {
        engineView = view
        containerView.engineView = view

        view.frame = containerView.bounds
        view.autoresizingMask = [.width, .height]
        containerView.addSubview(view)
        containerView.needsLayout = true
    }

    /// Take it back out, without destroying it.
    public func removeEngineView() {
        engineView?.removeFromSuperview()
        containerView.engineView = nil
        engineView = nil
    }

    // MARK: - Method channel

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Every call from Dart, named. This is the boundary that tells you
        // whether a control that "does nothing" ever left Dart.
        NSLog("GameEngineController: <- \(call.method)")

        switch call.method {
        case "engine#create":
            createEngine()
            result(true)

        case "engine#reload":
            reloadEngine()
            result(true)

        case "engine#pause":
            pauseEngine()
            result(nil)

        case "engine#resume":
            resumeEngine()
            result(nil)

        case "engine#unload":
            unloadEngine()
            result(nil)

        case "engine#quit":
            destroyEngine()
            result(nil)

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

        case "events#setup":
            // Answered so the Dart side knows the handler is live before it
            // subscribes. Without this it can listen too early and miss the
            // events already queued.
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Events

    public func sendEvent(name: String, data: Any?) {
        let event: [String: Any] = [
            "event": name,
            "data": data ?? NSNull()
        ]

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let sink = self.eventSink {
                sink(event)
            } else {
                self.eventQueueLock.lock()
                self.pendingEvents.append(event)
                self.eventQueueLock.unlock()
                NSLog("GameEngineController: Queued event '\(name)' (Flutter not subscribed yet)")
            }
        }
    }

    public func onListen(withArguments arguments: Any?,
                         eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events

        eventQueueLock.lock()
        let queued = pendingEvents
        pendingEvents.removeAll()
        eventQueueLock.unlock()

        if !queued.isEmpty {
            NSLog("GameEngineController: Flushing \(queued.count) pending events to Flutter")
            for event in queued {
                events(event)
            }
        }

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    /// Read a value from the config Flutter passed when creating the view.
    public func getConfigValue<T>(_ key: String) -> T? {
        return config[key] as? T
    }
}
