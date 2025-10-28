package com.xraph.gameframework.unity

import android.content.Context
import androidx.lifecycle.Lifecycle
import com.xraph.gameframework.gameframework.core.GameEngineController
import com.xraph.gameframework.gameframework.core.GameEngineFactory
import com.xraph.gameframework.gameframework.core.GameEngineRegistry
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/**
 * UnityEnginePlugin - Plugin for Unity Engine integration
 *
 * This plugin registers the Unity engine factory with the game framework,
 * allowing Unity engines to be embedded in Flutter applications.
 */
class UnityEnginePlugin : FlutterPlugin {

    companion object {
        private const val ENGINE_TYPE = "unity"

        /**
         * Manual registration method for early initialization
         *
         * Call this before the Flutter engine is fully initialized if needed.
         */
        @JvmStatic
        fun register() {
            GameEngineRegistry.instance.registerFactory(
                ENGINE_TYPE,
                UnityEngineFactory::class.java.newInstance()
            )
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Register Unity factory with the game framework
        val factory = UnityEngineFactory(binding.binaryMessenger)
        GameEngineRegistry.instance.registerFactory(ENGINE_TYPE, factory)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Unregister Unity factory
        GameEngineRegistry.instance.unregisterFactory(ENGINE_TYPE)
    }
}

/**
 * Factory for creating Unity engine controllers
 */
class UnityEngineFactory(
    messenger: BinaryMessenger
) : GameEngineFactory(messenger) {

    override fun createController(
        context: Context,
        viewId: Int,
        messenger: BinaryMessenger,
        lifecycle: Lifecycle,
        config: Map<String, Any?>
    ): GameEngineController {
        return UnityEngineController(
            context,
            viewId,
            messenger,
            lifecycle,
            config
        )
    }
}
