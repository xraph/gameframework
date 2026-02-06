package com.xraph.gameframework.unreal

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.lifecycle.Lifecycle
import com.xraph.gameframework.gameframework.core.GameEngineController
import com.xraph.gameframework.gameframework.core.GameEngineFactory
import com.xraph.gameframework.gameframework.core.GameEngineRegistry
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/**
 * Unreal Engine Plugin for Android
 *
 * This plugin registers the Unreal engine factory DIRECTLY with Flutter's platform view registry.
 * This approach ensures the platform view is registered regardless of plugin initialization order.
 *
 * Architecture follows the same pattern as UnityEnginePlugin for consistency.
 */
class UnrealEnginePlugin : FlutterPlugin {

    companion object {
        private const val TAG = "UnrealEnginePlugin"
        private const val ENGINE_TYPE = "unreal"
        private const val VIEW_TYPE = "com.xraph.gameframework/unreal"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine: Registering Unreal platform view factory")
        
        // CRITICAL: Register platform view factory DIRECTLY with Flutter
        // This ensures the view is registered regardless of plugin initialization order
        val factory = UnrealEngineFactory(binding.binaryMessenger)
        binding.platformViewRegistry.registerViewFactory(VIEW_TYPE, factory)
        Log.d(TAG, "Registered view factory for type: $VIEW_TYPE")
        
        // Also register with game framework registry for controller management
        GameEngineRegistry.instance.registerFactory(ENGINE_TYPE, factory)
        Log.d(TAG, "Registered with GameEngineRegistry as: $ENGINE_TYPE")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onDetachedFromEngine: Unregistering Unreal factory")
        // Unregister Unreal factory
        GameEngineRegistry.instance.unregisterFactory(ENGINE_TYPE)
    }
}

/**
 * Factory for creating Unreal engine controllers
 *
 * FUW Pattern: Activity is passed separately from Context, obtained from
 * onAttachedToActivity and provided via GameEngineRegistry.
 */
class UnrealEngineFactory(
    messenger: BinaryMessenger
) : GameEngineFactory(messenger) {

    companion object {
        private const val TAG = "UnrealEngineFactory"
    }

    override fun createController(
        context: Context,
        activity: Activity,
        viewId: Int,
        messenger: BinaryMessenger,
        lifecycle: Lifecycle,
        config: Map<String, Any?>
    ): GameEngineController {
        Log.d(TAG, "Creating Unreal engine controller with Activity from onAttachedToActivity, viewId: $viewId")
        return UnrealEngineController(
            context,
            activity,
            viewId,
            messenger,
            lifecycle,
            config
        )
    }
}
