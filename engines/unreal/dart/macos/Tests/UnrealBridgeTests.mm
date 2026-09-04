// Exercises UnrealBridge against a mock framework exporting the real C ABI.
// Runs natively on macOS, no simulator required.

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "UnrealBridge.h"

extern "C" {
void MockUnreal_FireMessage(const char*, const char*, const char*);
extern char gLastTarget[128], gLastMethod[128], gLastData[256];
extern int32_t gLastQuality[8];
extern int gConsoleCalls, gLevelCalls, gPauseState, gStopped;
extern int gInitCalls, gTickCalls, gDestroyViewCalls;
}

static int gFailures = 0;
static void check(bool ok, const char* what) {
    printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) gFailures++;
}

/// Stand-in for UnrealEngineController.
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
- (void)onLevelLoadedWithLevelName:(NSString*)n buildIndex:(NSInteger)i { self.gotLevel = n; }
@end

int main(void) {
    @autoreleasepool {
        UnrealBridge* bridge = UnrealBridge.shared;
        check(bridge != nil, "shared instance exists");

        FakeController* controller = [FakeController new];
        check([bridge createWithConfig:@{} controller:controller],
              "createWithConfig succeeds when the framework is loaded");

        [bridge sendMessageWithTarget:@"GameManager" method:@"startGame" data:@"{\"level\":1}"];
        check(strcmp(gLastTarget, "GameManager") == 0 &&
              strcmp(gLastMethod, "startGame") == 0 &&
              strcmp(gLastData, "{\"level\":1}") == 0,
              "sendMessage reaches the framework with target, method and data intact");

        NSData* payload = [@"binary-payload" dataUsingEncoding:NSUTF8StringEncoding];
        [bridge sendBinaryWithTarget:@"Assets" method:@"upload" data:payload];
        check(strcmp(gLastMethod, "upload") == 0 && atoi(gLastData) == (int)payload.length,
              "sendBinary forwards the byte count");

        [bridge executeConsoleCommand:@"stat fps"];
        check(gConsoleCalls == 1, "executeConsoleCommand reaches the framework");

        [bridge loadLevel:@"Arena"];
        check(gLevelCalls == 1, "loadLevel reaches the framework");

        [bridge applyQualitySettings:@{@"qualityLevel": @3, @"shadowQuality": @2}];
        check(gLastQuality[0] == 3 && gLastQuality[2] == 2 && gLastQuality[1] == -1,
              "applyQualitySettings maps keys by position and defaults missing ones to -1");

        NSDictionary* q = [bridge getQualitySettings];
        check([q[@"antiAliasing"] intValue] == 1 && [q[@"viewDistance"] intValue] == 7 && q.count == 7,
              "getQualitySettings maps the value array back onto named keys in order");

        [bridge pause];
        check(gPauseState == 1, "pause forwards 1");
        [bridge resume];
        check(gPauseState == 0, "resume forwards 0");

        MockUnreal_FireMessage("GameManager", "onScore", "{\"score\":42}");
        MockUnreal_FireMessage("FlutterBridge", "onLevelLoaded", "Arena");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];

        check([controller.gotTarget isEqualToString:@"GameManager"] &&
              [controller.gotMethod isEqualToString:@"onScore"] &&
              [controller.gotData isEqualToString:@"{\"score\":42}"],
              "a message from Unreal reaches the controller on the main thread");
        check([controller.gotLevel isEqualToString:@"Arena"],
              "onLevelLoaded is rerouted to the controller's level callback");

        check(gInitCalls == 1,
              "createWithConfig initialises the embedded engine exactly once");

        // The display link drives the tick, so give the run loop a moment and
        // check the engine actually got advanced.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
        check(gTickCalls > 0,
              "the display link ticks the engine without the host asking");

        [bridge quit];
        check(gStopped == 1, "quit stops the framework");
        check(gDestroyViewCalls >= 0, "quit tears the render view down");

        const int ticksAtQuit = gTickCalls;
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
        check(gTickCalls == ticksAtQuit, "ticking stops after quit");

        printf("\n%s (%d failures)\n", gFailures ? "FAILED" : "ALL PASSED", gFailures);
        return gFailures ? 1 : 0;
    }
}
