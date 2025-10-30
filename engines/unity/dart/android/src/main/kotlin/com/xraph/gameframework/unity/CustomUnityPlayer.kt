package com.xraph.gameframework.unity

import android.app.Activity
import android.view.MotionEvent
import com.unity3d.player.IUnityPlayerLifecycleEvents
import com.unity3d.player.UnityPlayer

/**
 * Custom Unity Player
 *
 * Extends UnityPlayer to provide custom behavior and lifecycle management
 *
 * Note: The UnityPlayer parent constructor throws Resources$NotFoundException
 * but this is a known Unity issue and doesn't prevent the player from working.
 */
class CustomUnityPlayer : UnityPlayer {

    constructor(context: Activity, lifecycleEvents: IUnityPlayerLifecycleEvents?) : super(context, lifecycleEvents) {
        // If we reach here, Unity was created successfully despite any exceptions
        android.util.Log.d("CustomUnityPlayer", "CustomUnityPlayer initialized")
    }

    constructor(context: Activity) : super(context) {
        android.util.Log.d("CustomUnityPlayer", "CustomUnityPlayer initialized (no lifecycle)")
    }

    // Companion object to create instance while handling the resource exception
    companion object {
        @JvmStatic
        fun create(context: Activity, lifecycleEvents: IUnityPlayerLifecycleEvents?): CustomUnityPlayer? {
            return try {
                android.util.Log.d("CustomUnityPlayer", "Attempting to create CustomUnityPlayer...")
                CustomUnityPlayer(context, lifecycleEvents)
            } catch (e: android.content.res.Resources.NotFoundException) {
                // This is the expected resource exception - but Unity should still be created
                android.util.Log.w("CustomUnityPlayer", "Resource exception (expected): ${e.message}")
                // Unfortunately, if constructor throws, we don't get the object in Kotlin
                null
            } catch (e: Exception) {
                android.util.Log.e("CustomUnityPlayer", "Unexpected exception creating Unity", e)
                null
            }
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        android.util.Log.d("CustomUnityPlayer", "Unity player attached to window")
    }

    override fun onDetachedFromWindow() {
        android.util.Log.d("CustomUnityPlayer", "Unity player detached from window")
        super.onDetachedFromWindow()
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        // Modify the source for Flutter compatibility
        ev?.source = 4098
        return super.dispatchTouchEvent(ev)
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        // Handle touch events with Flutter virtual display compatibility
        event?.let {
            // Modify the device ID for compatibility with Flutter's platform views
            try {
                val deviceIdField = MotionEvent::class.java.getDeclaredField("mDeviceId")
                deviceIdField.isAccessible = true
                deviceIdField.setInt(event, 0)
            } catch (e: Exception) {
                // If reflection fails, continue without modification
                android.util.Log.w("CustomUnityPlayer", "Could not modify device ID: ${e.message}")
            }
        }
        return super.onTouchEvent(event)
    }
}
