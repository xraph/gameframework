import UIKit
import Flutter

/**
 * Unreal Engine Controller for iOS
 *
 * Manages the Unreal Engine lifecycle, view integration, and communication
 * between Flutter and Unreal Engine on iOS.
 */
public class UnrealEngineController: NSObject {

    // MARK: - Properties

    private let viewId: Int
    private let channel: FlutterMethodChannel
    private let config: [String: Any]

    private var unrealView: UIView?
    private var unrealFramework: UnrealFramework?

    private var isReady: Bool = false
    private var isPaused: Bool = false
    private var isDestroyed: Bool = false

    // MARK: - Constants

    private static let engineType = "unreal"
    private static let engineVersion = "5.3.0"

    // MARK: - Initialization

    public init(viewId: Int, channel: FlutterMethodChannel, config: [String: Any]) {
        self.viewId = viewId
        self.channel = channel
        self.config = config
        super.init()
    }

    // MARK: - Lifecycle Methods

    /**
     * Initialize and create the Unreal Engine instance
     */
    public func create() -> Bool {
        if isDestroyed {
            sendError("Cannot create destroyed engine")
            return false
        }

        if isReady {
            return true
        }

        // Load Unreal Framework
        guard let framework = loadUnrealFramework() else {
            sendError("Failed to load Unreal Framework")
            return false
        }

        unrealFramework = framework

        // Apply configuration
        applyConfiguration(config)

        // Initialize Unreal Engine
        if !nativeCreate(config) {
            sendError("Failed to create Unreal Engine instance")
            return false
        }

        // Get Unreal view
        guard let view = nativeGetView() else {
            sendError("Failed to get Unreal view")
            return false
        }

        unrealView = view
        isReady = true

        sendEvent("created")
        sendEvent("loaded")

        return true
    }

    /**
     * Pause the Unreal Engine
     */
    public func pause() {
        if !isReady || isDestroyed {
            return
        }

        nativePause()
        isPaused = true
        sendEvent("paused")
    }

    /**
     * Resume the Unreal Engine
     */
    public func resume() {
        if !isReady || isDestroyed {
            return
        }

        nativeResume()
        isPaused = false
        sendEvent("resumed")
    }

    /**
     * Unload the Unreal Engine (pause and detach)
     */
    public func unload() {
        if !isReady || isDestroyed {
            return
        }

        pause()
        sendEvent("unloaded")
    }

    /**
     * Quit and destroy the Unreal Engine
     */
    public func quit() {
        if isDestroyed {
            return
        }

        nativeQuit()
        unrealView = nil
        unrealFramework = nil
        isReady = false
        isDestroyed = true
        sendEvent("destroyed")
    }

    // MARK: - Communication Methods

    /**
     * Send a message to Unreal Engine
     */
    public func sendMessage(target: String, method: String, data: String) {
        if !isReady || isDestroyed {
            sendError("Engine not ready for messages")
            return
        }

        nativeSendMessage(target: target, method: method, data: data)
    }

    /**
     * Send a JSON message to Unreal Engine
     */
    public func sendJsonMessage(target: String, method: String, data: [String: Any]) {
        if !isReady || isDestroyed {
            sendError("Engine not ready for messages")
            return
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            sendError("Failed to serialize JSON message")
            return
        }

        nativeSendMessage(target: target, method: method, data: jsonString)
    }

    // MARK: - Unreal-Specific Methods

    /**
     * Execute a console command in Unreal Engine
     */
    public func executeConsoleCommand(_ command: String) {
        if !isReady || isDestroyed {
            sendError("Engine not ready for console commands")
            return
        }

        nativeExecuteConsoleCommand(command)
    }

    /**
     * Load a level/map in Unreal Engine
     */
    public func loadLevel(_ levelName: String) {
        if !isReady || isDestroyed {
            sendError("Engine not ready to load level")
            return
        }

        nativeLoadLevel(levelName)
    }

    /**
     * Apply quality settings to Unreal Engine
     */
    public func applyQualitySettings(_ settings: [String: Any]) {
        if !isReady || isDestroyed {
            sendError("Engine not ready for quality settings")
            return
        }

        nativeApplyQualitySettings(settings)
    }

    /**
     * Get current quality settings from Unreal Engine
     */
    public func getQualitySettings() -> [String: Any]? {
        if !isReady || isDestroyed {
            sendError("Engine not ready")
            return nil
        }

        return nativeGetQualitySettings()
    }

    /**
     * Check if engine is in background
     */
    public func isInBackground() -> Bool {
        return isPaused
    }

    // MARK: - View Integration

    /**
     * Get the Unreal Engine view to attach to Flutter
     */
    public func getView() -> UIView? {
        return unrealView
    }

    /**
     * Attach Unreal view to parent
     */
    public func attachView(to parent: UIView) {
        guard let view = unrealView, view.superview == nil else {
            return
        }

        view.frame = parent.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addSubview(view)
        sendEvent("attached")
    }

    /**
     * Detach Unreal view from parent
     */
    public func detachView() {
        guard let view = unrealView else {
            return
        }

        view.removeFromSuperview()
        sendEvent("detached")
    }

    // MARK: - Event Handling

    private func sendEvent(_ eventType: String, message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var arguments: [String: Any] = ["type": eventType]
            if let message = message {
                arguments["message"] = message
            }

            self.channel.invokeMethod("onEvent", arguments: arguments)
        }
    }

    private func sendError(_ message: String) {
        NSLog("[UnrealEngineController] Error: \(message)")
        sendEvent("error", message: message)
    }

    /**
     * Called from native code when a message is received from Unreal
     */
    @objc public func onMessageFromUnreal(target: String, method: String, data: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.channel.invokeMethod("onMessage", arguments: [
                "target": target,
                "method": method,
                "data": data
            ])
        }
    }

    /**
     * Called from native code when a level is loaded
     */
    @objc public func onLevelLoaded(levelName: String, buildIndex: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.channel.invokeMethod("onLevelLoaded", arguments: [
                "name": levelName,
                "buildIndex": buildIndex,
                "isLoaded": true,
                "isValid": true,
                "metadata": [String: Any]()
            ])
        }
    }

    // MARK: - Framework Loading

    private func loadUnrealFramework() -> UnrealFramework? {
        // Load Unreal Framework from app bundle
        let bundlePath = Bundle.main.bundlePath + "/Frameworks/UnrealFramework.framework"

        guard let bundle = Bundle(path: bundlePath) else {
            NSLog("[UnrealEngineController] Failed to find UnrealFramework bundle at: \(bundlePath)")
            return nil
        }

        guard bundle.load() else {
            NSLog("[UnrealEngineController] Failed to load UnrealFramework bundle")
            return nil
        }

        NSLog("[UnrealEngineController] Successfully loaded UnrealFramework")
        return UnrealFramework(bundle: bundle)
    }

    private func applyConfiguration(_ config: [String: Any]) {
        // Apply configuration to Unreal Engine
        // This can include graphics settings, game mode, etc.
        if let enableMetal = config["enableMetal"] as? Bool, enableMetal {
            // Enable Metal graphics API
            NSLog("[UnrealEngineController] Metal graphics enabled")
        }

        if let enableHighDPI = config["enableHighDPI"] as? Bool, enableHighDPI {
            // Enable high DPI rendering
            NSLog("[UnrealEngineController] High DPI rendering enabled")
        }
    }

    // MARK: - Native Bridge Methods (Objective-C++)

    /**
     * Create Unreal Engine instance
     * Implemented in Objective-C++ bridge
     */
    private func nativeCreate(_ config: [String: Any]) -> Bool {
        // This will call into Objective-C++ bridge -> Unreal C++
        return UnrealBridge.shared.create(config: config, controller: self)
    }

    /**
     * Get the native Unreal view
     * Implemented in Objective-C++ bridge
     */
    private func nativeGetView() -> UIView? {
        return UnrealBridge.shared.getView()
    }

    /**
     * Pause the engine
     * Implemented in Objective-C++ bridge
     */
    private func nativePause() {
        UnrealBridge.shared.pause()
    }

    /**
     * Resume the engine
     * Implemented in Objective-C++ bridge
     */
    private func nativeResume() {
        UnrealBridge.shared.resume()
    }

    /**
     * Quit the engine
     * Implemented in Objective-C++ bridge
     */
    private func nativeQuit() {
        UnrealBridge.shared.quit()
    }

    /**
     * Send message to Unreal
     * Implemented in Objective-C++ bridge
     */
    private func nativeSendMessage(target: String, method: String, data: String) {
        UnrealBridge.shared.sendMessage(target: target, method: method, data: data)
    }

    /**
     * Execute console command
     * Implemented in Objective-C++ bridge
     */
    private func nativeExecuteConsoleCommand(_ command: String) {
        UnrealBridge.shared.executeConsoleCommand(command)
    }

    /**
     * Load level
     * Implemented in Objective-C++ bridge
     */
    private func nativeLoadLevel(_ levelName: String) {
        UnrealBridge.shared.loadLevel(levelName)
    }

    /**
     * Apply quality settings
     * Implemented in Objective-C++ bridge
     */
    private func nativeApplyQualitySettings(_ settings: [String: Any]) {
        UnrealBridge.shared.applyQualitySettings(settings)
    }

    /**
     * Get quality settings
     * Implemented in Objective-C++ bridge
     */
    private func nativeGetQualitySettings() -> [String: Any] {
        return UnrealBridge.shared.getQualitySettings()
    }
}

// MARK: - Unreal Framework Wrapper

/**
 * Wrapper for Unreal Framework bundle
 */
private class UnrealFramework {
    let bundle: Bundle

    init(bundle: Bundle) {
        self.bundle = bundle
    }
}

// MARK: - Unreal Bridge Interface

/**
 * Bridge to Objective-C++ code that interfaces with Unreal C++
 * This class will be implemented in UnrealBridge.mm (Objective-C++)
 */
@objc public class UnrealBridge: NSObject {

    @objc public static let shared = UnrealBridge()

    private weak var controller: UnrealEngineController?

    private override init() {
        super.init()
    }

    // These methods will be implemented in UnrealBridge.mm (Objective-C++)
    // They serve as the interface between Swift and Unreal C++

    @objc public func create(config: [String: Any], controller: UnrealEngineController) -> Bool {
        self.controller = controller
        // Implementation in UnrealBridge.mm
        return false // Placeholder
    }

    @objc public func getView() -> UIView? {
        // Implementation in UnrealBridge.mm
        return nil // Placeholder
    }

    @objc public func pause() {
        // Implementation in UnrealBridge.mm
    }

    @objc public func resume() {
        // Implementation in UnrealBridge.mm
    }

    @objc public func quit() {
        // Implementation in UnrealBridge.mm
    }

    @objc public func sendMessage(target: String, method: String, data: String) {
        // Implementation in UnrealBridge.mm
    }

    @objc public func executeConsoleCommand(_ command: String) {
        // Implementation in UnrealBridge.mm
    }

    @objc public func loadLevel(_ levelName: String) {
        // Implementation in UnrealBridge.mm
    }

    @objc public func applyQualitySettings(_ settings: [String: Any]) {
        // Implementation in UnrealBridge.mm
    }

    @objc public func getQualitySettings() -> [String: Any] {
        // Implementation in UnrealBridge.mm
        return [:] // Placeholder
    }

    // Called from Unreal C++ to send messages to Flutter
    @objc public func notifyMessage(target: String, method: String, data: String) {
        controller?.onMessageFromUnreal(target: target, method: method, data: data)
    }

    // Called from Unreal C++ when level is loaded
    @objc public func notifyLevelLoaded(levelName: String, buildIndex: Int) {
        controller?.onLevelLoaded(levelName: levelName, buildIndex: buildIndex)
    }
}
