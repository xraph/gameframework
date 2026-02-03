package com.xraph.gameframework.unreal

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Unreal Engine Plugin for Android
 *
 * Manages Unreal Engine integration with Flutter on Android.
 * Provides lifecycle management, communication, and quality settings control.
 */
class UnrealEnginePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null

    companion object {
        private const val CHANNEL_NAME = "gameframework_unreal"
        private const val ENGINE_TYPE = "unreal"
        private const val ENGINE_VERSION = "5.3.0"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    private val controllers = mutableMapOf<Int, UnrealEngineController>()

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getEngineType" -> {
                result.success(ENGINE_TYPE)
            }
            "getEngineVersion" -> {
                result.success(ENGINE_VERSION)
            }
            "isEngineSupported" -> {
                result.success(true)
            }
            "engine#create" -> {
                handleEngineCreate(call, result)
            }
            "engine#pause" -> {
                handleEnginePause(call, result)
            }
            "engine#resume" -> {
                handleEngineResume(call, result)
            }
            "engine#unload" -> {
                handleEngineUnload(call, result)
            }
            "engine#quit" -> {
                handleEngineQuit(call, result)
            }
            "engine#sendMessage" -> {
                handleSendMessage(call, result)
            }
            "engine#sendJsonMessage" -> {
                handleSendJsonMessage(call, result)
            }
            "engine#executeConsoleCommand" -> {
                handleExecuteConsoleCommand(call, result)
            }
            "engine#loadLevel" -> {
                handleLoadLevel(call, result)
            }
            "engine#applyQualitySettings" -> {
                handleApplyQualitySettings(call, result)
            }
            "engine#getQualitySettings" -> {
                handleGetQualitySettings(call, result)
            }
            "engine#isInBackground" -> {
                handleIsInBackground(call, result)
            }
            // Binary messaging
            "engine#sendBinaryMessage" -> {
                handleSendBinaryMessage(call, result)
            }
            "engine#sendBinaryChunk" -> {
                handleSendBinaryChunk(call, result)
            }
            "engine#sendCompressedMessage" -> {
                handleSendCompressedMessage(call, result)
            }
            "engine#setBinaryChunkSize" -> {
                handleSetBinaryChunkSize(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleEngineCreate(call: MethodCall, result: Result) {
        val viewId = call.argument<Int>("viewId") ?: 0
        val config = call.argument<Map<String, Any>>("config") ?: emptyMap()

        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        val controller = UnrealEngineController(
            context!!,
            currentActivity,
            viewId,
            channel,
            config
        )

        val success = controller.create()
        if (success) {
            controllers[viewId] = controller
        }

        result.success(success)
    }

    private fun handleEnginePause(call: MethodCall, result: Result) {
        getController(call)?.pause()
        result.success(null)
    }

    private fun handleEngineResume(call: MethodCall, result: Result) {
        getController(call)?.resume()
        result.success(null)
    }

    private fun handleEngineUnload(call: MethodCall, result: Result) {
        getController(call)?.unload()
        result.success(null)
    }

    private fun handleEngineQuit(call: MethodCall, result: Result) {
        val viewId = call.argument<Int>("viewId") ?: 0
        getController(call)?.quit()
        controllers.remove(viewId)
        result.success(null)
    }

    private fun handleSendMessage(call: MethodCall, result: Result) {
        val target = call.argument<String>("target") ?: ""
        val method = call.argument<String>("method") ?: ""
        val data = call.argument<String>("data") ?: ""

        getController(call)?.sendMessage(target, method, data)
        result.success(null)
    }

    private fun handleSendJsonMessage(call: MethodCall, result: Result) {
        val target = call.argument<String>("target") ?: ""
        val method = call.argument<String>("method") ?: ""
        val data = call.argument<Map<String, Any>>("data") ?: emptyMap()

        getController(call)?.sendJsonMessage(target, method, data)
        result.success(null)
    }

    private fun handleExecuteConsoleCommand(call: MethodCall, result: Result) {
        val command = call.argument<String>("command") ?: ""
        getController(call)?.executeConsoleCommand(command)
        result.success(null)
    }

    private fun handleLoadLevel(call: MethodCall, result: Result) {
        val levelName = call.argument<String>("levelName") ?: ""
        getController(call)?.loadLevel(levelName)
        result.success(null)
    }

    private fun handleApplyQualitySettings(call: MethodCall, result: Result) {
        val settings = call.arguments as? Map<String, Any> ?: emptyMap()
        getController(call)?.applyQualitySettings(settings)
        result.success(null)
    }

    private fun handleGetQualitySettings(call: MethodCall, result: Result) {
        val settings = getController(call)?.getQualitySettings()
        result.success(settings)
    }

    private fun handleIsInBackground(call: MethodCall, result: Result) {
        val isBackground = getController(call)?.isInBackground() ?: false
        result.success(isBackground)
    }

    // MARK: - Binary Messaging Handlers

    private fun handleSendBinaryMessage(call: MethodCall, result: Result) {
        val target = call.argument<String>("target") ?: ""
        val method = call.argument<String>("method") ?: ""
        val data = call.argument<String>("data") ?: ""
        val originalSize = call.argument<Int>("originalSize") ?: 0
        val compressedSize = call.argument<Int>("compressedSize") ?: 0
        val isCompressed = call.argument<Boolean>("isCompressed") ?: false
        val checksum = call.argument<Int>("checksum") ?: 0

        getController(call)?.sendBinaryMessage(
            target, method, data, originalSize, compressedSize, isCompressed, checksum
        )
        result.success(null)
    }

    private fun handleSendBinaryChunk(call: MethodCall, result: Result) {
        val target = call.argument<String>("target") ?: ""
        val method = call.argument<String>("method") ?: ""
        val chunkType = call.argument<String>("type") ?: "data"
        val transferId = call.argument<String>("transferId") ?: ""
        val chunkIndex = call.argument<Int>("chunkIndex")
        val totalChunks = call.argument<Int>("totalChunks") ?: 0
        val totalSize = call.argument<Int>("totalSize")
        val data = call.argument<String>("data")
        val checksum = call.argument<Int>("checksum")

        getController(call)?.sendBinaryChunk(
            target, method, chunkType, transferId, chunkIndex, totalChunks, totalSize, data, checksum
        )
        result.success(null)
    }

    private fun handleSendCompressedMessage(call: MethodCall, result: Result) {
        val target = call.argument<String>("target") ?: ""
        val method = call.argument<String>("method") ?: ""
        val data = call.argument<String>("data") ?: ""
        val originalSize = call.argument<Int>("originalSize") ?: 0
        val compressedSize = call.argument<Int>("compressedSize") ?: 0

        getController(call)?.sendCompressedMessage(target, method, data, originalSize, compressedSize)
        result.success(null)
    }

    private fun handleSetBinaryChunkSize(call: MethodCall, result: Result) {
        val size = call.argument<Int>("size") ?: 65536
        getController(call)?.setBinaryChunkSize(size)
        result.success(null)
    }

    private fun getController(call: MethodCall): UnrealEngineController? {
        val viewId = call.argument<Int>("viewId") ?: 0
        return controllers[viewId]
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ActivityAware implementation
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
