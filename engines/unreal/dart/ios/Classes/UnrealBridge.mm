// Copyright Epic Games, Inc. All Rights Reserved.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "UnrealAppDelegate.h"

// ============================================================
// MARK: - UnrealFramework C ABI
// ============================================================
//
// Resolved with dlsym rather than linked. The canonical declarations live in
// the plugin's Public/UnrealBridge.h and are copied into the framework's
// Headers/ at export time; keep the signatures below in step with them.
//
// Why dlsym and not a link-time dependency: UnrealFramework is produced by
// "game export unreal -p ios", so it may legitimately be absent when this pod
// is built. Linking against it would break those builds, and weak_import does
// not help, because it only makes a symbol optional at load time while the
// static linker still demands a definition. Looking the symbols up at runtime
// keeps the pod self-contained and turns "framework missing" into a clear log
// line instead of a build failure.
//
// This replaces an older __has_include split that decided at compile time and
// silently produced a do-nothing bridge whenever a header search path was
// slightly off.

#import <dlfcn.h>

typedef void (*UnrealMessageCallback)(const char* target,
                                      const char* method,
                                      const char* data);

typedef void (*UnrealBinaryCallback)(const char* target,
                                     const char* method,
                                     const void* data,
                                     int32_t length,
                                     int32_t checksum);

typedef void (*SetMessageCallbackFn)(UnrealMessageCallback);
typedef void (*SetBinaryCallbackFn)(UnrealBinaryCallback);
typedef void (*SendToUnrealFn)(const char*, const char*, const char*);
typedef void (*SendBinaryToUnrealFn)(const char*, const char*, const void*, int32_t, int32_t);
typedef void (*ExecuteConsoleCommandFn)(const char*);
typedef void (*LoadLevelFn)(const char*);
typedef void (*ApplyQualitySettingsFn)(int32_t, int32_t, int32_t, int32_t,
                                       int32_t, int32_t, int32_t, int32_t);
typedef int32_t (*GetQualitySettingsFn)(int32_t*, int32_t);
typedef void (*InitFn)(void);
typedef int32_t (*TickFn)(float);
typedef void (*KeepAwakeFn)(const char*, int32_t);
typedef void (*AllowSleepFn)(const char*);
typedef void (*EngineReadyCallback)(void);
typedef void (*SetEngineReadyCallbackFn)(EngineReadyCallback);
typedef int32_t (*StartEngineFn)(void);
typedef int32_t (*IsReadyForViewFn)(void);
typedef void* (*CreateViewFn)(float, float, float);
typedef void (*ResizeViewFn)(float, float, float);
typedef void (*DestroyViewFn)(void);
typedef int32_t (*IsViewReadyFn)(void);
typedef void (*PauseFn)(int32_t);
typedef void (*StopFn)(void);
typedef int32_t (*IsReadyFn)(void);

/// Look a bridge symbol up in whatever is already loaded into the process.
/// Returns NULL when UnrealFramework is not present.
static void* UnrealSymbol(const char* name) {
    return dlsym(RTLD_DEFAULT, name);
}

#define UNREAL_FN(type, name) ((type)UnrealSymbol(name))

/// Whether UnrealFramework is loaded into this process.
static BOOL UnrealFrameworkLinked(void) {
    static BOOL linked = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        linked = UnrealSymbol("UnrealBridge_SendToUnreal") != NULL;
    });
    return linked;
}

/// Matches UNREALBRIDGE_QUALITY_VALUE_COUNT in the plugin header.
static const int32_t kUnrealQualityValueCount = 7;

/// Keys for the quality values, in the order the framework writes them.
static NSArray<NSString*>* UnrealQualityKeys(void) {
    return @[ @"antiAliasing", @"shadow", @"postProcess", @"texture",
              @"effects", @"foliage", @"viewDistance" ];
}

// The Swift controller. Held strongly for as long as the bridge is live.
static id GUnrealEngineController = nil;

// ============================================================
// MARK: - Callbacks from Unreal
// ============================================================
//
// These fire on Unreal's GAME thread, and their pointers are only valid for the
// duration of the call. Copy into Foundation objects immediately, then hop to
// the main queue before touching the controller.

static void HandleUnrealMessage(const char* target, const char* method, const char* data) {
    NSString* nsTarget = target ? @(target) : @"";
    NSString* nsMethod = method ? @(method) : @"";
    NSString* nsData = data ? @(data) : @"";

    dispatch_async(dispatch_get_main_queue(), ^{
        id controller = GUnrealEngineController;
        if (!controller) {
            NSLog(@"[UnrealBridge] Dropping message, no controller: %@.%@", nsTarget, nsMethod);
            return;
        }

        // Level loads arrive on the message channel rather than a channel of
        // their own. Route them to the controller's level callback so the
        // existing Swift signature keeps working.
        if ([nsTarget isEqualToString:@"FlutterBridge"] &&
            [nsMethod isEqualToString:@"onLevelLoaded"]) {
            SEL levelSelector = NSSelectorFromString(@"onLevelLoadedWithLevelName:buildIndex:");
            if ([controller respondsToSelector:levelSelector]) {
                NSMethodSignature* sig = [controller methodSignatureForSelector:levelSelector];
                NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:controller];
                [inv setSelector:levelSelector];
                NSString* levelName = nsData;
                NSInteger buildIndex = 0;
                [inv setArgument:&levelName atIndex:2];
                [inv setArgument:&buildIndex atIndex:3];
                [inv invoke];
                return;
            }
        }

        SEL selector = NSSelectorFromString(@"onMessageFromUnrealWithTarget:method:data:");
        if (![controller respondsToSelector:selector]) {
            NSLog(@"[UnrealBridge] Controller does not respond to onMessageFromUnrealWithTarget:method:data:");
            return;
        }

        NSMethodSignature* sig = [controller methodSignatureForSelector:selector];
        NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:controller];
        [inv setSelector:selector];
        NSString* t = nsTarget; NSString* m = nsMethod; NSString* d = nsData;
        [inv setArgument:&t atIndex:2];
        [inv setArgument:&m atIndex:3];
        [inv setArgument:&d atIndex:4];
        [inv invoke];
    });
}

static void HandleUnrealBinary(const char* target, const char* method,
                               const void* data, int32_t length, int32_t checksum) {
    NSString* nsTarget = target ? @(target) : @"";
    NSString* nsMethod = method ? @(method) : @"";
    NSData* nsData = (data && length > 0)
        ? [NSData dataWithBytes:data length:(NSUInteger)length]
        : [NSData data];

    dispatch_async(dispatch_get_main_queue(), ^{
        id controller = GUnrealEngineController;
        if (!controller) {
            NSLog(@"[UnrealBridge] Dropping binary, no controller: %@.%@", nsTarget, nsMethod);
            return;
        }

        SEL selector = NSSelectorFromString(@"onBinaryFromUnrealWithTarget:method:data:checksum:");
        if (![controller respondsToSelector:selector]) {
            NSLog(@"[UnrealBridge] Controller has no binary handler, dropping %lu bytes from %@.%@",
                  (unsigned long)nsData.length, nsTarget, nsMethod);
            return;
        }

        NSMethodSignature* sig = [controller methodSignatureForSelector:selector];
        NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:controller];
        [inv setSelector:selector];
        NSString* t = nsTarget; NSString* m = nsMethod; NSData* d = nsData;
        NSInteger c = (NSInteger)checksum;
        [inv setArgument:&t atIndex:2];
        [inv setArgument:&m atIndex:3];
        [inv setArgument:&d atIndex:4];
        [inv setArgument:&c atIndex:5];
        [inv invoke];
    });
}


// ============================================================
// MARK: - Driving the engine
// ============================================================
//
// An embedded Unreal does not own the run loop, so nothing advances the engine
// unless the host does it. The bridge drives FEmbeddedCommunication::TickGameThread
// from a display link, which keeps the engine's timing tied to the display it
// renders to rather than to an arbitrary timer.
//
// Ticking happens on the main thread. That is where the host lives, and where
// an embedded engine expects to be driven from.

// Defined below, once the UnrealBridge class exists.
static void BuildViewNowThatEngineIsReady(void);
static BOOL HasEngineView(void);

static void UnrealTick(double deltaSeconds) {
    // The engine blocks in PreInit polling for AppDelegate.IOSView, so keep
    // offering one until it takes. This is also the only workable moment: too
    // early and Metal is not up, and the readiness announcement that would
    // otherwise tell us cannot reach a plugin that has not loaded yet.
    if (!HasEngineView()) {
        BuildViewNowThatEngineIsReady();
    }

    TickFn tick = UNREAL_FN(TickFn, "UnrealBridge_Tick");
    if (tick) {
        tick((float)deltaSeconds);
    }
}

/// CADisplayLink already fires on the main run loop, so no hop is needed.
static CADisplayLink* GDisplayLink = nil;
static CFTimeInterval GLastTickTime = 0;

@interface UnrealTicker : NSObject
+ (instancetype)shared;
- (void)onFrame:(CADisplayLink*)link;
@end

@implementation UnrealTicker
+ (instancetype)shared {
    static UnrealTicker* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[UnrealTicker alloc] init]; });
    return instance;
}
- (void)onFrame:(CADisplayLink*)link {
    const CFTimeInterval current = link.timestamp;
    const CFTimeInterval delta =
        (GLastTickTime > 0) ? (current - GLastTickTime) : link.duration;
    GLastTickTime = current;
    UnrealTick(delta);
}
@end

static void StartTicking(void) {
    if (GDisplayLink) return;
    GDisplayLink = [CADisplayLink displayLinkWithTarget:[UnrealTicker shared]
                                               selector:@selector(onFrame:)];
    GLastTickTime = 0;
    [GDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    NSLog(@"[UnrealBridge] Ticking the engine from the display link");
}

static void StopTicking(void) {
    if (!GDisplayLink) return;
    [GDisplayLink invalidate];
    GDisplayLink = nil;
}

// ============================================================
// MARK: - Waiting for the engine before building a view
// ============================================================
//
// The engine reads its config before a render view can exist, and announces
// when that is done. Asking earlier gets NULL, so the bridge registers for the
// signal and builds the view when it lands rather than guessing at a delay.

// ============================================================
// MARK: - UnrealBridge
// ============================================================

@interface UnrealBridge : NSObject {
    CGSize _requestedViewSize;
}
/// The engine's render view once it exists. Owned by the engine's app
/// delegate, so this is an observing reference.
@property (nonatomic, weak) UIView* engineView;
+ (UnrealBridge*)shared;
- (void)resizeViewTo:(CGSize)size;
- (BOOL)isViewReady;
- (BOOL)createWithConfig:(NSDictionary*)config controller:(id)controller;
- (UIView*)getView;
- (void)pause;
- (void)resume;
- (void)quit;
- (void)sendMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSString*)data;
- (void)sendBinaryWithTarget:(NSString*)target method:(NSString*)method data:(NSData*)data;
- (void)executeConsoleCommand:(NSString*)command;
- (void)loadLevel:(NSString*)levelName;
- (void)applyQualitySettings:(NSDictionary*)settings;
- (NSDictionary*)getQualitySettings;
@end

@implementation UnrealBridge

/// Size the engine renders at until the host resizes it. The screen bounds are
/// the best guess available before the widget has been laid out.
- (CGSize)requestedViewSize {
    if (_requestedViewSize.width > 0 && _requestedViewSize.height > 0) {
        return _requestedViewSize;
    }
    return UIScreen.mainScreen.bounds.size;
}

+ (UnrealBridge*)shared {
    static UnrealBridge* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UnrealBridge alloc] init];
    });
    return instance;
}

- (BOOL)createWithConfig:(NSDictionary*)config controller:(id)controller {
    if (!UnrealFrameworkLinked()) {
        NSLog(@"[UnrealBridge] UnrealFramework is not linked into this app. "
              @"Run 'game export unreal -p ios' and 'game sync unreal -p ios', "
              @"and check the framework is embedded in the Xcode target.");
        return NO;
    }

    // Unreal treats a delegate that does not descend from IOSAppDelegate as
    // fatal, and it would crash somewhere far less obvious than here. Check it
    // while there is still something useful to say about it.
    if (!UnrealAssertAppDelegateUsable()) {
        return NO;
    }

    GUnrealEngineController = controller;

    SetMessageCallbackFn setMessage = UNREAL_FN(SetMessageCallbackFn, "UnrealBridge_SetMessageCallback");
    if (setMessage) setMessage(&HandleUnrealMessage);

    SetBinaryCallbackFn setBinary = UNREAL_FN(SetBinaryCallbackFn, "UnrealBridge_SetBinaryCallback");
    if (setBinary) setBinary(&HandleUnrealBinary);

    // Start the engine. Nothing else works until this runs: it is what brings
    // Metal up, and the render view cannot be built before it.
    //
    // Deliberately not waiting for the engine's readiness announcement. It
    // broadcasts "inisareready" from PreInit and then blocks waiting for a
    // view, and plugin modules only load later in PreInit, so by the time
    // anything here could subscribe the announcement has been and gone and the
    // engine is already stuck. The view is offered from the tick instead, which
    // matches how the engine polls for it.
    StartEngineFn startEngine = UNREAL_FN(StartEngineFn, "UnrealBridge_StartEngine");
    if (startEngine) {
        NSLog(@"[UnrealBridge] StartEngine -> %d", startEngine());
    }

    KeepAwakeFn keepAwake = UNREAL_FN(KeepAwakeFn, "UnrealBridge_KeepAwake");
    if (keepAwake) keepAwake("flutter", 1);

    IsReadyFn isReady = UNREAL_FN(IsReadyFn, "UnrealBridge_IsReady");
    const BOOL engineReady = isReady && (isReady() != 0);
    if (!engineReady) {
        // The framework is linked but no AFlutterBridge actor has registered
        // yet. That is normal this early: the actor registers in BeginPlay.
        // Calls made before then are dropped by the framework, not by us.
        NSLog(@"[UnrealBridge] Framework linked, waiting for AFlutterBridge actor. "
              @"Place one in your level if messages never arrive.");
    }

    InitFn initEngine = UNREAL_FN(InitFn, "UnrealBridge_Init");
    if (initEngine) initEngine();

    StartTicking();

    NSLog(@"[UnrealBridge] Bridge created, callbacks registered, engine ticking");
    return YES;
}

- (UIView*)getView {
    // Unreal's embedded mode does not build its own view. The framework makes
    // an FIOSView, registers it with the app delegate and hands it back here,
    // so the engine renders straight into a view we can put inside a Flutter
    // platform view. Nothing is copied per frame.
    UIView* existing = [UnrealBridge shared].engineView;
    if (existing) {
        return existing;
    }

    // Not ready yet is the normal case on the first call: the engine announces
    // when its config is loaded and the view gets built then. The controller is
    // told through onUnrealViewReady, so returning nil here is not a failure.
    IsReadyForViewFn readyForView =
        UNREAL_FN(IsReadyForViewFn, "UnrealBridge_IsReadyForView");
    if (readyForView && readyForView()) {
        BuildViewNowThatEngineIsReady();
        return [UnrealBridge shared].engineView;
    }

    NSLog(@"[UnrealBridge] Engine not ready for a view yet; waiting for its signal");
    return nil;
}

- (void)resizeViewTo:(CGSize)size {
    ResizeViewFn resize = UNREAL_FN(ResizeViewFn, "UnrealBridge_ResizeView");
    if (!resize) return;
    _requestedViewSize = size;
    resize((float)size.width, (float)size.height, (float)UIScreen.mainScreen.scale);
}

- (BOOL)isViewReady {
    IsViewReadyFn ready = UNREAL_FN(IsViewReadyFn, "UnrealBridge_IsViewReady");
    return ready && ready() != 0;
}

- (void)pause {
    PauseFn pause = UNREAL_FN(PauseFn, "UnrealBridge_Pause");
    if (pause) pause(1);
}

- (void)resume {
    PauseFn pause = UNREAL_FN(PauseFn, "UnrealBridge_Pause");
    if (pause) pause(0);
}

- (void)quit {
    StopTicking();

    DestroyViewFn destroyView = UNREAL_FN(DestroyViewFn, "UnrealBridge_DestroyView");
    if (destroyView) destroyView();

    StopFn stop = UNREAL_FN(StopFn, "UnrealBridge_Stop");
    if (stop) stop();
    GUnrealEngineController = nil;
}

- (void)sendMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSString*)data {
    SendToUnrealFn send = UNREAL_FN(SendToUnrealFn, "UnrealBridge_SendToUnreal");
    if (!send) {
        NSLog(@"[UnrealBridge] Cannot send, framework not loaded");
        return;
    }
    send(target.UTF8String, method.UTF8String, data.UTF8String ?: "");
}

- (void)sendBinaryWithTarget:(NSString*)target method:(NSString*)method data:(NSData*)data {
    SendBinaryToUnrealFn send = UNREAL_FN(SendBinaryToUnrealFn, "UnrealBridge_SendBinaryToUnreal");
    if (!send) {
        NSLog(@"[UnrealBridge] Cannot send binary, framework not loaded");
        return;
    }
    // Checksum is computed engine-side on receipt; 0 means "unset".
    send(target.UTF8String, method.UTF8String, data.bytes, (int32_t)data.length, 0);
}

- (void)executeConsoleCommand:(NSString*)command {
    ExecuteConsoleCommandFn exec = UNREAL_FN(ExecuteConsoleCommandFn, "UnrealBridge_ExecuteConsoleCommand");
    if (exec) exec(command.UTF8String);
}

- (void)loadLevel:(NSString*)levelName {
    LoadLevelFn load = UNREAL_FN(LoadLevelFn, "UnrealBridge_LoadLevel");
    if (load) load(levelName.UTF8String);
}

- (void)applyQualitySettings:(NSDictionary*)settings {
    ApplyQualitySettingsFn apply = UNREAL_FN(ApplyQualitySettingsFn, "UnrealBridge_ApplyQualitySettings");
    if (!apply) return;

    int32_t (^value)(NSString*) = ^int32_t(NSString* key) {
        id v = settings[key];
        return v ? (int32_t)[v intValue] : -1;
    };

    apply(
        value(@"qualityLevel"),
        value(@"antiAliasingQuality"),
        value(@"shadowQuality"),
        value(@"postProcessQuality"),
        value(@"textureQuality"),
        value(@"effectsQuality"),
        value(@"foliageQuality"),
        value(@"viewDistanceQuality"));
}

- (NSDictionary*)getQualitySettings {
    GetQualitySettingsFn get = UNREAL_FN(GetQualitySettingsFn, "UnrealBridge_GetQualitySettings");
    if (!get) return @{};

    int32_t values[kUnrealQualityValueCount];
    const int32_t written = get(values, kUnrealQualityValueCount);
    if (written < kUnrealQualityValueCount) {
        // The framework serves a cache refreshed on the game thread, so the
        // very first call can land before it is populated.
        return @{};
    }

    NSArray<NSString*>* keys = UnrealQualityKeys();
    NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:keys.count];
    for (NSUInteger i = 0; i < keys.count; i++) {
        result[keys[i]] = @(values[i]);
    }
    return result;
}

@end

// ============================================================
// MARK: - Deferred view creation
// ============================================================

static BOOL HasEngineView(void) {
    return UnrealBridge.shared.engineView != nil;
}

static void BuildViewNowThatEngineIsReady(void) {
    UnrealBridge* bridge = UnrealBridge.shared;
    if (bridge.engineView) {
        return;
    }

    CreateViewFn createView = UNREAL_FN(CreateViewFn, "UnrealBridge_CreateView");
    if (!createView) {
        NSLog(@"[UnrealBridge] Framework has no render view entry point");
        return;
    }

    const CGSize size = bridge.requestedViewSize;
    const CGFloat scale = UIScreen.mainScreen.scale;
    void* handle = createView((float)size.width, (float)size.height, (float)scale);
    if (!handle) {
        NSLog(@"[UnrealBridge] The engine declined to make a render view");
        return;
    }

    // Unretained and owned by the engine's app delegate, so do not take
    // ownership of it here.
    UIView* view = (__bridge UIView*)handle;
    bridge.engineView = view;
    NSLog(@"[UnrealBridge] Render view built at %@", NSStringFromCGSize(size));

    id controller = GUnrealEngineController;
    SEL selector = NSSelectorFromString(@"onUnrealViewReadyWithView:");
    if ([controller respondsToSelector:selector]) {
        NSMethodSignature* sig = [controller methodSignatureForSelector:selector];
        NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:controller];
        [inv setSelector:selector];
        UIView* arg = view;
        [inv setArgument:&arg atIndex:2];
        [inv invoke];
    } else {
        NSLog(@"[UnrealBridge] Controller has no onUnrealViewReady handler; "
              @"the view exists but nothing will show it");
    }
}
