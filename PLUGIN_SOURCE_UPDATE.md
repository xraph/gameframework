# Plugin Source Update Summary

## Changes Made

Updated `cli/lib/src/utils/game_project_copier.dart` to use the actual Unity and Unreal plugin sources from the `engines/` directory instead of the example project.

## Unity Plugin Source

**Old Path**: `example/unity/demo/Demo/Assets/game-framework`  
**New Path**: `engines/unity/plugin`

**Copied To**: `<unity_project>/Assets/game-framework`

**Contents**:
- `Editor/` - FlutterBuildScript, FlutterExporter, XCodePostBuild, etc.
- `Scripts/` - FlutterBridge, FlutterGameManager, NativeAPI, MessageHandler, etc.
- `Plugins/iOS/` - FlutterBridge.mm
- Documentation: README.md, NATIVE_API_GUIDE.md, AR_FOUNDATION.md

## Unreal Plugin Source

**Old Path**: (was creating minimal embedded plugin)  
**New Path**: `engines/unreal/plugin`

**Copied To**: `<unreal_project>/Plugins/GameFramework`

**Contents**:
- `Source/FlutterPlugin/` - Full plugin source code
  - `Public/FlutterBridge.h`
  - `Private/FlutterBridge.cpp`
  - `FlutterPlugin.Build.cs`
- `FlutterPlugin.uplugin` - Plugin manifest

## Source Priority

Both Unity and Unreal project creation now follow this priority:

1. **Local files** (development) - Looks for `engines/{unity|unreal}/plugin` relative to CLI
2. **GitHub download** (production) - Downloads from repository
3. **Embedded templates** (fallback) - Creates minimal working plugin if download fails

## Commands Affected

### `game scaffold`
- Creates Flutter plugin package with full game engine project
- Uses plugin sources for engine project

### `game add`
- Adds game engine project to existing Flutter app
- Uses plugin sources for engine project

## Files Updated

- `cli/lib/src/utils/game_project_copier.dart`
  - Updated `_unityPluginPath` constant
  - Added `_unrealPluginPath` constant
  - Renamed `_findLocalGameFramework()` → `_findLocalUnityPlugin()`
  - Added `_findLocalUnrealPlugin()`
  - Renamed `_downloadGameFramework()` → `_downloadUnityPlugin()`
  - Added `_downloadUnrealPlugin()`
  - Updated `_setupMinimalUnityProject()` to use Unity plugin
  - Updated `_setupMinimalUnrealProject()` to use Unreal plugin
  - Added `_createEmbeddedUnrealPlugin()` fallback

## Testing

To verify the changes work correctly:

```bash
# Test Unity scaffold (should use engines/unity/plugin)
game scaffold --name test_unity --engine unity
ls -la test_unity/unity_project/Assets/game-framework/

# Test Unity add (should use engines/unity/plugin)
mkdir test_app && cd test_app
game add unity
ls -la unity_project/Assets/game-framework/

# Test Unreal scaffold (should use engines/unreal/plugin)
game scaffold --name test_unreal --engine unreal
ls -la test_unreal/unreal_project/Plugins/GameFramework/

# Test Unreal add (should use engines/unreal/plugin)
mkdir test_unreal_app && cd test_unreal_app
game add unreal
ls -la unreal_project/Plugins/GameFramework/
```

## Benefits

1. **Single source of truth** - Plugin code lives in `engines/` directory
2. **Consistency** - All scaffolded/added projects use the same plugin code
3. **Maintainability** - Update plugin in one place, affects all generated projects
4. **Completeness** - Full plugin with all features, editor tools, and documentation
5. **Version control** - Plugin changes tracked separately from example projects

## Deployment

When the repository is published to GitHub:
- Users installing via `dart pub global activate` will automatically download plugins from GitHub
- Local development (within the repo) uses local `engines/` directory
- Embedded fallbacks ensure CLI works even offline
