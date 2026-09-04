// Mock UnrealFramework: exports the C ABI so the pod's dlsym path can be
// exercised without an engine build.
#include <stdint.h>
#include <string.h>
#include <stdio.h>

typedef void (*UnrealMessageCallback)(const char*, const char*, const char*);
typedef void (*UnrealBinaryCallback)(const char*, const char*, const void*, int32_t, int32_t);

static UnrealMessageCallback gMessage = 0;
static UnrealBinaryCallback gBinary = 0;

char gLastTarget[128], gLastMethod[128], gLastData[256];
int32_t gLastQuality[8];
int gConsoleCalls = 0, gLevelCalls = 0, gPauseState = -1, gStopped = 0;

void UnrealBridge_SetMessageCallback(UnrealMessageCallback cb) { gMessage = cb; }
void UnrealBridge_SetBinaryCallback(UnrealBinaryCallback cb) { gBinary = cb; }
void UnrealBridge_SendToUnreal(const char* t, const char* m, const char* d) {
    snprintf(gLastTarget, sizeof gLastTarget, "%s", t ? t : "");
    snprintf(gLastMethod, sizeof gLastMethod, "%s", m ? m : "");
    snprintf(gLastData, sizeof gLastData, "%s", d ? d : "");
}
void UnrealBridge_SendBinaryToUnreal(const char* t, const char* m, const void* d, int32_t n, int32_t c) {
    (void)d; (void)c;
    snprintf(gLastTarget, sizeof gLastTarget, "%s", t ? t : "");
    snprintf(gLastMethod, sizeof gLastMethod, "%s", m ? m : "");
    snprintf(gLastData, sizeof gLastData, "%d", n);
}
void UnrealBridge_ExecuteConsoleCommand(const char* c) { (void)c; gConsoleCalls++; }
void UnrealBridge_LoadLevel(const char* l) { (void)l; gLevelCalls++; }
void UnrealBridge_ApplyQualitySettings(int32_t a,int32_t b,int32_t c,int32_t d,
                                       int32_t e,int32_t f,int32_t g,int32_t h) {
    gLastQuality[0]=a; gLastQuality[1]=b; gLastQuality[2]=c; gLastQuality[3]=d;
    gLastQuality[4]=e; gLastQuality[5]=f; gLastQuality[6]=g; gLastQuality[7]=h;
}
int32_t UnrealBridge_GetQualitySettings(int32_t* out, int32_t cap) {
    if (!out || cap < 7) return 0;
    for (int i = 0; i < 7; i++) out[i] = i + 1;
    return 7;
}
void UnrealBridge_Pause(int32_t p) { gPauseState = p; }

/* Engine lifecycle */
int gInitCalls = 0, gTickCalls = 0;
float gLastDelta = 0;
void UnrealBridge_Init(void) { gInitCalls++; }
int32_t UnrealBridge_Tick(float dt) { gTickCalls++; gLastDelta = dt; return 1; }
void UnrealBridge_WakeGameThread(void) {}
void UnrealBridge_KeepAwake(const char* r, int32_t n) { (void)r; (void)n; }
void UnrealBridge_AllowSleep(const char* r) { (void)r; }
int32_t UnrealBridge_IsAwakeForTicking(void) { return 1; }
int32_t UnrealBridge_IsAwakeForRendering(void) { return 1; }

/* Engine readiness. The engine announces when a view can be made. */
typedef void (*ReadyCb)(void);
static ReadyCb gReadyCb = 0;
int gReadyForView = 0;
void UnrealBridge_SetEngineReadyCallback(ReadyCb cb) {
    gReadyCb = cb;
    if (cb && gReadyForView) cb();
}
int32_t UnrealBridge_IsReadyForView(void) { return gReadyForView; }

/* Test hook: pretend the engine just announced readiness. */
void MockUnreal_SignalEngineReady(void) {
    gReadyForView = 1;
    if (gReadyCb) gReadyCb();
}

/* Render surface.
 *
 * The view has to be a real Objective-C object: the bridge holds it in a weak
 * property, and ARC cannot register a weak reference to an arbitrary pointer.
 * The test supplies one through MockUnreal_SetView. */
static void* gView = 0;
void MockUnreal_SetView(void* v) { gView = v; }
int gCreateViewCalls = 0, gDestroyViewCalls = 0;
float gViewWidth = 0, gViewHeight = 0, gViewScale = 0;
void* UnrealBridge_CreateView(float w, float h, float s) {
    gCreateViewCalls++; gViewWidth = w; gViewHeight = h; gViewScale = s;
    return gView;
}
void UnrealBridge_ResizeView(float w, float h, float s) {
    gViewWidth = w; gViewHeight = h; gViewScale = s;
}
void UnrealBridge_DestroyView(void) { gDestroyViewCalls++; }
int32_t UnrealBridge_IsViewReady(void) { return 1; }
void UnrealBridge_Stop(void) { gStopped = 1; }
int32_t UnrealBridge_IsReady(void) { return 1; }

/// Drive a message from "Unreal" back into the pod.
void MockUnreal_FireMessage(const char* t, const char* m, const char* d) {
    if (gMessage) gMessage(t, m, d);
}
