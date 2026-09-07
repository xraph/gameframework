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

## Subclass it directly

The pod ships a header that declares `IOSAppDelegate` for you, so you can
subclass it from your own app without any engine headers.

Add this to `ios/Runner/Runner-Bridging-Header.h`:

```objc
#import <gameframework_unreal/UnrealAppDelegate.h>
```

Then write `ios/Runner/AppDelegate.swift` against it:

```swift
import UIKit
import Flutter

@main
class AppDelegate: IOSAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let controller = unrealWindow?.rootViewController as? FlutterViewController {
            GeneratedPluginRegistrant.register(with: controller)
        }
        return true
    }
}
```

Three things in there are load bearing.

Do not call `super`. In an embedded build that starts Unreal the non-embedded
way and fights with the pod, which starts it for you. `IOSAppDelegate` caches
itself during `init`, which has already run by this point, so the engine still
finds its delegate.

Register plugins against the `FlutterViewController`, not against `self`.
Normally `GeneratedPluginRegistrant.register(with: self)` works because
`FlutterAppDelegate` conforms to `FlutterPluginRegistry`, and you no longer
inherit from it. `FlutterViewController` conforms too, and your storyboard
already creates one as the root view controller.

**Do not declare a `window` property.** This is the one that will cost you an
afternoon, so it gets its own section.

### The window trap

Unreal reads its own `Window` to work out the interface orientation. It only
assigns that window on the startup path you just skipped, so you would expect it
to be nil. It is not, and the reason is a naming coincidence.

Unreal spells the property with a capital W. Objective-C builds a setter from
that by capitalising the first letter, giving `setWindow:`. That is the exact
selector UIKit calls on your app delegate when the storyboard loads its window.
So UIKit hands Unreal its window without either side knowing about the other.

Declare `var window: UIWindow?` in your delegate and you take that selector
over. Unreal's `Window` stays nil, orientation goes wrong, and nothing anywhere
reports an error. Leave it out and read `unrealWindow` when you need it.

The bridge checks for this before starting the engine and logs a warning naming
the setter, so you do not have to remember. It is a warning rather than a
refusal, because an app driving Unreal from a scene delegate legitimately has no
window on the app delegate.

### Two more things worth knowing

Subclassing needs the class at link time, so the app has to link
UnrealFramework. That is already true for anything embedding Unreal, but it
means this header is no use in a build without the framework.

The header redeclares a class Epic owns, and nothing checks that redeclaration
against the real one at compile time. So the bridge checks it at runtime
instead, before starting the engine, and refuses with a clear log line if the
shape has drifted or if your delegate does not descend from `IOSAppDelegate`
after all. Call `UnrealAssertAppDelegateUsable()` yourself if you want to fail
earlier.

### Naming

| Objective-C | Swift | What it is |
|---|---|---|
| `Window` | `unrealWindow` | Unreal's window. Renamed because the capital W collides with `UIApplicationDelegate`'s `window`, and Swift otherwise decides the two are one property under an old name and refuses to let you touch it. |
| `IOSView` | `iosView` | Unreal's render view. Read only. |

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
