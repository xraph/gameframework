package com.xraph.gameframework.unity

import android.content.Context
import androidx.lifecycle.Lifecycle
import android.util.Log
import com.xraph.gameframework.gameframework.core.GameEngineController
import com.xraph.gameframework.gameframework.core.GameEngineFactory
import com.xraph.gameframework.gameframework.core.GameEngineRegistry
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/**
 * UnityEnginePlugin - Plugin for Unity Engine integration
 *
 * This plugin registers the Unity engine factory DIRECTLY with Flutter's platform view registry.
 * This approach ensures the platform view is registered regardless of plugin initialization order.
 * 
 * Inspired by: https://github.com/juicycleff/flutter-unity-view-widget
 */
class UnityEnginePlugin : FlutterPlugin {

    companion object {
        private const val ENGINE_TYPE = "unity"
        private const val VIEW_TYPE = "com.xraph.gameframework/unity"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // CRITICAL: Register platform view factory DIRECTLY with Flutter
        // This ensures the view is registered regardless of plugin initialization order
        val factory = UnityEngineFactory(binding.binaryMessenger)
        binding.platformViewRegistry.registerViewFactory(VIEW_TYPE, factory)
        
        // Also register with game framework registry for controller management
        GameEngineRegistry.instance.registerFactory(ENGINE_TYPE, factory)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Unregister Unity factory
        GameEngineRegistry.instance.unregisterFactory(ENGINE_TYPE)
    }
}

/**
 * Factory for creating Unity engine controllers
 * 
 * FUW Pattern: Activity is passed separately from Context, obtained from
 * onAttachedToActivity and provided via GameEngineRegistry.
 */
class UnityEngineFactory(
    messenger: BinaryMessenger
) : GameEngineFactory(messenger) {

    override fun createController(
        context: Context,
        activity: android.app.Activity,
        viewId: Int,
        messenger: BinaryMessenger,
        lifecycle: Lifecycle,
        config: Map<String, Any?>
    ): GameEngineController {
        Log.d("UnityEngineFactory", "Creating Unity engine controller with Activity from onAttachedToActivity")
        return UnityEngineController(
            context,
            activity,
            viewId,
            messenger,
            lifecycle,
            config
        )
    }
}
