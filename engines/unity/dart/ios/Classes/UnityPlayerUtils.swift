import Foundation
import UIKit
import UnityFramework

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
    
    /// Get Unity view
    @objc public func getUnityView() -> UIView? {
        return unityFramework?.appController()?.rootViewController?.view
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

// MARK: - UnityFramework Extension

/// Extension to get Unity framework instance
extension UnityFramework {
    @objc public static func getInstance() -> UnityFramework? {
        return UnityPlayerUtils.shared.getUnityFramework()
    }
}

