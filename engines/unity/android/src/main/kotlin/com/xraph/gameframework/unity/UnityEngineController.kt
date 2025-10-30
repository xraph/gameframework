package com.xraph.gameframework.unity

import android.content.Context
import android.view.View
import androidx.lifecycle.Lifecycle
import com.unity3d.player.UnityPlayer
import com.xraph.gameframework.gameframework.core.GameEngineController
import io.flutter.plugin.common.BinaryMessenger

/**
 * Unity-specific implementation of GameEngineController
 *
 * This controller manages the Unity player lifecycle and communication
 * between Flutter and Unity.
 */
class UnityEngineController(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    lifecycle: Lifecycle,
    config: Map<String, Any?>
) : GameEngineController(context, viewId, messenger, lifecycle, config) {

    private var unityPlayer: UnityPlayer? = null
    private var unityReady = false

    companion object {
        private const val ENGINE_TYPE = "unity"
        private const val ENGINE_VERSION = "2022.3.0" // Should match Unity version

        // Unity player status
        private var isUnityLoaded = false
        private var isUnityPaused = false
    }

    override fun createEngine() {
        runOnMainThread {
            try {
                if (unityPlayer == null) {
                    // Create Unity player
                    unityPlayer = UnityPlayer(context)

                    // Wait for Unity to initialize
                    unityPlayer?.let { player ->
                        // Unity needs to be added to view hierarchy
                        attachEngineView()

                        // Mark as ready
                        unityReady = true
                        engineReady = true
                        isUnityLoaded = true

                        // Send created event
                        sendEventToFlutter("onCreated", null)
                        sendEventToFlutter("onLoaded", null)
                    }
                }
            } catch (e: Exception) {
                sendEventToFlutter("onError", mapOf("message" to e.message))
            }
        }
    }

    override fun attachEngineView() {
        runOnMainThread {
            unityPlayer?.let { player ->
                if (player.parent == null) {
                    container.addView(player)
                    player.bringToFront()
                    player.requestLayout()
                    player.invalidate()
                    sendEventToFlutter("onAttached", null)
                }
            }
        }
    }

    override fun detachEngineView() {
        runOnMainThread {
            unityPlayer?.let { player ->
                container.removeView(player)
                sendEventToFlutter("onDetached", null)
            }
        }
    }

    override fun pauseEngine() {
        runOnMainThread {
            unityPlayer?.pause()
            enginePaused = true
            isUnityPaused = true
            sendEventToFlutter("onPaused", null)
        }
    }

    override fun resumeEngine() {
        runOnMainThread {
            unityPlayer?.resume()
            enginePaused = false
            isUnityPaused = false
            sendEventToFlutter("onResumed", null)
        }
    }

    override fun unloadEngine() {
        runOnMainThread {
            // Unity doesn't support unloading without destroying
            // We'll pause it instead
            pauseEngine()
            sendEventToFlutter("onUnloaded", null)
        }
    }

    override fun destroyEngine() {
        runOnMainThread {
            try {
                unityPlayer?.quit()
                unityPlayer?.destroy()
                unityPlayer = null
                unityReady = false
                engineReady = false
                isUnityLoaded = false
                isUnityPaused = false
                sendEventToFlutter("onDestroyed", null)
            } catch (e: Exception) {
                sendEventToFlutter("onError", mapOf("message" to e.message))
            }
        }
    }

    override fun sendMessageToEngine(target: String, method: String, data: String) {
        runOnMainThread {
            try {
                // Send message to Unity using UnitySendMessage
                UnityPlayer.UnitySendMessage(target, method, data)
            } catch (e: Exception) {
                sendEventToFlutter(
                    "onError",
                    mapOf("message" to "Failed to send message: ${e.message}")
                )
            }
        }
    }

    override fun getEngineType(): String = ENGINE_TYPE

    override fun getEngineVersion(): String = ENGINE_VERSION

    override fun getView(): View {
        return container
    }

    override fun dispose() {
        super.dispose()
        destroyEngine()
    }

    // Unity lifecycle callbacks (called from Unity's C# bridge)

    /**
     * Called from Unity when a message is sent to Flutter
     */
    fun onUnityMessage(target: String, method: String, data: String) {
        sendEventToFlutter(
            "onMessage", mapOf(
                "target" to target,
                "method" to method,
                "data" to data
            )
        )
    }

    /**
     * Called from Unity when a scene is loaded
     */
    fun onUnitySceneLoaded(name: String, buildIndex: Int) {
        sendEventToFlutter(
            "onSceneLoaded", mapOf(
                "name" to name,
                "buildIndex" to buildIndex,
                "isLoaded" to true,
                "isValid" to true,
                "metadata" to emptyMap<String, Any>()
            )
        )
    }

    // Lifecycle callbacks from DefaultLifecycleObserver

    override fun onResume(owner: androidx.lifecycle.LifecycleOwner) {
        super.onResume(owner)
        if (unityReady && isUnityPaused) {
            resumeEngine()
        }
    }

    override fun onPause(owner: androidx.lifecycle.LifecycleOwner) {
        super.onPause(owner)
        if (unityReady && !isUnityPaused) {
            pauseEngine()
        }
    }

    override fun onDestroy(owner: androidx.lifecycle.LifecycleOwner) {
        super.onDestroy(owner)
        destroyEngine()
    }
}
