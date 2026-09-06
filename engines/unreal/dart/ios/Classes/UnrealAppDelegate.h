//
//  UnrealAppDelegate.h
//
//  Just enough of Unreal's IOSAppDelegate to subclass it.
//
//  Unreal insists, and states it as a Fatal rather than a warning, that an app
//  embedding the engine has an app delegate descending from IOSAppDelegate. The
//  delegate caches itself in its own init, and that cached pointer is how the
//  engine later finds its delegate, its window and its view. No subclass, no
//  engine.
//
//  The declaration lives in the engine's own headers, which a Flutter app does
//  not have and should not need. So the class is redeclared here, narrowly. You
//  get to write:
//
//      class AppDelegate: IOSAppDelegate { ... }
//
//  and the real class, which ships inside UnrealFramework, is what you actually
//  subclass at runtime.
//
//  Two things to know before you rely on this.
//
//  Subclassing needs the symbol at link time, so the app has to link
//  UnrealFramework. That is already true for anything embedding Unreal, but it
//  does mean this header is not usable in a build without the framework.
//
//  This is a redeclaration, so it can drift if Epic changes the class. Nothing
//  here is checked by the compiler against the real thing. UnrealAssertAppDelegateUsable()
//  checks it at runtime instead, and the bridge calls it before starting the
//  engine so drift surfaces as a clear log line rather than as a strange crash
//  much later on.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Define this before importing if the real engine headers are already in scope,
// otherwise the two declarations collide.
#ifndef UNREAL_HAS_REAL_IOSAPPDELEGATE

/// Unreal's application delegate. Declared, never defined: the implementation
/// comes from UnrealFramework at link time.
///
/// The real class conforms to several more protocols (gesture recognisers, Game
/// Center, notifications, text fields). They are left out deliberately, because
/// declaring fewer is safe for subclassing and every extra one is another thing
/// that can drift. The superclass is not optional and must stay UIResponder.
@interface IOSAppDelegate : UIResponder <UIApplicationDelegate>

/// The engine's window.
///
/// Unreal spells it with a capital W, and that collides with the lowercase
/// `window` on UIApplicationDelegate: Swift decides the two are the same
/// property under an old name and refuses to let you touch it. So it comes
/// across to Swift as `unrealWindow`, which also keeps it clearly distinct from
/// the UIKit window your own delegate may want.
@property (strong, retain, nonatomic, nullable) UIWindow* Window
    NS_SWIFT_NAME(unrealWindow);

/// The engine's render view.
///
/// Really an FIOSView, which is a UIView subclass, so reading it as a UIView is
/// always valid. Treat it as read-only. The bridge assigns it while starting the
/// engine, and assigning something that is not an FIOSView will crash the
/// renderer rather than fail politely.
@property (retain, nullable) UIView* IOSView;

@end

#endif  // UNREAL_HAS_REAL_IOSAPPDELEGATE

#ifdef __cplusplus
extern "C" {
#endif

/// Why this engine delegate class and app delegate cannot be used together, or
/// nil when they can.
///
/// Takes both as arguments rather than looking them up, so the checks can be
/// exercised without a running UIApplication. `appDelegate` may be nil, which
/// means there is nothing to judge and only `engineDelegateClass` is checked.
///
/// The returned string is meant to be read by a person who is about to have a
/// bad afternoon, so it says what to do, not just what is wrong.
NSString* _Nullable UnrealAppDelegateProblem(Class _Nullable engineDelegateClass,
                                             id _Nullable appDelegate);

/// Why this app delegate's window arrangement will misbehave, or nil when it
/// looks right.
///
/// Unreal reads its `Window` for interface orientation, but only assigns it on
/// the startup path an embedded app skips. What fills it in is a naming
/// coincidence: the `Window` property generates a `setWindow:` setter, which is
/// the same selector UIKit calls on the delegate when the storyboard loads.
///
/// Declare your own `window` property and you take that selector over, Unreal's
/// stays nil, and orientation handling quietly goes wrong. That is a warning
/// rather than a refusal, because an app driving Unreal from a scene delegate
/// legitimately has no window on the app delegate.
NSString* _Nullable UnrealAppDelegateWindowWarning(id _Nullable appDelegate);

/// Start Unreal. Call this from your app delegate's
/// application:didFinishLaunchingWithOptions:, after calling super.
///
/// This cannot wait until a GameWidget appears. Unreal's own
/// -handleDidBecomeActive reads the command line, and in a non-shipping build
/// that is Fatal if nothing has set it yet. Starting the engine is what sets
/// it, so an app that becomes active before showing a GameWidget dies on launch
/// with a stack that points at UIKit rather than at anything you wrote.
///
/// Safe to call more than once; the engine only starts the first time. Returns
/// NO when the framework is absent or the delegate is unusable, having already
/// logged why.
BOOL UnrealStartEngineAtLaunch(void);

/// Check that the delegate UnrealAppDelegate.h describes matches the one that
/// shipped, and that the running app is actually using it.
///
/// Returns YES when the engine can start. On NO it has already logged what is
/// wrong and what to do about it. Cheap enough to call on every launch, and the
/// bridge does exactly that.
///
/// Declared extern "C" so it links the same whether you call it from a .m or a
/// .mm. Without that the bridge, which is ObjC++, would look for a mangled name
/// that an Objective-C caller never emits.
BOOL UnrealAssertAppDelegateUsable(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
