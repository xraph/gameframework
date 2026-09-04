// Copyright Epic Games, Inc. All Rights Reserved.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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
// MARK: - UnrealBridge
// ============================================================

@interface UnrealBridge : NSObject
+ (UnrealBridge*)shared;
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

    GUnrealEngineController = controller;

    SetMessageCallbackFn setMessage = UNREAL_FN(SetMessageCallbackFn, "UnrealBridge_SetMessageCallback");
    if (setMessage) setMessage(&HandleUnrealMessage);

    SetBinaryCallbackFn setBinary = UNREAL_FN(SetBinaryCallbackFn, "UnrealBridge_SetBinaryCallback");
    if (setBinary) setBinary(&HandleUnrealBinary);

    IsReadyFn isReady = UNREAL_FN(IsReadyFn, "UnrealBridge_IsReady");
    const BOOL engineReady = isReady && (isReady() != 0);
    if (!engineReady) {
        // The framework is linked but no AFlutterBridge actor has registered
        // yet. That is normal this early: the actor registers in BeginPlay.
        // Calls made before then are dropped by the framework, not by us.
        NSLog(@"[UnrealBridge] Framework linked, waiting for AFlutterBridge actor. "
              @"Place one in your level if messages never arrive.");
    }

    NSLog(@"[UnrealBridge] Bridge created, callbacks registered");
    return YES;
}

- (UIView*)getView {
    // Unreal owns its own window on iOS; there is no subview to hand back.
    return nil;
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
