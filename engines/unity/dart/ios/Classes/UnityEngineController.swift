import Flutter
import UIKit
import UnityFramework
import gameframework

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

            do {
                // Load Unity framework
                self.unityFramework = self.loadUnityFramework()

                guard let unity = self.unityFramework else {
                    self.sendEvent(name: "onError", data: ["message": "Failed to load Unity framework"])
                    return
                }

                // Set up Unity framework
                unity.setDataBundleId("com.unity3d.framework")
                unity.register(self)

                // Show Unity view
                unity.showUnityWindow()

                // Get Unity view
                if let unityView = unity.appController()?.rootViewController?.view {
                    self.unityView = unityView
                    self.attachEngine()
                }

                // Mark as ready
                self._isReady = true
                self.unityReady = true

                self.sendEvent(name: "onCreated", data: nil)
                self.sendEvent(name: "onLoaded", data: nil)

            } catch {
                self.sendEvent(name: "onError", data: ["message": error.localizedDescription])
            }
        }
    }

    public override func attachEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let unityView = self.unityView else { return }

            if unityView.superview == nil {
                self.addEngineView(unityView)
                self.sendEvent(name: "onAttached", data: nil)
            }
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
     */
    public func onUnityMessage(target: String, method: String, data: String) {
        sendEvent(name: "onMessage", data: [
            "target": target,
            "method": method,
            "data": data
        ])
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
    func registerAsActive() {
        UnityEngineController.activeController = self
    }
    
    /// Unregister this controller
    func unregisterAsActive() {
        if UnityEngineController.activeController === self {
            UnityEngineController.activeController = nil
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
