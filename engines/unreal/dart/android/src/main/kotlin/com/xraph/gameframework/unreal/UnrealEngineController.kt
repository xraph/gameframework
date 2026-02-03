package com.xraph.gameframework.unreal

import android.app.Activity
import android.content.Context
import android.util.Base64
import android.view.View
import android.view.ViewGroup
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream

/**
 * Unreal Engine Controller for Android
 *
 * Manages the Unreal Engine lifecycle, view integration, and communication
 * between Flutter and Unreal Engine on Android.
 */
class UnrealEngineController(
    private val context: Context,
    private val activity: Activity,
    private val viewId: Int,
    private val channel: MethodChannel,
    private val config: Map<String, Any>
) {
    private var unrealView: View? = null
    private val isReady = AtomicBoolean(false)
    private val isPaused = AtomicBoolean(false)
    private val isDestroyed = AtomicBoolean(false)

    companion object {
        private const val TAG = "UnrealEngineController"
        const val ENGINE_TYPE = "unreal"
        const val ENGINE_VERSION = "5.3.0"

        init {
            try {
                System.loadLibrary("UnrealFlutterBridge")
            } catch (e: UnsatisfiedLinkError) {
                // Library not available - Unreal native library not linked
                android.util.Log.w(TAG, "UnrealFlutterBridge native library not found")
            }
        }
    }

    // MARK: - Lifecycle Methods

    /**
     * Initialize and create the Unreal Engine instance
     */
    fun create(): Boolean {
        if (isDestroyed.get()) {
            sendError("Cannot create destroyed engine")
            return false
        }

        if (isReady.get()) {
            return true
        }

        try {
            // Initialize Unreal Engine native
            if (!nativeCreate(config)) {
                sendError("Failed to create Unreal Engine instance")
                return false
            }

            // Create Unreal view
            unrealView = nativeGetView()
            if (unrealView == null) {
                sendError("Failed to get Unreal view")
                return false
            }

            isReady.set(true)
            sendEvent("created")
            sendEvent("loaded")

            return true
        } catch (e: Exception) {
            sendError("Exception during engine creation: ${e.message}")
            return false
        }
    }

    /**
     * Pause the Unreal Engine
     */
    fun pause() {
        if (!isReady.get() || isDestroyed.get()) {
            return
        }

        try {
            nativePause()
            isPaused.set(true)
            sendEvent("paused")
        } catch (e: Exception) {
            sendError("Exception during pause: ${e.message}")
        }
    }

    /**
     * Resume the Unreal Engine
     */
    fun resume() {
        if (!isReady.get() || isDestroyed.get()) {
            return
        }

        try {
            nativeResume()
            isPaused.set(false)
            sendEvent("resumed")
        } catch (e: Exception) {
            sendError("Exception during resume: ${e.message}")
        }
    }

    /**
     * Unload the Unreal Engine (pause and detach)
     */
    fun unload() {
        if (!isReady.get() || isDestroyed.get()) {
            return
        }

        try {
            pause()
            sendEvent("unloaded")
        } catch (e: Exception) {
            sendError("Exception during unload: ${e.message}")
        }
    }

    /**
     * Quit and destroy the Unreal Engine
     */
    fun quit() {
        if (isDestroyed.get()) {
            return
        }

        try {
            nativeQuit()
            unrealView = null
            isReady.set(false)
            isDestroyed.set(true)
            sendEvent("destroyed")
        } catch (e: Exception) {
            sendError("Exception during quit: ${e.message}")
        }
    }

    // MARK: - Communication Methods

    /**
     * Send a message to Unreal Engine
     */
    fun sendMessage(target: String, method: String, data: String) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for messages")
            return
        }

        try {
            nativeSendMessage(target, method, data)
        } catch (e: Exception) {
            sendError("Failed to send message: ${e.message}")
        }
    }

    /**
     * Send a JSON message to Unreal Engine
     */
    fun sendJsonMessage(target: String, method: String, data: Map<String, Any>) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for messages")
            return
        }

        try {
            val jsonString = org.json.JSONObject(data).toString()
            nativeSendMessage(target, method, jsonString)
        } catch (e: Exception) {
            sendError("Failed to send JSON message: ${e.message}")
        }
    }

    // MARK: - Binary Messaging

    /**
     * Send binary data to Unreal Engine
     *
     * @param target Target object in Unreal
     * @param method Method name to call
     * @param data Base64 encoded binary data
     * @param originalSize Original uncompressed size
     * @param compressedSize Size after compression
     * @param isCompressed Whether data is compressed
     * @param checksum CRC32 checksum
     */
    fun sendBinaryMessage(
        target: String,
        method: String,
        data: String,
        originalSize: Int,
        compressedSize: Int,
        isCompressed: Boolean,
        checksum: Int
    ) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for binary messages")
            return
        }

        try {
            val decodedData = Base64.decode(data, Base64.DEFAULT)
            val processedData = if (isCompressed) {
                decompressGzip(decodedData)
            } else {
                decodedData
            }
            nativeSendBinaryMessage(target, method, processedData, checksum)
        } catch (e: Exception) {
            sendError("Failed to send binary message: ${e.message}")
        }
    }

    /**
     * Send binary chunk for chunked transfer
     */
    fun sendBinaryChunk(
        target: String,
        method: String,
        chunkType: String,
        transferId: String,
        chunkIndex: Int?,
        totalChunks: Int,
        totalSize: Int?,
        data: String?,
        checksum: Int?
    ) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for binary chunks")
            return
        }

        try {
            when (chunkType) {
                "header" -> {
                    nativeBinaryChunkHeader(
                        target, method, transferId, totalSize ?: 0, totalChunks, checksum ?: 0
                    )
                }
                "data" -> {
                    val decodedData = data?.let { Base64.decode(it, Base64.DEFAULT) } ?: ByteArray(0)
                    nativeBinaryChunkData(target, method, transferId, chunkIndex ?: 0, decodedData)
                }
                "footer" -> {
                    nativeBinaryChunkFooter(target, method, transferId, totalChunks, checksum ?: 0)
                }
            }
        } catch (e: Exception) {
            sendError("Failed to send binary chunk: ${e.message}")
        }
    }

    /**
     * Send compressed string data
     */
    fun sendCompressedMessage(
        target: String,
        method: String,
        data: String,
        originalSize: Int,
        compressedSize: Int
    ) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for compressed messages")
            return
        }

        try {
            val decodedData = Base64.decode(data, Base64.DEFAULT)
            val decompressed = decompressGzip(decodedData)
            nativeSendMessage(target, method, String(decompressed, Charsets.UTF_8))
        } catch (e: Exception) {
            sendError("Failed to send compressed message: ${e.message}")
        }
    }

    /**
     * Set the chunk size for binary transfers
     */
    fun setBinaryChunkSize(size: Int) {
        try {
            nativeSetBinaryChunkSize(size)
        } catch (e: Exception) {
            android.util.Log.w(TAG, "Failed to set binary chunk size: ${e.message}")
        }
    }

    // MARK: - Compression Utilities

    private fun compressGzip(data: ByteArray): ByteArray {
        val byteStream = ByteArrayOutputStream()
        GZIPOutputStream(byteStream).use { gzip ->
            gzip.write(data)
        }
        return byteStream.toByteArray()
    }

    private fun decompressGzip(data: ByteArray): ByteArray {
        // Check for GZIP magic number
        if (data.size >= 2 && data[0] == 0x1F.toByte() && data[1] == 0x8B.toByte()) {
            val byteStream = ByteArrayInputStream(data)
            GZIPInputStream(byteStream).use { gzip ->
                return gzip.readBytes()
            }
        }
        return data
    }

    // MARK: - Unreal-Specific Methods

    /**
     * Execute a console command in Unreal Engine
     */
    fun executeConsoleCommand(command: String) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for console commands")
            return
        }

        try {
            nativeExecuteConsoleCommand(command)
        } catch (e: Exception) {
            sendError("Failed to execute console command: ${e.message}")
        }
    }

    /**
     * Load a level/map in Unreal Engine
     */
    fun loadLevel(levelName: String) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready to load level")
            return
        }

        try {
            nativeLoadLevel(levelName)
        } catch (e: Exception) {
            sendError("Failed to load level: ${e.message}")
        }
    }

    /**
     * Apply quality settings to Unreal Engine
     */
    fun applyQualitySettings(settings: Map<String, Any>) {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready for quality settings")
            return
        }

        try {
            nativeApplyQualitySettings(settings)
        } catch (e: Exception) {
            sendError("Failed to apply quality settings: ${e.message}")
        }
    }

    /**
     * Get current quality settings from Unreal Engine
     */
    fun getQualitySettings(): Map<String, Any>? {
        if (!isReady.get() || isDestroyed.get()) {
            sendError("Engine not ready")
            return null
        }

        return try {
            nativeGetQualitySettings()
        } catch (e: Exception) {
            sendError("Failed to get quality settings: ${e.message}")
            null
        }
    }

    /**
     * Check if engine is in background
     */
    fun isInBackground(): Boolean {
        return isPaused.get()
    }

    // MARK: - View Integration

    /**
     * Get the Unreal Engine view to attach to Flutter
     */
    fun getView(): View? {
        return unrealView
    }

    /**
     * Attach Unreal view to parent
     */
    fun attachView(parent: ViewGroup) {
        unrealView?.let { view ->
            if (view.parent == null) {
                parent.addView(view)
                sendEvent("attached")
            }
        }
    }

    /**
     * Detach Unreal view from parent
     */
    fun detachView() {
        unrealView?.let { view ->
            (view.parent as? ViewGroup)?.removeView(view)
            sendEvent("detached")
        }
    }

    // MARK: - Event Handling

    private fun sendEvent(eventType: String, message: String? = null) {
        activity.runOnUiThread {
            channel.invokeMethod("onEvent", mapOf(
                "type" to eventType,
                "message" to message
            ))
        }
    }

    private fun sendError(message: String) {
        android.util.Log.e(TAG, message)
        sendEvent("error", message)
    }

    /**
     * Called from native code when a message is received from Unreal
     */
    @Suppress("unused")
    fun onMessageFromUnreal(target: String, method: String, data: String) {
        activity.runOnUiThread {
            channel.invokeMethod("onMessage", mapOf(
                "target" to target,
                "method" to method,
                "data" to data
            ))
        }
    }

    /**
     * Called from native code when a level is loaded
     */
    @Suppress("unused")
    fun onLevelLoaded(levelName: String, buildIndex: Int) {
        activity.runOnUiThread {
            channel.invokeMethod("onLevelLoaded", mapOf(
                "name" to levelName,
                "buildIndex" to buildIndex,
                "isLoaded" to true,
                "isValid" to true,
                "metadata" to emptyMap<String, Any>()
            ))
        }
    }

    /**
     * Called from native code when a binary message is received from Unreal
     */
    @Suppress("unused")
    fun onBinaryMessageFromUnreal(
        target: String,
        method: String,
        data: ByteArray,
        isCompressed: Boolean,
        checksum: Int
    ) {
        activity.runOnUiThread {
            val encodedData = Base64.encodeToString(data, Base64.NO_WRAP)
            channel.invokeMethod("onBinaryMessage", mapOf(
                "target" to target,
                "method" to method,
                "data" to encodedData,
                "isCompressed" to isCompressed,
                "checksum" to checksum
            ))
        }
    }

    /**
     * Called from native code when a binary chunk is received from Unreal
     */
    @Suppress("unused")
    fun onBinaryChunkFromUnreal(
        target: String,
        method: String,
        chunkType: String,
        transferId: String,
        chunkIndex: Int?,
        totalChunks: Int,
        totalSize: Int?,
        data: ByteArray?,
        checksum: Int?
    ) {
        activity.runOnUiThread {
            val chunkMap = mutableMapOf<String, Any>(
                "target" to target,
                "method" to method,
                "type" to chunkType,
                "transferId" to transferId,
                "totalChunks" to totalChunks
            )
            chunkIndex?.let { chunkMap["chunkIndex"] = it }
            totalSize?.let { chunkMap["totalSize"] = it }
            data?.let { chunkMap["data"] = Base64.encodeToString(it, Base64.NO_WRAP) }
            checksum?.let { chunkMap["checksum"] = it }

            channel.invokeMethod("onBinaryChunk", chunkMap)
        }
    }

    /**
     * Called from native code to report binary transfer progress
     */
    @Suppress("unused")
    fun onBinaryProgress(
        transferId: String,
        currentChunk: Int,
        totalChunks: Int,
        bytesTransferred: Long,
        totalBytes: Long
    ) {
        activity.runOnUiThread {
            channel.invokeMethod("onBinaryProgress", mapOf(
                "transferId" to transferId,
                "currentChunk" to currentChunk,
                "totalChunks" to totalChunks,
                "bytesTransferred" to bytesTransferred,
                "totalBytes" to totalBytes
            ))
        }
    }

    // MARK: - Native Methods (JNI)

    /**
     * Create Unreal Engine instance
     */
    private external fun nativeCreate(config: Map<String, Any>): Boolean

    /**
     * Get the native Unreal view
     */
    private external fun nativeGetView(): View?

    /**
     * Pause the engine
     */
    private external fun nativePause()

    /**
     * Resume the engine
     */
    private external fun nativeResume()

    /**
     * Quit the engine
     */
    private external fun nativeQuit()

    /**
     * Send message to Unreal
     */
    private external fun nativeSendMessage(target: String, method: String, data: String)

    /**
     * Execute console command
     */
    private external fun nativeExecuteConsoleCommand(command: String)

    /**
     * Load level
     */
    private external fun nativeLoadLevel(levelName: String)

    /**
     * Apply quality settings
     */
    private external fun nativeApplyQualitySettings(settings: Map<String, Any>)

    /**
     * Get quality settings
     */
    private external fun nativeGetQualitySettings(): Map<String, Any>

    // MARK: - Binary Native Methods (JNI)

    /**
     * Send binary message to Unreal
     */
    private external fun nativeSendBinaryMessage(
        target: String,
        method: String,
        data: ByteArray,
        checksum: Int
    )

    /**
     * Send binary chunk header
     */
    private external fun nativeBinaryChunkHeader(
        target: String,
        method: String,
        transferId: String,
        totalSize: Int,
        totalChunks: Int,
        checksum: Int
    )

    /**
     * Send binary chunk data
     */
    private external fun nativeBinaryChunkData(
        target: String,
        method: String,
        transferId: String,
        chunkIndex: Int,
        data: ByteArray
    )

    /**
     * Send binary chunk footer
     */
    private external fun nativeBinaryChunkFooter(
        target: String,
        method: String,
        transferId: String,
        totalChunks: Int,
        checksum: Int
    )

    /**
     * Set chunk size for binary transfers
     */
    private external fun nativeSetBinaryChunkSize(size: Int)
}
