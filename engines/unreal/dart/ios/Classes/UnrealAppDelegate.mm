//
//  UnrealAppDelegate.mm
//
//  Runtime check that the IOSAppDelegate declared in UnrealAppDelegate.h still
//  matches the one inside UnrealFramework, and that the app is using it.
//
//  Nothing here may reference IOSAppDelegate by name in code. Doing that emits a
//  link-time reference to the class, and the pod deliberately builds without
//  UnrealFramework so it can ship to projects that have no engine. The class
//  arrives as an argument instead.
//

#import "UnrealAppDelegate.h"

#import <objc/runtime.h>
#import <objc/message.h>

#include <dlfcn.h>

/// Defined in UnrealBridge.mm.
extern "C" void UnrealBridgeBeginDrivingEngine(void);
#import <objc/message.h>

extern "C" BOOL UnrealStartEngineAtLaunch(void) {
    if (!UnrealAssertAppDelegateUsable()) {
        return NO;
    }

    // Resolved at runtime rather than linked, so the pod still builds for
    // projects with no engine. Same reason the rest of the bridge does it.
    typedef int32_t (*StartEngineFn)(void);
    StartEngineFn startEngine =
        (StartEngineFn)dlsym(RTLD_DEFAULT, "UnrealBridge_StartEngine");
    if (startEngine == NULL) {
        NSLog(@"[UnrealAppDelegate] UnrealFramework has no UnrealBridge_StartEngine, "
              @"so it was built without the Flutter plugin. Add it under "
              @"Plugins/FlutterPlugin and package again.");
        return NO;
    }

    const int32_t started = startEngine();
    NSLog(@"[UnrealAppDelegate] Engine start at launch -> %d", started);
    if (started == 0) {
        return NO;
    }

    // The engine is now blocking until it is handed a view, and the tick is
    // what offers one. It has to start here rather than when a GameWidget
    // appears, because that widget's engine call runs in a post-frame callback
    // and Flutter cannot produce that frame while the engine is blocked.
    UnrealBridgeBeginDrivingEngine();
    return YES;
}

extern "C" NSString* UnrealAppDelegateProblem(Class engineDelegateClass, id appDelegate) {
    if (engineDelegateClass == nil) {
        return @"IOSAppDelegate is missing, so UnrealFramework is not loaded. "
               @"Check that your plugin vendors UnrealFramework.framework and "
               @"that it is embedded in the app bundle.";
    }

    // The shim declares IOSAppDelegate : UIResponder. If that ever stops being
    // true, every subclass built against the shim has the wrong superclass, and
    // the failure would otherwise land somewhere unrecognisable.
    Class superclass = class_getSuperclass(engineDelegateClass);
    if (superclass != [UIResponder class]) {
        return [NSString stringWithFormat:
            @"IOSAppDelegate now descends from %s, not UIResponder. "
            @"UnrealAppDelegate.h is out of date with this engine build and "
            @"subclassing it is no longer safe.",
            superclass ? class_getName(superclass) : "nothing"];
    }

    // Getters for the properties the shim redeclares. A missing setter is not
    // worth refusing to start over, but a missing getter means the shim is
    // describing a class that no longer has that shape.
    static const char* const kRequiredGetters[] = {"Window", "IOSView"};
    for (size_t i = 0; i < sizeof(kRequiredGetters) / sizeof(kRequiredGetters[0]); ++i) {
        if (![engineDelegateClass instancesRespondToSelector:sel_getUid(kRequiredGetters[i])]) {
            return [NSString stringWithFormat:
                @"IOSAppDelegate no longer has a '%s' property. "
                @"UnrealAppDelegate.h is out of date with this engine build.",
                kRequiredGetters[i]];
        }
    }

    // No delegate to judge. That happens outside a real app, in a test binary or
    // an extension, where UIApplication was never started. The class checks
    // above still ran, which is everything that can be known here.
    if (appDelegate == nil) {
        return nil;
    }

    // Declaring the class correctly is not the same as using it. This catches
    // the common mistake, which is a delegate still subclassing
    // FlutterAppDelegate.
    if (![appDelegate isKindOfClass:engineDelegateClass]) {
        return [NSString stringWithFormat:
            @"Your app delegate is %s, which does not descend from "
            @"IOSAppDelegate. Unreal treats that as fatal and will not start. "
            @"Subclass IOSAppDelegate instead of FlutterAppDelegate; see "
            @"INTEGRATION.md.",
            class_getName(object_getClass(appDelegate))];
    }

    return nil;
}

extern "C" NSString* UnrealAppDelegateWindowWarning(id appDelegate) {
    SEL windowGetter = sel_getUid("Window");
    if (appDelegate == nil || ![appDelegate respondsToSelector:windowGetter]) {
        return nil;
    }

    // -Window is a plain object getter, so messaging it through a typed
    // function pointer is safe and avoids a performSelector cast warning.
    typedef id (*WindowGetterFn)(id, SEL);
    id window = ((WindowGetterFn)objc_msgSend)(appDelegate, windowGetter);
    if (window != nil) {
        return nil;
    }

    return @"Unreal's Window is nil, so it will read the wrong interface "
           @"orientation. UIKit sets that window by calling setWindow: on your "
           @"delegate, and declaring your own 'window' property takes over that "
           @"selector. Remove it and read unrealWindow instead. Ignore this if "
           @"you drive Unreal from a scene delegate.";
}

extern "C" BOOL UnrealAssertAppDelegateUsable(void) {
    UIApplication* application = UIApplication.sharedApplication;

    // Outside a real app there is no delegate to check, so check what can be
    // checked and let the caller proceed. Inside one, a missing delegate is its
    // own problem and worth saying so.
    id appDelegate = application.delegate;
    if (application != nil && appDelegate == nil) {
        NSLog(@"[UnrealAppDelegate] The application has no delegate yet. Start "
              @"the engine after the app has finished launching.");
        return NO;
    }

    NSString* problem =
        UnrealAppDelegateProblem(NSClassFromString(@"IOSAppDelegate"), appDelegate);
    if (problem != nil) {
        NSLog(@"[UnrealAppDelegate] %@", problem);
        return NO;
    }

    NSString* warning = UnrealAppDelegateWindowWarning(appDelegate);
    if (warning != nil) {
        NSLog(@"[UnrealAppDelegate] %@", warning);
    }
    return YES;
}
