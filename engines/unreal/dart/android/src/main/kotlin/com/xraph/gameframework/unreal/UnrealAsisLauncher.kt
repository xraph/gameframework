package com.xraph.gameframework.unreal

import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import com.epicgames.asis.AsisGameActivity
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Starts Unreal through ASIS, the path the engine supports for running as a
 * library rather than as the app.
 *
 * What this replaces is worth stating, because the old code looked like it
 * worked. It started the engine by reflecting on
 * com.epicgames.unreal.GameActivity.initializeForLibraryMode and
 * .setExternalSurface, neither of which exists in UE 5.8. Both calls threw
 * NoSuchMethodException into a catch that logged a warning, and the caller then
 * reported onLoaded regardless, so Flutter was told an engine had started when
 * nothing had.
 *
 * The supported sequence is four steps and the order is not negotiable:
 *
 *  1. nativeSetCommandline, which only writes GAndroidCommandLine and so has to
 *     happen before the engine reads it.
 *  2. a live surface, so that GAndroidWindowOverride points somewhere. The
 *     engine reads that global when it handles APP_CMD_INIT_WINDOW, and reads
 *     it again through GetHardwareWindow_EventThread for the lifetime of the
 *     window.
 *  3. nativeMain, which does not block. It records the calling thread as the
 *     engine's event thread, spawns AndroidMain detached, and returns.
 *  4. APP_CMD_INIT_WINDOW, which is what actually hands the window over.
 *
 * Step 3 is why this class owns a thread at all. Whichever thread calls
 * nativeMain becomes the event thread for the rest of the process, and the
 * engine asserts on IsInAndroidEventThread in several places reached from
 * window handling, so every later command has to arrive on that same thread.
 */
class UnrealAsisLauncher(private val projectModule: String) {

    companion object {
        private const val TAG = "UnrealAsisLauncher"

        // From android_native_app_glue.h. The enum carries no explicit values,
        // so these are ordinals, and they are part of the NDK's stable ABI
        // rather than something Unreal defines.
        const val APP_CMD_INIT_WINDOW = 1
        const val APP_CMD_TERM_WINDOW = 2
        const val APP_CMD_WINDOW_RESIZED = 3
        const val APP_CMD_GAINED_FOCUS = 6
        const val APP_CMD_LOST_FOCUS = 7
        const val APP_CMD_RESUME = 11
        const val APP_CMD_PAUSE = 13
    }

    private val started = AtomicBoolean(false)
    private var eventThread: HandlerThread? = null
    private var eventHandler: Handler? = null

    /**
     * The most recent window command received before the event thread existed,
     * replayed once startup finishes. Guarded because postAppCommand is called
     * from whichever thread Flutter hands us a surface on, which is not the one
     * that calls start().
     */
    private val pendingLock = Any()
    private var pendingWindowCommand: Int? = null

    /** True once nativeMain has been called and the event thread is live. */
    val isStarted: Boolean get() = started.get()

    /**
     * Starts the engine. Returns once nativeMain has been dispatched, which is
     * not the same as the engine being ready to render: that follows later, off
     * the back of APP_CMD_INIT_WINDOW.
     *
     * @param commandLine passed to nativeSetCommandline before startup.
     */
    fun start(commandLine: String) {
        if (!started.compareAndSet(false, true)) {
            Log.d(TAG, "start: already started, ignoring")
            return
        }

        val thread = HandlerThread("UnrealEventThread")
        thread.start()
        eventThread = thread
        val handler = Handler(thread.looper)

        // Published under the same lock the latch uses, so a caller cannot read
        // a null handler, get preempted, and then latch a command after the
        // drain below has already run. Once this is visible, postAppCommand
        // posts instead of latching, and the post queues behind nativeMain.
        synchronized(pendingLock) {
            eventHandler = handler
        }

        handler.post {
            try {
                Log.d(TAG, "Setting command line: $commandLine")
                AsisGameActivity.nativeSetCommandline(commandLine)

                Log.d(TAG, "Calling nativeMain(projectModule=$projectModule) on ${Thread.currentThread().name}")
                AsisGameActivity.nativeMain(projectModule)

                Log.d(TAG, "nativeMain returned, engine thread spawned")

                val pending = synchronized(pendingLock) {
                    val value = pendingWindowCommand
                    pendingWindowCommand = null
                    value
                }
                if (pending != null) {
                    Log.d(TAG, "Replaying latched window command $pending")
                    deliver(pending)
                }
            } catch (e: UnsatisfiedLinkError) {
                // Means the natives were never registered, which in turn means
                // the engine did not find com.epicgames.asis.AsisGameActivity at
                // JNI init, or found it with signatures that did not match.
                Log.e(TAG, "ASIS natives unavailable, engine cannot start", e)
                started.set(false)
            }
        }
    }

    /**
     * Delivers one APP_CMD_* value to the engine on the event thread.
     *
     * Commands that arrive before start() cannot be delivered, because there is
     * no event thread to deliver them on, and the two orderings genuinely both
     * happen: Flutter creates the platform view's surface on its own schedule
     * and createEngine runs on ours.
     *
     * What survives the wait is one window command, the most recent. Not a
     * queue, because window events supersede each other rather than accumulate,
     * and replaying a stale INIT_WINDOW for a surface that has since gone would
     * hand the engine a dead window. Keeping only the last one means the engine
     * learns the current state on startup, which is the only state that is true.
     *
     * Lifecycle commands are dropped instead of latched, deliberately. Pause and
     * resume describe transitions rather than state, so a resume replayed after
     * startup against an engine that was never paused is noise at best. The
     * engine starts in the resumed state anyway.
     */
    fun postAppCommand(cmd: Int) {
        val handler = synchronized(pendingLock) {
            val current = eventHandler
            if (current == null) {
                if (isWindowCommand(cmd)) {
                    pendingWindowCommand = cmd
                    Log.d(TAG, "postAppCommand($cmd) before start(), latched as pending window state")
                } else {
                    Log.d(TAG, "postAppCommand($cmd) before start(), dropped (not a window command)")
                }
            }
            current
        } ?: return

        handler.post { deliver(cmd) }
    }

    private fun deliver(cmd: Int) {
        Log.d(TAG, "nativeAppCommand($cmd)")
        AsisGameActivity.nativeAppCommand(cmd)
    }

    private fun isWindowCommand(cmd: Int): Boolean =
        cmd == APP_CMD_INIT_WINDOW || cmd == APP_CMD_TERM_WINDOW || cmd == APP_CMD_WINDOW_RESIZED

    /** Stops the event thread. The engine's own thread is not joined here. */
    fun shutdown() {
        eventThread?.quitSafely()
        eventThread = null
        eventHandler = null
        synchronized(pendingLock) { pendingWindowCommand = null }
        started.set(false)
    }
}
