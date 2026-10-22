# Engine patches

Unreal Engine changes needed to build an embedded framework. They apply to a
source build of the engine, since an installed engine ships its modules prebuilt
and cannot honour the settings embedding requires.

Apply from the root of your engine clone:

```bash
cd /path/to/UnrealEngine
git apply /path/to/gameframework/engines/unreal/patches/*.patch
```

## Engine revision

Verified against `EpicGames/UnrealEngine` branch `5.8`, commit
`79f0816a799dd45f7ebd6c366daec7d4d568a6e5`.

```bash
git clone git@github.com:EpicGames/UnrealEngine.git -b 5.8
cd UnrealEngine
git checkout 79f0816a7
./Setup.sh
```

Branch `5.8` moves, so a fresh clone will not land on that commit. The patch
matches on context rather than line numbers and the code around it changes
rarely, so it will usually still apply. If `git apply` rejects it, check out the
commit above, or re-roll the patch against whatever revision you want to build.

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
