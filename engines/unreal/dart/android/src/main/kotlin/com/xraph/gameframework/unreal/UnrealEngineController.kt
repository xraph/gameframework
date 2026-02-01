package com.xraph.gameframework.unreal

import android.app.Activity
import android.content.Context
import android.view.View
import android.view.ViewGroup
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Unreal Engine Controller for Android
 *
 * Manages the Unreal Engine lifecycle, view integration, and communication
 * between Flutter and Unreal Engine on Android.
 */
class UnrealEngineController(
    private val context: Context,
    private val activity: Activity,
    private val viewId: Int,
    private val channel: MethodChannel,
    private val config: Map<String, Any>
) {
    private var unrealView: View? = null
    private val isReady = AtomicBoolean(false)
    private val isPaused = AtomicBoolean(false)
    private val isDestroyed = AtomicBoolean(false)

    companion object {
        private const val TAG = "UnrealEngineController"
        const val ENGINE_TYPE = "unreal"
        const val ENGINE_VERSION = "5.3.0"

        init {
            try {
                System.loadLibrary("UnrealFlutterBridge")
            } catch (e: UnsatisfiedLinkError) {
                // Library not available - Unreal native library not linked
                android.util.Log.w(TAG, "UnrealFlutterBridge native library not found")
            }
        }
    }

    // MARK: - Lifecycle Methods

    /**
     * Initialize and create the Unreal Engine instance
     */
    fun create(): Boolean {
        if (isDestroyed.get()) {
            sendError("Cannot create destroyed engine")
            return false
        }

        if (isReady.get()) {
            return true
        }

        try {
            // Initialize Unreal Engine native
            if (!nativeCreate(config)) {
                sendError("Failed to create Unreal Engine instance")
                return false
            }

            // Create Unreal view
            unrealView = nativeGetView()
            if (unrealView == null) {
                sendError("Failed to get Unreal view")
                return false
            }

            isReady.set(true)
            sendEvent("created")
            sendEvent("loaded")

            return true
        } catch (e: Exception) {
            sendError("Exception during engine creation: ${e.message}")
            return false
        }
    }

    /**
     * Pause the Unreal Engine
     */
    fun pause() {
        if (!isReady.get() || isDestroyed.get()) {
            return
        }

        try {
            nativePause()
            isPaused.set(true)
            sendEvent("paused")
        } catch (e: Exception) {
            sendError("Exception during pause: ${e.message}")
        }
    }

    /**
     * Resume the Unreal Engine
     */
    fun resume() {
        if (!isReady.get() || isDestroyed.get()) {
            return
        }

        try {
            nativeResume()
            isPaused.set(false)
            sendEvent("resumed")
        } catch (e: Exception) {
            sendError("Exception during resume: ${e.message}")
        }
    }

    /**
     * Unload the Unreal Engine (pause and detach)
     */
    fun unload() {
        if (!isReady.get() || isDestroyed.get()) {
            return
        }

        try {
            pause()
            sendEvent("unloaded")
        } catch (e: Exception) {
            sendError("Exception during unload: ${e.message}")
        }
    }

    /**
     * Quit and destroy the Unreal Engine
     */
    fun quit() {
        if (isDestroyed.get()) {
            return
        }

        try {
            nativeQuit()
            unrealView = null
            isReady.set(false)
            isDestroyed.set(true)
            sendEvent("destroyed")
        } catch (e: Exception) {
            sendError("Exception during quit: ${e.message}")
        }
    }

    // MARK: - Communication Methods

    /**
     * Send a message to Unreal Engine
     */
    fun sendMessage(target: String, method: String, data: String) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for messages")
            return
        }

        try {
            nativeSendMessage(target, method, data)
        } catch (e: Exception) {
            sendError("Failed to send message: ${e.message}")
        }
    }

    /**
     * Send a JSON message to Unreal Engine
     */
    fun sendJsonMessage(target: String, method: String, data: Map<String, Any>) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for messages")
            return
        }

        try {
            val jsonString = org.json.JSONObject(data).toString()
            nativeSendMessage(target, method, jsonString)
        } catch (e: Exception) {
            sendError("Failed to send JSON message: ${e.message}")
        }
    }

    // MARK: - Unreal-Specific Methods

    /**
     * Execute a console command in Unreal Engine
     */
    fun executeConsoleCommand(command: String) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for console commands")
            return
        }

        try {
            nativeExecuteConsoleCommand(command)
        } catch (e: Exception) {
            sendError("Failed to execute console command: ${e.message}")
        }
    }

    /**
     * Load a level/map in Unreal Engine
     */
    fun loadLevel(levelName: String) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready to load level")
            return
        }

        try {
            nativeLoadLevel(levelName)
        } catch (e: Exception) {
            sendError("Failed to load level: ${e.message}")
        }
    }

    /**
     * Apply quality settings to Unreal Engine
     */
    fun applyQualitySettings(settings: Map<String, Any>) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for quality settings")
            return
        }

        try {
            nativeApplyQualitySettings(settings)
        } catch (e: Exception) {
            sendError("Failed to apply quality settings: ${e.message}")
        }
    }

    /**
     * Get current quality settings from Unreal Engine
     */
    fun getQualitySettings(): Map<String, Any>? {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready")
            return null
        }

        return try {
            nativeGetQualitySettings()
        } catch (e: Exception) {
            sendError("Failed to get quality settings: ${e.message}")
            null
        }
    }

    /**
     * Check if engine is in background
     */
    fun isInBackground(): Boolean {
        return isPaused.get()
    }

    // MARK: - View Integration

    /**
     * Get the Unreal Engine view to attach to Flutter
     */
    fun getView(): View? {
        return unrealView
    }

    /**
     * Attach Unreal view to parent
     */
    fun attachView(parent: ViewGroup) {
        unrealView?.let { view ->
            if (view.parent == null) {
                parent.addView(view)
                sendEvent("attached")
            }
        }
    }

    /**
     * Detach Unreal view from parent
     */
    fun detachView() {
        unrealView?.let { view ->
            (view.parent as? ViewGroup)?.removeView(view)
            sendEvent("detached")
        }
    }

    // MARK: - Event Handling

    private fun sendEvent(eventType: String, message: String? = null) {
        activity.runOnUiThread {
            channel.invokeMethod("onEvent", mapOf(
                "type" to eventType,
                "message" to message
            ))
        }
    }

    private fun sendError(message: String) {
        android.util.Log.e(TAG, message)
        sendEvent("error", message)
    }

    /**
     * Called from native code when a message is received from Unreal
     */
    @Suppress("unused")
    fun onMessageFromUnreal(target: String, method: String, data: String) {
        activity.runOnUiThread {
            channel.invokeMethod("onMessage", mapOf(
                "target" to target,
                "method" to method,
                "data" to data
            ))
        }
    }

    /**
     * Called from native code when a level is loaded
     */
    @Suppress("unused")
    fun onLevelLoaded(levelName: String, buildIndex: Int) {
        activity.runOnUiThread {
            channel.invokeMethod("onLevelLoaded", mapOf(
                "name" to levelName,
                "buildIndex" to buildIndex,
                "isLoaded" to true,
                "isValid" to true,
                "metadata" to emptyMap<String, Any>()
            ))
        }
    }

    // MARK: - Native Methods (JNI)

    /**
     * Create Unreal Engine instance
     */
    private external fun nativeCreate(config: Map<String, Any>): Boolean

    /**
     * Get the native Unreal view
     */
    private external fun nativeGetView(): View?

    /**
     * Pause the engine
     */
    private external fun nativePause()

    /**
     * Resume the engine
     */
    private external fun nativeResume()

    /**
     * Quit the engine
     */
    private external fun nativeQuit()

    /**
     * Send message to Unreal
     */
    private external fun nativeSendMessage(target: String, method: String, data: String)

    /**
     * Execute console command
     */
    private external fun nativeExecuteConsoleCommand(command: String)

    /**
     * Load level
     */
    private external fun nativeLoadLevel(levelName: String)

    /**
     * Apply quality settings
     */
    private external fun nativeApplyQualitySettings(settings: Map<String, Any>)

    /**
     * Get quality settings
     */
    private external fun nativeGetQualitySettings(): Map<String, Any>
}
