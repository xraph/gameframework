package com.xraph.gameframework.unreal

import android.util.Log

/**
 * Registry for the Flutter bridge controller.
 * 
 * This singleton class is accessible from Unreal C++ via JNI (JNIEnv).
 * It provides a reliable way for Unreal to find the active UnrealEngineController
 * without relying on Activity methods that may not exist.
 * 
 * This is the Android equivalent of iOS's FlutterBridgeRegistry.swift.
 * 
 * Usage from Unreal C++:
 * ```cpp
 * JNIEnv* Env = FAndroidApplication::GetJavaEnv();
 * jclass RegistryClass = Env->FindClass("com/xraph/gameframework/unreal/FlutterBridgeRegistry");
 * jmethodID GetController = Env->GetStaticMethodID(RegistryClass, "getSharedController", 
 *     "()Lcom/xraph/gameframework/unreal/UnrealEngineController;");
 * jobject Controller = Env->CallStaticObjectMethod(RegistryClass, GetController);
 * if (Controller != nullptr) {
 *     // Send message to Flutter
 * }
 * ```
 */
object FlutterBridgeRegistry {
    
    private const val TAG = "FlutterBridgeRegistry"
    
    init {
        Log.d(TAG, "FlutterBridgeRegistry initialized (static init)")
    }
    
    /**
     * The currently active UnrealEngineController.
     * Set when a controller registers, cleared when it unregisters.
     */
    @Volatile
    private var _sharedController: UnrealEngineController? = null
    
    /**
     * Track all registered controllers for multi-instance support.
     */
    private val _controllers = mutableMapOf<Int, UnrealEngineController>()
    
    /**
     * Current platform view mode.
     */
    @Volatile
    private var _platformViewMode: PlatformViewMode = PlatformViewMode.VIRTUAL_DISPLAY
    
    /**
     * Platform view mode enumeration.
     */
    enum class PlatformViewMode {
        VIRTUAL_DISPLAY,   // Default - renders in virtual display texture
        HYBRID_COMPOSITION // Uses Android's hybrid composition mode
    }
    
    /**
     * Get the shared controller instance.
     * Called from Unreal C++ via JNI.
     * 
     * @return The active UnrealEngineController, or null if none registered.
     */
    @JvmStatic
    fun getSharedController(): UnrealEngineController? {
        return _sharedController
    }
    
    /**
     * Get a specific controller by ID.
     * Called from Unreal C++ via JNI for multi-instance support.
     * 
     * @param controllerId The unique controller ID.
     * @return The controller, or null if not found.
     */
    @JvmStatic
    fun getController(controllerId: Int): UnrealEngineController? {
        return _controllers[controllerId]
    }
    
    /**
     * Get all registered controller IDs.
     * 
     * @return Array of registered controller IDs.
     */
    @JvmStatic
    fun getRegisteredControllerIds(): IntArray {
        return _controllers.keys.toIntArray()
    }
    
    /**
     * Check if a controller is registered.
     * Called from Unreal C++ via JNI.
     * 
     * @return true if a controller is registered, false otherwise.
     */
    @JvmStatic
    fun isReady(): Boolean {
        return _sharedController != null
    }
    
    /**
     * Get the current platform view mode.
     * 
     * @return The current PlatformViewMode.
     */
    @JvmStatic
    fun getPlatformViewMode(): PlatformViewMode {
        return _platformViewMode
    }
    
    /**
     * Get the platform view mode as a string.
     * 
     * @return "virtualDisplay" or "hybridComposition"
     */
    @JvmStatic
    fun getPlatformViewModeString(): String {
        return when (_platformViewMode) {
            PlatformViewMode.VIRTUAL_DISPLAY -> "virtualDisplay"
            PlatformViewMode.HYBRID_COMPOSITION -> "hybridComposition"
        }
    }
    
    /**
     * Set the platform view mode.
     * Should be called before creating controllers.
     * 
     * @param mode The PlatformViewMode to use.
     */
    @JvmStatic
    fun setPlatformViewMode(mode: PlatformViewMode) {
        _platformViewMode = mode
        Log.d(TAG, "Platform view mode set to: $mode")
    }
    
    /**
     * Set the platform view mode from a string.
     * 
     * @param modeString "virtualDisplay" or "hybridComposition"
     */
    @JvmStatic
    fun setPlatformViewModeFromString(modeString: String) {
        val mode = when (modeString.lowercase()) {
            "virtualDisplay", "virtualdisplay", "virtual_display" -> PlatformViewMode.VIRTUAL_DISPLAY
            "hybridComposition", "hybridcomposition", "hybrid_composition" -> PlatformViewMode.HYBRID_COMPOSITION
            else -> {
                Log.w(TAG, "Unknown platform view mode: $modeString, defaulting to VIRTUAL_DISPLAY")
                PlatformViewMode.VIRTUAL_DISPLAY
            }
        }
        setPlatformViewMode(mode)
    }
    
    /**
     * Register a controller with the registry.
     * Called by UnrealEngineController when it becomes active.
     * 
     * @param controller The controller to register.
     */
    @JvmStatic
    fun register(controller: UnrealEngineController) {
        _sharedController = controller
        _controllers[controller.hashCode()] = controller
        Log.d(TAG, "Controller registered (id: ${controller.hashCode()})")
    }
    
    /**
     * Register a controller with a specific ID.
     * 
     * @param controller The controller to register.
     * @param controllerId The unique ID for this controller.
     */
    @JvmStatic
    fun registerWithId(controller: UnrealEngineController, controllerId: Int) {
        _controllers[controllerId] = controller
        if (_sharedController == null) {
            _sharedController = controller
        }
        Log.d(TAG, "Controller registered with ID: $controllerId")
    }
    
    /**
     * Unregister a specific controller.
     * 
     * @param controller The controller to unregister.
     */
    @JvmStatic
    fun unregister(controller: UnrealEngineController) {
        val controllerId = controller.hashCode()
        _controllers.remove(controllerId)
        
        if (_sharedController == controller) {
            _sharedController = _controllers.values.firstOrNull()
        }
        
        Log.d(TAG, "Controller unregistered (id: $controllerId)")
    }
    
    /**
     * Unregister a controller by ID.
     * 
     * @param controllerId The ID of the controller to unregister.
     */
    @JvmStatic
    fun unregisterById(controllerId: Int) {
        val controller = _controllers.remove(controllerId)
        
        if (_sharedController == controller) {
            _sharedController = _controllers.values.firstOrNull()
        }
        
        Log.d(TAG, "Controller unregistered by ID: $controllerId")
    }
    
    /**
     * Unregister all controllers.
     * Called when the plugin is detached.
     */
    @JvmStatic
    fun unregisterAll() {
        _sharedController = null
        _controllers.clear()
        Log.d(TAG, "All controllers unregistered")
    }
    
    /**
     * Send a message from Unreal to Flutter.
     * This is the main entry point for Unreal→Flutter communication.
     * Called from Unreal C++ via JNI.
     * 
     * @param target The target component name (e.g., "GameManager")
     * @param method The method name (e.g., "onScoreChanged")
     * @param data The JSON data string
     * @return true if the message was sent, false if no controller is registered
     */
    @JvmStatic
    fun sendMessageToFlutter(target: String, method: String, data: String): Boolean {
        Log.d(TAG, ">>> sendMessageToFlutter called from Unreal!")
        Log.d(TAG, "    Target: $target, Method: $method")
        Log.d(TAG, "    Data length: ${data.length}")
        
        val controller = _sharedController
        if (controller == null) {
            Log.e(TAG, "Cannot send message - no controller registered!")
            Log.e(TAG, "  Target: $target, Method: $method")
            Log.e(TAG, "  Fix: Ensure UnrealEngineController.register() is called before Unreal sends messages")
            return false
        }
        
        Log.d(TAG, "Controller found, forwarding to onMessageFromUnreal")
        controller.onMessageFromUnreal(target, method, data)
        Log.d(TAG, "<<< Message forwarded successfully")
        return true
    }
    
    /**
     * Send a message to a specific controller.
     * 
     * @param controllerId The target controller ID.
     * @param target The target component name.
     * @param method The method name.
     * @param data The JSON data string.
     * @return true if the message was sent, false if controller not found.
     */
    @JvmStatic
    fun sendMessageToController(controllerId: Int, target: String, method: String, data: String): Boolean {
        val controller = _controllers[controllerId]
        if (controller == null) {
            Log.e(TAG, "Cannot send message - controller $controllerId not found!")
            return false
        }
        
        controller.onMessageFromUnreal(target, method, data)
        return true
    }
    
    /**
     * Send binary data from Unreal to Flutter.
     * Called from Unreal C++ via JNI.
     * 
     * @param target The target component name.
     * @param method The method name.
     * @param data The binary data as base64 string.
     * @return true if the message was sent, false if no controller is registered.
     */
    @JvmStatic
    fun sendBinaryToFlutter(target: String, method: String, data: String): Boolean {
        val controller = _sharedController ?: return false
        // Convert base64 string to ByteArray
        val byteData = android.util.Base64.decode(data, android.util.Base64.DEFAULT)
        controller.onBinaryMessageFromUnreal(target, method, byteData, false, 0)
        return true
    }
    
    /**
     * Send a simple message from Unreal to Flutter.
     * Wraps the message as Unreal:onMessage.
     * Called from Unreal C++ via JNI.
     * 
     * @param message The message string
     * @return true if the message was sent, false if no controller is registered
     */
    @JvmStatic
    fun sendSimpleMessage(message: String): Boolean {
        return sendMessageToFlutter("Unreal", "onMessage", message)
    }
    
    /**
     * Notify Flutter that Unreal is ready.
     * Called from Unreal C++ via JNI.
     * 
     * @return true if the notification was sent, false if no controller is registered
     */
    @JvmStatic
    fun notifyUnrealReady(): Boolean {
        return sendMessageToFlutter("Unreal", "onReady", "true")
    }
    
    /**
     * Get controller count for debugging.
     * 
     * @return Number of registered controllers.
     */
    @JvmStatic
    fun getControllerCount(): Int {
        return _controllers.size
    }
}
