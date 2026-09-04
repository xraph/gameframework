# Engine patches

Unreal Engine changes needed to build an embedded framework. They apply to a
source build of the engine, since an installed engine ships its modules prebuilt
and cannot honour the settings embedding requires.

Apply from the root of your engine clone:

```bash
cd /path/to/UnrealEngine
git apply /path/to/gameframework/engines/unreal/patches/*.patch
```

## 0001-EmbeddedCommunication-numeric-conversions

Six numeric conversion defects in
`Engine/Source/Runtime/Core/Private/Misc/EmbeddedCommunication.cpp`, all inside
code that only compiles when `BUILD_EMBEDDED_APP` is defined. UE 5.8 treats them
as errors, so the file does not build and neither does an embedded target.

Five are narrowing warnings. One is a real bug: `ForceTickMin` and
`ForceTickMax` are time slices in seconds and were parsed with `FCString::Atoi`,
so `-ForceTickMin=0.05` became zero. They now use `Atof`.

That six defects sit in one file says something about how rarely this path is
built. Verified against UE 5.8.2. Worth sending upstream.
