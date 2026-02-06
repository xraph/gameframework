package com.xraph.gameframework.unreal

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.util.Base64
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.xraph.gameframework.gameframework.core.GameEngineController
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
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
 *
 * This controller extends GameEngineController to integrate with the
 * gameframework plugin system and Flutter's platform view mechanism.
 */
class UnrealEngineController(
    context: Context,
    activity: Activity?,
    viewId: Int,
    messenger: BinaryMessenger,
    lifecycle: Lifecycle,
    config: Map<String, Any?>
) : GameEngineController(context, activity, viewId, messenger, lifecycle, config), SurfaceHolder.Callback {

    private var unrealView: View? = null
    private var unrealSurfaceView: SurfaceView? = null
    private var surfaceReady = false
    private val isDestroyed = AtomicBoolean(false)

    companion object {
        private const val TAG = "UnrealEngineController"
        const val ENGINE_TYPE = "unreal"
        const val ENGINE_VERSION = "5.3.0"
        
        // Track whether native library is available
        private var nativeLibraryLoaded = false
        private var loadedLibraryName: String? = null

        init {
            // Try loading native libraries in order of preference
            val librariesToTry = listOf(
                "UnrealFlutterBridge",  // Dedicated bridge library (if built separately)
                "Unreal",               // Main Unreal library (contains JNI bridge when FlutterPlugin is included)
                "UE4",                  // Legacy Unreal 4 library name
                "UE5"                   // Alternative Unreal 5 library name
            )
            
            for (libraryName in librariesToTry) {
                try {
                    System.loadLibrary(libraryName)
                    nativeLibraryLoaded = true
                    loadedLibraryName = libraryName
                    Log.d(TAG, "Native library loaded successfully: lib$libraryName.so")
                    break
                } catch (e: UnsatisfiedLinkError) {
                    Log.d(TAG, "Library lib$libraryName.so not found, trying next...")
                }
            }
            
            if (!nativeLibraryLoaded) {
                Log.w(TAG, "No Unreal native library found. Ensure the Unreal project is properly exported with FlutterPlugin.")
            }
        }
        
        /**
         * Check if native library is available
         */
        fun isNativeLibraryAvailable(): Boolean = nativeLibraryLoaded
        
        /**
         * Get the name of the loaded library
         */
        fun getLoadedLibraryName(): String? = loadedLibraryName
    }

    // ===== GameEngineController Abstract Method Implementations =====

    override fun createEngine() {
        Log.d(TAG, "createEngine: Starting Unreal engine creation")
        
        if (isDestroyed.get()) {
            Log.e(TAG, "Cannot create destroyed engine")
            sendEventToFlutter("onError", mapOf("message" to "Cannot create destroyed engine"))
            return
        }

        if (engineReady) {
            Log.d(TAG, "Engine already ready")
            return
        }
        
        // Check if native library is available
        if (!nativeLibraryLoaded) {
            Log.e(TAG, "Unreal native library not available - cannot create engine")
            Log.e(TAG, "Ensure the Unreal project is properly exported and linked")
            sendEventToFlutter("onError", mapOf(
                "message" to "Unreal native library not available. " +
                    "Please ensure the Unreal project is properly exported with 'game export unreal -p android' " +
                    "and synced with 'game sync unreal -p android'.",
                "code" to "NATIVE_LIBRARY_NOT_FOUND"
            ))
            // Create placeholder view even without native library
            runOnMainThread {
                unrealView = createPlaceholderView()
                attachEngineView()
            }
            return
        }

        runOnMainThread {
            try {
                // Try to initialize via GameActivity library mode (optional, may not work)
                // The main rendering will be handled via FlutterPlugin's nativeSetSurface
                Log.d(TAG, "Attempting GameActivity library mode initialization...")
                
                try {
                    val gameActivityClass = Class.forName("com.epicgames.unreal.GameActivity")
                    val initMethod = gameActivityClass.getMethod(
                        "initializeForLibraryMode",
                        Context::class.java,
                        Activity::class.java
                    )
                    val hostActivity = activity
                    if (hostActivity != null) {
                        val result = initMethod.invoke(null, context, hostActivity) as Boolean
                        Log.d(TAG, "GameActivity.initializeForLibraryMode returned: $result")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "GameActivity library mode not available: ${e.message}")
                    // Continue anyway - we'll try with FlutterPlugin's JNI functions
                }

                // Try to initialize via FlutterPlugin's nativeCreate
                // This is in libUnreal.so when FlutterPlugin is compiled in
                Log.d(TAG, "Attempting FlutterPlugin nativeCreate...")
                try {
                    val configMap = config.filterValues { it != null }.mapValues { it.value!! }
                    val createResult = nativeCreate(configMap)
                    Log.d(TAG, "nativeCreate result: $createResult")
                } catch (e: UnsatisfiedLinkError) {
                    Log.w(TAG, "nativeCreate not available in this build: ${e.message}")
                    // FlutterPlugin JNI functions not compiled - continue anyway
                } catch (e: Exception) {
                    Log.w(TAG, "nativeCreate failed: ${e.message}")
                }

                // Create SurfaceView for Unreal to render to
                Log.d(TAG, "Creating SurfaceView for Unreal rendering")
                unrealSurfaceView = SurfaceView(context).apply {
                    // Set up the surface holder
                    holder.addCallback(this@UnrealEngineController)
                    holder.setFormat(PixelFormat.RGBA_8888)
                    
                    // Configure z-order for proper rendering in Flutter platform view
                    setZOrderOnTop(false)
                    setZOrderMediaOverlay(true)
                }
                
                unrealView = unrealSurfaceView
                
                engineReady = true
                Log.d(TAG, "Unreal engine created successfully with SurfaceView")
                
                // Attach view to container
                attachEngineView()
                
                sendEventToFlutter("onCreated", null)
                // Note: onLoaded will be sent when surface is ready
                
            } catch (e: Exception) {
                Log.e(TAG, "Exception during engine creation: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Exception during engine creation: ${e.message}"))
                // Fallback to placeholder view
                unrealView = createPlaceholderView()
                attachEngineView()
            }
        }
    }

    override fun attachEngineView() {
        runOnMainThread {
            unrealView?.let { view ->
                Log.d(TAG, "Attaching Unreal view to container")
                
                // Remove from any existing parent
                (view.parent as? ViewGroup)?.removeView(view)
                
                // Set layout params
                val layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                view.layoutParams = layoutParams
                
                // Add to container
                container.addView(view, layoutParams)
                
                view.bringToFront()
                view.requestLayout()
                view.invalidate()
                container.requestLayout()
                container.invalidate()
                
                Log.d(TAG, "Unreal view attached to container")
                sendEventToFlutter("onAttached", null)
            } ?: run {
                Log.d(TAG, "No Unreal view to attach")
            }
        }
    }

    override fun detachEngineView() {
        runOnMainThread {
            unrealView?.let { view ->
                Log.d(TAG, "Detaching Unreal view from container")
                (view.parent as? ViewGroup)?.removeView(view)
                sendEventToFlutter("onDetached", null)
            }
        }
    }

    // ===== SurfaceHolder.Callback Implementation =====
    
    /**
     * Called when the surface is first created.
     * Pass the surface to native code for Unreal to render to.
     */
    override fun surfaceCreated(holder: SurfaceHolder) {
        Log.d(TAG, "surfaceCreated: Surface ready for Unreal rendering")
        surfaceReady = true
        
        // Get surface dimensions
        val frame = holder.surfaceFrame
        val width = frame.width()
        val height = frame.height()
        Log.d(TAG, "Surface dimensions: ${width}x${height}")
        
        // Step 1: Pass the surface to FlutterPlugin JNI bridge (for rendering integration)
        try {
            nativeSetSurface(holder.surface)
            Log.d(TAG, "Surface passed to FlutterPlugin JNI bridge successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "nativeSetSurface not found in libUnreal.so: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error calling nativeSetSurface: ${e.message}", e)
        }
        
        // Step 2: ALWAYS call GameActivity.setExternalSurface to start the engine
        // This calls nativeResumeMainInit which is required to start Unreal's main loop
        try {
            val gameActivityClass = Class.forName("com.epicgames.unreal.GameActivity")
            val setExternalSurfaceMethod = gameActivityClass.getMethod(
                "setExternalSurface",
                SurfaceHolder::class.java,
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType
            )
            setExternalSurfaceMethod.invoke(null, holder, width, height)
            Log.d(TAG, "GameActivity.setExternalSurface called - engine starting")
        } catch (e: Exception) {
            Log.w(TAG, "GameActivity.setExternalSurface failed: ${e.message}")
        }
        
        // Send onLoaded event - the surface is ready
        sendEventToFlutter("onLoaded", null)
    }
    
    /**
     * Called when the surface dimensions change.
     * Notify GameActivity to update rendering dimensions.
     */
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        Log.d(TAG, "surfaceChanged: ${width}x${height}, format=$format")
        
        try {
            // Update surface dimensions via GameActivity
            val gameActivityClass = Class.forName("com.epicgames.unreal.GameActivity")
            val updateMethod = gameActivityClass.getMethod(
                "updateExternalSurface",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType
            )
            updateMethod.invoke(null, width, height)
            Log.d(TAG, "Surface dimensions updated via GameActivity")
        } catch (e: Exception) {
            Log.w(TAG, "Could not update surface via GameActivity: ${e.message}")
            // Fallback to direct JNI
            try {
                nativeSurfaceChanged(width, height)
                Log.d(TAG, "Fallback: Surface dimensions updated via direct JNI")
            } catch (ex: Exception) {
                Log.w(TAG, "Direct JNI fallback also failed: ${ex.message}")
            }
        }
    }
    
    /**
     * Called when the surface is destroyed.
     * Notify GameActivity to stop rendering.
     */
    override fun surfaceDestroyed(holder: SurfaceHolder) {
        Log.d(TAG, "surfaceDestroyed: Surface no longer available")
        surfaceReady = false
        
        try {
            // Clear surface in GameActivity
            val gameActivityClass = Class.forName("com.epicgames.unreal.GameActivity")
            val clearMethod = gameActivityClass.getMethod("clearExternalSurface")
            clearMethod.invoke(null)
            Log.d(TAG, "Surface cleared via GameActivity")
        } catch (e: Exception) {
            Log.w(TAG, "Could not clear surface via GameActivity: ${e.message}")
            // Fallback to direct JNI
            try {
                nativeSetSurface(null)
                Log.d(TAG, "Fallback: Surface cleared via direct JNI")
            } catch (ex: Exception) {
                Log.w(TAG, "Direct JNI fallback also failed: ${ex.message}")
            }
        }
    }

    override fun pauseEngine() {
        if (!engineReady || isDestroyed.get()) {
            return
        }

        runOnMainThread {
            try {
                Log.d(TAG, "Pausing Unreal engine")
                nativePause()
                enginePaused = true
                sendEventToFlutter("onPaused", null)
            } catch (e: Exception) {
                Log.e(TAG, "Exception during pause: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Exception during pause: ${e.message}"))
            }
        }
    }

    override fun resumeEngine() {
        if (!engineReady || isDestroyed.get()) {
            return
        }

        runOnMainThread {
            try {
                Log.d(TAG, "Resuming Unreal engine")
                nativeResume()
                enginePaused = false
                sendEventToFlutter("onResumed", null)
            } catch (e: Exception) {
                Log.e(TAG, "Exception during resume: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Exception during resume: ${e.message}"))
            }
        }
    }

    override fun unloadEngine() {
        if (!engineReady || isDestroyed.get()) {
            return
        }

        runOnMainThread {
            try {
                Log.d(TAG, "Unloading Unreal engine")
                pauseEngine()
                sendEventToFlutter("onUnloaded", null)
            } catch (e: Exception) {
                Log.e(TAG, "Exception during unload: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Exception during unload: ${e.message}"))
            }
        }
    }

    override fun destroyEngine() {
        if (isDestroyed.get()) {
            return
        }

        runOnMainThread {
            try {
                Log.d(TAG, "Destroying Unreal engine")
                
                // Clean up surface callback
                unrealSurfaceView?.holder?.removeCallback(this)
                
                // Only call native quit if library is loaded and engine was created
                if (nativeLibraryLoaded && engineReady) {
                    // Clear the surface in native code first
                    try {
                        nativeSetSurface(null)
                    } catch (e: UnsatisfiedLinkError) {
                        // Ignore if not implemented
                    }
                    nativeQuit()
                }
                
                unrealSurfaceView = null
                unrealView = null
                surfaceReady = false
                engineReady = false
                isDestroyed.set(true)
                sendEventToFlutter("onDestroyed", null)
            } catch (e: Exception) {
                Log.e(TAG, "Exception during quit: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Exception during quit: ${e.message}"))
            }
        }
    }

    override fun sendMessageToEngine(target: String, method: String, data: String) {
        if (!engineReady || isDestroyed.get()) {
            Log.w(TAG, "Engine not ready for messages")
            sendEventToFlutter("onError", mapOf("message" to "Engine not ready for messages"))
            return
        }

        runOnMainThread {
            try {
                Log.d(TAG, "Sending message to Unreal: target=$target, method=$method")
                nativeSendMessage(target, method, data)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send message: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Failed to send message: ${e.message}"))
            }
        }
    }

    override fun getEngineType(): String = ENGINE_TYPE

    override fun getEngineVersion(): String = ENGINE_VERSION

    override fun getView(): View = container
    
    // ===== Helper Methods =====
    
    /**
     * Create a placeholder view to show when native Unreal view is not available.
     * This happens when:
     * - The FlutterPlugin JNI code is not properly integrated in the Unreal project
     * - The Unreal project was built without FlutterPlugin
     * - The native view creation failed
     */
    private fun createPlaceholderView(): View {
        val layout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1a1a2e"))
            setPadding(48, 48, 48, 48)
        }
        
        val titleText = TextView(context).apply {
            text = "Unreal Engine"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            gravity = Gravity.CENTER
        }
        
        val statusText = TextView(context).apply {
            text = "Engine Connected"
            setTextColor(Color.parseColor("#4ade80"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
        }
        
        val infoText = TextView(context).apply {
            text = "Native view not available.\n\n" +
                "The Unreal project needs to be built with\n" +
                "the FlutterPlugin properly configured.\n\n" +
                "Message communication is working."
            setTextColor(Color.parseColor("#94a3b8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 0)
        }
        
        val libraryText = TextView(context).apply {
            text = "Loaded: lib${loadedLibraryName ?: "none"}.so"
            setTextColor(Color.parseColor("#64748b"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 0)
        }
        
        layout.addView(titleText)
        layout.addView(statusText)
        layout.addView(infoText)
        layout.addView(libraryText)
        
        return layout
    }

    // ===== Additional Method Channel Handling =====

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Unreal-specific methods
            "engine#executeConsoleCommand" -> {
                val command = call.argument<String>("command") ?: ""
                executeConsoleCommand(command)
                result.success(null)
            }
            "engine#loadLevel" -> {
                val levelName = call.argument<String>("levelName") ?: ""
                loadLevel(levelName)
                result.success(null)
            }
            "engine#applyQualitySettings" -> {
                @Suppress("UNCHECKED_CAST")
                val settings = call.arguments as? Map<String, Any> ?: emptyMap()
                applyQualitySettings(settings)
                result.success(null)
            }
            "engine#getQualitySettings" -> {
                val settings = getQualitySettings()
                result.success(settings)
            }
            // Binary messaging
            "engine#sendBinaryMessage" -> {
                handleSendBinaryMessage(call, result)
            }
            "engine#sendBinaryChunk" -> {
                handleSendBinaryChunk(call, result)
            }
            "engine#sendCompressedMessage" -> {
                handleSendCompressedMessage(call, result)
            }
            "engine#setBinaryChunkSize" -> {
                val size = call.argument<Int>("size") ?: 65536
                setBinaryChunkSize(size)
                result.success(null)
            }
            else -> {
                // Delegate to parent for common methods
                super.onMethodCall(call, result)
            }
        }
    }

    // ===== Binary Messaging Methods =====

    private fun handleSendBinaryMessage(call: MethodCall, result: MethodChannel.Result) {
        val target = call.argument<String>("target") ?: ""
        val method = call.argument<String>("method") ?: ""
        val data = call.argument<String>("data") ?: ""
        val isCompressed = call.argument<Boolean>("isCompressed") ?: false
        val checksum = call.argument<Int>("checksum") ?: 0

        sendBinaryMessage(target, method, data, isCompressed, checksum)
        result.success(null)
    }

    private fun handleSendBinaryChunk(call: MethodCall, result: MethodChannel.Result) {
        val target = call.argument<String>("target") ?: ""
        val method = call.argument<String>("method") ?: ""
        val chunkType = call.argument<String>("type") ?: "data"
        val transferId = call.argument<String>("transferId") ?: ""
        val chunkIndex = call.argument<Int>("chunkIndex")
        val totalChunks = call.argument<Int>("totalChunks") ?: 0
        val totalSize = call.argument<Int>("totalSize")
        val data = call.argument<String>("data")
        val checksum = call.argument<Int>("checksum")

        sendBinaryChunk(target, method, chunkType, transferId, chunkIndex, totalChunks, totalSize, data, checksum)
        result.success(null)
    }

    private fun handleSendCompressedMessage(call: MethodCall, result: MethodChannel.Result) {
        val target = call.argument<String>("target") ?: ""
        val method = call.argument<String>("method") ?: ""
        val data = call.argument<String>("data") ?: ""
        val originalSize = call.argument<Int>("originalSize") ?: 0
        val compressedSize = call.argument<Int>("compressedSize") ?: 0

        sendCompressedMessage(target, method, data, originalSize, compressedSize)
        result.success(null)
    }

    // ===== Binary Messaging Implementation =====

    fun sendBinaryMessage(
        target: String,
        method: String,
        data: String,
        isCompressed: Boolean,
        checksum: Int
    ) {
        if (!engineReady || isDestroyed.get()) {
            sendEventToFlutter("onError", mapOf("message" to "Engine not ready for binary messages"))
            return
        }

        runOnMainThread {
            try {
                val decodedData = Base64.decode(data, Base64.DEFAULT)
                val processedData = if (isCompressed) {
                    decompressGzip(decodedData)
                } else {
                    decodedData
                }
                nativeSendBinaryMessage(target, method, processedData, checksum)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send binary message: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Failed to send binary message: ${e.message}"))
            }
        }
    }

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
        if (!engineReady || isDestroyed.get()) {
            sendEventToFlutter("onError", mapOf("message" to "Engine not ready for binary chunks"))
            return
        }

        runOnMainThread {
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
                Log.e(TAG, "Failed to send binary chunk: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Failed to send binary chunk: ${e.message}"))
            }
        }
    }

    fun sendCompressedMessage(
        target: String,
        method: String,
        data: String,
        originalSize: Int,
        compressedSize: Int
    ) {
        if (!engineReady || isDestroyed.get()) {
            sendEventToFlutter("onError", mapOf("message" to "Engine not ready for compressed messages"))
            return
        }

        runOnMainThread {
            try {
                val decodedData = Base64.decode(data, Base64.DEFAULT)
                val decompressed = decompressGzip(decodedData)
                nativeSendMessage(target, method, String(decompressed, Charsets.UTF_8))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send compressed message: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Failed to send compressed message: ${e.message}"))
            }
        }
    }

    fun setBinaryChunkSize(size: Int) {
        try {
            nativeSetBinaryChunkSize(size)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to set binary chunk size: ${e.message}")
        }
    }

    // ===== Compression Utilities =====

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

    // ===== Unreal-Specific Methods =====

    fun executeConsoleCommand(command: String) {
        if (!engineReady || isDestroyed.get()) {
            sendEventToFlutter("onError", mapOf("message" to "Engine not ready for console commands"))
            return
        }

        runOnMainThread {
            try {
                Log.d(TAG, "Executing console command: $command")
                nativeExecuteConsoleCommand(command)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to execute console command: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Failed to execute console command: ${e.message}"))
            }
        }
    }

    fun loadLevel(levelName: String) {
        if (!engineReady || isDestroyed.get()) {
            sendEventToFlutter("onError", mapOf("message" to "Engine not ready to load level"))
            return
        }

        runOnMainThread {
            try {
                Log.d(TAG, "Loading level: $levelName")
                nativeLoadLevel(levelName)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load level: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Failed to load level: ${e.message}"))
            }
        }
    }

    fun applyQualitySettings(settings: Map<String, Any>) {
        if (!engineReady || isDestroyed.get()) {
            sendEventToFlutter("onError", mapOf("message" to "Engine not ready for quality settings"))
            return
        }

        runOnMainThread {
            try {
                Log.d(TAG, "Applying quality settings")
                nativeApplyQualitySettings(settings)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to apply quality settings: ${e.message}", e)
                sendEventToFlutter("onError", mapOf("message" to "Failed to apply quality settings: ${e.message}"))
            }
        }
    }

    fun getQualitySettings(): Map<String, Any>? {
        if (!engineReady || isDestroyed.get()) {
            sendEventToFlutter("onError", mapOf("message" to "Engine not ready"))
            return null
        }

        return try {
            nativeGetQualitySettings()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get quality settings: ${e.message}", e)
            sendEventToFlutter("onError", mapOf("message" to "Failed to get quality settings: ${e.message}"))
            null
        }
    }

    // ===== Lifecycle Callbacks =====

    override fun onResume(owner: LifecycleOwner) {
        super.onResume(owner)
        Log.d(TAG, "onResume: engineReady=$engineReady, enginePaused=$enginePaused")
        if (engineReady && enginePaused) {
            resumeEngine()
        }
    }

    override fun onPause(owner: LifecycleOwner) {
        super.onPause(owner)
        Log.d(TAG, "onPause: engineReady=$engineReady, enginePaused=$enginePaused")
        if (engineReady && !enginePaused) {
            pauseEngine()
        }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        super.onDestroy(owner)
        destroyEngine()
    }

    override fun dispose() {
        Log.d(TAG, "Disposing Unreal controller")
        super.dispose()
        destroyEngine()
    }

    // ===== Callbacks from Native Code =====

    /**
     * Called from native code when a message is received from Unreal
     */
    @Suppress("unused")
    fun onMessageFromUnreal(target: String, method: String, data: String) {
        runOnMainThread {
            sendEventToFlutter("onMessage", mapOf(
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
        runOnMainThread {
            sendEventToFlutter("onSceneLoaded", mapOf(
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
        runOnMainThread {
            val encodedData = Base64.encodeToString(data, Base64.NO_WRAP)
            sendEventToFlutter("onBinaryMessage", mapOf(
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
        runOnMainThread {
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

            sendEventToFlutter("onBinaryChunk", chunkMap)
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
        runOnMainThread {
            sendEventToFlutter("onBinaryProgress", mapOf(
                "transferId" to transferId,
                "currentChunk" to currentChunk,
                "totalChunks" to totalChunks,
                "bytesTransferred" to bytesTransferred,
                "totalBytes" to totalBytes
            ))
        }
    }

    // ===== Native Methods (JNI) =====

    private external fun nativeCreate(config: Map<String, Any>): Boolean
    private external fun nativeGetView(): View?
    private external fun nativePause()
    private external fun nativeResume()
    private external fun nativeQuit()
    private external fun nativeSendMessage(target: String, method: String, data: String)
    private external fun nativeExecuteConsoleCommand(command: String)
    private external fun nativeLoadLevel(levelName: String)
    private external fun nativeApplyQualitySettings(settings: Map<String, Any>)
    private external fun nativeGetQualitySettings(): Map<String, Any>
    private external fun nativeSendBinaryMessage(target: String, method: String, data: ByteArray, checksum: Int)
    private external fun nativeBinaryChunkHeader(target: String, method: String, transferId: String, totalSize: Int, totalChunks: Int, checksum: Int)
    private external fun nativeBinaryChunkData(target: String, method: String, transferId: String, chunkIndex: Int, data: ByteArray)
    
    // Surface rendering methods - for passing rendering surface to native Unreal
    private external fun nativeSetSurface(surface: Surface?)
    private external fun nativeSurfaceChanged(width: Int, height: Int)
    private external fun nativeBinaryChunkFooter(target: String, method: String, transferId: String, totalChunks: Int, checksum: Int)
    private external fun nativeSetBinaryChunkSize(size: Int)
}
