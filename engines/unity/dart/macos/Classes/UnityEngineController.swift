import FlutterMacOS
import Cocoa

// NOTE: Unity→Flutter messaging on macOS uses two mechanisms:
// 1. FlutterBridgeRegistry - Swift class accessible via Objective-C runtime from FlutterBridge.mm
// 2. UnityBridge.swift @_cdecl functions - for Swift-only DllImport scenarios
//
// FlutterBridgeRegistry is the PRIMARY mechanism because:
// - Objective-C runtime (NSClassFromString) works reliably across dynamically loaded frameworks
// - dlsym for C functions in dynamically loaded frameworks is unreliable (symbols may be stripped)

/**
 * Unity-specific implementation of GameEngineController for macOS
 *
 * This controller manages the Unity framework lifecycle and communication
 * between Flutter and Unity on macOS.
 *
 * Features:
 * - Bidirectional message passing between Unity and Flutter
 * - Message queuing for messages received before the channel is ready
 * - Proper NSView lifecycle management for embedding Unity in Flutter
 * - Error handling with descriptive error events
 */
public class UnityEngineController: NSObject, FlutterPlatformView {

    // MARK: - Static Active Controller Tracking

    /// The currently active controller instance.
    /// Used by the C bridge functions in UnityBridge.swift.
    static weak var activeController: UnityEngineController?

    // MARK: - Properties

    private let viewId: Int64
    private let messenger: FlutterBinaryMessenger
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel

    private var unityView: NSView?
    private var containerView: NSView
    private var unityReady = false

    /// Whether Unity engine has been initialized
    var _isReady = false

    /// Whether Unity engine is paused
    var _isPaused = false

    // MARK: - Message Queue Properties

    /// Queue messages received before Flutter's message channel is ready
    private var messageQueue: [(target: String, method: String, data: String)] = []
    private var isMessageChannelReady = false
    private let messageQueueLock = NSLock()
    private static let maxQueueSize = 100

    private static let engineTypeValue = "unity"
    private static let engineVersionValue = "2022.3.0"

    // MARK: - Event Sink

    private var eventSink: FlutterEventSink?

    // MARK: - Initialization

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) {
        self.viewId = viewId
        self.messenger = messenger

        let channelName = "com.xraph.gameframework/engine_\(viewId)"
        self.methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        self.eventChannel = FlutterEventChannel(
            name: "com.xraph.gameframework/engine_events_\(viewId)",
            binaryMessenger: messenger
        )

        self.containerView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        self.containerView.wantsLayer = true
        self.containerView.layer?.backgroundColor = NSColor.black.cgColor

        super.init()

        self.setupMethodChannel()
        self.setupEventChannel()
    }

    // MARK: - FlutterPlatformView

    public func view() -> NSView {
        return containerView
    }

    // MARK: - Method Channel Setup

    private func setupMethodChannel() {
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }

            switch call.method {
            case "events#setup":
                self.isMessageChannelReady = true
                self.flushMessageQueue()
                result(true)

            case "engine#create":
                self.createEngine()
                result(true)

            case "engine#isReady":
                result(self._isReady)

            case "engine#isPaused":
                result(self._isPaused)

            case "engine#isLoaded":
                result(self._isReady)

            case "engine#isInBackground":
                result(false)

            case "engine#sendMessage":
                if let args = call.arguments as? [String: Any],
                   let target = args["target"] as? String,
                   let method = args["method"] as? String,
                   let data = args["data"] as? String {
                    self.sendMessage(target: target, method: method, data: data)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS",
                                       message: "Missing target, method, or data",
                                       details: nil))
                }

            case "engine#pause":
                self.pauseEngine()
                result(nil)

            case "engine#resume":
                self.resumeEngine()
                result(nil)

            case "engine#unload":
                self.unloadEngine()
                result(nil)

            case "engine#quit":
                self.destroyEngine()
                result(nil)

            case "streaming#setCachePath":
                // macOS supports local cache paths
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Event Channel Setup

    private func setupEventChannel() {
        eventChannel.setStreamHandler(self)
    }

    // MARK: - Active Controller Registration

    /// Register this controller as the active one for C bridge functions
    func registerAsActive() {
        UnityEngineController.activeController = self
        FlutterBridgeRegistry.register(controller: self)
        NSLog("UnityEngineController [macOS]: Registered as active controller (viewId: \(viewId))")
    }

    // MARK: - Engine Lifecycle

    func createEngine() {
        // Register as active controller for C bridge functions
        self.registerAsActive()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Load Unity framework
            guard let unityFramework = self.loadUnityFramework() else {
                self.sendEvent(name: "onError", data: [
                    "message": "Failed to load Unity framework. Ensure UnityFramework.framework is included."
                ])
                return
            }

            // Register the Unity framework with the FlutterBridgeRegistry
            FlutterBridgeRegistry.register(unityFramework: unityFramework)

            // Set up Unity framework
            unityFramework.setDataBundleId("com.unity3d.framework")

            // Run Unity embedded
            unityFramework.runEmbedded(
                withArgc: CommandLine.argc,
                argv: CommandLine.unsafeArgv,
                appLaunchOpts: nil
            )

            // Get Unity's root view
            if let appController = unityFramework.appController(),
               let rootView = appController.rootViewController?.view {
                self.unityView = rootView

                // Embed Unity view in our container
                rootView.translatesAutoresizingMaskIntoConstraints = false
                self.containerView.addSubview(rootView)

                NSLayoutConstraint.activate([
                    rootView.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
                    rootView.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
                    rootView.topAnchor.constraint(equalTo: self.containerView.topAnchor),
                    rootView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor),
                ])
            }

            // Mark as ready
            self._isReady = true
            self.unityReady = true

            self.sendEvent(name: "onCreated", data: nil)
            self.sendEvent(name: "onLoaded", data: nil)

            // Flush any queued messages
            self.flushMessageQueue()
        }
    }

    func pauseEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let unityFramework = self.loadUnityFramework() {
                unityFramework.pause(true)
            }
            self._isPaused = true
            self.sendEvent(name: "onPaused", data: nil)
        }
    }

    func resumeEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let unityFramework = self.loadUnityFramework() {
                unityFramework.pause(false)
            }
            self._isPaused = false
            self.sendEvent(name: "onResumed", data: nil)
        }
    }

    func unloadEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Unity on macOS doesn't fully support unloading without destroying
            // Pause instead
            self.pauseEngine()
            self.sendEvent(name: "onUnloaded", data: nil)
        }
    }

    func destroyEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Clean up Unity view
            self.unityView?.removeFromSuperview()
            self.unityView = nil

            // Unregister from bridge
            FlutterBridgeRegistry.unregisterAll()
            if UnityEngineController.activeController === self {
                UnityEngineController.activeController = nil
            }

            self.unityReady = false
            self._isReady = false
            self._isPaused = false

            // Clear message queue
            self.messageQueueLock.lock()
            self.messageQueue.removeAll()
            self.messageQueueLock.unlock()

            self.sendEvent(name: "onDestroyed", data: nil)
        }
    }

    // MARK: - Messaging

    func sendMessage(target: String, method: String, data: String) {
        guard _isReady else {
            NSLog("UnityEngineController [macOS]: Engine not ready, cannot send message")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let unityFramework = self.loadUnityFramework() {
                unityFramework.sendMessageToGO(
                    withName: target,
                    functionName: method,
                    message: data
                )
            }
        }
    }

    // MARK: - Unity Message Handling (called from C bridge)

    /// Called from Unity when a message is sent to Flutter
    @objc public func onUnityMessage(target: String, method: String, data: String) {
        onUnityMessageWithTarget(target, method: method, data: data)
    }

    /// Objective-C compatible method signature for FlutterBridge.mm
    @objc public func onUnityMessageWithTarget(_ target: String, method: String, data: String) {
        messageQueueLock.lock()

        if isMessageChannelReady {
            messageQueueLock.unlock()
            // Send immediately
            sendEvent(name: "onMessage", data: [
                "target": target,
                "method": method,
                "data": data,
            ])
        } else {
            // Queue the message
            if messageQueue.count >= UnityEngineController.maxQueueSize {
                messageQueue.removeFirst()
                NSLog("UnityEngineController [macOS]: Message queue full, dropped oldest message")
            }
            messageQueue.append((target: target, method: method, data: data))
            NSLog("UnityEngineController [macOS]: Queued message \(target).\(method) (\(messageQueue.count)/\(UnityEngineController.maxQueueSize))")
            messageQueueLock.unlock()
        }
    }

    /// Flush all queued messages to Flutter
    private func flushMessageQueue() {
        messageQueueLock.lock()
        let pending = messageQueue
        messageQueue.removeAll()
        isMessageChannelReady = true
        messageQueueLock.unlock()

        if !pending.isEmpty {
            NSLog("UnityEngineController [macOS]: Flushing \(pending.count) queued messages")
        }

        for msg in pending {
            sendEvent(name: "onMessage", data: [
                "target": msg.target,
                "method": msg.method,
                "data": msg.data,
            ])
        }
    }

    // MARK: - Event Sending

    func sendEvent(name: String, data: [String: Any]?) {
        var eventData: [String: Any] = [
            "event": name,
            "engineType": UnityEngineController.engineTypeValue,
            "engineVersion": UnityEngineController.engineVersionValue,
        ]

        if let data = data {
            eventData.merge(data) { (_, new) in new }
        }

        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(eventData)
        }
    }

    // MARK: - Unity Framework Loader
    //
    // The macOS UnityFramework.framework is assembled by game-cli from the Xcode build:
    // - UnityFramework (binary) = UnityPlayer.dylib
    // - Libraries/GameAssembly.dylib = IL2CPP code
    // - Data/ = game data
    // Pre-load GameAssembly.dylib so UnityPlayer can resolve IL2CPP symbols when the bundle loads.

    private func loadUnityFramework() -> UnityFramework? {
        // Try to get from cache first
        if let cached = FlutterBridgeRegistry.sharedUnityFramework as? UnityFramework {
            return cached
        }

        let frameworkPath = Bundle.main.bundlePath + "/Contents/Frameworks/UnityFramework.framework"
        let gameAssemblyPath = frameworkPath + "/Libraries/GameAssembly.dylib"

        // Pre-load GameAssembly.dylib so the framework binary (UnityPlayer) can resolve IL2CPP symbols
        if FileManager.default.fileExists(atPath: gameAssemblyPath) {
            let gameAssembly = dlopen(gameAssemblyPath, RTLD_NOW | RTLD_GLOBAL)
            if gameAssembly == nil {
                NSLog("UnityEngineController [macOS]: dlopen GameAssembly.dylib failed: \(String(cString: dlerror()))")
            }
        }

        guard let bundle = Bundle(path: frameworkPath) else {
            NSLog("UnityEngineController [macOS]: UnityFramework.framework not found at: \(frameworkPath)")
            return nil
        }

        if !bundle.isLoaded {
            bundle.load()
        }

        guard let principalClass = bundle.principalClass else {
            NSLog("UnityEngineController [macOS]: No principal class in UnityFramework bundle")
            return nil
        }

        let getInstance = principalClass.getInstance()
        return getInstance as? UnityFramework
    }

    // MARK: - Cleanup

    deinit {
        destroyEngine()
    }
}

// MARK: - FlutterStreamHandler

extension UnityEngineController: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - UnityFramework Protocol (Weak Linking)
// Define the UnityFramework interface so we can compile without the actual framework present.
// At runtime, the framework must be available or loadUnityFramework() will return nil.

@objc protocol UnityFrameworkProtocol {
    func setDataBundleId(_ bundleId: String)
    func runEmbedded(withArgc argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, appLaunchOpts: [AnyHashable: Any]?)
    func sendMessageToGO(withName goName: String, functionName name: String, message msg: String)
    func unloadApplication()
    func pause(_ pause: Bool)
    func appController() -> AnyObject?
    static func getInstance() -> AnyObject?
}
