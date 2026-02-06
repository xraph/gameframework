import Flutter
import UIKit
import gameframework

/**
 * Unreal Engine specific implementation of GameEngineController
 *
 * This controller manages the Unreal Engine framework lifecycle and communication
 * between Flutter and Unreal Engine on iOS.
 */
public class UnrealEngineController: GameEngineController {

    // MARK: - Properties

    private var unrealView: UIView?
    private var unrealReady = false
    
    // Message queue for events before Flutter subscribes
    private var messageQueue: [(target: String, method: String, data: String)] = []
    private var isMessageChannelReady = false
    private let messageQueueLock = NSLock()
    
    private static let engineTypeValue = "unreal"
    private static let engineVersionValue = "5.3.0"

    // MARK: - Initialization

    public override init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) {
        super.init(frame: frame, viewId: viewId, messenger: messenger, config: config)
        NSLog("UnrealEngineController: Initialized with viewId \(viewId)")
    }
    
    // MARK: - GameEnginePlatformView Implementation
    
    public override func createEngine() {
        // Register as active controller for bridge callbacks
        self.registerAsActive()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            NSLog("UnrealEngineController: Creating Unreal Engine...")
            
            // Try to create engine via UnrealBridge (Objective-C class)
            guard let bridge = self.getUnrealBridge() else {
                NSLog("UnrealEngineController: UnrealBridge not available")
                self.handleBridgeNotAvailable()
            return
        }

            let config = self.getConfigValue("config") as [String: Any]? ?? [:]
            
            // Call bridge.createWithConfig:controller:
            let success = self.callBridgeCreate(bridge: bridge, config: config)
            
            if !success {
                NSLog("UnrealEngineController: Failed to create Unreal Engine (UnrealFramework not available)")
                self.handleBridgeNotAvailable()
            return
        }

            // Try to get the Unreal view
            if let view = self.callBridgeGetView(bridge: bridge) {
                self.unrealView = view
                self.attachEngine()
                NSLog("UnrealEngineController: Unreal view attached successfully")
            } else {
                NSLog("UnrealEngineController: No Unreal view available (stub mode)")
            }
            
            // Mark as ready
            self._isReady = true
            self.unrealReady = true
            
            self.sendEvent(name: "onCreated", data: nil)
            self.sendEvent(name: "onLoaded", data: nil)
            
            // Send onReady message to Flutter
            self.sendEvent(name: "onMessage", data: [
                "target": "Unreal",
                "method": "onReady",
                "data": "{\"success\":true,\"message\":\"Unreal Engine ready\"}"
            ])
            NSLog("UnrealEngineController: Sent onReady message to Flutter")
            
            // Flush queued messages
            self.flushMessageQueue()
        }
    }
    
    private func handleBridgeNotAvailable() {
        self.sendEvent(name: "onError", data: [
            "message": "Failed to create Unreal Engine. UnrealFramework.framework may not be available."
        ])
        
        // Still mark as ready so the app can handle the error gracefully
        self._isReady = true
        self.sendEvent(name: "onCreated", data: nil)
        
        // Send onReady message so Flutter knows initialization completed (even if failed)
        self.sendEvent(name: "onMessage", data: [
            "target": "Unreal",
            "method": "onReady",
            "data": "{\"success\":false,\"message\":\"UnrealFramework not available\"}"
        ])
        
        self.flushMessageQueue()
    }
    
    public override func attachEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let unrealView = self.unrealView else {
                NSLog("UnrealEngineController: No view to attach")
                return
            }
            
            // Remove from existing superview if any
            if let superview = unrealView.superview {
                unrealView.removeFromSuperview()
                superview.layoutIfNeeded()
            }
            
            // Add to our container
            self.addEngineView(unrealView)
            unrealView.layoutIfNeeded()
            
            self.sendEvent(name: "onAttached", data: nil)
        }
    }
    
    public override func detachEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.removeEngineView()
            self.sendEvent(name: "onDetached", data: nil)
        }
    }
    
    public override func pauseEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let bridge = self.getUnrealBridge() {
                self.callBridgePause(bridge: bridge)
            }
            self._isPaused = true
            self.sendEvent(name: "onPaused", data: nil)
        }
    }
    
    public override func resumeEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let bridge = self.getUnrealBridge() {
                self.callBridgeResume(bridge: bridge)
            }
            self._isPaused = false
            self.sendEvent(name: "onResumed", data: nil)
        }
    }
    
    public override func unloadEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Unreal doesn't support unloading without destroying, pause instead
            self.pauseEngine()
            self.sendEvent(name: "onUnloaded", data: nil)
        }
    }
    
    public override func destroyEngine() {
        // Unregister as active controller
        self.unregisterAsActive()
        
        // Clear message queue
        messageQueueLock.lock()
        messageQueue.removeAll()
        isMessageChannelReady = false
        messageQueueLock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let bridge = self.getUnrealBridge() {
                self.callBridgeQuit(bridge: bridge)
            }
            self.unrealView = nil
            self.unrealReady = false
            self._isReady = false
            self._isPaused = false
            
            self.sendEvent(name: "onDestroyed", data: nil)
        }
    }
    
    public override func sendMessage(target: String, method: String, data: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            NSLog("UnrealEngineController: Sending message - Target: \(target), Method: \(method)")
            if let bridge = self.getUnrealBridge() {
                self.callBridgeSendMessage(bridge: bridge, target: target, method: method, data: data)
            }
        }
    }
    
    public override var engineType: String {
        return UnrealEngineController.engineTypeValue
    }
    
    public override var engineVersion: String {
        return UnrealEngineController.engineVersionValue
    }
    
    // MARK: - UnrealBridge Interaction (Objective-C Runtime)
    
    /// Get the UnrealBridge shared instance using Objective-C runtime
    private func getUnrealBridge() -> AnyObject? {
        guard let bridgeClass = NSClassFromString("UnrealBridge") else {
            NSLog("UnrealEngineController: UnrealBridge class not found")
            return nil
        }

        let selector = NSSelectorFromString("shared")
        guard bridgeClass.responds(to: selector) else {
            NSLog("UnrealEngineController: UnrealBridge.shared not found")
            return nil
        }

        let method = bridgeClass.method(for: selector)
        typealias SharedFunc = @convention(c) (AnyClass, Selector) -> AnyObject
        let shared = unsafeBitCast(method, to: SharedFunc.self)
        return shared(bridgeClass, selector)
    }
    
    private func callBridgeCreate(bridge: AnyObject, config: [String: Any]) -> Bool {
        let selector = NSSelectorFromString("createWithConfig:controller:")
        guard bridge.responds(to: selector) else { return false }
        
        let imp = bridge.method(for: selector)
        typealias CreateFunc = @convention(c) (AnyObject, Selector, NSDictionary, AnyObject) -> Bool
        let create = unsafeBitCast(imp, to: CreateFunc.self)
        return create(bridge, selector, config as NSDictionary, self)
    }
    
    private func callBridgeGetView(bridge: AnyObject) -> UIView? {
        let selector = NSSelectorFromString("getView")
        guard bridge.responds(to: selector) else { return nil }
        
        let imp = bridge.method(for: selector)
        typealias GetViewFunc = @convention(c) (AnyObject, Selector) -> UIView?
        let getView = unsafeBitCast(imp, to: GetViewFunc.self)
        return getView(bridge, selector)
    }
    
    private func callBridgePause(bridge: AnyObject) {
        let selector = NSSelectorFromString("pause")
        guard bridge.responds(to: selector) else { return }
        bridge.perform(selector)
    }
    
    private func callBridgeResume(bridge: AnyObject) {
        let selector = NSSelectorFromString("resume")
        guard bridge.responds(to: selector) else { return }
        bridge.perform(selector)
    }
    
    private func callBridgeQuit(bridge: AnyObject) {
        let selector = NSSelectorFromString("quit")
        guard bridge.responds(to: selector) else { return }
        bridge.perform(selector)
    }
    
    private func callBridgeSendMessage(bridge: AnyObject, target: String, method: String, data: String) {
        let selector = NSSelectorFromString("sendMessageWithTarget:method:data:")
        guard bridge.responds(to: selector) else { return }
        
        let imp = bridge.method(for: selector)
        typealias SendFunc = @convention(c) (AnyObject, Selector, NSString, NSString, NSString) -> Void
        let send = unsafeBitCast(imp, to: SendFunc.self)
        send(bridge, selector, target as NSString, method as NSString, data as NSString)
    }
    
    // MARK: - Message Queue Management
    
    /**
     * Called from UnrealBridge when Unreal sends a message to Flutter
     * @objc makes this callable from Objective-C
     */
    @objc public func onMessageFromUnrealWithTarget(_ target: String, method: String, data: String) {
        messageQueueLock.lock()
        defer { messageQueueLock.unlock() }
        
        if !isMessageChannelReady {
            NSLog("UnrealEngineController: Queueing message (channel not ready): \(target).\(method)")
            messageQueue.append((target, method, data))
            
            // Limit queue size
            if messageQueue.count > 100 {
                NSLog("UnrealEngineController: Message queue overflow, dropping oldest")
                messageQueue.removeFirst()
            }
            return
        }
        
        NSLog("UnrealEngineController: Forwarding message to Flutter: \(target).\(method)")
        sendEvent(name: "onMessage", data: [
            "target": target,
            "method": method,
            "data": data
        ])
    }
    
    /**
     * Called from UnrealBridge when a scene/level is loaded
     * @objc makes this callable from Objective-C
     */
    @objc public func onLevelLoadedWithLevelName(_ levelName: String, buildIndex: Int) {
        sendEvent(name: "onSceneLoaded", data: [
            "name": levelName,
            "buildIndex": buildIndex,
            "isLoaded": true,
            "isValid": true,
            "metadata": [String: Any]()
        ])
    }
    
    /**
     * Flush queued messages to Flutter
     */
    private func flushMessageQueue() {
        messageQueueLock.lock()
        let queuedMessages = messageQueue
        messageQueue.removeAll()
        isMessageChannelReady = true
        messageQueueLock.unlock()
        
        if !queuedMessages.isEmpty {
            NSLog("UnrealEngineController: Flushing \(queuedMessages.count) queued messages")
            for msg in queuedMessages {
                sendEvent(name: "onMessage", data: [
                    "target": msg.target,
                    "method": msg.method,
                    "data": msg.data
                ])
            }
        } else {
            NSLog("UnrealEngineController: Message channel ready (no queued messages)")
        }
    }
    
    // MARK: - Active Controller Tracking
    
    private static var _activeController: UnrealEngineController?
    
    static var activeController: UnrealEngineController? {
        get { return _activeController }
        set { _activeController = newValue }
    }
    
    func registerAsActive() {
        UnrealEngineController.activeController = self
        NSLog("UnrealEngineController: Registered as active controller")
    }
    
    func unregisterAsActive() {
        if UnrealEngineController.activeController === self {
            UnrealEngineController.activeController = nil
            NSLog("UnrealEngineController: Unregistered as active controller")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        unregisterAsActive()
        NSLog("UnrealEngineController: Deinit")
    }
}
