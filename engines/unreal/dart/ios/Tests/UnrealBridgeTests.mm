#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

extern "C" {
void MockUnreal_FireMessage(const char*, const char*, const char*);
void MockUnreal_SignalEngineReady(void);
void MockUnreal_SetView(void*);
extern int gCreateViewCalls, gReadyForView;
extern char gLastTarget[128], gLastMethod[128], gLastData[256];
extern int32_t gLastQuality[8];
extern int gConsoleCalls, gLevelCalls, gPauseState, gStopped;
}

static int gFailures = 0;
static void check(bool ok, const char* what) {
    printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) gFailures++;
}

// Stand-in for the Swift controller.
@interface FakeController : NSObject
@property (nonatomic, copy) NSString* gotTarget;
@property (nonatomic, copy) NSString* gotMethod;
@property (nonatomic, copy) NSString* gotData;
@property (nonatomic, copy) NSString* gotLevel;
@property (nonatomic, strong) UIView* gotView;
@end

// How many times the bridge handed a view to the controller. This is the
// handoff the Flutter platform view depends on, so it is worth counting rather
// than merely observing.
static int gViewReadyCallbacks = 0;
@implementation FakeController
- (void)onMessageFromUnrealWithTarget:(NSString*)t method:(NSString*)m data:(NSString*)d {
    self.gotTarget = t; self.gotMethod = m; self.gotData = d;
}
- (void)onLevelLoadedWithLevelName:(NSString*)n buildIndex:(NSInteger)i {
    self.gotLevel = n;
}
- (void)onUnrealViewReadyWithView:(UIView*)v {
    self.gotView = v;
    gViewReadyCallbacks++;
}
@end

int main(void) {
    @autoreleasepool {
        Class cls = NSClassFromString(@"UnrealBridge");
        id bridge = ((id(*)(id, SEL))objc_msgSend)(cls, NSSelectorFromString(@"shared"));
        FakeController* controller = [FakeController new];

        BOOL created = ((BOOL(*)(id, SEL, id, id))objc_msgSend)(
            bridge, NSSelectorFromString(@"createWithConfig:controller:"), @{}, controller);
        check(created, "createWithConfig succeeds when the framework is loaded");

        // Flutter -> Unreal
        ((void(*)(id, SEL, id, id, id))objc_msgSend)(
            bridge, NSSelectorFromString(@"sendMessageWithTarget:method:data:"),
            @"GameManager", @"startGame", @"{\"level\":1}");
        check(strcmp(gLastTarget, "GameManager") == 0 &&
              strcmp(gLastMethod, "startGame") == 0 &&
              strcmp(gLastData, "{\"level\":1}") == 0,
              "sendMessage reaches the framework with target, method and data intact");

        NSData* payload = [@"binary-payload" dataUsingEncoding:NSUTF8StringEncoding];
        ((void(*)(id, SEL, id, id, id))objc_msgSend)(
            bridge, NSSelectorFromString(@"sendBinaryWithTarget:method:data:"),
            @"Assets", @"upload", payload);
        check(strcmp(gLastMethod, "upload") == 0 && atoi(gLastData) == (int)payload.length,
              "sendBinary forwards the byte count");

        ((void(*)(id, SEL, id))objc_msgSend)(bridge, NSSelectorFromString(@"executeConsoleCommand:"), @"stat fps");
        check(gConsoleCalls == 1, "executeConsoleCommand reaches the framework");

        ((void(*)(id, SEL, id))objc_msgSend)(bridge, NSSelectorFromString(@"loadLevel:"), @"Arena");
        check(gLevelCalls == 1, "loadLevel reaches the framework");

        ((void(*)(id, SEL, id))objc_msgSend)(
            bridge, NSSelectorFromString(@"applyQualitySettings:"),
            (@{@"qualityLevel": @3, @"shadowQuality": @2}));
        check(gLastQuality[0] == 3 && gLastQuality[2] == 2 && gLastQuality[1] == -1,
              "applyQualitySettings maps keys by position and defaults missing ones to -1");

        NSDictionary* q = ((id(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"getQualitySettings"));
        check([q[@"antiAliasing"] intValue] == 1 && [q[@"viewDistance"] intValue] == 7 && q.count == 7,
              "getQualitySettings maps the value array back onto named keys in order");

        ((void(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"pause"));
        check(gPauseState == 1, "pause forwards 1");
        ((void(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"resume"));
        check(gPauseState == 0, "resume forwards 0");

        // Unreal -> Flutter, including the level-load reroute.
        MockUnreal_FireMessage("GameManager", "onScore", "{\"score\":42}");
        MockUnreal_FireMessage("FlutterBridge", "onLevelLoaded", "Arena");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];

        check([controller.gotTarget isEqualToString:@"GameManager"] &&
              [controller.gotMethod isEqualToString:@"onScore"] &&
              [controller.gotData isEqualToString:@"{\"score\":42}"],
              "a message from Unreal reaches the controller on the main thread");
        check([controller.gotLevel isEqualToString:@"Arena"],
              "onLevelLoaded is rerouted to the controller's level callback");

        // A real view, because the bridge stores it weakly and ARC will not
        // register a weak reference to an arbitrary pointer.
        UIView* fakeEngineView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];

        // Readiness is whatever CreateView returns, not a separate announcement.
        // The engine broadcasts readiness from PreInit and then blocks waiting
        // for a view, and plugin modules load later in that same PreInit, so
        // nothing here can ever hear the broadcast. The bridge polls from the
        // tick instead, which is how the engine expects to be handed a view.
        //
        // Until the engine can make one, CreateView returns NULL and the bridge
        // has nothing to show.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        check(gCreateViewCalls > 0,
              "the bridge keeps offering to build a view while the engine starts");
        check(((id(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"getView")) == nil,
              "getView returns nil while the engine is still starting");

        // Now let the engine hand one back.
        MockUnreal_SetView((__bridge void*)fakeEngineView);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        check(((id(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"getView")) == fakeEngineView,
              "getView hands back the engine's view once it exists");
        check(gViewReadyCallbacks == 1 && controller.gotView == fakeEngineView,
              "the controller is handed that exact view, exactly once");

        // The poll has to stop, or it runs at display-link rate forever.
        const int callsOnceBuilt = gCreateViewCalls;
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        check(gCreateViewCalls == callsOnceBuilt,
              "the bridge stops asking once it has a view");

        ((void(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"quit"));
        check(gStopped == 1, "quit stops the framework");

        printf("\n%s (%d failures)\n", gFailures ? "FAILED" : "ALL PASSED", gFailures);
        return gFailures ? 1 : 0;
    }
}
