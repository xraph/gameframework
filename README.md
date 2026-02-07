# Game Framework

A unified, modular framework for embedding multiple game engines (Unity, Unreal Engine) into Flutter applications with bidirectional communication and lifecycle management.

[![pub package](https://img.shields.io/pub/v/gameframework.svg)](https://pub.dev/packages/gameframework)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Overview

Game Framework provides a consistent API for integrating game engines into Flutter applications. Built as a Dart workspace monorepo, it includes:

- **gameframework** - Core framework package with unified engine API
- **gameframework_unity** - Unity Engine integration plugin
- **gameframework_unreal** - Unreal Engine integration plugin
- **example** - Demo application showcasing framework capabilities

## Features

- **Unified API** - Single interface for all game engines
- **Modular Architecture** - Use only the engines you need
- **Bidirectional Communication** - Flutter ↔ Engine messaging with type safety
- **Lifecycle Management** - Automatic pause/resume/destroy handling
- **Multi-Platform** - Android, iOS, macOS, Windows, Linux support
- **Production Ready** - Comprehensive testing and documentation

## Monorepo Structure

```
gameframework-workspace/
├── pubspec.yaml                        # Workspace configuration
├── Makefile                            # Build automation
├── packages/
│   └── gameframework/                  # Core framework
│       ├── lib/                        # Dart API
│       ├── android/                    # Android platform code
│       ├── ios/                        # iOS platform code
│       └── pubspec.yaml                # v0.0.1
├── engines/
│   ├── unity/
│   │   ├── dart/                       # Unity plugin package
│   │   └── plugin/                     # Unity C# scripts
│   └── unreal/
│       ├── dart/                       # Unreal plugin package
│       └── plugin/                     # Unreal C++ plugin
└── example/                            # Example application
    └── pubspec.yaml
```

## Quick Start

### Prerequisites

- Flutter SDK >= 3.3.0
- Dart SDK >= 3.6.0
- Unity 2022.3.x or Unreal Engine 5.x (depending on your needs)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/xraph/gameframework.git
cd gameframework
```

2. Bootstrap the workspace:
```bash
make bootstrap
```

This single command resolves all dependencies for all packages in the workspace.

### Using in Your Project

Add to your `pubspec.yaml`:

```yaml
dependencies:
  gameframework: ^0.0.2
  gameframework_unity: ^0.0.2  # If using Unity
  gameframework_stream: ^0.0.2  # If using asset streaming
  # gameframework_unreal: ^0.0.2  # If using Unreal (WIP)
```

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UnityEnginePlugin.initialize();
  runApp(MyApp());
}

class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        engineType: GameEngineType.unity,
        config: GameEngineConfig(
          runImmediately: true,
        ),
        onEngineCreated: (controller) {
          controller.sendMessage('GameManager', 'Start', 'level1');
        },
        onMessage: (message) {
          print('Message from engine: ${message.data}');
        },
      ),
    );
  }
}
```

## Development

### Workspace Commands

The Makefile provides comprehensive workspace management:

#### Setup & Dependencies
```bash
make bootstrap          # Resolve all workspace dependencies
make setup              # Alias for bootstrap
```

#### Testing
```bash
make test               # Run tests for all packages
make gameframework      # Test core package only
make unity              # Test Unity plugin only
make unreal             # Test Unreal plugin only
make test-package PKG=packages/gameframework  # Test specific package
```

#### Code Quality
```bash
make analyze            # Static analysis for all packages
make format             # Format all code
make format-check       # Check formatting without changes
make lint               # Run format check + analyze + test
```

#### Diagnostics
```bash
make doctor             # Check Flutter and dependencies
make list-packages      # List all workspace packages
make version            # Show versions of all packages
make coverage           # Generate coverage reports
```

#### Cleanup
```bash
make clean              # Clean all build artifacts
make clean-deep         # Deep clean (removes all generated files)
```

#### Package-Specific Development
```bash
# Work on gameframework package
cd packages/gameframework
flutter test
flutter analyze

# Work on Unity plugin
cd engines/unity/dart
flutter test
```

### Running the Example

```bash
make example            # Run example app
make build-android      # Build Android APK
make build-ios          # Build iOS (macOS only)
```

## Publishing

### Check Publish Readiness

```bash
make publish-check      # Validate all packages
```

### Publish Packages

Packages must be published in dependency order:

```bash
# Publish core framework first
make publish-gameframework

# Then publish engine plugins
make publish-unity
make publish-unreal

# Or publish all in order
make publish-all
```

## Architecture

### Core Package (gameframework)

The core package provides:
- `GameWidget` - Universal widget for all engines
- `GameEngineController` - Engine lifecycle and communication
- `GameEngineRegistry` - Engine plugin registration
- Platform-specific implementations for Android, iOS, macOS, Windows, Linux

### Engine Plugins

Each engine plugin (Unity, Unreal) implements:
- Engine-specific controller
- Platform view integration
- Bidirectional messaging
- Lifecycle management

### Communication Flow

```
Flutter App
    ↕ (MethodChannel)
GameWidget (gameframework)
    ↕ (Platform Interface)
Engine Plugin (gameframework_unity/unreal)
    ↕ (Native Bridge)
Game Engine (Unity/Unreal)
```

## 📊 Project Status & Roadmap

**Current Version:** 0.0.2

### ✅ Production Ready
- **Unity:** Android, iOS
- **Core Framework:** All platforms

### 🚧 Work in Progress
- **Unity:** Web, macOS, Windows, Linux
- **Unreal:** Android, iOS

### 📋 Roadmap
- Complete Unity desktop & web support
- Complete Unreal Engine mobile integration
- Unreal desktop & web support
- Advanced streaming features
- Performance optimization tools
- v1.0 Production release

## Platform Support

| Platform | gameframework | Unity | Unreal | Status |
|----------|--------------|-------|--------|--------|
| Android  | ✅ Ready     | ✅ Ready | 🚧 WIP | Stable |
| iOS      | ✅ Ready     | ✅ Ready | 🚧 WIP | Stable |
| Web      | ✅ Ready     | 🚧 WIP | ⏳ Planned | Beta   |
| macOS    | ✅ Ready     | 🚧 WIP | ⏳ Planned | Beta   |
| Windows  | ✅ Ready     | 🚧 WIP | ⏳ Planned | Beta   |
| Linux    | ✅ Ready     | 🚧 WIP | ⏳ Planned | Beta   |

## Continuous Integration

The Makefile includes CI-optimized commands:

```bash
make ci                 # Run all CI checks (format, analyze, test)
make check              # Run quality checks with coverage
```

Example GitHub Actions workflow:

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: make bootstrap
      - run: make ci
```

## Documentation

- **MONOREPO_MAKEFILE.md** - Comprehensive Makefile guide
- **QUICK_START.md** - Detailed quick start guide
- **packages/gameframework/README.md** - Core package documentation
- **engines/unity/dart/README.md** - Unity plugin documentation
- **engines/unreal/dart/README.md** - Unreal plugin documentation

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork and clone the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and add tests
4. Run quality checks: `make lint`
5. Commit changes: `git commit -m "Add my feature"`
6. Push to your fork: `git push origin feature/my-feature`
7. Open a Pull Request

### Code Standards

- Follow Dart style guide
- Maintain test coverage above 80%
- Add documentation for public APIs
- Run `make lint` before committing

## Versioning

All packages use semantic versioning (semver). Current versions:

- gameframework: 0.0.2
- gameframework_stream: 0.0.2
- gameframework_unity: 0.0.2
- gameframework_unreal: 0.0.2

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/xraph/gameframework/issues)
- **Discussions**: [GitHub Discussions](https://github.com/xraph/gameframework/discussions)
- **Documentation**: [docs.gameframework.dev](https://docs.gameframework.dev)

## Acknowledgments

- Flutter team for the excellent framework
- Unity Technologies and Epic Games for their game engines
- Contributors and community members

---

**Note**: This is a monorepo managed with Dart workspaces. All packages share dependencies and can be developed together. Use the provided Makefile commands for workspace operations.
