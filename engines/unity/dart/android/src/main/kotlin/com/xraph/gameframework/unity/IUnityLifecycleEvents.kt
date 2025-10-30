package com.xraph.gameframework.unity

/**
 * Unity Lifecycle Events Interface
 *
 * Callback interface for Unity player lifecycle events
 */
interface IUnityLifecycleEvents {
    /**
     * Called when Unity sends a message to Flutter
     */
    fun onMessage(message: String)

    /**
     * Called when Unity scene is loaded
     */
    fun onSceneLoaded(name: String, buildIndex: Int, isLoaded: Boolean, isValid: Boolean)

    /**
     * Called when Unity is created
     */
    fun onUnityCreated()

    /**
     * Called when Unity is paused
     */
    fun onUnityPaused()

    /**
     * Called when Unity is resumed
     */
    fun onUnityResumed()

    /**
     * Called when Unity is unloaded
     */
    fun onUnityUnloaded()
}
