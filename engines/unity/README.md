# Unity Engine Plugin

Flutter plugin for integrating Unity game engine with the Game Framework.

## Status

🚧 **In Development** - Phase 3 (Weeks 9-12)

## Structure

```
unity/
├── dart/           # Flutter/Dart plugin
├── android/        # Android native (Kotlin)
├── ios/            # iOS native (Swift)
└── plugin/         # Unity .unitypackage
```

## Planned Features

- Unity 2022.3.x and 2023.1.x support
- Android and iOS integration
- AR Foundation support
- Automated export scripts
- Web (WebGL) support

## Next Steps

1. Implement Dart plugin extending `GameEngineController`
2. Build Android native bridge (Kotlin)
3. Build iOS native bridge (Swift)
4. Create Unity package with communication scripts
5. Add export automation

See `docs-files/08-implementation-roadmap.md` Phase 3-4 for detailed plan.
