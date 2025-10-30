package com.xraph.gameframework.unity

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory for creating Unity platform views
 */
class UnityViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any?>
        return UnityPlatformView(
            context,
            viewId,
            creationParams,
            messenger,
            activityProvider
        )
    }
}
