package com.xraph.gameframework.gameframework.core

import android.app.Activity
import androidx.lifecycle.Lifecycle

/**
 * Singleton registry for game engine implementations
 *
 * Manages the registration and lifecycle of engine controllers and factories.
 * Ensures only one engine can be active at a time.
 */
class GameEngineRegistry private constructor() {

    private val factories = mutableMapOf<String, GameEngineFactory>()
    private val controllers = mutableListOf<GameEngineController>()
    private var currentActivity: Activity? = null
    private var currentLifecycle: Lifecycle? = null

    companion object {
        @Volatile
        private var INSTANCE: GameEngineRegistry? = null

        val instance: GameEngineRegistry
            get() = INSTANCE ?: synchronized(this) {
                INSTANCE ?: GameEngineRegistry().also { INSTANCE = it }
            }
    }

    /**
     * Register an engine factory for a specific engine type
     *
     * Called by engine plugins during initialization.
     *
     * @param engineType The engine identifier (e.g., "unity", "unreal")
     * @param factory The factory that creates controllers for this engine
     */
    fun registerFactory(engineType: String, factory: GameEngineFactory) {
        factories[engineType] = factory
    }

    /**
     * Unregister an engine factory
     */
    fun unregisterFactory(engineType: String) {
        factories.remove(engineType)
    }

    /**
     * Check if an engine is registered
     */
    fun isEngineRegistered(engineType: String): Boolean {
        return factories.containsKey(engineType)
    }

    /**
     * Get all registered engine types
     */
    fun getRegisteredEngines(): List<String> {
        return factories.keys.toList()
    }

    /**
     * Get factory for a specific engine type
     */
    fun getFactory(engineType: String): GameEngineFactory? {
        return factories[engineType]
    }

    /**
     * Register a controller instance
     *
     * Called automatically by factories when creating controllers.
     */
    fun registerController(controller: GameEngineController) {
        controllers.add(controller)
    }

    /**
     * Unregister a controller instance
     */
    fun unregisterController(controller: GameEngineController) {
        controllers.remove(controller)
    }

    /**
     * Get all active controllers
     */
    fun getControllers(): List<GameEngineController> {
        return controllers.toList()
    }

    /**
     * Notify all controllers of activity attachment
     */
    fun onActivityAttached(activity: Activity, lifecycle: Lifecycle) {
        currentActivity = activity
        currentLifecycle = lifecycle
    }

    /**
     * Notify all controllers of activity detachment
     */
    fun onActivityDetached() {
        currentActivity = null
        currentLifecycle = null
    }

    /**
     * Get the current activity
     */
    fun getCurrentActivity(): Activity? = currentActivity

    /**
     * Get the current lifecycle
     */
    fun getCurrentLifecycle(): Lifecycle? = currentLifecycle

    /**
     * Clear all registrations (mainly for testing)
     */
    fun clear() {
        factories.clear()
        controllers.clear()
        currentActivity = null
        currentLifecycle = null
    }
}
