package com.xraph.gameframework.gameframework.core

import android.app.Activity
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

        // FUW Pattern: Get Activity and Lifecycle from registry
        // Activity comes from onAttachedToActivity - the ONLY proper way to get it
        val activity = GameEngineRegistry.instance.getCurrentActivity()
            ?: throw IllegalStateException("Activity not available - ensure plugin is properly initialized")
        
        val lifecycle = GameEngineRegistry.instance.getCurrentLifecycle()
            ?: throw IllegalStateException("Lifecycle not available - ensure plugin is properly initialized")

        // Pass both Context (for resources) and Activity (for engine operations) separately
        val controller = createController(context, activity, viewId, messenger, lifecycle, config)
        GameEngineRegistry.instance.registerController(controller)
        return controller
    }

    /**
     * Create engine-specific controller
     *
     * This must be implemented by each engine plugin to return
     * its specific controller implementation.
     *
     * @param context Context for general Android operations (resources, inflater, etc.)
     * @param activity Activity from onAttachedToActivity for engine-specific operations
     * @param viewId Unique identifier for this view
     * @param messenger Binary messenger for method/event channels
     * @param lifecycle Lifecycle from FlutterLifecycleAdapter
     * @param config Configuration map from Flutter
     */
    abstract fun createController(
        context: Context,
        activity: Activity,
        viewId: Int,
        messenger: BinaryMessenger,
        lifecycle: Lifecycle,
        config: Map<String, Any?>
    ): GameEngineController
}
