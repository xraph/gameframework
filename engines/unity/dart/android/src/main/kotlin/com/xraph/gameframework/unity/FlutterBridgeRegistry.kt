package com.xraph.gameframework.unity

import android.util.Log

/**
 * Registry for the Flutter bridge controller.
 * 
 * This singleton class is accessible from Unity C# via JNI (AndroidJavaClass).
 * It provides a reliable way for Unity to find the active UnityEngineController
 * without relying on Activity methods that may not exist.
 * 
 * This is the Android equivalent of iOS's FlutterBridgeRegistry.swift.
 * 
 * Usage from Unity C#:
 * ```csharp
 * using (var registry = new AndroidJavaClass("com.xraph.gameframework.unity.FlutterBridgeRegistry"))
 * {
 *     var controller = registry.CallStatic<AndroidJavaObject>("getSharedController");
 *     if (controller != null)
 *     {
 *         controller.Call("onUnityMessage", target, method, data);
 *     }
 * }
 * ```
 */
object FlutterBridgeRegistry {
    
    private const val TAG = "FlutterBridgeRegistry"
    
    init {
        Log.d(TAG, "FlutterBridgeRegistry initialized (static init)")
    }
    
    /**
     * The currently active UnityEngineController.
     * Set when a controller registers, cleared when it unregisters.
     */
    @Volatile
    private var _sharedController: UnityEngineController? = null
    
    /**
     * The UnityPlayer instance (for utility functions).
     */
    @Volatile
    private var _sharedUnityPlayer: Any? = null
    
    /**
     * Get the shared controller instance.
     * Called from Unity C# via JNI.
     * 
     * @return The active UnityEngineController, or null if none registered.
     */
    @JvmStatic
    fun getSharedController(): UnityEngineController? {
        return _sharedController
    }
    
    /**
     * Get the shared UnityPlayer instance.
     * Called from Unity C# via JNI.
     * 
     * @return The UnityPlayer instance, or null if not set.
     */
    @JvmStatic
    fun getSharedUnityPlayer(): Any? {
        return _sharedUnityPlayer
    }
    
    /**
     * Check if a controller is registered.
     * Called from Unity C# via JNI.
     * 
     * @return true if a controller is registered, false otherwise.
     */
    @JvmStatic
    fun isReady(): Boolean {
        return _sharedController != null
    }
    
    /**
     * Register a controller with the registry.
     * Called by UnityEngineController when it becomes active.
     * 
     * @param controller The controller to register.
     */
    @JvmStatic
    fun register(controller: UnityEngineController) {
        _sharedController = controller
        Log.d(TAG, "Controller registered")
    }
    
    /**
     * Register the UnityPlayer instance.
     * Called by UnityEngineController when Unity is initialized.
     * 
     * @param unityPlayer The UnityPlayer instance.
     */
    @JvmStatic
    fun registerUnityPlayer(unityPlayer: Any?) {
        _sharedUnityPlayer = unityPlayer
        if (unityPlayer != null) {
            Log.d(TAG, "UnityPlayer registered")
        } else {
            Log.d(TAG, "UnityPlayer unregistered")
        }
    }
    
    /**
     * Unregister the current controller.
     * Called by UnityEngineController when it's destroyed.
     */
    @JvmStatic
    fun unregisterAll() {
        _sharedController = null
        _sharedUnityPlayer = null
        Log.d(TAG, "All references cleared")
    }
    
    /**
     * Send a message from Unity to Flutter.
     * This is the main entry point for Unity→Flutter communication.
     * Called from Unity C# via JNI.
     * 
     * @param target The target component name (e.g., "GameFrameworkDemo")
     * @param method The method name (e.g., "onCurrentSpeed")
     * @param data The JSON data string
     * @return true if the message was sent, false if no controller is registered
     */
    @JvmStatic
    fun sendMessageToFlutter(target: String, method: String, data: String): Boolean {
        Log.d(TAG, ">>> sendMessageToFlutter called from Unity!")
        Log.d(TAG, "    Target: $target, Method: $method")
        Log.d(TAG, "    Data length: ${data.length}")
        
        val controller = _sharedController
        if (controller == null) {
            Log.e(TAG, "Cannot send message - no controller registered!")
            Log.e(TAG, "  Target: $target, Method: $method")
            Log.e(TAG, "  Fix: Ensure UnityEngineController.register() is called before Unity sends messages")
            return false
        }
        
        Log.d(TAG, "Controller found, forwarding to onUnityMessage")
        controller.onUnityMessage(target, method, data)
        Log.d(TAG, "<<< Message forwarded successfully")
        return true
    }
    
    /**
     * Send a simple message from Unity to Flutter.
     * Wraps the message as Unity:onMessage.
     * Called from Unity C# via JNI.
     * 
     * @param message The message string
     * @return true if the message was sent, false if no controller is registered
     */
    @JvmStatic
    fun sendSimpleMessage(message: String): Boolean {
        return sendMessageToFlutter("Unity", "onMessage", message)
    }
    
    /**
     * Notify Flutter that Unity is ready.
     * Called from Unity C# via JNI.
     * 
     * @return true if the notification was sent, false if no controller is registered
     */
    @JvmStatic
    fun notifyUnityReady(): Boolean {
        return sendMessageToFlutter("Unity", "onReady", "true")
    }
}
