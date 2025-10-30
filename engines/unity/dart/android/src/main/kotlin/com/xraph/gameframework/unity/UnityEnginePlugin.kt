package com.xraph.gameframework.unity

import android.app.Activity
import androidx.annotation.NonNull
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformViewRegistry

/**
 * Unity Engine Plugin for Flutter Game Framework
 *
 * Provides Unity integration with platform views and bidirectional communication
 */
class UnityEnginePlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var lifecycle: Lifecycle? = null
    private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding

    companion object {
        private const val CHANNEL_NAME = "com.xraph.gameframework.unity"
        private const val VIEW_TYPE = "com.xraph.gameframework/unity"
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        // Register Unity platform view factory
        registerPlatformView(binding.platformViewRegistry, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        android.util.Log.d("UnityEnginePlugin", "onAttachedToActivity called")
        activity = binding.activity
        lifecycle = null // Lifecycle not currently used

        // Just set the activity reference - Unity will be initialized when the platform view is created
        activity?.let {
            android.util.Log.d("UnityEnginePlugin", "Setting activity reference in UnityPlayerManager")
            UnityPlayerManager.setActivity(it)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        // Clean up Unity on activity detach
        UnityPlayerManager.unload()
        UnityPlayerManager.setActivity(null)

        activity = null
        lifecycle = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isUnityReady" -> {
                // Check if Unity is initialized
                result.success(UnityPlayerManager.isInitialized())
            }
            "getUnityVersion" -> {
                result.success(UnityPlayerManager.getUnityVersion())
            }
            "pauseUnity" -> {
                UnityPlayerManager.pause()
                result.success(null)
            }
            "resumeUnity" -> {
                UnityPlayerManager.resume()
                result.success(null)
            }
            "unloadUnity" -> {
                UnityPlayerManager.unload()
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
                    result.error("INVALID_ARGS", "Missing gameObject or methodName", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun registerPlatformView(
        registry: PlatformViewRegistry,
        messenger: BinaryMessenger
    ) {
        registry.registerViewFactory(
            VIEW_TYPE,
            UnityViewFactory(messenger) { activity }
        )
    }
}
