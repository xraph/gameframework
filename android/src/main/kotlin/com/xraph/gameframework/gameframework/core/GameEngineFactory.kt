package com.xraph.gameframework.gameframework.core

import android.content.Context
import androidx.lifecycle.Lifecycle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Abstract factory for creating game engine controllers
 *
 * Each engine plugin must provide its own factory implementation
 * that creates engine-specific controllers.
 */
abstract class GameEngineFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(
        context: Context,
        viewId: Int,
        args: Any?
    ): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val config = args as? Map<String, Any?> ?: emptyMap()

        val lifecycle = GameEngineRegistry.instance.getCurrentLifecycle()
            ?: throw IllegalStateException("Lifecycle not available")

        val controller = createController(context, viewId, messenger, lifecycle, config)
        GameEngineRegistry.instance.registerController(controller)
        return controller
    }

    /**
     * Create engine-specific controller
     *
     * This must be implemented by each engine plugin to return
     * its specific controller implementation.
     */
    abstract fun createController(
        context: Context,
        viewId: Int,
        messenger: BinaryMessenger,
        lifecycle: Lifecycle,
        config: Map<String, Any?>
    ): GameEngineController
}
