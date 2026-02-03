import Foundation
import UIKit
import UnityFramework

// MARK: - Global Variables for Unity Initialization

/// Command-line argument count for Unity initialization
private var gArgc: Int32 = 0

/// Command-line argument values for Unity initialization
private var gArgv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>? = nil

/// Application launch options for Unity initialization
private var appLaunchOpts: [UIApplication.LaunchOptionsKey: Any]? = nil

/// Unity Player utility class for managing Unity framework lifecycle
///
/// Provides utility methods for Unity player management in Flutter integration.
/// Based on flutter-unity-view-widget UnityPlayerUtils.swift
/// https://github.com/juicycleff/flutter-unity-view-widget
@objc public class UnityPlayerUtils: NSObject {
    
    /// Shared instance
    @objc public static let shared = UnityPlayerUtils()
    
    /// Reference to Unity framework
    private var unityFramework: UnityFramework?
    
    /// Application delegate reference
    private weak var appDelegate: UIApplicationDelegate?
    
    /// Is Unity loaded flag
    @objc public private(set) var isUnityLoaded: Bool = false
    
    /// Is Unity paused flag
    @objc public private(set) var isUnityPaused: Bool = false
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Unity Integration Setup
    
    /// Initialize Unity integration with command-line arguments
    /// Call this from AppDelegate.application(_:didFinishLaunchingWithOptions:)
    /// 
    /// - Parameters:
    ///   - argc: Command-line argument count (CommandLine.argc)
    ///   - argv: Command-line argument values (CommandLine.unsafeArgv)
    ///   - launchingOptions: Application launch options from didFinishLaunchingWithOptions
    @objc public func InitUnityIntegrationWithOptions(
        argc: Int32,
        argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?,
        _ launchingOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        gArgc = argc
        gArgv = argv
        appLaunchOpts = launchingOptions
        NSLog("UnityPlayerUtils: Unity integration options initialized")
    }
    
    /// Initialize and run Unity embedded in the app
    /// This must be called after InitUnityIntegrationWithOptions
    /// 
    /// - Returns: true if Unity was initialized successfully, false otherwise
    @objc public func initializeUnity() -> Bool {
        // Check if already initialized
        if isUnityReady() {
            NSLog("UnityPlayerUtils: Unity already initialized")
            return true
        }
        
        // Load Unity framework
        guard let framework = loadUnityFramework() else {
            NSLog("UnityPlayerUtils: Failed to load Unity framework")
            return false
        }
        
        // Set Unity data bundle ID
        framework.setDataBundleId("com.unity3d.framework")
        
        // Run Unity embedded with command-line arguments
        // This is the critical call that actually starts Unity!
        framework.runEmbedded(withArgc: gArgc, argv: gArgv, appLaunchOpts: appLaunchOpts)
        
        // Set Unity's window level below Flutter's window
        // This ensures Flutter UI renders on top of Unity, not the other way around
        if let window = framework.appController()?.window {
            window.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue - 1)
        }
        
        // Configure gesture handling to prevent "System gesture gate timed out" errors
        // This happens when iOS system gestures conflict with Unity's touch handling
        configureGestureHandling(framework: framework)
        
        NSLog("UnityPlayerUtils: Unity initialized and running embedded")
        return true
    }
    
    /// Configure gesture handling to prevent "System gesture gate timed out" errors
    /// This issue occurs when iOS system edge gestures conflict with Unity's touch handling
    private func configureGestureHandling(framework: UnityFramework) {
        guard let unityAppController = framework.appController() else {
            NSLog("UnityPlayerUtils: Cannot configure gestures - no app controller")
            return
        }
        
        // Get Unity's root view controller
        guard let rootVC = unityAppController.rootViewController else {
            NSLog("UnityPlayerUtils: Cannot configure gestures - no root view controller")
            return
        }
        
        // Swizzle the preferredScreenEdgesDeferringSystemGestures method to defer system gestures
        // This tells iOS to prioritize app gestures over system edge gestures
        swizzleScreenEdgesDeferring(for: type(of: rootVC))
        
        // Also configure the Unity view's gesture recognizers
        if let unityView = unityAppController.rootView {
            configureUnityViewGestures(unityView)
        }
        
        // Force the view controller to re-query gesture preferences
        rootVC.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        
        NSLog("UnityPlayerUtils: Gesture handling configured to prevent timeouts")
    }
    
    /// Configure Unity view gesture recognizers to reduce conflicts
    private func configureUnityViewGestures(_ view: UIView) {
        // Cancel touches in view should be NO to allow gestures to pass through properly
        for gestureRecognizer in view.gestureRecognizers ?? [] {
            gestureRecognizer.cancelsTouchesInView = false
            gestureRecognizer.delaysTouchesBegan = false
            gestureRecognizer.delaysTouchesEnded = false
        }
        
        // Recursively configure subviews
        for subview in view.subviews {
            configureUnityViewGestures(subview)
        }
    }
    
    /// Swizzle preferredScreenEdgesDeferringSystemGestures to return .all
    /// This defers system edge gestures, giving the app priority
    private var hasSwizzled = false
    private func swizzleScreenEdgesDeferring(for viewControllerClass: AnyClass) {
        guard !hasSwizzled else { return }
        hasSwizzled = true
        
        let originalSelector = #selector(getter: UIViewController.preferredScreenEdgesDeferringSystemGestures)
        let swizzledSelector = #selector(UnityPlayerUtils.swizzled_preferredScreenEdgesDeferringSystemGestures)
        
        guard let originalMethod = class_getInstanceMethod(viewControllerClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UnityPlayerUtils.self, swizzledSelector) else {
            NSLog("UnityPlayerUtils: Failed to swizzle preferredScreenEdgesDeferringSystemGestures")
            return
        }
        
        // Add the swizzled method to the view controller class
        let didAddMethod = class_addMethod(
            viewControllerClass,
            swizzledSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )
        
        if didAddMethod {
            // Replace the original with our implementation
            class_replaceMethod(
                viewControllerClass,
                originalSelector,
                method_getImplementation(swizzledMethod),
                method_getTypeEncoding(swizzledMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        
        NSLog("UnityPlayerUtils: Swizzled preferredScreenEdgesDeferringSystemGestures to defer all edges")
    }
    
    /// Swizzled implementation that defers system gestures on all edges
    @objc func swizzled_preferredScreenEdgesDeferringSystemGestures() -> UIRectEdge {
        return .all
    }
    
    /// Check if Unity integration options have been set
    @objc public func isIntegrationInitialized() -> Bool {
        return gArgv != nil
    }
    
    /// Public method to reconfigure gesture handling
    /// Call this if you experience gesture timeouts after Unity view changes
    @objc public func reconfigureGestureHandling() {
        guard let framework = unityFramework else {
            NSLog("UnityPlayerUtils: Cannot reconfigure gestures - Unity not loaded")
            return
        }
        configureGestureHandling(framework: framework)
    }
    
    // MARK: - Unity Framework Management
    
    /// Load Unity framework
    @objc public func loadUnityFramework() -> UnityFramework? {
        if unityFramework != nil {
            return unityFramework
        }
        
        let bundlePath = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"
        let bundle = Bundle(path: bundlePath)
        
        if bundle == nil {
            NSLog("UnityPlayerUtils: UnityFramework.framework not found at path: \(bundlePath)")
            return nil
        }
        
        if !bundle!.isLoaded {
            bundle!.load()
        }
        
        guard let framework = bundle!.principalClass?.getInstance() as? UnityFramework else {
            NSLog("UnityPlayerUtils: Failed to get UnityFramework instance")
            return nil
        }
        
        unityFramework = framework
        isUnityLoaded = true
        
        NSLog("UnityPlayerUtils: Unity framework loaded successfully")
        return framework
    }
    
    /// Get Unity framework instance
    @objc public func getUnityFramework() -> UnityFramework? {
        return unityFramework
    }
    
    /// Check if Unity is loaded
    @objc public func isLoaded() -> Bool {
        return unityFramework != nil && isUnityLoaded
    }
    
    // MARK: - Unity Lifecycle
    
    /// Show Unity view
    @objc public func showUnity() {
        if let framework = unityFramework {
            framework.showUnityWindow()
            isUnityPaused = false
            NSLog("UnityPlayerUtils: Unity view shown")
        } else {
            NSLog("UnityPlayerUtils: Cannot show Unity - framework not loaded")
        }
    }
    
    /// Hide Unity view
    @objc public func hideUnity() {
        if let framework = unityFramework {
            // Unity doesn't have a built-in hide, so we pause it
            framework.pause(true)
            isUnityPaused = true
            NSLog("UnityPlayerUtils: Unity view hidden (paused)")
        }
    }
    
    /// Pause Unity
    @objc public func pauseUnity() {
        if let framework = unityFramework {
            framework.pause(true)
            isUnityPaused = true
            NSLog("UnityPlayerUtils: Unity paused")
        }
    }
    
    /// Resume Unity
    @objc public func resumeUnity() {
        if let framework = unityFramework {
            framework.pause(false)
            isUnityPaused = false
            NSLog("UnityPlayerUtils: Unity resumed")
        }
    }
    
    /// Unload Unity
    @objc public func unloadUnity() {
        if let framework = unityFramework {
            framework.unloadApplication()
            unityFramework = nil
            isUnityLoaded = false
            isUnityPaused = false
            NSLog("UnityPlayerUtils: Unity unloaded")
        }
    }
    
    /// Quit Unity
    @objc public func quitUnity() {
        if let framework = unityFramework {
            framework.quitApplication(0)
            unityFramework = nil
            isUnityLoaded = false
            isUnityPaused = false
            NSLog("UnityPlayerUtils: Unity quit")
        }
    }
    
    // MARK: - Unity Messaging
    
    /// Send message to Unity GameObject
    @objc public func sendMessage(toGameObject gameObject: String, 
                                  methodName: String, 
                                  message: String) {
        if let framework = unityFramework {
            framework.sendMessageToGO(withName: gameObject, 
                                     functionName: methodName, 
                                     message: message)
            NSLog("UnityPlayerUtils: Sent message to GameObject '\(gameObject)' method '\(methodName)'")
        } else {
            NSLog("UnityPlayerUtils: Cannot send message - Unity framework not loaded")
        }
    }
    
    // MARK: - App Lifecycle Forwarding
    
    /// Forward application lifecycle events to Unity
    @objc public func applicationDidBecomeActive() {
        if let framework = unityFramework {
            framework.appController()?.applicationDidBecomeActive(UIApplication.shared)
            NSLog("UnityPlayerUtils: Application became active")
        }
    }
    
    @objc public func applicationWillResignActive() {
        if let framework = unityFramework {
            framework.appController()?.applicationWillResignActive(UIApplication.shared)
            NSLog("UnityPlayerUtils: Application will resign active")
        }
    }
    
    @objc public func applicationDidEnterBackground() {
        if let framework = unityFramework {
            framework.appController()?.applicationDidEnterBackground(UIApplication.shared)
            pauseUnity()
            NSLog("UnityPlayerUtils: Application entered background")
        }
    }
    
    @objc public func applicationWillEnterForeground() {
        if let framework = unityFramework {
            framework.appController()?.applicationWillEnterForeground(UIApplication.shared)
            NSLog("UnityPlayerUtils: Application will enter foreground")
        }
    }
    
    @objc public func applicationWillTerminate() {
        if let framework = unityFramework {
            framework.appController()?.applicationWillTerminate(UIApplication.shared)
            NSLog("UnityPlayerUtils: Application will terminate")
        }
    }
    
    // MARK: - Memory Management
    
    @objc public func applicationDidReceiveMemoryWarning() {
        if let framework = unityFramework {
            framework.appController()?.applicationDidReceiveMemoryWarning(UIApplication.shared)
            NSLog("UnityPlayerUtils: Received memory warning")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get Unity view (uses rootView directly, which is more reliable than rootViewController.view)
    @objc public func getUnityView() -> UIView? {
        return unityFramework?.appController()?.rootView
    }
    
    /// Check if Unity view is available and ready to be attached
    @objc public func isUnityViewReady() -> Bool {
        return unityFramework?.appController()?.rootView != nil
    }
    
    /// Check if Unity is ready
    @objc public func isUnityReady() -> Bool {
        return unityFramework != nil && 
               unityFramework!.appController() != nil && 
               isUnityLoaded
    }
    
    /// Get Unity root view controller
    @objc public func getUnityRootViewController() -> UIViewController? {
        return unityFramework?.appController()?.rootViewController
    }
}

// Note: DO NOT add an extension that overrides UnityFramework.getInstance()
// The getInstance() method is provided by Unity's UnityFramework class itself
// and must not be overridden as it would create a circular dependency.
