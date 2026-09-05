# Embedding Unreal in a Flutter app on iOS

The pod handles starting the engine, driving its tick, and handing its render
view to `GameWidget`. One thing it cannot do for you is the app delegate, and
without that the engine will not start at all.

## Your AppDelegate must subclass IOSAppDelegate

Unreal states this itself, and as a Fatal rather than a warning:

> Currently, a native app embedding Unreal must have the AppDelegate subclass
> from IOSAppDelegate.

`IOSAppDelegate` caches itself in its own `init`, and that cached pointer is how
the engine finds its delegate, its window, and its view. No subclass, no engine.

The awkward part is that Flutter apps normally subclass `FlutterAppDelegate`,
and an Objective-C class cannot have two superclasses.

`FlutterAppDelegate` is a convenience, not a requirement. What Flutter actually
needs is a delegate that registers plugins and forwards application lifecycle to
them. So the working shape is a delegate that subclasses `IOSAppDelegate` and
conforms to `FlutterPluginRegistry` and `FlutterAppLifeCycleProvider`.

## Building the delegate class at runtime

This is the approach verified on device. It needs no Unreal headers, because the
framework exports the class and you subclass it through the Objective-C runtime.

Replace your app's `main.m`:

```objc
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

int main(int argc, char* argv[]) {
    @autoreleasepool {
        Class base = NSClassFromString(@"IOSAppDelegate");
        if (!base) {
            // UnrealFramework is not linked. Fall back so the app still runs,
            // with no engine.
            base = NSClassFromString(@"FlutterAppDelegate");
        }
        Class delegate = objc_allocateClassPair(base, "AppDelegate", 0);
        objc_registerClassPair(delegate);
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
```

Then register your plugins from `application:didFinishLaunchingWithOptions:` on
that class, using a category or `class_addMethod`.

Do not call `super`'s `didFinishLaunchingWithOptions`. In an embedded build it
would start Unreal the non-embedded way and fight with the pod, which starts it
for you. `IOSAppDelegate` caches itself in `init`, which `UIApplicationMain`
already did, so the engine can still find it.

## What the pod does for you

Once the delegate is right, `GameWidget(engineType: GameEngineType.unreal)` is
enough. Behind it:

- `UnrealBridge_StartEngine` runs on create, which is what brings Metal up
- The display link drives `UnrealBridge_Tick`
- The render view is offered to the engine every tick until it takes, then
  handed to the controller and added to Flutter's platform view container
- Container size is pushed down so the engine renders at the right resolution

The pod does not wait for the engine's `inisareready` announcement, and neither
should you. The engine broadcasts it from `PreInit` and then blocks waiting for
a view, while plugin modules only load later in `PreInit`. By the time anything
could subscribe, the announcement has gone and the engine is already stuck.

## Keep the engine view inside the visible hierarchy

If you place the view yourself, put it inside a view that is actually on screen,
not merely in the window behind an opaque one. A `CAMetalLayer` that
CoreAnimation never composites never presents, its drawables are never released,
and the game thread blocks on `nextDrawable` once the queue fills. That looks
like a frozen screen and an engine stuck at a couple of dozen frames, which
resembles a rendering bug far more than a view hierarchy mistake.

`GameWidget` handles this correctly.

## Requirements

- An engine built from source. A launcher install cannot define
  `BUILD_EMBEDDED_APP` for its own prebuilt modules, so the framework links and
  launches and never boots an engine. See `docs/UNREAL_FRAMEWORK_BLOCKER.md` in
  game-cli.
- `bBuildAsFramework=True` under `[/Script/IOSRuntimeSettings.IOSRuntimeSettings]`
- Cooked content staged into the app bundle, alongside `uecommandline.txt`
- A level to load. An empty `GameDefaultMap` gets you all the way through
  renderer init and then "Failed to load package ''".
