import Flutter
import UIKit
import UnityFramework
import gameframework

// MARK: - C Bridge Function Declarations
// These functions are defined in FlutterBridge.mm (Objective-C)
// They set the controller reference used by Unity's SendMessageToFlutter

@_silgen_name("SetFlutterBridgeController")
func SetFlutterBridgeController(_ controller: UnsafeMutableRawPointer?)

@_silgen_name("SetUnityFramework")
func SetUnityFramework(_ framework: UnsafeMutableRawPointer?)

/**
 * Unity-specific implementation of GameEngineController
 *
 * This controller manages the Unity framework lifecycle and communication
 * between Flutter and Unity on iOS.
 */
public class UnityEngineController: GameEngineController {

    private var unityFramework: UnityFramework?
    private var unityView: UIView?
    private var unityReady = false
    
    // MARK: - Message Queue Properties
    // Queue messages received before Flutter's message channel is ready
    private var messageQueue: [(target: String, method: String, data: String)] = []
    private var isMessageChannelReady = false
    private let messageQueueLock = NSLock()

    private static let engineTypeValue = "unity"
    private static let engineVersionValue = "2022.3.0" // Should match Unity version

    // MARK: - Initialization

    public override init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) {
        super.init(frame: frame, viewId: viewId, messenger: messenger, config: config)
    }

    // MARK: - GameEnginePlatformView Implementation

    public override func createEngine() {
        // Register as active controller for C bridge functions
        self.registerAsActive()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let utils = UnityPlayerUtils.shared
            
            // Check if Unity integration was initialized in AppDelegate
            if !utils.isIntegrationInitialized() {
                NSLog("UnityEngineController: Warning - Unity integration not initialized in AppDelegate")
                NSLog("UnityEngineController: Call UnityPlayerUtils.shared.InitUnityIntegrationWithOptions() in AppDelegate")
            }
            
            // Initialize Unity if not already done (calls runEmbedded)
            if !utils.isUnityReady() {
                guard utils.initializeUnity() else {
                    self.sendEvent(name: "onError", data: ["message": "Failed to initialize Unity. Make sure Unity integration is initialized in AppDelegate."])
                    return
                }
            }
            
            // Get Unity framework from utils
            guard let unity = utils.getUnityFramework() else {
                self.sendEvent(name: "onError", data: ["message": "Failed to get Unity framework"])
                return
            }
            
            self.unityFramework = unity
            
            // Register Unity framework with Objective-C bridge for native methods
            let frameworkPtr = Unmanaged.passUnretained(unity as AnyObject).toOpaque()
            SetUnityFramework(frameworkPtr)
            NSLog("UnityEngineController: Unity framework registered with Objective-C bridge")
            
            // Register as listener for Unity events
            unity.register(self)
            
            // Show Unity window
            unity.showUnityWindow()

            // Get Unity view with retry logic
            // Unity's view hierarchy may not be immediately ready after runEmbedded()
            // The waitForUnityView method handles retrying and sends events when ready
            self.waitForUnityView(utils: utils, retries: 10)
        }
    }

    public override func attachEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let unityView = self.unityView else { return }

            // Remove Unity view from its current superview if it has one
            // This is critical - Unity may have added the view to its own window hierarchy
            if let superview = unityView.superview {
                unityView.removeFromSuperview()
                superview.layoutIfNeeded()
            }

            // Add Unity view to our container
            self.addEngineView(unityView)
            // Force layout update to ensure Unity view is properly sized
            unityView.layoutIfNeeded()
            
            self.sendEvent(name: "onAttached", data: nil)
        }
    }
    
    /// Wait for Unity view to become available with retry logic
    /// Unity's view hierarchy may not be immediately ready after runEmbedded()
    private func waitForUnityView(utils: UnityPlayerUtils, retries: Int, attempt: Int = 0) {
        if let unityView = utils.getUnityView() {
            // Unity view is ready - attach it
            self.unityView = unityView
            self.attachEngine()
            NSLog("UnityEngineController: Unity view attached successfully")
            
            // Mark as ready after view is attached
            self._isReady = true
            self.unityReady = true
            
            self.sendEvent(name: "onCreated", data: nil)
            self.sendEvent(name: "onLoaded", data: nil)
            
            // Flush any queued messages now that Flutter is ready
            self.flushMessageQueue()
        } else if attempt < retries {
            // Unity view not ready yet, retry after a short delay
            let delayMs = 100 * (attempt + 1) // 100ms, 200ms, 300ms, 400ms, 500ms
            NSLog("UnityEngineController: Unity view not ready, retrying in \(delayMs)ms (attempt \(attempt + 1)/\(retries))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self] in
                self?.waitForUnityView(utils: utils, retries: retries, attempt: attempt + 1)
            }
        } else {
            // All retries exhausted
            NSLog("UnityEngineController: ERROR - Unity view not available after \(retries) attempts")
            self.sendEvent(name: "onError", data: ["message": "Unity view not available after initialization"])
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

            self.unityFramework?.pause(true)
            self._isPaused = true
            self.sendEvent(name: "onPaused", data: nil)
        }
    }

    public override func resumeEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.unityFramework?.pause(false)
            self._isPaused = false
            self.sendEvent(name: "onResumed", data: nil)
        }
    }

    public override func unloadEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Unity on iOS doesn't support unloading without destroying
            // We'll pause it instead
            self.pauseEngine()
            self.sendEvent(name: "onUnloaded", data: nil)
        }
    }

    public override func destroyEngine() {
        // Unregister as active controller
        self.unregisterAsActive()
        
        // Reset message queue state
        messageQueueLock.lock()
        messageQueue.removeAll()
        isMessageChannelReady = false
        messageQueueLock.unlock()
        
        // Clear Unity framework reference from Objective-C bridge
        SetUnityFramework(nil)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.unityFramework?.unloadApplication()
            self.unityFramework?.unregisterFrameworkListener(self)
            self.unityFramework = nil
            self.unityView = nil
            self.unityReady = false
            self._isReady = false
            self._isPaused = false

            self.sendEvent(name: "onDestroyed", data: nil)
        }
    }

    public override func sendMessage(target: String, method: String, data: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Send message to Unity using UnitySendMessage
            self.unityFramework?.sendMessageToGO(
                withName: target,
                functionName: method,
                message: data
            )
        }
    }

    public override var engineType: String {
        return UnityEngineController.engineTypeValue
    }

    public override var engineVersion: String {
        return UnityEngineController.engineVersionValue
    }

    // MARK: - Unity Framework Loader

    private func loadUnityFramework() -> UnityFramework? {
        let bundlePath = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"

        let bundle = Bundle(path: bundlePath)
        if bundle?.isLoaded == false {
            bundle?.load()
        }

        let ufw = bundle?.principalClass?.getInstance()
        return ufw as? UnityFramework
    }

    // MARK: - Unity Lifecycle Callbacks

    /**
     * Called from Unity when a message is sent to Flutter
     * Messages are queued if the Flutter message channel isn't ready yet
     * 
     * Note: The Objective-C selector is explicitly defined to match FlutterBridge.mm
     */
    @objc(onUnityMessageWithTarget:method:data:)
    public func onUnityMessage(target: String, method: String, data: String) {
        messageQueueLock.lock()
        defer { messageQueueLock.unlock() }
        
        if !isMessageChannelReady {
            NSLog("UnityEngineController: Queueing message (channel not ready): \(target).\(method)")
            messageQueue.append((target, method, data))
            
            // Limit queue size to prevent memory issues
            if messageQueue.count > 100 {
                NSLog("UnityEngineController: Message queue overflow, dropping oldest message")
                messageQueue.removeFirst()
            }
            return
        }
        
        NSLog("UnityEngineController: Forwarding message to Flutter: \(target).\(method)")
        sendEvent(name: "onMessage", data: [
            "target": target,
            "method": method,
            "data": data
        ])
    }
    
    /**
     * Flush all queued messages to Flutter
     * Called when the message channel becomes ready
     */
    private func flushMessageQueue() {
        messageQueueLock.lock()
        let queuedMessages = messageQueue
        messageQueue.removeAll()
        isMessageChannelReady = true
        messageQueueLock.unlock()
        
        if !queuedMessages.isEmpty {
            NSLog("UnityEngineController: Flushing \(queuedMessages.count) queued messages")
            for msg in queuedMessages {
                sendEvent(name: "onMessage", data: [
                    "target": msg.target,
                    "method": msg.method,
                    "data": msg.data
                ])
            }
        } else {
            NSLog("UnityEngineController: Message channel ready (no queued messages)")
        }
    }

    /**
     * Called from Unity when a scene is loaded
     */
    public func onUnitySceneLoaded(name: String, buildIndex: Int) {
        sendEvent(name: "onSceneLoaded", data: [
            "name": name,
            "buildIndex": buildIndex,
            "isLoaded": true,
            "isValid": true,
            "metadata": [String: Any]()
        ])
    }

    // MARK: - Streaming Cache Path
    
    /**
     * Set the streaming cache path for Unity Addressables
     *
     * This configures Unity to load asset bundles from the specified path
     * instead of the default remote URLs.
     */
    public override func setStreamingCachePath(_ path: String) {
        NSLog("UnityEngineController: Setting streaming cache path: \(path)")
        
        // Create directory if needed
        let fileManager = FileManager.default
        let cacheDir = URL(fileURLWithPath: path)
        
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            } catch {
                NSLog("UnityEngineController: Failed to create cache directory: \(error)")
                sendEvent(name: "onError", data: [
                    "message": "Failed to create cache directory: \(error.localizedDescription)"
                ])
                return
            }
        }
        
        // Set user default for Unity to pick up
        UserDefaults.standard.set(path, forKey: "unity_streaming_assets_path")
        
        // Also send to Unity via message if ready
        if unityReady {
            sendMessage(
                target: "FlutterAddressablesManager",
                method: "SetCachePath",
                data: path
            )
        }
        
        NSLog("UnityEngineController: Streaming cache path set to: \(path)")
        sendEvent(name: "onStreamingCachePathSet", data: ["path": path])
    }
    
    // MARK: - Cleanup

    deinit {
        unregisterAsActive()
        destroyEngine()
    }
    
    // MARK: - Active Controller Tracking
    
    private static var _activeController: UnityEngineController?
    
    /// Store the active controller for bridge access
    static var activeController: UnityEngineController? {
        get { return _activeController }
        set { _activeController = newValue }
    }
    
    /// Register this controller as the active one
    /// This also registers with the Objective-C bridge for Unity messaging
    func registerAsActive() {
        UnityEngineController.activeController = self
        
        // Register with Objective-C bridge so Unity's SendMessageToFlutter can reach us
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        SetFlutterBridgeController(selfPtr)
        
        NSLog("UnityEngineController: Registered controller with Objective-C bridge")
    }
    
    /// Unregister this controller
    /// This also clears the Objective-C bridge reference
    func unregisterAsActive() {
        if UnityEngineController.activeController === self {
            UnityEngineController.activeController = nil
            SetFlutterBridgeController(nil)
            NSLog("UnityEngineController: Unregistered controller from Objective-C bridge")
        }
    }
}

// MARK: - UnityFramework Extensions

extension UnityFramework {
    func unloadApplication() {
        // Note: UnityFrameworkUnload may not be available in all Unity versions
        // The framework will be deallocated when the view controller is destroyed
        // If you need explicit unloading, you may need to implement it differently
        // based on your Unity version
    }

    func showUnityWindow() {
        if let appController = self.appController() {
            appController.window?.makeKeyAndVisible()
        }
    }
}

// MARK: - UnityFrameworkListener Protocol

extension UnityEngineController: UnityFrameworkListener {
    public func unityDidUnload(_ notification: Notification!) {
        sendEvent(name: "onUnloaded", data: nil)
    }

    public func unityDidQuit(_ notification: Notification!) {
        sendEvent(name: "onDestroyed", data: nil)
    }
}
