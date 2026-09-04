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
@end
@implementation FakeController
- (void)onMessageFromUnrealWithTarget:(NSString*)t method:(NSString*)m data:(NSString*)d {
    self.gotTarget = t; self.gotMethod = m; self.gotData = d;
}
- (void)onLevelLoadedWithLevelName:(NSString*)n buildIndex:(NSInteger)i {
    self.gotLevel = n;
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
        MockUnreal_SetView((__bridge void*)fakeEngineView);

        // The engine has not announced readiness, so no view should exist yet.
        check(gCreateViewCalls == 0,
              "no render view is built before the engine signals readiness");
        check(((id(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"getView")) == nil,
              "getView returns nil while the engine is still starting");

        MockUnreal_SignalEngineReady();
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
        check(gCreateViewCalls == 1,
              "the render view is built once the engine announces it can be");
        check(((id(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"getView")) == fakeEngineView,
              "getView hands back the engine's view once it exists");

        ((void(*)(id, SEL))objc_msgSend)(bridge, NSSelectorFromString(@"quit"));
        check(gStopped == 1, "quit stops the framework");

        printf("\n%s (%d failures)\n", gFailures ? "FAILED" : "ALL PASSED", gFailures);
        return gFailures ? 1 : 0;
    }
}
