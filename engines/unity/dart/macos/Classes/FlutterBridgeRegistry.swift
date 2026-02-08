import Foundation

/// Registry for the Flutter bridge controller on macOS.
/// This class is discoverable via Objective-C runtime from UnityFramework's FlutterBridge.mm
///
/// The key insight is that Objective-C runtime (`NSClassFromString`) works across modules,
/// while `dlsym` for C functions in dynamically loaded frameworks is unreliable.
@objc(FlutterBridgeRegistry)
public class FlutterBridgeRegistry: NSObject {

    /// Shared controller instance - accessed by FlutterBridge.mm
    @objc public static var sharedController: NSObject? {
        get { return _sharedController }
        set {
            _sharedController = newValue
            if newValue != nil {
                NSLog("FlutterBridgeRegistry [macOS]: Controller registered")
            } else {
                NSLog("FlutterBridgeRegistry [macOS]: Controller unregistered")
            }
        }
    }
    private static var _sharedController: NSObject?

    /// Shared UnityFramework instance - accessed by FlutterBridge.mm
    @objc public static var sharedUnityFramework: NSObject? {
        get { return _sharedUnityFramework }
        set {
            _sharedUnityFramework = newValue
            if newValue != nil {
                NSLog("FlutterBridgeRegistry [macOS]: UnityFramework registered")
            } else {
                NSLog("FlutterBridgeRegistry [macOS]: UnityFramework unregistered")
            }
        }
    }
    private static var _sharedUnityFramework: NSObject?

    /// Register a controller with the bridge
    @objc public class func register(controller: NSObject) {
        sharedController = controller
    }

    /// Register the Unity framework
    @objc public class func register(unityFramework: NSObject) {
        sharedUnityFramework = unityFramework
    }

    /// Unregister all references
    @objc public class func unregisterAll() {
        sharedController = nil
        sharedUnityFramework = nil
    }

    /// Check if the bridge is ready
    @objc public class func isReady() -> Bool {
        return sharedController != nil
    }
}
