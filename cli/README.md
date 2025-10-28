# Game CLI - Flutter Game Framework

Command-line tool to automate Unity and Unreal Engine game exports and integration with Flutter.

## Features

- ✅ **Automated Exports** - Export Unity/Unreal games for all platforms
- ✅ **Smart Sync** - Automatically copy exported files to Flutter project
- ✅ **Configuration Management** - Simple `.game.yml` configuration
- ✅ **Multi-Platform** - Android, iOS, macOS, Windows, Linux
- ✅ **Build Integration** - Trigger exports during Flutter builds
- ✅ **Validation** - Check configurations and paths

## Installation

### Global Installation (Recommended)

```bash
dart pub global activate --source path /path/to/flutter-game-framework/cli
```

Now you can use `game` command anywhere:

```bash
game --help
```

### Local Installation

```bash
cd /path/to/flutter-game-framework/cli
dart pub get
dart run bin/game.dart --help
```

---

## Quick Start

### 1. Initialize Configuration

In your Flutter project root:

```bash
cd your_flutter_app
game init
```

This creates `.game.yml` with default configuration.

### 2. Edit Configuration

Edit `.game.yml` and set your engine project paths:

```yaml
name: MyGame
version: 1.0.0

engines:
  unity:
    project_path: ../MyUnityProject
    export_path: ../MyUnityProject/Exports

    platforms:
      android:
        enabled: true
        target_path: android/unityLibrary

      ios:
        enabled: true
        target_path: ios/UnityFramework.framework
```

### 3. Export Game

```bash
# Export Unity for Android
game export unity --platform android

# Export Unreal for iOS
game export unreal --platform ios
```

### 4. Sync to Flutter

```bash
# Sync Unity Android files
game sync unity --platform android

# Sync Unreal iOS files
game sync unreal --platform ios
```

### 5. Build (All-in-One)

```bash
# Export + Sync + Flutter build
game build android --engine unity
```

---

## Commands

### `game init`

Create `.game.yml` configuration file.

**Options:**
- `--name, -n` - Project name (default: current directory name)
- `--unity` - Include Unity configuration (default: true)
- `--unreal` - Include Unreal configuration (default: false)
- `--force, -f` - Overwrite existing config

**Examples:**
```bash
# Create config with Unity
game init

# Create config with both engines
game init --unreal

# Create with custom name
game init --name MyAwesomeGame

# Force overwrite existing config
game init --force
```

---

### `game export`

Export/package game from Unity or Unreal.

**Usage:**
```bash
game export <engine> --platform <platform> [options]
```

**Arguments:**
- `<engine>` - Engine type: `unity` or `unreal`

**Options:**
- `--platform, -p` - Target platform: `android`, `ios`, `macos`, `windows`, `linux`
- `--all` - Export all enabled platforms
- `--development, -d` - Development build (default: false)
- `--config, -c` - Path to .game.yml (default: auto-detect)

**Examples:**
```bash
# Export Unity for Android
game export unity --platform android

# Export Unreal for iOS (development build)
game export unreal --platform ios --development

# Export Unity for all enabled platforms
game export unity --all

# Use custom config file
game export unity --platform android --config /path/to/.game.yml
```

**What it does:**
- Validates configuration
- Locates Unity/Unreal installation
- Triggers engine build/package process
- Saves output to configured export path

---

### `game sync`

Copy exported game files to Flutter project.

**Usage:**
```bash
game sync <engine> --platform <platform> [options]
```

**Arguments:**
- `<engine>` - Engine type: `unity` or `unreal`

**Options:**
- `--platform, -p` - Target platform: `android`, `ios`, `macos`, `windows`, `linux`
- `--all` - Sync all enabled platforms
- `--clean` - Delete target directory before syncing
- `--config, -c` - Path to .game.yml

**Examples:**
```bash
# Sync Unity Android files
game sync unity --platform android

# Sync Unreal iOS files (clean first)
game sync unreal --platform ios --clean

# Sync all enabled Unity platforms
game sync unity --all
```

**What it does:**

**Unity:**
- Android: Copies `unityLibrary` folder
- iOS/macOS: Copies `UnityFramework.framework`
- Windows/Linux: Copies build directory

**Unreal:**
- Android: Extracts APK, copies `.so` libraries and assets
- iOS: Extracts IPA, copies `UnrealFramework.framework`
- macOS: Copies `.app` bundle or framework
- Windows/Linux: Copies packaged build

---

### `game build`

Export, sync, and build Flutter app (all-in-one).

**Usage:**
```bash
game build <platform> --engine <engine> [options]
```

**Arguments:**
- `<platform>` - Target platform: `android`, `ios`, `macos`, `windows`, `linux`

**Options:**
- `--engine, -e` - Engine to build: `unity` or `unreal`
- `--development, -d` - Development build
- `--release` - Release build (default)
- `--skip-export` - Skip game export step
- `--skip-sync` - Skip file sync step
- `--config, -c` - Path to .game.yml

**Examples:**
```bash
# Full build: export Unity + sync + build Android APK
game build android --engine unity

# Build iOS with Unreal (skip export if already done)
game build ios --engine unreal --skip-export

# Development build
game build android --engine unity --development
```

**What it does:**
1. Exports game (unless `--skip-export`)
2. Syncs files to Flutter (unless `--skip-sync`)
3. Runs `flutter build <platform>`

---

### `game config`

View or validate configuration.

**Usage:**
```bash
game config [command]
```

**Subcommands:**
- `show` - Display current configuration
- `validate` - Validate configuration
- `edit` - Open config in default editor

**Examples:**
```bash
# Show current config
game config show

# Validate config
game config validate

# Open config file in editor
game config edit
```

---

## Configuration File (.game.yml)

### Basic Structure

```yaml
# Project metadata
name: MyGame
version: 1.0.0

# Engine configurations
engines:
  unity:
    project_path: ../MyUnityProject
    export_path: ../MyUnityProject/Exports

    export_settings:
      development: false
      build_configuration: Release
      scenes:
        - MainMenu
        - Gameplay

    platforms:
      android:
        enabled: true
        target_path: android/unityLibrary
        build_settings:
          export_project: true
          scripting_backend: IL2CPP
          target_architectures: [ARM64]

      ios:
        enabled: true
        target_path: ios/UnityFramework.framework
        build_settings:
          symlink_libraries: true

  unreal:
    project_path: ../MyUnrealProject
    export_path: ../MyUnrealProject/Packaged

    export_settings:
      development: false
      build_configuration: Shipping
      levels:
        - MainMenu
        - Level_01

    platforms:
      android:
        enabled: true
        target_path: android/app/src/main
        build_settings:
          architecture: ARM64
          package_data_in_apk: false

      ios:
        enabled: true
        target_path: ios/UnrealFramework.framework
        build_settings:
          minimum_ios_version: 12.0
```

### Configuration Options

#### Root Level
- `name` (required) - Project name
- `version` (optional) - Project version

#### Engine Level
- `project_path` (required) - Path to Unity/Unreal project
- `export_path` (optional) - Where exports are saved (default: `{project}/Exports` or `{project}/Packaged`)
- `export_settings` (optional) - Engine-specific export settings
- `platforms` (required) - Platform configurations

#### Export Settings
- `development` (optional) - Development build flag (default: false)
- `build_configuration` (optional) - Build configuration (Release, Debug, Shipping, etc.)
- `scenes` (Unity) - List of scenes to include
- `levels` (Unreal) - List of levels to include
- `custom_settings` (optional) - Additional engine-specific settings

#### Platform Level
- `enabled` (required) - Whether platform is enabled
- `target_path` (optional) - Where to copy files in Flutter project (default: auto-detected)
- `build_settings` (optional) - Platform-specific build settings

---

## Workflows

### Daily Development Workflow

```bash
# Make changes in Unity/Unreal
# ...

# Export and sync in one command
game export unity --platform android
game sync unity --platform android

# Or use build command (does everything)
game build android --engine unity
```

### Multi-Platform Release Workflow

```bash
# Export all platforms
game export unity --all
game export unreal --all

# Sync all platforms
game sync unity --all
game sync unreal --all

# Build Flutter apps
flutter build apk
flutter build ios
flutter build macos
```

### Continuous Integration (CI/CD)

```yaml
# .github/workflows/build.yml
- name: Export Unity
  run: game export unity --platform android

- name: Sync Unity files
  run: game sync unity --platform android

- name: Build Android APK
  run: flutter build apk
```

---

## Tips & Best Practices

### 1. **Version Control**

**Add to `.gitignore`:**
```gitignore
# Game exports (large files)
android/unityLibrary/
android/app/src/main/jniLibs/
ios/UnityFramework.framework/
ios/UnrealFramework.framework/
macos/*.app
windows/unity_build/
windows/unreal_build/
```

**Commit `.game.yml`:**
```bash
git add .game.yml
git commit -m "Add game CLI configuration"
```

### 2. **Relative Paths**

Use relative paths in `.game.yml` for team collaboration:

```yaml
# Good ✅
project_path: ../MyUnityProject

# Bad ❌
project_path: /Users/john/Projects/MyUnityProject
```

### 3. **Pre-Export Checks**

Before exporting:
- Ensure Unity/Unreal project compiles
- Check all scenes/levels are included
- Verify platform-specific settings in engine

### 4. **Clean Builds**

For release builds, use clean sync:

```bash
game sync unity --platform android --clean
```

### 5. **Development vs Release**

Use development flag during development:

```bash
# Development
game export unity --platform android --development

# Release (default)
game export unity --platform android
```

---

## Troubleshooting

### Config File Not Found

```
Error: No .game.yml found
```

**Solution:** Run `game init` in your Flutter project root.

### Unity/Unreal Not Found

```
Error: Unity Editor not found
```

**Solution:** Install Unity/Unreal in standard location or add to PATH.

### Export Failed

```
Error: Unity build failed
```

**Solutions:**
- Check Unity project compiles in Editor
- Verify all scenes are in Build Settings
- Check Unity console for errors
- Ensure target platform is installed in Unity

### Sync Failed

```
Error: Export directory not found
```

**Solution:** Run `game export` first before `game sync`.

### Permission Denied

```
Error: Permission denied
```

**Solution:**
```bash
# Make game executable
chmod +x /path/to/game

# Or run with dart
dart run game.dart <command>
```

---

## Platform-Specific Notes

### Android

**Requirements:**
- Android SDK & NDK
- Unity: Minimum API 22, ARM64
- Unreal: Minimum API 22, ARM64

**Target Paths:**
- Unity: `android/unityLibrary`
- Unreal: `android/app/src/main/jniLibs/` and `android/app/src/main/assets/`

### iOS

**Requirements:**
- macOS with Xcode
- Valid Apple Developer account
- Unity: iOS 12.0+
- Unreal: iOS 12.0+

**Target Paths:**
- Unity: `ios/UnityFramework.framework`
- Unreal: `ios/UnrealFramework.framework`

**Post-Sync:**
1. Open Xcode workspace
2. Add framework with "Embed & Sign"
3. Disable Bitcode in Build Settings

### macOS

**Requirements:**
- macOS 10.14+
- Xcode

**Target Paths:**
- Unity: `macos/UnityFramework.framework`
- Unreal: `macos/UnrealFramework.framework` or `.app` bundle

### Windows

**Requirements:**
- Windows 10+
- Visual Studio 2022 with C++

**Target Paths:**
- Unity: `windows/unity_build`
- Unreal: `windows/unreal_build`

### Linux

**Requirements:**
- Ubuntu 20.04+ (or equivalent)
- Build essentials

**Target Paths:**
- Unity: `linux/unity_build`
- Unreal: `linux/unreal_build`

---

## Advanced Usage

### Custom Scripts

Create custom scripts using `.game.yml`:

```dart
// scripts/export_all.dart
import 'package:game_cli/src/config/config_loader.dart';
import 'package:game_cli/src/exporters/unity_exporter.dart';

void main() async {
  final config = ConfigLoader.loadConfig();
  final unityConfig = config.engines['unity']!;
  final exporter = UnityExporter(config: unityConfig, logger: Logger());

  for (final platform in unityConfig.platforms.keys) {
    await exporter.export(platform);
  }
}
```

### Watch Mode

Use with file watchers for automatic export:

```bash
# Install watchexec
brew install watchexec

# Watch Unity project, export on changes
watchexec -w ../MyUnityProject/Assets \
  game export unity --platform android
```

### Integration with Build Systems

**Make:**
```makefile
.PHONY: export-unity sync-unity build-android

export-unity:
	game export unity --platform android

sync-unity:
	game sync unity --platform android

build-android: export-unity sync-unity
	flutter build apk
```

**Just:**
```just
export-unity:
    game export unity --platform android

sync-unity:
    game sync unity --platform android

build-android: export-unity sync-unity
    flutter build apk
```

---

## Contributing

See main [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

---

## Support

- **Issues:** [GitHub Issues](https://github.com/xraph/flutter-game-framework/issues)
- **Discussions:** [GitHub Discussions](https://github.com/xraph/flutter-game-framework/discussions)

---

## License

See [LICENSE](../LICENSE)

---

**Last Updated:** 2025-10-27
**CLI Version:** 0.5.0
