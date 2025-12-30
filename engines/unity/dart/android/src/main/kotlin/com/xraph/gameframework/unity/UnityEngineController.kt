package com.xraph.gameframework.unity

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.lifecycle.Lifecycle
import com.unity3d.player.IUnityPlayerLifecycleEvents
import com.unity3d.player.UnityPlayer
import com.xraph.gameframework.gameframework.core.GameEngineController
import io.flutter.plugin.common.BinaryMessenger
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Unity-specific implementation of GameEngineController
 *
 * This controller manages the Unity player lifecycle and communication
 * between Flutter and Unity.
 *
 * Architecture Note (FUW Pattern):
 * Following flutter-unity-view-widget's proven pattern, Activity MUST be passed separately
 * from Context. The Activity comes from onAttachedToActivity (the ONLY proper way to get it
 * in Flutter plugins) and is provided explicitly rather than extracted from Context.
 *
 * Key principles from FUW:
 * 1. Activity comes from onAttachedToActivity via ActivityPluginBinding
 * 2. Stored in registry/singleton (UnityPlayerUtils.activity in FUW, GameEngineRegistry in ours)
 * 3. Passed separately to controllers - never extracted from Context
 * 4. All engine initialization waits for Activity availability
 *
 * This separation is critical because:
 * - Context might be Application context, not Activity
 * - Unity requires Activity for proper lifecycle, window management, and rendering
 * - Activity lifecycle is managed by Flutter via FlutterLifecycleAdapter
 *
 * Uses Unity's IUnityPlayerLifecycleEvents for proper event-driven initialization
 */
class UnityEngineController(
    context: Context,
    activity: Activity?,
    viewId: Int,
    messenger: BinaryMessenger,
    lifecycle: Lifecycle,
    config: Map<String, Any?>
) : GameEngineController(context, activity, viewId, messenger, lifecycle, config) {

    private var unityPlayer: UnityPlayer? = null
    private var unityReady = false
    private val initializationHandler = Handler(Looper.getMainLooper())
    private val isInitializing = AtomicBoolean(false)
    private val isCancelled = AtomicBoolean(false)
    
    /**
     * Unity lifecycle callback implementation
     * This is the proper way to know when Unity is ready
     */
    private val unityLifecycleEvents = object : IUnityPlayerLifecycleEvents {
        override fun onUnityPlayerUnloaded() {
            Log.d(TAG, "Unity player unloaded")
            unityReady = false
            isUnityLoaded = false
            sendEventToFlutter("onUnloaded", null)
        }

        override fun onUnityPlayerQuitted() {
            Log.d(TAG, "Unity player quitted")
            unityReady = false
            isUnityLoaded = false
            sendEventToFlutter("onDestroyed", null)
        }
    }

    companion object {
        private const val TAG = "UnityEngineController"
        private const val ENGINE_TYPE = "unity"
        private const val ENGINE_VERSION = "2022.3.0"
        
        // Unity player status (singleton)
        private var isUnityLoaded = false
        private var isUnityPaused = false
        
        // Unity initialization timeout
        private const val INIT_TIMEOUT_MS = 30000L
        private const val INIT_RETRY_DELAY_MS = 100L
        private const val MAX_INIT_RETRIES = 50 // 5 seconds total
    }
    
    /**
     * Get this controller instance for Unity utilities that need PlatformView access
     * 
     * FUW Pattern: Unity utilities in FUW receive the controller via `this` reference.
     * This method provides the same capability for utilities that need view-level access.
     * 
     * @return This UnityEngineController instance as a PlatformView
     */
    fun getController(): UnityEngineController = this
    
    /**
     * Get the Activity (from onAttachedToActivity)
     * 
     * FUW Pattern: Activity is obtained via onAttachedToActivity and passed explicitly.
     * This helper provides access for Unity utilities that need it.
     * 
     * Note: The protected 'activity' property is already accessible via inheritance.
     * This method is provided for explicit access from external utilities if needed.
     * 
     * @return Activity from onAttachedToActivity, or null if not available
     */
    fun getUnityActivity(): Activity? = activity
    
    /**
     * Configure z-order for Unity's SurfaceView to ensure proper rendering
     * 
     * UnityPlayer is a FrameLayout that contains a SurfaceView. We need to find and
     * configure that SurfaceView's z-order properties.
     * 
     * Learned from: https://github.com/juicycleff/flutter-unity-view-widget
     */
    private fun configureUnityViewZOrder(unityPlayer: UnityPlayer) {
        try {
            // Find the SurfaceView inside UnityPlayer (it's a child of the FrameLayout)
            for (i in 0 until unityPlayer.childCount) {
                val child = unityPlayer.getChildAt(i)
                if (child is android.view.SurfaceView) {
                    // Configure z-order for proper rendering
                    child.setZOrderOnTop(false)      // Unity should be below Flutter's UI elements
                    child.setZOrderMediaOverlay(true) // But above other media
                    child.z = 0f                      // Set explicit z-order
                    
                    Log.d(TAG, "Unity SurfaceView z-order configured (z=${child.z}, " +
                            "zOrderOnTop=false, zOrderMediaOverlay=true)")
                    return
                }
            }
            
            // If no SurfaceView found yet, Unity might not have created it
            // This is normal during early initialization - it will be configured later
            Log.d(TAG, "Unity SurfaceView not found yet (will be configured when available)")
            
        } catch (e: Exception) {
            Log.w(TAG, "Failed to configure Unity z-order: ${e.message}")
        }
    }

    override fun createEngine() {
        Log.d(TAG, "Creating Unity engine")
        if (isInitializing.getAndSet(true)) {
            Log.w(TAG, "Unity initialization already in progress")
            return
        }
        
        runOnMainThread {
            try {
                if (unityPlayer != null) {
                    Log.d(TAG, "Unity player already created")
                    isInitializing.set(false)
                    return@runOnMainThread
                }
                
                // // CRITICAL: Unity MUST receive Activity context, not generic Context
                // val activity = context as? Activity
                // if (activity == null) {
                //     val error = "Unity requires Activity context, got: ${context::class.java.simpleName}"
                //     Log.e(TAG, error)
                //     sendEventToFlutter("onError", mapOf(
                //         "message" to error,
                //         "fatal" to true
                //     ))
                //     isInitializing.set(false)
                //     return@runOnMainThread
                // }
                
                Log.d(TAG, "Creating Unity player with Activity context and lifecycle callbacks")
                
                // Create Unity player with Activity and lifecycle callbacks
                // This is the proper way to know when Unity is ready!
                // FUW Pattern: Use Activity from onAttachedToActivity (never extract from Context!)
                if (activity == null) {
                    val error = "Unity initialization failed: Activity not available. " +
                            "This should never happen if plugin is properly initialized."
                    Log.e(TAG, error)
                    sendEventToFlutter("onError", mapOf(
                        "message" to error,
                        "fatal" to true
                    ))
                    isInitializing.set(false)
                    return@runOnMainThread
                }
                
                unityPlayer = UnityPlayer(activity, unityLifecycleEvents).also { player ->
                    Log.d(TAG, "Unity player instance created with Activity from onAttachedToActivity and lifecycle callbacks")
                    
                    // Configure Unity player view with proper layout params
                    player.layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                    
                    // CRITICAL: Configure z-order for proper rendering
                    // UnityPlayer is a FrameLayout containing a SurfaceView - we need to configure that SurfaceView
                    configureUnityViewZOrder(player)
                    
                    // Wait for Unity to actually initialize before attaching
                    // Using polling as fallback, but lifecycle callbacks are primary
                    waitForUnityInitialization(player, 0)
                }
                
            } catch (e: OutOfMemoryError) {
                val error = "Out of memory creating Unity player"
                Log.e(TAG, error, e)
                sendEventToFlutter("onError", mapOf(
                    "message" to error,
                    "fatal" to true
                ))
                isInitializing.set(false)
                
            } catch (e: Exception) {
                val error = "Failed to create Unity player: ${e.message}"
                Log.e(TAG, error, e)
                sendEventToFlutter("onError", mapOf(
                    "message" to error,
                    "fatal" to false
                ))
                isInitializing.set(false)
            }
        }
    }
    
    /**
     * Wait for Unity to actually initialize before marking as ready
     * BLACK SCREEN FIX: Unity needs time to initialize its rendering
     */
    private fun waitForUnityInitialization(player: UnityPlayer, retryCount: Int) {
        if (isCancelled.get()) {
            Log.d(TAG, "Unity initialization cancelled")
            isInitializing.set(false)
            return
        }
        
        if (retryCount >= MAX_INIT_RETRIES) {
            Log.e(TAG, "Unity initialization timeout after ${MAX_INIT_RETRIES} retries")
            sendEventToFlutter("onError", mapOf(
                "message" to "Unity initialization timeout",
                "fatal" to false
            ))
            isInitializing.set(false)
            return
        }

        finalizeInitialization(player)
        
        // Check if Unity is ready (non-zero size indicates rendering initialized)
        if (player.width > 0 && player.height > 0) {
            Log.d(TAG, "Unity initialized successfully (size: ${player.width}x${player.height})")
            finalizeInitialization(player)
        } else {
            // Unity not ready yet, retry after delay
            Log.d(TAG, "Unity not ready yet (retry $retryCount/$MAX_INIT_RETRIES)")
            initializationHandler.postDelayed({
                waitForUnityInitialization(player, retryCount + 1)
            }, INIT_RETRY_DELAY_MS)
        }
    }
    
    /**
     * Finalize Unity initialization after it's actually ready
     */
    private fun finalizeInitialization(player: UnityPlayer) {
        runOnMainThread {
            if (isCancelled.get()) {
                Log.d(TAG, "Initialization cancelled during finalization")
                isInitializing.set(false)
                return@runOnMainThread
            }
            
            // Attach view to hierarchy
            attachEngineView()
            
            // Give Unity one more frame to settle
            player.postDelayed({
                if (!isCancelled.get()) {
                    // Now Unity is truly ready
                    unityReady = true
                    engineReady = true
                    isUnityLoaded = true
                    
                    Log.d(TAG, "Unity engine ready and rendering")
                    
                    // Notify Flutter
                    sendEventToFlutter("onCreated", null)
                    sendEventToFlutter("onLoaded", null)
                    
                    // Request focus for input
                    player.requestFocus()
                }
                isInitializing.set(false)
            }, 100) // One frame delay
        }
    }

    override fun attachEngineView() {
        runOnMainThread {
            unityPlayer?.let { player ->
                if (player.parent != null) {
                    (player.parent as? ViewGroup)?.removeView(player)
                }
                
                // Ensure proper layout params
                val layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                player.layoutParams = layoutParams
                
                // Configure z-order BEFORE adding to container
                // Learned from: https://github.com/juicycleff/flutter-unity-view-widget
                configureUnityViewZOrder(player)
                
                // Add to container
                container.addView(player, layoutParams)
                
                // Ensure proper rendering
                player.bringToFront()
                player.requestLayout()
                player.invalidate()
                
                // Force container to refresh
                container.requestLayout()
                container.invalidate()
                
                Log.d(TAG, "Unity view attached to container with z-order: ${player.z}")
                sendEventToFlutter("onAttached", null)
            }
        }
    }

    override fun detachEngineView() {
        runOnMainThread {
            unityPlayer?.let { player ->
                if (player.parent != null) {
                    (player.parent as? ViewGroup)?.removeView(player)
                    Log.d(TAG, "Unity view detached from container")
                }
                sendEventToFlutter("onDetached", null)
            }
        }
    }

    override fun pauseEngine() {
        runOnMainThread {
            unityPlayer?.pause()
            enginePaused = true
            isUnityPaused = true
            sendEventToFlutter("onPaused", null)
        }
    }

    override fun resumeEngine() {
        runOnMainThread {
            unityPlayer?.resume()
            enginePaused = false
            isUnityPaused = false
            sendEventToFlutter("onResumed", null)
        }
    }

    override fun unloadEngine() {
        runOnMainThread {
            // Unity doesn't support unloading without destroying
            // We'll pause it instead
            pauseEngine()
            sendEventToFlutter("onUnloaded", null)
        }
    }

    override fun destroyEngine() {
        runOnMainThread {
            try {
                unityPlayer?.quit()
                unityPlayer?.destroy()
                unityPlayer = null
                unityReady = false
                engineReady = false
                isUnityLoaded = false
                isUnityPaused = false
                sendEventToFlutter("onDestroyed", null)
            } catch (e: Exception) {
                sendEventToFlutter("onError", mapOf("message" to e.message))
            }
        }
    }

    override fun sendMessageToEngine(target: String, method: String, data: String) {
        runOnMainThread {
            try {
                // Send message to Unity using UnitySendMessage
                UnityPlayer.UnitySendMessage(target, method, data)
            } catch (e: Exception) {
                sendEventToFlutter(
                    "onError",
                    mapOf("message" to "Failed to send message: ${e.message}")
                )
            }
        }
    }

    override fun getEngineType(): String = ENGINE_TYPE

    override fun getEngineVersion(): String = ENGINE_VERSION

    override fun getView(): View {
        return container
    }

    override fun dispose() {
        Log.d(TAG, "Disposing Unity controller")
        
        // Cancel any pending initialization
        isCancelled.set(true)
        initializationHandler.removeCallbacksAndMessages(null)
        
        // Call parent dispose
        super.dispose()
        
        // Destroy Unity
        destroyEngine()
    }

    // Unity lifecycle callbacks (called from Unity's C# bridge)

    /**
     * Called from Unity when a message is sent to Flutter
     * This method is called via NativeAPI.cs from Unity
     */
    fun onUnityMessage(target: String, method: String, data: String) {
        sendEventToFlutter(
            "onMessage", mapOf(
                "target" to target,
                "method" to method,
                "data" to data
            )
        )
    }

    /**
     * Get UnityEngineController instance from Activity
     * Called from Unity's NativeAPI.cs via JNI
     */
    fun getUnityEngineController(): UnityEngineController {
        return this
    }

    /**
     * Called from Unity when a scene is loaded
     */
    fun onUnitySceneLoaded(name: String, buildIndex: Int) {
        sendEventToFlutter(
            "onSceneLoaded", mapOf(
                "name" to name,
                "buildIndex" to buildIndex,
                "isLoaded" to true,
                "isValid" to true,
                "metadata" to emptyMap<String, Any>()
            )
        )
    }

    // Lifecycle callbacks from DefaultLifecycleObserver

    override fun onResume(owner: androidx.lifecycle.LifecycleOwner) {
        super.onResume(owner)
        if (unityReady && isUnityPaused) {
            resumeEngine()
        }
    }

    override fun onPause(owner: androidx.lifecycle.LifecycleOwner) {
        super.onPause(owner)
        if (unityReady && !isUnityPaused) {
            pauseEngine()
        }
    }

    override fun onDestroy(owner: androidx.lifecycle.LifecycleOwner) {
        super.onDestroy(owner)
        destroyEngine()
    }
}
