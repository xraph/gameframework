package com.xraph.gameframework.gameframework

import com.xraph.gameframework.gameframework.core.GameEngineConfig
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Unit tests for GameEngineConfig
 */
class GameEngineConfigTest {

    @Test
    fun testDefaultValues() {
        val config = GameEngineConfig()
        
        assertFalse(config.fullscreen)
        assertFalse(config.hideStatusBar)
        assertFalse(config.runImmediately)
        assertFalse(config.unloadOnDispose)
        assertTrue(config.enableDebugLogs)
        assertNull(config.targetFrameRate)
        assertNull(config.engineSpecificConfig)
    }

    @Test
    fun testFromMapWithFullConfig() {
        val map = mapOf(
            "fullscreen" to true,
            "hideStatusBar" to true,
            "runImmediately" to true,
            "unloadOnDispose" to true,
            "enableDebugLogs" to false,
            "targetFrameRate" to 60,
            "engineSpecificConfig" to mapOf("key" to "value")
        )
        
        val config = GameEngineConfig.fromMap(map)
        
        assertTrue(config.fullscreen)
        assertTrue(config.hideStatusBar)
        assertTrue(config.runImmediately)
        assertTrue(config.unloadOnDispose)
        assertFalse(config.enableDebugLogs)
        assertEquals(60, config.targetFrameRate)
        assertEquals(mapOf("key" to "value"), config.engineSpecificConfig)
    }

    @Test
    fun testFromMapWithPartialConfig() {
        val map = mapOf(
            "fullscreen" to true,
            "targetFrameRate" to 30
        )
        
        val config = GameEngineConfig.fromMap(map)
        
        assertTrue(config.fullscreen)
        assertFalse(config.hideStatusBar) // Default
        assertFalse(config.runImmediately) // Default
        assertTrue(config.enableDebugLogs) // Default
        assertEquals(30, config.targetFrameRate)
    }

    @Test
    fun testFromEmptyMap() {
        val config = GameEngineConfig.fromMap(emptyMap())
        
        assertFalse(config.fullscreen)
        assertFalse(config.hideStatusBar)
        assertFalse(config.runImmediately)
        assertTrue(config.enableDebugLogs)
        assertNull(config.targetFrameRate)
    }

    @Test
    fun testToMapRoundTrip() {
        val original = GameEngineConfig(
            fullscreen = true,
            hideStatusBar = true,
            runImmediately = true,
            unloadOnDispose = false,
            enableDebugLogs = true,
            targetFrameRate = 120
        )
        
        val map = original.toMap()
        val restored = GameEngineConfig.fromMap(map)
        
        assertEquals(original.fullscreen, restored.fullscreen)
        assertEquals(original.hideStatusBar, restored.hideStatusBar)
        assertEquals(original.runImmediately, restored.runImmediately)
        assertEquals(original.unloadOnDispose, restored.unloadOnDispose)
        assertEquals(original.enableDebugLogs, restored.enableDebugLogs)
        assertEquals(original.targetFrameRate, restored.targetFrameRate)
    }
}
