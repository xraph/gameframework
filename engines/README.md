# Game Engines

This directory contains engine-specific plugins for the GameFramework.

## Structure

```
engines/
├── unity/               # Unity engine plugin
│   ├── dart/           # Dart/Flutter plugin code
│   ├── android/        # Android native (Kotlin)
│   ├── ios/            # iOS native (Swift)
│   └── plugin/         # Unity .unitypackage
└── unreal/             # Unreal Engine plugin
    ├── dart/           # Dart/Flutter plugin code
    ├── android/        # Android native (Kotlin)
    ├── ios/            # iOS native (Swift)
    └── plugin/         # Unreal .uplugin
```

## Development Status

- **Core Framework**: ✅ Implemented (Phase 1 complete)
- **Unity Plugin**: 🚧 Coming next (Phase 3-4)
- **Unreal Plugin**: 📋 Planned (Phase 5-6)

## Next Steps

See the implementation roadmap in `docs-files/08-implementation-roadmap.md` for the full development plan.
