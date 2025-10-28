package com.xraph.gameframework.gameframework

import android.app.Activity
import androidx.annotation.NonNull
import androidx.lifecycle.Lifecycle
import com.xraph.gameframework.gameframework.core.GameEngineRegistry
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * GameframeworkPlugin - Main plugin for Flutter Game Framework
 *
 * This plugin provides the core infrastructure for embedding game engines.
 * Engine-specific plugins (Unity, Unreal) register their factories here.
 */
class GameframeworkPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var lifecycle: Lifecycle? = null
    private val engineRegistry = GameEngineRegistry.instance

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "gameframework")
        channel.setMethodCallHandler(this)

        // Register platform view factories for each registered engine type
        // Engine plugins will have registered their factories by this point
        engineRegistry.getRegisteredEngines().forEach { engineType ->
            val factory = engineRegistry.getFactory(engineType)
            if (factory != null) {
                binding.platformViewRegistry.registerViewFactory(
                    "com.xraph.gameframework/$engineType",
                    factory
                )
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)

        // Notify registry of activity attachment
        activity?.let { act ->
            lifecycle?.let { lc ->
                engineRegistry.onActivityAttached(act, lc)
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        engineRegistry.onActivityDetached()
        activity = null
        lifecycle = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getRegisteredEngines" -> {
                result.success(engineRegistry.getRegisteredEngines())
            }
            "isEngineRegistered" -> {
                val engineType = call.argument<String>("engineType")
                if (engineType != null) {
                    result.success(engineRegistry.isEngineRegistered(engineType))
                } else {
                    result.error("INVALID_ARGS", "Missing engineType", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}
