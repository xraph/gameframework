# Contributing to GameFramework

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the GameFramework.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive experience for everyone. We expect all contributors to:

- Use welcoming and inclusive language
- Be respectful of differing viewpoints
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other community members

### Reporting Issues

If you experience or witness unacceptable behavior, please report it by opening an issue.

---

## Getting Started

### Ways to Contribute

- 🐛 **Bug Reports** - Found a bug? Let us know!
- ✨ **Feature Requests** - Have an idea? Share it!
- 📝 **Documentation** - Improve our docs
- 🧪 **Testing** - Help test on different platforms
- 💻 **Code** - Submit bug fixes or new features
- 🎮 **Engine Integration** - Add support for new game engines

### Before You Start

1. **Check existing issues** - Someone might already be working on it
2. **Discuss major changes** - Open an issue first for large features
3. **Read the documentation** - Familiarize yourself with the architecture

---

## Development Setup

### Prerequisites

- **Flutter:** 3.10.0 or higher
- **Dart:** 3.0.0 or higher
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)
- **Unity:** 2022.3.x or 2023.1.x (for Unity plugin work)

### Clone and Setup

```bash
# Clone the repository
git clone https://github.com/xraph/gameframework.git
cd gameframework

# Install dependencies
flutter pub get

# Run tests to ensure everything works
flutter test

# Run static analysis
flutter analyze
```

### Example App Setup

```bash
cd example
flutter pub get
flutter run
```

---

## Project Structure

```
gameframework/
├── lib/                      # Core Dart framework
│   ├── src/
│   │   ├── core/            # Core classes (Widget, Controller, Registry)
│   │   ├── models/          # Data models
│   │   ├── exceptions/      # Exception classes
│   │   └── utils/           # Utility classes
│   └── gameframework.dart   # Main export file
├── android/                  # Android native bridge
├── ios/                      # iOS native bridge
├── engines/                  # Engine-specific plugins
│   └── unity/               # Unity plugin
│       ├── dart/            # Dart plugin code
│       ├── android/         # Android native
│       ├── ios/             # iOS native
│       └── plugin/          # Unity C# scripts
├── example/                  # Example application
├── test/                     # Unit tests
└── docs-files/              # Design documentation
```

See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for detailed information.

---

## Contributing Guidelines

### Issue Guidelines

#### Bug Reports

When reporting bugs, include:

```markdown
**Description:** Brief description of the bug

**Steps to Reproduce:**
1. Step one
2. Step two
3. ...

**Expected Behavior:** What should happen

**Actual Behavior:** What actually happens

**Environment:**
- Flutter version:
- Dart version:
- Platform: Android/iOS/Web
- Device/Emulator:
- Framework version:

**Additional Context:** Screenshots, logs, etc.
```

#### Feature Requests

When requesting features, include:

```markdown
**Problem:** What problem does this solve?

**Proposed Solution:** Your suggested approach

**Alternatives Considered:** Other options you thought about

**Use Case:** Real-world scenario where this is needed

**Additional Context:** Mockups, examples, etc.
```

---

## Pull Request Process

### 1. Fork and Branch

```bash
# Fork the repo on GitHub, then:
git clone https://github.com/YOUR_USERNAME/gameframework.git
cd gameframework

# Create a feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 2. Make Your Changes

- Write clean, readable code
- Follow the coding standards (see below)
- Add tests for new features
- Update documentation as needed

### 3. Test Your Changes

```bash
# Run tests
flutter test

# Run static analysis
flutter analyze

# Format code
dart format .

# Test on actual devices if possible
flutter run
```

### 4. Commit Your Changes

Use clear, descriptive commit messages:

```bash
# Good commit messages:
git commit -m "feat: Add WebGL support for Unity plugin"
git commit -m "fix: Resolve memory leak in Android controller"
git commit -m "docs: Update Unity integration guide"
git commit -m "test: Add tests for GameEngineMessage"

# Bad commit messages:
git commit -m "fixed stuff"
git commit -m "update"
git commit -m "wip"
```

**Commit Message Format:**
```
type(scope): subject

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `style`: Code style changes (formatting)
- `perf`: Performance improvements
- `chore`: Build process or tooling changes

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub with:

- **Clear title** describing the change
- **Description** explaining what and why
- **Reference issues** (e.g., "Closes #123")
- **Screenshots** (for UI changes)
- **Testing done** (devices, platforms tested)

### 6. Code Review

- Respond to review comments
- Make requested changes
- Push updates to the same branch

---

## Coding Standards

### Dart Code Style

Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines:

```dart
// ✅ Good
class GameEngineController {
  /// Creates a game engine controller.
  ///
  /// The [engineType] must not be null.
  GameEngineController({
    required this.engineType,
    this.config = const GameEngineConfig(),
  });

  final GameEngineType engineType;
  final GameEngineConfig config;

  /// Sends a message to the game engine.
  Future<void> sendMessage(String target, String method, String data) async {
    // Implementation
  }
}

// ❌ Bad
class game_engine_controller {
  game_engine_controller(this.engineType, [this.config]);
  var engineType;
  var config;
  Future sendMessage(target, method, data) async {
    // Implementation
  }
}
```

### Kotlin Code Style

```kotlin
// ✅ Good
class UnityEngineController(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger
) : GameEngineController(context, viewId, messenger) {

    private var unityPlayer: UnityPlayer? = null

    override fun createEngine() {
        runOnMainThread {
            unityPlayer = UnityPlayer(context)
            attachEngineView()
        }
    }
}

// ❌ Bad
class UnityEngineController(context:Context,viewId:Int,messenger:BinaryMessenger):GameEngineController(context,viewId,messenger){
    var unityPlayer:UnityPlayer?=null
    override fun createEngine(){
        runOnMainThread{unityPlayer=UnityPlayer(context);attachEngineView()}
    }
}
```

### Swift Code Style

```swift
// ✅ Good
public class UnityEngineController: GameEngineController {
    private var unityFramework: UnityFramework?

    public override func createEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.unityFramework = self.loadUnityFramework()
        }
    }
}

// ❌ Bad
public class UnityEngineController: GameEngineController {
    var unityFramework: UnityFramework?
    public override func createEngine() {
        DispatchQueue.main.async {
            self.unityFramework = self.loadUnityFramework()
        }
    }
}
```

### Documentation Comments

All public APIs must have documentation:

```dart
/// A unified widget for embedding game engines in Flutter.
///
/// This widget provides a common interface for displaying game engines
/// like Unity and Unreal Engine within a Flutter application.
///
/// Example:
/// ```dart
/// GameWidget(
///   engineType: GameEngineType.unity,
///   onEngineCreated: (controller) {
///     controller.sendMessage('GameManager', 'Start', 'level1');
///   },
/// )
/// ```
class GameWidget extends StatefulWidget {
  // ...
}
```

---

## Testing Guidelines

### Test Requirements

- **All new features must have tests**
- **Bug fixes should include regression tests**
- **Maintain 90%+ coverage for core code**

### Writing Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework/gameframework.dart';

void main() {
  group('GameEngineConfig', () {
    test('should create with default values', () {
      // Arrange & Act
      const config = GameEngineConfig();

      // Assert
      expect(config.fullscreen, false);
      expect(config.runImmediately, false);
    });

    test('should serialize to map correctly', () {
      // Arrange
      const config = GameEngineConfig(fullscreen: true);

      // Act
      final map = config.toMap();

      // Assert
      expect(map['fullscreen'], true);
    });
  });
}
```

See [TESTING.md](TESTING.md) for more details.

---

## Documentation

### Types of Documentation

1. **Code Comments** - Explain complex logic
2. **API Documentation** - Document all public APIs
3. **README Files** - Guide users and developers
4. **Example Code** - Show usage patterns
5. **Architecture Docs** - Explain design decisions

### Documentation Standards

- Use clear, concise language
- Provide code examples
- Include screenshots for UI features
- Update docs when changing APIs
- Keep examples up-to-date

---

## Engine Plugin Development

### Adding a New Engine

1. **Create plugin structure:**
   ```
   engines/your-engine/
   ├── dart/                 # Dart plugin
   ├── android/             # Android native
   ├── ios/                 # iOS native
   └── plugin/              # Engine-specific scripts
   ```

2. **Implement required interfaces:**
   - `GameEngineController` (Dart)
   - `GameEngineFactory` (Dart)
   - Native controllers (Android/iOS)

3. **Add tests and documentation**

4. **Create example integration**

See existing Unity plugin for reference.

---

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **Major (1.0.0):** Breaking changes
- **Minor (0.1.0):** New features (backward compatible)
- **Patch (0.0.1):** Bug fixes

### Release Checklist

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in pubspec.yaml
- [ ] Example app tested
- [ ] Performance tested
- [ ] Create release tag
- [ ] Publish to pub.dev (when ready)

---

## Getting Help

### Resources

- **Documentation:** See [docs-files/](docs-files/)
- **Examples:** Check [example/](example/)
- **Issues:** [GitHub Issues](https://github.com/xraph/gameframework/issues)
- **Discussions:** [GitHub Discussions](https://github.com/xraph/gameframework/discussions)

### Questions?

- Open a discussion on GitHub
- Check existing issues and PRs
- Review the documentation

---

## Recognition

Contributors will be:

- Listed in CONTRIBUTORS.md
- Credited in release notes
- Mentioned in the README (for significant contributions)

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to GameFramework!** 🎮✨

Every contribution, no matter how small, helps make this project better for everyone.
