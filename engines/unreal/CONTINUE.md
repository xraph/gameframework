# Where the Unreal work stands

Written 2026-09-07, at the end of a long session. Everything here was seen
working or seen failing on this machine, not inferred.

## iOS: working, verified on device

Unreal renders inside a `GameWidget` on an iPhone 16 Pro at full native
portrait resolution. Drag orbits, pinch zooms, the HUD controls drive the
cube, and camera state streams back. Pause freezes the scene, unload releases
the view and reload brings it back mid-scene.

Three commands, no hand editing:

    game export unreal -p ios && game sync unreal -p ios && flutter build ios

`flutter run` times out installing 565MB over wireless. USB is fine.

## macOS: builds, starts, stops at shaders

Further than it looks, and not finished. The app builds, the framework loads,
the engine starts, reads its command line, opens the project and initialises
Metal. It then fails:

    LogShaderLibrary: Error: Failed to initialize ShaderCodeLibrary ...
    part of the Global shader library is missing

Nothing has been cooked for Mac, and a non-editor build cannot compile shaders
at runtime.

**Next step, and it is a long one.** Build the Mac editor from source, cook the
project for Mac, then re-export. The engine build alone took 78 minutes for the
game target; the editor is bigger. After that the framework should have what it
needs, and the next unknown is whether reparenting the engine's `FCocoaWindow`
content view into the Flutter platform view actually renders. That has never
run, so treat it as unproven rather than merely untested.

Two things a macOS host needs, which the export prints but nothing enforces:

- The app must not be sandboxed for an uncooked run, because it reads the
  project from a path outside its container. Cooked content in the bundle
  removes this.
- The engine finds its own content relative to the executable, so it needs
  `-basedir=<engine>/Engine/Binaries/Mac`. That is read from the process argv,
  not from `uecommandline.txt`, so it cannot be set from inside the library.
  A staged layout beside the app would avoid it.

## Android

The UPL migration is in and the library-mode Java is injected at build time.
Not run on a device in this session, so treat it as built but unverified.

## Things worth knowing before changing anything

- `BUILD_EMBEDDED_APP` is defined only by `UEBuildIOS.cs`. The Mac target
  defines it itself and takes `TargetBuildEnvironment.Unique` so it reaches
  Core, which is why the Mac build rebuilds the engine.
- The host's tick is a display link on the **main thread**, not Unreal's game
  loop. `TickGameThread` drains its queue on whoever calls it, so anything
  touching the renderer must not run there. `FTSTicker` is the way onto the
  real game thread; `RunOnGameThread` is not.
- Unreal's log file is buffered and mostly shows startup. Do not conclude
  anything from a missing runtime line. Route diagnostics back over the bridge
  instead; `flutter.TraceMessages 1` turns the message trace on.
- A flat iOS framework must not contain `Resources/`. A versioned macOS one
  must carry `Versions/A/Resources/Info.plist`. These are opposite rules and
  both are enforced by tooling that blames something else.

## Known broken, and not mine

`engines/unity/dart/macos/Classes/UnityEngineController.swift` does not
compile: it references `FlutterPlatformView`, which does not exist on macOS,
and `UnityFramework`, and it declares two methods with the same Objective-C
selector. Any Flutter app depending on both engines fails to build for macOS
because of it. Untouched here, since Unity could not be tested.
