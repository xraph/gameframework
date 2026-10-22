package com.epicgames.asis;

/**
 * The Java half of Unreal's ASIS entry point, which the engine expects to find
 * and this engine tree does not ship.
 *
 * Turning on bEnableASISPlugin gets you USE_ANDROID_STANDALONE, and with it a
 * set of JNI entry points declared in Core's AndroidJniGameActivity.h as
 * UE::Jni::Asis::FAsisGameActivity. Those are registered rather than exported:
 * the engine walks a UE_Jni_Initialize linker section at startup, looks each
 * type's ClassName up with FindClass, and calls RegisterNatives against it.
 *
 * Two consequences worth knowing before you touch this file.
 *
 * The class name is a string in the engine binary, "com/epicgames/asis/AsisGameActivity",
 * so the package and name here are load-bearing. Rename either and the lookup
 * fails.
 *
 * And a failed lookup is not survivable. FEnv::Initialize guards it with a
 * checkf, and FAsisGameActivity does not opt out through bIsOptional the way an
 * optional binding would, so an APK that enables ASIS without shipping this
 * class asserts during JNI init rather than falling back to anything.
 *
 * The methods are static because the native side declares each one taking a
 * jclass rather than a jobject. Signatures have to match exactly; RegisterNatives
 * reports a mismatch by returning negative, which the engine turns into a
 * cleared exception and a false, so a wrong signature here surfaces later as an
 * UnsatisfiedLinkError at the call rather than as an error at startup.
 *
 * Nothing extends com.epicgames.unreal.GameActivity on purpose. The C++ wrapper
 * FAsisGameActivity does derive from FGameActivity, but that is a C++ type
 * hierarchy for member access, and RegisterNatives only cares about names and
 * signatures on the class it is handed. Keeping this standalone means the plugin
 * compiles without Unreal's generated Java on the source path.
 */
public class AsisGameActivity {

    /**
     * Starts the engine. Runs UE's main on the calling thread and does not
     * return while the engine lives, so call it from a thread you are willing
     * to give up.
     *
     * @param projectModule name of the game module to load, matching the
     *                      project's module name rather than the .so name.
     */
    public static native void nativeMain(String projectModule);

    /**
     * Sets the command line before nativeMain. Same role as uecommandline.txt
     * on the Apple platforms, and like it this has to be set before the engine
     * reads it rather than after.
     */
    public static native void nativeSetCommandline(String commandline);

    /**
     * Feeds one APP_CMD_* value to the engine's event loop, which is how a host
     * that is not a NativeActivity drives lifecycle and window events.
     *
     * The engine reads the window from GAndroidWindowOverride when it handles
     * APP_CMD_INIT_WINDOW, so that global has to point at a live ANativeWindow
     * before this is called with it.
     */
    public static native void nativeAppCommand(int cmd);

    /** Returns the OBB comment, unused when content is packaged inside the APK. */
    public static native String nativeGetObbComment();

    private AsisGameActivity() {
    }
}
