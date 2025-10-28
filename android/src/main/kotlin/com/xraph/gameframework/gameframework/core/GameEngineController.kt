package com.xraph.gameframework.gameframework.core

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Abstract base class for all game engine controllers.
 *
 * Provides common functionality and defines the contract for engine-specific implementations.
 * Engine plugins (Unity, Unreal, etc.) should extend this class.
 */
abstract class GameEngineController(
    protected val context: Context,
    protected val viewId: Int,
    protected val messenger: BinaryMessenger,
    protected val lifecycle: Lifecycle,
    protected val config: Map<String, Any?>
) : PlatformView, DefaultLifecycleObserver, MethodChannel.MethodCallHandler {

    // Common properties
    protected val methodChannel: MethodChannel
    protected val container: FrameLayout
    protected var disposed = false
    protected var engineReady = false
    protected var enginePaused = false

    init {
        container = FrameLayout(context)
        methodChannel = MethodChannel(
            messenger,
            "com.xraph.gameframework/engine_$viewId"
        )
        methodChannel.setMethodCallHandler(this)
        lifecycle.addObserver(this)
    }

    // ===== Abstract Methods (Engine-specific) =====

    /**
     * Create and initialize the game engine
     */
    protected abstract fun createEngine()

    /**
     * Attach the engine's view to the container
     */
    protected abstract fun attachEngineView()

    /**
     * Detach the engine's view from the container
     */
    protected abstract fun detachEngineView()

    /**
     * Pause the engine execution
     */
    protected abstract fun pauseEngine()

    /**
     * Resume the engine execution
     */
    protected abstract fun resumeEngine()

    /**
     * Unload the engine
     */
    protected abstract fun unloadEngine()

    /**
     * Destroy the engine
     */
    protected abstract fun destroyEngine()

    /**
     * Send a message to the engine
     */
    protected abstract fun sendMessageToEngine(
        target: String,
        method: String,
        data: String
    )

    /**
     * Get engine type identifier
     */
    abstract fun getEngineType(): String

    /**
     * Get engine version
     */
    abstract fun getEngineVersion(): String

    // ===== Common Method Channel Handling =====

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "engine#create" -> {
                createEngine()
                result.success(true)
            }
            "engine#isReady" -> {
                result.success(engineReady)
            }
            "engine#isPaused" -> {
                result.success(enginePaused)
            }
            "engine#isLoaded" -> {
                result.success(engineReady)
            }
            "engine#isInBackground" -> {
                result.success(enginePaused)
            }
            "engine#sendMessage" -> {
                val target = call.argument<String>("target")
                val method = call.argument<String>("method")
                val data = call.argument<String>("data")

                if (target != null && method != null && data != null) {
                    sendMessageToEngine(target, method, data)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing required arguments", null)
                }
            }
            "engine#pause" -> {
                pauseEngine()
                enginePaused = true
                result.success(null)
            }
            "engine#resume" -> {
                resumeEngine()
                enginePaused = false
                result.success(null)
            }
            "engine#unload" -> {
                unloadEngine()
                result.success(null)
            }
            "engine#quit" -> {
                destroyEngine()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    // ===== Lifecycle Methods =====

    override fun onCreate(owner: LifecycleOwner) {
        onEngineCreate()
    }

    override fun onResume(owner: LifecycleOwner) {
        if (!disposed && engineReady) {
            resumeEngine()
            reattachViewIfNeeded()
        }
    }

    override fun onPause(owner: LifecycleOwner) {
        if (!disposed && engineReady) {
            pauseEngine()
            enginePaused = true
        }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        dispose()
    }

    protected open fun onEngineCreate() {
        // Override in subclasses if needed
    }

    protected open fun reattachViewIfNeeded() {
        // Override in subclasses if needed
    }

    // ===== PlatformView Methods =====

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return

        methodChannel.setMethodCallHandler(null)
        lifecycle.removeObserver(this)
        detachEngineView()

        if (config["unloadOnDispose"] as? Boolean == true) {
            unloadEngine()
        }

        disposed = true
    }

    // ===== Utility Methods =====

    /**
     * Send an event to Flutter
     */
    protected fun sendEventToFlutter(event: String, data: Any?) {
        runOnMainThread {
            methodChannel.invokeMethod("events#$event", data)
        }
    }

    /**
     * Run code on main thread
     */
    protected fun runOnMainThread(action: () -> Unit) {
        if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
            action()
        } else {
            android.os.Handler(android.os.Looper.getMainLooper()).post(action)
        }
    }
}
