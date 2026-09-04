//
//  UnrealBridge.h
//  FlutterPlugin
//
//  Flat C ABI across the UnrealFramework boundary.
//
//  This header is deliberately free of Unreal types. The Flutter side compiles
//  it inside the host app, which must not need CoreMinimal.h, UBT include paths
//  or any engine symbols. Everything crossing the boundary is a C primitive.
//
//  Direction of travel:
//    Flutter -> Unreal   UnrealBridge_SendToUnreal and friends
//    Unreal  -> Flutter  callbacks registered with UnrealBridge_Set*Callback
//
//  Threading: every UnrealBridge_* entry point is safe to call from any thread
//  and hops to the game thread internally. Callbacks fire on the GAME thread,
//  so the Flutter side must marshal to the main thread before touching UIKit.
//

#ifndef UnrealBridge_h
#define UnrealBridge_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Exported from UnrealFramework so the host app can link against it.
#define UNREALBRIDGE_API __attribute__((visibility("default")))

// ============================================================
// MARK: - Unreal to Flutter
// ============================================================

/// A string message from Unreal. Pointers are valid only for the duration of
/// the call; copy anything you need to keep.
typedef void (*UnrealMessageCallback)(const char* target,
                                      const char* method,
                                      const char* data);

/// Binary payload from Unreal. `data` is valid only for the duration of the
/// call. `checksum` is the CRC32 Unreal computed over the payload.
typedef void (*UnrealBinaryCallback)(const char* target,
                                     const char* method,
                                     const void* data,
                                     int32_t length,
                                     int32_t checksum);

/// Register callbacks. Pass NULL to unregister. Registering replaces any
/// previous callback rather than chaining.
///
/// There is no separate level-loaded callback: Unreal reports level loads
/// through the message callback with target "FlutterBridge" and method
/// "onLevelLoaded", carrying the level name as data.
UNREALBRIDGE_API void UnrealBridge_SetMessageCallback(UnrealMessageCallback callback);
UNREALBRIDGE_API void UnrealBridge_SetBinaryCallback(UnrealBinaryCallback callback);

// ============================================================
// MARK: - Flutter to Unreal
// ============================================================

UNREALBRIDGE_API void UnrealBridge_SendToUnreal(const char* target,
                                                const char* method,
                                                const char* data);

UNREALBRIDGE_API void UnrealBridge_SendBinaryToUnreal(const char* target,
                                                      const char* method,
                                                      const void* data,
                                                      int32_t length,
                                                      int32_t checksum);

UNREALBRIDGE_API void UnrealBridge_ExecuteConsoleCommand(const char* command);

UNREALBRIDGE_API void UnrealBridge_LoadLevel(const char* levelName);

/// Quality levels are 0 to 4 (Low, Medium, High, Epic, Cinematic). Pass -1 for
/// any value that should be left alone.
UNREALBRIDGE_API void UnrealBridge_ApplyQualitySettings(int32_t qualityLevel,
                                                        int32_t antiAliasing,
                                                        int32_t shadow,
                                                        int32_t postProcess,
                                                        int32_t texture,
                                                        int32_t effects,
                                                        int32_t foliage,
                                                        int32_t viewDistance);

/// Read the current quality settings into a caller-owned array, in this order:
///
///   0 antiAliasing, 1 shadow, 2 postProcess, 3 texture,
///   4 effects, 5 foliage, 6 viewDistance
///
/// Note this is the Apply order minus the leading overall quality level, which
/// Unreal exposes no getter for. Returns the number of values written, or 0 if
/// the bridge is not ready or `capacity` is too small.
UNREALBRIDGE_API int32_t UnrealBridge_GetQualitySettings(int32_t* outValues,
                                                         int32_t capacity);

/// Number of values UnrealBridge_GetQualitySettings writes when it succeeds.
#define UNREALBRIDGE_QUALITY_VALUE_COUNT 7

// ============================================================
// MARK: - Lifecycle
// ============================================================

UNREALBRIDGE_API void UnrealBridge_Pause(int32_t paused);

/// Tear the bridge down. Clears the registered callbacks and tells Unreal the
/// host is going away.
UNREALBRIDGE_API void UnrealBridge_Stop(void);

/// Whether an AFlutterBridge actor has registered itself. Everything above is
/// safe to call when this returns 0, it just does nothing.
UNREALBRIDGE_API int32_t UnrealBridge_IsReady(void);

#ifdef __cplusplus
}
#endif

#endif /* UnrealBridge_h */
