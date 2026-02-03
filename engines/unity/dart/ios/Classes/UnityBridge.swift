import Foundation
import UnityFramework

/**
 * C Bridge functions for Unity-Flutter communication
 * 
 * These functions are called from Unity's C# code via [DllImport("__Internal")]
 * They provide the bridge between Unity's C# and the Swift UnityEngineController.
 * 
 * IMPORTANT: These @_cdecl functions are exported from the Flutter plugin and are
 * available to Unity's DllImport because they're linked into the main app binary.
 * This is the primary mechanism for Unity→Flutter messaging on iOS.
 * 
 * Pattern mirrors Android's approach:
 * - Android uses Java reflection to call controller methods
 * - iOS uses C bridge functions with @_cdecl to call controller methods
 * 
 * All bridge functions follow the same pattern:
 * 1. Get the active UnityEngineController
 * 2. Call the appropriate method on the controller
 */

/// Get the Unity controller from the registry
/// This searches for an active UnityEngineController instance
private func getUnityController() -> UnityEngineController? {
    return UnityEngineController.activeController
}

// MARK: - Unity to Flutter Bridge Functions

/**
 * Called from Unity's FlutterBridge.cs to send a structured message to Flutter
 * This is the PRIMARY messaging function - handles target, method, and data separately
 * 
 * Unity C#: [DllImport("__Internal")] extern void SendMessageToFlutter(string target, string method, string data)
 */
@_cdecl("SendMessageToFlutter")
public func SendMessageToFlutter(
    _ targetPtr: UnsafePointer<CChar>?,
    _ methodPtr: UnsafePointer<CChar>?,
    _ dataPtr: UnsafePointer<CChar>?
) {
    let target = targetPtr.map { String(cString: $0) } ?? ""
    let method = methodPtr.map { String(cString: $0) } ?? ""
    let data = dataPtr.map { String(cString: $0) } ?? ""
    
    NSLog("✅ UnityBridge: SendMessageToFlutter called - \(target).\(method)")
    
    if let controller = getUnityController() {
        controller.onUnityMessage(target: target, method: method, data: data)
    } else {
        NSLog("❌ UnityBridge ERROR: No active controller - message dropped!")
        NSLog("   Target: \(target), Method: \(method)")
    }
}

/**
 * Called from Unity's NativeAPI.cs to send a simple message to Flutter
 * This is a secondary messaging function that takes a single JSON string
 * 
 * Unity C#: [DllImport("__Internal")] extern void _sendMessageToFlutter(string message)
 */
@_cdecl("_sendMessageToFlutter")
public func _sendMessageToFlutter(_ messagePtr: UnsafePointer<CChar>?) {
    guard let messagePtr = messagePtr else { return }
    let message = String(cString: messagePtr)
    
    NSLog("✅ UnityBridge: _sendMessageToFlutter called")
    
    // Parse the JSON message to extract target, method, data
    // Or call controller with raw message
    if let controller = getUnityController() {
        // Try to parse as JSON first
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let target = json["target"],
           let method = json["method"],
           let messageData = json["data"] {
            controller.onUnityMessage(target: target, method: method, data: messageData)
        } else {
            // Fallback: send as raw message
            controller.onUnityMessage(target: "Unity", method: "onMessage", data: message)
        }
    } else {
        NSLog("❌ UnityBridge ERROR: No active controller for _sendMessageToFlutter")
    }
}

/**
 * Called from Unity to notify Flutter that Unity is ready
 * Unity C#: [DllImport("__Internal")] extern void _notifyUnityReady()
 */
@_cdecl("_notifyUnityReady")
public func _notifyUnityReady() {
    NSLog("✅ UnityBridge: _notifyUnityReady called")
    if let controller = getUnityController() {
        controller.onUnityMessage(target: "Unity", method: "onReady", data: "true")
    } else {
        NSLog("❌ UnityBridge ERROR: No active controller for _notifyUnityReady")
    }
}

/**
 * Called from Unity to show the Flutter host window
 * Unity C#: [DllImport("__Internal")] extern void _showHostMainWindow()
 */
@_cdecl("_showHostMainWindow")
public func _showHostMainWindow() {
    NSLog("✅ UnityBridge: _showHostMainWindow called")
    if let controller = getUnityController() {
        controller.onUnityMessage(target: "Unity", method: "showHostWindow", data: "")
    } else {
        NSLog("❌ UnityBridge ERROR: No active controller for _showHostMainWindow")
    }
}

/**
 * Called from Unity to unload Unity from memory
 * Unity C#: [DllImport("__Internal")] extern void _unloadUnity()
 */
@_cdecl("_unloadUnity")
public func _unloadUnity() {
    NSLog("✅ UnityBridge: _unloadUnity called")
    if let controller = getUnityController() {
        controller.onUnityMessage(target: "Unity", method: "unload", data: "")
        controller.destroyEngine()
    } else {
        NSLog("❌ UnityBridge ERROR: No active controller for _unloadUnity")
    }
}

/**
 * Called from Unity to quit Unity application
 * Unity C#: [DllImport("__Internal")] extern void _quitUnity()
 */
@_cdecl("_quitUnity")
public func _quitUnity() {
    NSLog("✅ UnityBridge: _quitUnity called")
    if let controller = getUnityController() {
        controller.onUnityMessage(target: "Unity", method: "quit", data: "")
        controller.destroyEngine()
    } else {
        NSLog("❌ UnityBridge ERROR: No active controller for _quitUnity")
    }
}

// Note: Active controller tracking is in UnityEngineController.swift
// The activeController property is set when createEngine() calls registerAsActive()

