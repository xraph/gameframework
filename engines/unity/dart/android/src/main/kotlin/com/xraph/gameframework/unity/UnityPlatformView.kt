package com.xraph.gameframework.unity

import android.app.Activity
import android.content.Context
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Unity Platform View
 *
 * Hosts the Unity player within a Flutter platform view
 */
class UnityPlatformView(
    private val context: Context,
    private val viewId: Int,
    creationParams: Map<String, Any?>?,
    messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?
) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val containerView: FrameLayout = FrameLayout(context)
    private val viewMethodChannel: MethodChannel
    private val engineMethodChannel: MethodChannel
    private val eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var unityView: View? = null

    init {
        // Platform view channel (for view-specific methods)
        viewMethodChannel = MethodChannel(
            messenger,
            "com.xraph.gameframework.unity/view_$viewId"
        )
        viewMethodChannel.setMethodCallHandler(this)

        // Engine channel (for game engine communication)
        engineMethodChannel = MethodChannel(
            messenger,
            "com.xraph.gameframework/engine_$viewId"
        )
        engineMethodChannel.setMethodCallHandler(this)

        // Event channel (for Unity → Flutter events)
        eventChannel = EventChannel(
            messenger,
            "com.xraph.gameframework/events_$viewId"
        )
        eventChannel.setStreamHandler(this)

        // Register this view with UnityPlayerManager for receiving events
        UnityPlayerManager.registerEventListener(viewId, this::onUnityEvent)

        // Initialize Unity view
        initializeUnityView(creationParams)
    }

    private fun initializeUnityView(params: Map<String, Any?>?) {
        val activity = activityProvider()

        if (activity == null) {
            showErrorView("Activity not available")
            return
        }

        try {
            // Get or create Unity player with THIS context (the PlatformView context)
            // This is crucial - Unity needs the view context, not just the activity context
            unityView = UnityPlayerManager.getUnityView(context, activity)

            if (unityView != null) {
                // If Unity player is already attached to another parent, remove it first
                (unityView?.parent as? android.view.ViewGroup)?.removeView(unityView)

                // Add Unity player to our container
                containerView.removeAllViews()
                containerView.addView(unityView)

                // Request focus for Unity player
                unityView?.requestFocus()

                // Notify Flutter that Unity is ready (on both channels)
                viewMethodChannel.invokeMethod("onUnityReady", null)
                engineMethodChannel.invokeMethod("onCreated", null)

                android.util.Log.d("UnityPlatformView", "Unity view attached successfully to view $viewId")
            } else {
                showErrorView("Unity not initialized. Make sure unityLibrary is properly integrated.")
            }
        } catch (e: Exception) {
            showErrorView("Error initializing Unity: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun showErrorView(message: String) {
        val textView = TextView(context).apply {
            text = message
            textSize = 14f
            setPadding(16, 16, 16, 16)
        }
        containerView.removeAllViews()
        containerView.addView(textView)
    }

    override fun getView(): View {
        return containerView
    }

    override fun dispose() {
        viewMethodChannel.setMethodCallHandler(null)
        engineMethodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        UnityPlayerManager.unregisterEventListener(viewId)
        eventSink = null
        // Don't dispose Unity player here as it may be shared
    }

    // EventChannel.StreamHandler implementation
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        android.util.Log.d("UnityPlatformView", "Event stream started for view $viewId")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        android.util.Log.d("UnityPlatformView", "Event stream cancelled for view $viewId")
    }

    // Callback for Unity events
    private fun onUnityEvent(event: Map<String, Any>) {
        eventSink?.success(event)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // View channel methods
            "pause" -> {
                UnityPlayerManager.pause()
                result.success(null)
            }
            "resume" -> {
                UnityPlayerManager.resume()
                result.success(null)
            }
            "sendMessage" -> {
                val gameObject = call.argument<String>("gameObject")
                val methodName = call.argument<String>("methodName")
                val message = call.argument<String>("message") ?: ""

                if (gameObject != null && methodName != null) {
                    UnityPlayerManager.sendMessage(gameObject, methodName, message)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                }
            }

            // Engine channel methods (prefixed with engine#)
            "engine#isReady" -> {
                result.success(UnityPlayerManager.isInitialized())
            }
            "engine#isPaused" -> {
                result.success(false) // TODO: Implement pause state tracking
            }
            "engine#isLoaded" -> {
                result.success(UnityPlayerManager.isInitialized())
            }
            "engine#isInBackground" -> {
                result.success(false) // TODO: Implement background state tracking
            }
            "engine#create" -> {
                result.success(UnityPlayerManager.isInitialized())
            }
            "engine#sendMessage" -> {
                val target = call.argument<String>("target")
                val method = call.argument<String>("method")
                val data = call.argument<String>("data") ?: ""

                if (target != null && method != null) {
                    UnityPlayerManager.sendMessage(target, method, data)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing target or method", null)
                }
            }
            "engine#pause" -> {
                UnityPlayerManager.pause()
                result.success(null)
            }
            "engine#resume" -> {
                UnityPlayerManager.resume()
                result.success(null)
            }
            "engine#unload" -> {
                UnityPlayerManager.unload()
                result.success(null)
            }
            "engine#quit" -> {
                UnityPlayerManager.unload()
                result.success(null)
            }

            else -> {
                result.notImplemented()
            }
        }
    }
}
