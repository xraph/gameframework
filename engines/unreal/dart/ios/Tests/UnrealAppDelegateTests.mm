//
//  Exercise the app delegate contract check.
//
//  UnrealAppDelegateProblem takes the engine class and the app delegate as
//  arguments precisely so this can run without a UIApplication, which a spawned
//  test binary does not have. Every branch below is reachable here; the only
//  untested part is UnrealAssertAppDelegateUsable's two-line wiring.
//

#import <UIKit/UIKit.h>
#import "../Classes/UnrealAppDelegate.h"

static int gFailures = 0;

static void check(BOOL condition, const char* what) {
    printf("%s: %s\n", condition ? "PASS" : "FAIL", what);
    if (!condition) gFailures++;
}

/// Shaped like the real IOSAppDelegate: descends from UIResponder and has both
/// properties the shim redeclares.
@interface FakeEngineDelegate : UIResponder
@property (retain) UIWindow* Window;
@property (retain) UIView* IOSView;
@end
@implementation FakeEngineDelegate
@end

/// What a correctly written host app delegate looks like.
@interface GoodAppDelegate : FakeEngineDelegate
@end
@implementation GoodAppDelegate
@end

/// Stands in for a delegate still subclassing FlutterAppDelegate.
@interface UnrelatedAppDelegate : UIResponder
@end
@implementation UnrelatedAppDelegate
@end

/// Epic changing the superclass out from under the shim.
@interface WrongSuperclassDelegate : NSObject
@end
@implementation WrongSuperclassDelegate
@end

/// Epic dropping a property the shim redeclares.
@interface MissingPropertyDelegate : UIResponder
@end
@implementation MissingPropertyDelegate
@end

static BOOL mentions(NSString* haystack, NSString* needle) {
    return haystack != nil &&
           [haystack rangeOfString:needle].location != NSNotFound;
}

int main(void) {
    @autoreleasepool {
        NSString* problem;

        problem = UnrealAppDelegateProblem(nil, nil);
        check(mentions(problem, @"UnrealFramework"),
              "a missing IOSAppDelegate is reported as a missing framework");

        problem = UnrealAppDelegateProblem([WrongSuperclassDelegate class], nil);
        check(mentions(problem, @"UIResponder"),
              "a changed superclass is refused, because subclassing is then unsafe");

        problem = UnrealAppDelegateProblem([MissingPropertyDelegate class], nil);
        check(mentions(problem, @"Window"),
              "a dropped property is refused and named");

        problem = UnrealAppDelegateProblem([FakeEngineDelegate class], nil);
        check(problem == nil,
              "a well shaped class passes when there is no delegate to judge");

        // The case that actually matters: the app delegate is a subclass, which
        // is what a host app writes.
        GoodAppDelegate* good = [GoodAppDelegate new];
        problem = UnrealAppDelegateProblem([FakeEngineDelegate class], good);
        check(problem == nil,
              "a delegate subclassing the engine's delegate is accepted");

        // And the mistake this check exists to catch.
        UnrelatedAppDelegate* wrong = [UnrelatedAppDelegate new];
        problem = UnrealAppDelegateProblem([FakeEngineDelegate class], wrong);
        check(mentions(problem, @"IOSAppDelegate") &&
              mentions(problem, @"UnrelatedAppDelegate"),
              "a delegate that does not descend from IOSAppDelegate is refused, and named");

        // An exact instance, rather than a subclass, is also fine.
        FakeEngineDelegate* exact = [FakeEngineDelegate new];
        problem = UnrealAppDelegateProblem([FakeEngineDelegate class], exact);
        check(problem == nil, "an exact instance of the engine's delegate is accepted");

        // The window trap: Unreal reads its Window for orientation, and a host
        // that declares its own 'window' property steals the setter that fills
        // it in.
        check(UnrealAppDelegateWindowWarning(nil) == nil,
              "no window warning when there is no delegate to inspect");

        UnrelatedAppDelegate* noWindowProperty = [UnrelatedAppDelegate new];
        check(UnrealAppDelegateWindowWarning(noWindowProperty) == nil,
              "no window warning for a delegate with no Window property at all");

        GoodAppDelegate* windowless = [GoodAppDelegate new];
        check(mentions(UnrealAppDelegateWindowWarning(windowless), @"setWindow:"),
              "a nil Window is reported, naming the setter that should have filled it");

        GoodAppDelegate* windowed = [GoodAppDelegate new];
        windowed.Window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        check(UnrealAppDelegateWindowWarning(windowed) == nil,
              "no window warning once Unreal's Window is set");

        printf("\n%s (%d failures)\n", gFailures ? "FAILED" : "ALL PASSED", gFailures);
        return gFailures ? 1 : 0;
    }
}
