import Foundation
import UnityFramework

/**
 * C Bridge functions for Unity-Flutter communication
 * 
 * These functions are called from Unity's C# code (NativeAPI.cs) via [DllImport("__Internal")]
 * They provide the bridge between Unity's C# and the Swift UnityEngineController.
 * 
 * Pattern mirrors Android's approach:
 * - Android uses Java reflection to call controller methods
 * - iOS uses C bridge functions with @_cdecl to call controller methods
 * 
 * All bridge functions follow the same pattern:
 * 1. Get the shared registry
 * 2. Find the UnityEngineController for the Unity view
 * 3. Call the appropriate method on the controller
 */

/// Get the Unity controller from the registry
/// This searches for an active UnityEngineController instance
private func getUnityController() -> UnityEngineController? {
    // Import is at top, but we need to access GameEngineRegistry
    // GameEngineRegistry.shared would work if it's accessible
    // For now, we'll use a simpler approach via NotificationCenter
    return UnityEngineController.activeController
}

// MARK: - Unity to Flutter Bridge Functions

/**
 * Called from Unity to send a structured message to Flutter
 * Matches Android's SendToFlutterAndroid(target, method, data)
 */
@_cdecl("_sendMessageToFlutter")
public func sendMessageToFlutter(_ messagePtr: UnsafePointer<CChar>?) {
    guard let messagePtr = messagePtr else { return }
    let message = String(cString: messagePtr)
    
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
    }
}

/**
 * Called from Unity to notify Flutter that Unity is ready
 * Matches Android's SendToFlutterAndroid("Unity", "onReady", "")
 */
@_cdecl("_notifyUnityReady")
public func notifyUnityReady() {
    if let controller = getUnityController() {
        controller.onUnityMessage(target: "Unity", method: "onReady", data: "")
    }
}

/**
 * Called from Unity to show the Flutter host window
 * Matches Android's SendToFlutterAndroid("Unity", "showHostWindow", "")
 */
@_cdecl("_showHostMainWindow")
public func showHostMainWindow() {
    if let controller = getUnityController() {
        controller.onUnityMessage(target: "Unity", method: "showHostWindow", data: "")
    }
}

/**
 * Called from Unity to unload Unity from memory
 * Matches Android's SendToFlutterAndroid("Unity", "unload", "")
 */
@_cdecl("_unloadUnity")
public func unloadUnity() {
    if let controller = getUnityController() {
        controller.onUnityMessage(target: "Unity", method: "unload", data: "")
        controller.destroyEngine()
    }
}

/**
 * Called from Unity to quit Unity application
 * Matches Android's SendToFlutterAndroid("Unity", "quit", "")
 */
@_cdecl("_quitUnity")
public func quitUnity() {
    if let controller = getUnityController() {
        controller.onUnityMessage(target: "Unity", method: "quit", data: "")
        controller.destroyEngine()
    }
}

// Note: Active controller tracking is now in UnityEngineController.swift

