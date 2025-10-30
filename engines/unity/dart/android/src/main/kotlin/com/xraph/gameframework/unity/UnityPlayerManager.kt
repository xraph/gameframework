package com.xraph.gameframework.unity

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.res.Configuration
import android.view.View
import com.unity3d.player.IUnityPlayerLifecycleEvents
import com.unity3d.player.UnityPlayer

/**
 * Unity Player Manager
 *
 * Manages the Unity player singleton and provides interface for Unity operations
 */
object UnityPlayerManager : IUnityPlayerLifecycleEvents {

    private var unityPlayer: UnityPlayer? = null
    private var isUnityInitialized = false
    private var activity: Activity? = null
    private val eventListeners = mutableMapOf<Int, (Map<String, Any>) -> Unit>()

    /**
     * Set the activity reference
     */
    fun setActivity(newActivity: Activity?) {
        activity = newActivity
        if (newActivity == null) {
            android.util.Log.d("UnityPlayerManager", "Activity reference cleared")
        } else {
            android.util.Log.d("UnityPlayerManager", "Activity reference set")
        }
    }

    /**
     * Initialize Unity player with the given context and activity
     * @param viewContext The PlatformView's context (critical for proper initialization)
     * @param activity The activity reference (for Unity internals)
     */
    fun initialize(viewContext: Context, activity: Activity) {
        // Only initialize once
        if (unityPlayer != null && isUnityInitialized) {
            android.util.Log.d("UnityPlayerManager", "Unity already initialized, skipping")
            return
        }

        this.activity = activity

        // Create Unity player with the view's context and lifecycle events
        android.util.Log.d("UnityPlayerManager", "Creating CustomUnityPlayer...")
        unityPlayer = CustomUnityPlayer.create(activity, this)

        if (unityPlayer != null) {
            isUnityInitialized = true
            android.util.Log.d("UnityPlayerManager", "Unity player initialized successfully!")
        } else {
            isUnityInitialized = false
            android.util.Log.e("UnityPlayerManager", "Unity player is null after creation attempt")
        }
    }

    /**
     * Get the Unity player view
     * @param viewContext The PlatformView's context (important for proper resource resolution)
     * @param activity The activity (for Unity's internal activity references)
     */
    fun getUnityView(viewContext: Context, activity: Activity): View? {
        // Initialize Unity if not already done
        if (unityPlayer == null || !isUnityInitialized) {
            android.util.Log.d("UnityPlayerManager", "Unity not initialized, initializing with view context...")
            initialize(viewContext, activity)
        }

        if (unityPlayer == null) {
            android.util.Log.e("UnityPlayerManager", "Unity player is null even after initialization")
            return null
        }

        android.util.Log.d("UnityPlayerManager", "Returning Unity player view (initialized=${isUnityInitialized})")
        return unityPlayer
    }

    /**
     * Check if Unity is initialized
     */
    fun isInitialized(): Boolean {
        return isUnityInitialized && unityPlayer != null
    }

    /**
     * Get Unity version
     */
    fun getUnityVersion(): String {
        return try {
            UnityPlayer.currentActivity?.let {
                val versionName = it.packageManager.getPackageInfo(it.packageName, 0).versionName
                versionName ?: "Unknown"
            } ?: "Unknown"
        } catch (e: Exception) {
            "Unknown"
        }
    }

    /**
     * Send a message to Unity GameObject
     */
    fun sendMessage(gameObject: String, methodName: String, message: String) {
        try {
            UnityPlayer.UnitySendMessage(gameObject, methodName, message)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Pause Unity player
     */
    fun pause() {
        unityPlayer?.pause()
    }

    /**
     * Resume Unity player
     */
    fun resume() {
        unityPlayer?.resume()
    }

    /**
     * Unload Unity player
     */
    fun unload() {
        unityPlayer?.destroy()
        unityPlayer = null
        isUnityInitialized = false
    }

    /**
     * Handle low memory situation
     */
    fun lowMemory() {
        unityPlayer?.lowMemory()
    }

    /**
     * Register an event listener for a specific view
     */
    fun registerEventListener(viewId: Int, listener: (Map<String, Any>) -> Unit) {
        eventListeners[viewId] = listener
        android.util.Log.d("UnityPlayerManager", "Registered event listener for view $viewId")
    }

    /**
     * Unregister an event listener
     */
    fun unregisterEventListener(viewId: Int) {
        eventListeners.remove(viewId)
        android.util.Log.d("UnityPlayerManager", "Unregistered event listener for view $viewId")
    }

    /**
     * Send an event to all registered listeners
     * This is called from Unity via UnitySendMessage to bridge events to Flutter
     */
    fun dispatchEvent(eventType: String, eventData: String) {
        val event = mapOf(
            "event" to eventType,
            "data" to eventData
        )

        eventListeners.values.forEach { listener ->
            try {
                listener(event)
            } catch (e: Exception) {
                android.util.Log.e("UnityPlayerManager", "Error dispatching event", e)
            }
        }
    }

    // IUnityPlayerLifecycleEvents implementation
    override fun onUnityPlayerUnloaded() {
        android.util.Log.d("UnityPlayerManager", "Unity player unloaded")
        dispatchEvent("onUnloaded", "")
    }

    override fun onUnityPlayerQuitted() {
        android.util.Log.d("UnityPlayerManager", "Unity player quitted")
        dispatchEvent("onDestroyed", "")
    }
}
