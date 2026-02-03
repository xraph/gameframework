package com.xraph.gameframework.unity

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.lifecycle.Lifecycle
import com.unity3d.player.UnityPlayer
import com.unity3d.player.IUnityPlayerLifecycleEvents
import com.xraph.gameframework.gameframework.core.GameEngineController
import io.flutter.plugin.common.BinaryMessenger
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Unity-specific implementation of GameEngineController
 *
 * This controller manages the Unity player lifecycle and communication
 * between Flutter and Unity.
 *
 * Compatible with Unity 6 (6000.x) and later versions.
 * Unity 6 changed the API - UnityPlayer is now abstract and UnityPlayerForActivityOrService
 * is the concrete implementation, which is NOT a View but provides one.
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
    private var unityView: View? = null  // The actual View from Unity (separate from UnityPlayer in Unity 6)
    private var unityReady = false
    private val initializationHandler = Handler(Looper.getMainLooper())
    private val isInitializing = AtomicBoolean(false)
    private val isCancelled = AtomicBoolean(false)

    companion object {
        private const val TAG = "UnityEngineController"
        private const val ENGINE_TYPE = "unity"
        private const val ENGINE_VERSION = "6000.0.0"
        
        // Unity player status (singleton)
        private var isUnityLoaded = false
        private var isUnityPaused = false
        
        // Unity initialization timeout
        private const val INIT_TIMEOUT_MS = 30000L
        private const val INIT_RETRY_DELAY_MS = 100L
        private const val MAX_INIT_RETRIES = 50 // 5 seconds total
    }
    
    /**
     * Create a custom container that fixes touch events for Unity.
     * 
     * Flutter's platform view system may change the input source of touch events,
     * but Unity expects InputDevice.SOURCE_TOUCHSCREEN to process them correctly.
     */
    override fun createContainer(): FrameLayout {
        return UnityTouchContainer(context)
    }
    
    /**
     * Get this controller instance for Unity utilities that need PlatformView access
     */
    fun getController(): UnityEngineController = this
    
    /**
     * Get the Activity (from onAttachedToActivity)
     */
    fun getUnityActivity(): Activity? = activity
    
    /**
     * Configure window flags for Unity rendering
     * Similar to flutter-unity-view-widget's performWindowUpdate()
     */
    private fun configureWindowForUnity() {
        try {
            activity?.let { act ->
                // Clear fullscreen flags that might interfere with Flutter
                act.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN)
                act.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
                Log.d(TAG, "Window configured for Unity")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to configure window for Unity: ${e.message}")
        }
    }
    
    /**
     * Configure z-order for Unity's SurfaceView to ensure proper rendering
     */
    private fun configureUnityViewZOrder(view: View) {
        try {
            if (view is ViewGroup) {
                for (i in 0 until view.childCount) {
                    val child = view.getChildAt(i)
                    if (child is android.view.SurfaceView) {
                        child.setZOrderOnTop(false)
                        child.setZOrderMediaOverlay(true)
                        child.z = 0f
                        Log.d(TAG, "Unity SurfaceView z-order configured")
                        return
                    }
                }
            }
            Log.d(TAG, "Unity SurfaceView not found yet")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to configure Unity z-order: ${e.message}")
        }
    }

    /**
     * Unity lifecycle callback implementation for Unity 6+
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
                
                if (activity == null) {
                    val error = "Unity initialization failed: Activity not available."
                    Log.e(TAG, error)
                    sendEventToFlutter("onError", mapOf("message" to error, "fatal" to true))
                    isInitializing.set(false)
                    return@runOnMainThread
                }
                
                Log.d(TAG, "Creating Unity player with Activity context")
                
                // Unity 6 has changed the UnityPlayer API
                val result = createUnityPlayerInstance(activity!!)
                
                if (result == null) {
                    val error = "Failed to create Unity player - no compatible constructor found"
                    Log.e(TAG, error)
                    sendEventToFlutter("onError", mapOf("message" to error, "fatal" to true))
                    isInitializing.set(false)
                    return@runOnMainThread
                }
                
                unityPlayer = result.player
                unityView = result.view
                Log.d(TAG, "Unity player instance created, view type: ${unityView?.javaClass?.simpleName}")
                
                // Configure the Unity view
                unityView?.let { view ->
                    view.layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                    
                    // Set z-order
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                        view.z = -1f
                    }
                    
                    configureUnityViewZOrder(view)
                }
                
                // Configure window for Unity (important for proper rendering)
                configureWindowForUnity()
                
                waitForUnityInitialization(0)
                
            } catch (e: OutOfMemoryError) {
                val error = "Out of memory creating Unity player"
                Log.e(TAG, error, e)
                sendEventToFlutter("onError", mapOf("message" to error, "fatal" to true))
                isInitializing.set(false)
                
            } catch (e: Exception) {
                val error = "Failed to create Unity player: ${e.message}"
                Log.e(TAG, error, e)
                sendEventToFlutter("onError", mapOf("message" to error, "fatal" to false))
                isInitializing.set(false)
            }
        }
    }
    
    /**
     * Result class for Unity player creation
     */
    private data class UnityPlayerResult(
        val player: UnityPlayer,
        val view: View
    )
    
    /**
     * Create UnityPlayer instance using reflection to handle Unity 6 API changes.
     * Unity 6 made UnityPlayer abstract, so we need to find and use the concrete implementation.
     * In Unity 6, UnityPlayerForActivityOrService is NOT a View - it provides a View via getFrameLayout()
     */
    private fun createUnityPlayerInstance(activity: Activity): UnityPlayerResult? {
        // Try 1: Look for UnityPlayerForActivityOrService (Unity 6 concrete class)
        try {
            val concreteClass = Class.forName("com.unity3d.player.UnityPlayerForActivityOrService")
            Log.d(TAG, "Found UnityPlayerForActivityOrService class")
            
            var player: UnityPlayer? = null
            
            // Try constructor with Activity and IUnityPlayerLifecycleEvents
            try {
                val constructor = concreteClass.getConstructor(
                    Context::class.java,
                    IUnityPlayerLifecycleEvents::class.java
                )
                constructor.isAccessible = true
                player = constructor.newInstance(activity, unityLifecycleEvents) as UnityPlayer
                Log.d(TAG, "Created UnityPlayer via UnityPlayerForActivityOrService(Context, IUnityPlayerLifecycleEvents)")
            } catch (e: Exception) {
                Log.d(TAG, "Constructor with lifecycle events failed: ${e.message}")
            }
            
            // Try constructor with just Activity/Context
            if (player == null) {
                try {
                    val constructor = concreteClass.getConstructor(Context::class.java)
                    constructor.isAccessible = true
                    player = constructor.newInstance(activity) as UnityPlayer
                    Log.d(TAG, "Created UnityPlayer via UnityPlayerForActivityOrService(Context)")
                } catch (e: Exception) {
                    Log.d(TAG, "Constructor with Context only failed: ${e.message}")
                }
            }
            
            // If we got a player, try to get the View from it
            if (player != null) {
                val view = getViewFromUnityPlayer(player)
                if (view != null) {
                    return UnityPlayerResult(player, view)
                } else {
                    Log.e(TAG, "Failed to get View from UnityPlayer")
                }
            }
        } catch (e: ClassNotFoundException) {
            Log.d(TAG, "UnityPlayerForActivityOrService not found, trying other approaches")
        }
        
        // Try 2: Use reflection to access UnityPlayer's protected constructor
        try {
            val unityPlayerClass = UnityPlayer::class.java
            
            for (constructor in unityPlayerClass.declaredConstructors) {
                try {
                    constructor.isAccessible = true
                    val paramTypes = constructor.parameterTypes
                    Log.d(TAG, "Found constructor with params: ${paramTypes.map { it.simpleName }}")
                    
                    var player: UnityPlayer? = null
                    
                    when (paramTypes.size) {
                        1 -> {
                            if (Context::class.java.isAssignableFrom(paramTypes[0])) {
                                player = constructor.newInstance(activity) as UnityPlayer
                                Log.d(TAG, "Created UnityPlayer via reflection (Context)")
                            }
                        }
                        2 -> {
                            if (Context::class.java.isAssignableFrom(paramTypes[0]) &&
                                IUnityPlayerLifecycleEvents::class.java.isAssignableFrom(paramTypes[1])) {
                                player = constructor.newInstance(activity, unityLifecycleEvents) as UnityPlayer
                                Log.d(TAG, "Created UnityPlayer via reflection (Context, IUnityPlayerLifecycleEvents)")
                            }
                        }
                    }
                    
                    if (player != null) {
                        val view = getViewFromUnityPlayer(player)
                        if (view != null) {
                            return UnityPlayerResult(player, view)
                        }
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "Constructor invocation failed: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Reflection approach failed: ${e.message}")
        }
        
        Log.e(TAG, "All UnityPlayer creation approaches failed")
        return null
    }
    
    /**
     * Get the View from a UnityPlayer instance.
     * In Unity 6, UnityPlayerForActivityOrService is not a View, so we need to get it via method.
     */
    private fun getViewFromUnityPlayer(player: UnityPlayer): View? {
        // First check if the player itself is a View (older Unity versions)
        if (player is View) {
            Log.d(TAG, "UnityPlayer is a View directly")
            return player
        }
        
        // Try various methods to get the View
        val methodNames = listOf(
            "getFrameLayout",
            "getView",
            "getPlayerView",
            "getSurfaceView",
            "getRootView"
        )
        
        for (methodName in methodNames) {
            try {
                val method = player.javaClass.getMethod(methodName)
                method.isAccessible = true
                val result = method.invoke(player)
                if (result is View) {
                    Log.d(TAG, "Got View via $methodName(): ${result.javaClass.simpleName}")
                    return result
                }
            } catch (e: NoSuchMethodException) {
                // Method doesn't exist, try next
            } catch (e: Exception) {
                Log.d(TAG, "Error calling $methodName: ${e.message}")
            }
        }
        
        // Try getting fields that might be Views
        val fieldNames = listOf("mFrameLayout", "mView", "frameLayout", "view", "surfaceView")
        for (fieldName in fieldNames) {
            try {
                val field = player.javaClass.getDeclaredField(fieldName)
                field.isAccessible = true
                val result = field.get(player)
                if (result is View) {
                    Log.d(TAG, "Got View via field $fieldName: ${result.javaClass.simpleName}")
                    return result
                }
            } catch (e: NoSuchFieldException) {
                // Field doesn't exist, try next
            } catch (e: Exception) {
                Log.d(TAG, "Error accessing field $fieldName: ${e.message}")
            }
        }
        
        // Try to find any View field
        try {
            for (field in player.javaClass.declaredFields) {
                field.isAccessible = true
                val value = field.get(player)
                if (value is View) {
                    Log.d(TAG, "Found View in field ${field.name}: ${value.javaClass.simpleName}")
                    return value
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "Error scanning fields: ${e.message}")
        }
        
        Log.e(TAG, "Could not find View in UnityPlayer of type: ${player.javaClass.name}")
        return null
    }
    
    /**
     * Wait for Unity to actually initialize before marking as ready
     */
    private fun waitForUnityInitialization(retryCount: Int) {
        if (isCancelled.get()) {
            Log.d(TAG, "Unity initialization cancelled")
            isInitializing.set(false)
            return
        }
        
        if (retryCount >= MAX_INIT_RETRIES) {
            Log.e(TAG, "Unity initialization timeout after $MAX_INIT_RETRIES retries")
            sendEventToFlutter("onError", mapOf("message" to "Unity initialization timeout", "fatal" to false))
            isInitializing.set(false)
            return
        }

        // Always try to finalize after some retries
        if (retryCount > 5) {
            finalizeInitialization()
            return
        }
        
        val view = unityView
        if (view != null && view.width > 0 && view.height > 0) {
            Log.d(TAG, "Unity initialized (size: ${view.width}x${view.height})")
            finalizeInitialization()
        } else {
            Log.d(TAG, "Unity not ready yet (retry $retryCount/$MAX_INIT_RETRIES)")
            initializationHandler.postDelayed({
                waitForUnityInitialization(retryCount + 1)
            }, INIT_RETRY_DELAY_MS)
        }
    }
    
    /**
     * Finalize Unity initialization
     */
    private fun finalizeInitialization() {
        runOnMainThread {
            if (isCancelled.get()) {
                Log.d(TAG, "Initialization cancelled during finalization")
                isInitializing.set(false)
                return@runOnMainThread
            }
            
            attachEngineView()
            
            // CRITICAL: Refocus Unity to start rendering (same pattern as flutter-unity-view-widget)
            // This "shake" pattern is required for Unity to properly initialize rendering
            refocusUnity()
            
            initializationHandler.postDelayed({
                if (!isCancelled.get()) {
                    unityReady = true
                    engineReady = true
                    isUnityLoaded = true
                    
                    Log.d(TAG, "Unity engine ready")
                    
                    // Register with FlutterBridgeRegistry
                    FlutterBridgeRegistry.register(this)
                    unityPlayer?.let { FlutterBridgeRegistry.registerUnityPlayer(it) }
                    Log.d(TAG, "Registered with FlutterBridgeRegistry")
                    
                    sendEventToFlutter("onCreated", null)
                    sendEventToFlutter("onLoaded", null)
                    
                    unityView?.requestFocus()
                }
                isInitializing.set(false)
            }, 100)
        }
    }
    
    /**
     * CRITICAL: Refocus Unity to start rendering
     * 
     * This pattern (resume -> pause -> resume) is essential for Unity to properly
     * initialize its rendering when embedded as a library. Without this, Unity
     * may not render anything even though the player is created.
     * 
     * This is the same pattern used in flutter-unity-view-widget which has been
     * proven to work across many Unity versions.
     */
    private fun refocusUnity() {
        Log.d(TAG, "Refocusing Unity (resume -> pause -> resume)")
        try {
            unityPlayer?.let { player ->
                // In Unity 6, UnityPlayer is abstract and not a View
                // Use the unityView for focus and player for lifecycle
                val focused = unityView?.requestFocus() ?: false
                player.windowFocusChanged(focused)
                player.resume()
                player.pause()
                player.resume()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error during refocusUnity: ${e.message}")
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun attachEngineView() {
        runOnMainThread {
            unityView?.let { view ->
                (view.parent as? ViewGroup)?.removeView(view)
                
                val layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                view.layoutParams = layoutParams
                
                // Set z-order before adding to ensure proper rendering
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    view.z = -1f
                }
                
                configureUnityViewZOrder(view)
                container.addView(view, layoutParams)
                
                // CRITICAL: Set up touch event interception to ensure Unity receives touch events
                // Flutter's platform view system may change the input source, but Unity expects
                // InputDevice.SOURCE_TOUCHSCREEN to properly process touch events
                setupTouchInterception(view)
                
                view.bringToFront()
                view.requestLayout()
                view.invalidate()
                container.requestLayout()
                container.invalidate()
                
                // Focus the Unity view to enable input and trigger rendering
                focusUnity()
                
                Log.d(TAG, "Unity view attached to container")
                sendEventToFlutter("onAttached", null)
            } ?: run {
                Log.e(TAG, "Cannot attach - Unity view is null")
            }
        }
    }
    
    /**
     * Set up touch event interception to ensure Unity receives touch events correctly.
     * 
     * Note: Touch handling is now done by UnityTouchContainer (the container created via createContainer).
     * This method is kept for any additional setup if needed.
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun setupTouchInterception(view: View) {
        // Touch handling is done by UnityTouchContainer
        // Make sure the view is focusable for touch events
        view.isFocusable = true
        view.isFocusableInTouchMode = true
        Log.d(TAG, "Touch interception configured via UnityTouchContainer")
    }
    
    /**
     * Focus the Unity player to enable input and rendering
     */
    private fun focusUnity() {
        try {
            unityPlayer?.let { player ->
                // In Unity 6, UnityPlayer is abstract and not a View
                // Use the unityView for focus and player for lifecycle
                val focused = unityView?.requestFocus() ?: false
                player.windowFocusChanged(focused)
                player.resume()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error during focusUnity: ${e.message}")
        }
    }

    override fun detachEngineView() {
        runOnMainThread {
            unityView?.let { view ->
                (view.parent as? ViewGroup)?.removeView(view)
                Log.d(TAG, "Unity view detached")
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
            pauseEngine()
            sendEventToFlutter("onUnloaded", null)
        }
    }

    override fun destroyEngine() {
        runOnMainThread {
            try {
                FlutterBridgeRegistry.unregisterAll()
                Log.d(TAG, "Unregistered from FlutterBridgeRegistry")
                
                unityPlayer?.destroy()
                unityPlayer = null
                unityView = null
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
                val jsonMessage = """{"target":"${escapeJsonString(target)}","method":"${escapeJsonString(method)}","data":"${escapeJsonString(data)}"}"""
                UnityPlayer.UnitySendMessage("FlutterBridge", "ReceiveMessage", jsonMessage)
            } catch (e: Exception) {
                sendEventToFlutter("onError", mapOf("message" to "Failed to send message: ${e.message}"))
            }
        }
    }
    
    private fun escapeJsonString(input: String): String {
        return input
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
    }

    override fun getEngineType(): String = ENGINE_TYPE

    override fun getEngineVersion(): String = ENGINE_VERSION

    override fun getView(): View = container

    override fun dispose() {
        Log.d(TAG, "Disposing Unity controller")
        isCancelled.set(true)
        initializationHandler.removeCallbacksAndMessages(null)
        super.dispose()
        destroyEngine()
    }
    
    override fun setStreamingCachePath(path: String) {
        Log.d(TAG, "Setting Unity streaming cache path: $path")
        
        try {
            val cacheDir = java.io.File(path)
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            
            System.setProperty("unity.streaming-assets-path", cacheDir.absolutePath)
            
            if (unityReady) {
                sendMessageToEngine("FlutterAddressablesManager", "SetCachePath", cacheDir.absolutePath)
            }
            
            Log.d(TAG, "Unity streaming cache path set to: ${cacheDir.absolutePath}")
            sendEventToFlutter("onStreamingCachePathSet", mapOf("path" to cacheDir.absolutePath))
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set streaming cache path: ${e.message}")
            sendEventToFlutter("onError", mapOf("message" to "Failed to set streaming cache path: ${e.message}"))
        }
    }

    /**
     * Called from Unity when a message is sent to Flutter
     */
    fun onUnityMessage(target: String, method: String, data: String) {
        Log.d(TAG, "onUnityMessage: target=$target, method=$method")
        Log.d(TAG, "onUnityMessage: data=$data")
        sendEventToFlutter("onMessage", mapOf(
            "target" to target,
            "method" to method,
            "data" to data
        ))
        Log.d(TAG, "onUnityMessage: event sent to Flutter")
    }

    fun getUnityEngineController(): UnityEngineController = this

    fun onUnitySceneLoaded(name: String, buildIndex: Int) {
        sendEventToFlutter("onSceneLoaded", mapOf(
            "name" to name,
            "buildIndex" to buildIndex,
            "isLoaded" to true,
            "isValid" to true,
            "metadata" to emptyMap<String, Any>()
        ))
    }

    override fun onResume(owner: androidx.lifecycle.LifecycleOwner) {
        super.onResume(owner)
        Log.d(TAG, "onResume: unityReady=$unityReady, isUnityPaused=$isUnityPaused")
        if (unityReady) {
            // Reattach and refocus Unity when resuming
            reattachToView()
            if (isUnityPaused) {
                resumeEngine()
            }
        }
    }

    override fun onPause(owner: androidx.lifecycle.LifecycleOwner) {
        super.onPause(owner)
        Log.d(TAG, "onPause: unityReady=$unityReady, isUnityPaused=$isUnityPaused")
        if (unityReady && !isUnityPaused) {
            pauseEngine()
        }
    }
    
    /**
     * Reattach Unity view to container if needed (e.g., after resuming)
     */
    private fun reattachToView() {
        runOnMainThread {
            unityView?.let { view ->
                if (view.parent != container) {
                    Log.d(TAG, "Reattaching Unity view to container")
                    attachEngineView()
                    // Refocus after reattaching
                    refocusUnity()
                } else {
                    // Just request layout to ensure proper rendering
                    container.requestLayout()
                }
            }
        }
    }

    override fun onDestroy(owner: androidx.lifecycle.LifecycleOwner) {
        super.onDestroy(owner)
        destroyEngine()
    }
}

/**
 * Custom FrameLayout container that ensures touch events have the correct source for Unity.
 * 
 * Flutter's platform view system may change the input source of touch events,
 * but Unity expects InputDevice.SOURCE_TOUCHSCREEN to properly process them.
 * This container intercepts all touch events and sets the correct source before
 * dispatching to Unity's view hierarchy.
 * 
 * This is equivalent to flutter-unity-view-widget's CustomUnityPlayer behavior,
 * adapted for Unity 6 where UnityPlayer is abstract and not directly subclassable.
 */
@SuppressLint("ViewConstructor")
class UnityTouchContainer(context: Context) : FrameLayout(context) {
    
    companion object {
        private const val TAG = "UnityTouchContainer"
    }
    
    init {
        // Ensure the container can receive touch events
        isFocusable = true
        isFocusableInTouchMode = true
        isClickable = true
    }
    
    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        if (ev == null) return super.dispatchTouchEvent(ev)
        
        // CRITICAL: Set the source to touchscreen for Unity
        // This is the key fix from flutter-unity-view-widget's CustomUnityPlayer
        ev.source = InputDevice.SOURCE_TOUCHSCREEN
        
        return super.dispatchTouchEvent(ev)
    }
    
    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent?): Boolean {
        if (event == null) return false
        
        // CRITICAL: Set the source to touchscreen for Unity
        event.source = InputDevice.SOURCE_TOUCHSCREEN
        
        return super.onTouchEvent(event)
    }
    
    override fun onInterceptTouchEvent(ev: MotionEvent?): Boolean {
        if (ev != null) {
            // CRITICAL: Set the source to touchscreen for Unity
            ev.source = InputDevice.SOURCE_TOUCHSCREEN
        }
        // Don't intercept - let events pass through to Unity's view
        return false
    }
}
