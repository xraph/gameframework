# Monorepo Makefile Guide

**Last Updated:** 2026-01-31

## Overview

The Flutter Game Framework has been converted to a Dart workspace monorepo. The Makefile provides comprehensive workspace management commands for building, testing, and publishing all packages.

## Monorepo Structure

```
gameframework/
├── pubspec.yaml                    # Workspace configuration
├── Makefile                        # Monorepo build automation
├── packages/
│   └── gameframework/             # Core framework package
│       └── pubspec.yaml           # gameframework@0.0.1
├── engines/
│   ├── unity/
│   │   └── dart/                  # Unity engine plugin
│   │       └── pubspec.yaml       # gameframework_unity@0.0.1
│   └── unreal/
│       └── dart/                  # Unreal engine plugin
│           └── pubspec.yaml       # gameframework_unreal@0.0.1
└── example/                       # Example Flutter app
    └── pubspec.yaml               # gameframework_example
```

## Workspace Packages

The workspace includes 4 packages:
1. **gameframework** - Core framework package (`packages/gameframework`)
2. **gameframework_unity** - Unity engine plugin (`engines/unity/dart`)
3. **gameframework_unreal** - Unreal engine plugin (`engines/unreal/dart`)
4. **gameframework_example** - Example app (`example`)

## Key Makefile Changes

### 1. Workspace Variables
```makefile
PACKAGES := packages/gameframework engines/unity/dart engines/unreal/dart
EXAMPLE := example
```

### 2. Bootstrap Command
- **New**: `make bootstrap` - Resolves dependencies for all workspace packages
- Uses `flutter pub get` which resolves the entire workspace in one command
- Replaces multiple `pub get` commands with single workspace command
- `make setup` is now an alias for `make bootstrap`

### 3. Workspace-Wide Operations
All commands now operate across the entire workspace:
- `make test` - Tests all packages
- `make analyze` - Analyzes all packages
- `make clean` - Cleans all packages
- `make lint` - Lints all packages

### 4. Package-Specific Commands
New shortcuts for testing individual packages:
- `make gameframework` - Test core framework only
- `make unity` - Test Unity plugin only
- `make unreal` - Test Unreal plugin only

### 5. New Commands

#### **list-packages**
```bash
make list-packages
```
Lists all packages in the workspace with their names and versions.

#### **test-package**
```bash
make test-package PKG=packages/gameframework
make test-package PKG=engines/unity/dart
```
Run tests for a specific package.

#### **clean-deep**
```bash
make clean-deep
```
Deep clean that removes all `pubspec.lock`, `.dart_tool`, and `build` directories.

#### **version**
```bash
make version
```
Shows versions of all publishable packages.

#### **publish-check**
```bash
make publish-check
```
Checks if all packages are ready to publish.

#### **publish-* commands**
```bash
make publish-gameframework  # Publish core framework
make publish-unity          # Publish Unity plugin
make publish-unreal         # Publish Unreal plugin
make publish-all            # Publish all in order
```

## Usage Examples

### Initial Setup
```bash
# Clone repository
git clone https://github.com/xraph/gameframework.git
cd gameframework

# Bootstrap workspace (download all dependencies)
make bootstrap
# or
make setup
```

### Development Workflow
```bash
# Run all tests across workspace
make test

# Test specific package
make test-package PKG=packages/gameframework
# or use shortcuts
make gameframework
make unity
make unreal

# Analyze all packages
make analyze

# Format all code
make format

# Check code formatting
make format-check

# Run all linting checks
make lint
```

### Package Management
```bash
# List all packages in workspace
make list-packages

# Show versions of all packages
make version

# Check dependencies status
make doctor
```

### Cleaning
```bash
# Clean all build artifacts
make clean

# Deep clean (removes all generated files)
make clean-deep
```

### Testing & Quality
```bash
# Run tests in watch mode
make test-watch

# Generate coverage report for all packages
make coverage

# Run pre-build checks
make prebuild
```

### Example App
```bash
# Run example app
make example

# Build Android APK
make build-android

# Build iOS (macOS only)
make build-ios
```

### Publishing Workflow
```bash
# 1. Check if all packages are ready
make publish-check

# 2. Publish core framework first
make publish-gameframework

# 3. Publish engine plugins (order matters - they depend on core)
make publish-unity
make publish-unreal

# Or publish all at once (in correct order)
make publish-all
```

### CI/CD
```bash
# Run all CI checks
make ci

# Run all quality checks
make check

# Run everything (bootstrap + test + analyze)
make all
```

## Command Reference

### Setup & Installation
| Command | Description |
|---------|-------------|
| `make bootstrap` | Bootstrap workspace (resolve all package dependencies) |
| `make setup` | Alias for bootstrap |

### Development
| Command | Description |
|---------|-------------|
| `make test` | Run all tests across workspace packages |
| `make test-package PKG=<path>` | Run tests for specific package |
| `make test-watch` | Run tests in watch mode |
| `make analyze` | Run static analysis across workspace |
| `make format` | Format all code |
| `make format-check` | Check code formatting without modifying |
| `make lint` | Run all linting checks across workspace |
| `make prebuild` | Run all pre-build checks |

### Cleanup
| Command | Description |
|---------|-------------|
| `make clean` | Clean all build artifacts across workspace |
| `make clean-deep` | Deep clean (includes pub cache and generated files) |

### Diagnostics
| Command | Description |
|---------|-------------|
| `make doctor` | Run Flutter doctor and check dependencies |
| `make list-packages` | List all packages in workspace |
| `make coverage` | Generate test coverage report for all packages |

### Example App
| Command | Description |
|---------|-------------|
| `make example` | Run example app |
| `make build-android` | Build example for Android |
| `make build-ios` | Build example for iOS (macOS only) |

### Release
| Command | Description |
|---------|-------------|
| `make version` | Show versions of all packages |
| `make publish-check` | Check if all packages are ready to publish |
| `make publish-gameframework` | Publish gameframework package to pub.dev |
| `make publish-unity` | Publish gameframework_unity package to pub.dev |
| `make publish-unreal` | Publish gameframework_unreal package to pub.dev |
| `make publish-all` | Publish all packages to pub.dev (in order) |

### Package-Specific
| Command | Description |
|---------|-------------|
| `make gameframework` | Run tests for gameframework package only |
| `make unity` | Run tests for gameframework_unity package only |
| `make unreal` | Run tests for gameframework_unreal package only |

### All-in-one
| Command | Description |
|---------|-------------|
| `make all` | Bootstrap and run all checks |
| `make check` | Run all quality checks |
| `make ci` | Continuous Integration checks |

## Benefits of Monorepo + Makefile

### 1. Simplified Dependency Management
- Single `dart pub get` command resolves all workspace dependencies
- Automatic local package resolution
- No need for `path:` dependencies or manual linking

### 2. Consistent Versioning
- Easy to see all package versions at once
- Update versions across packages consistently
- Track dependencies between workspace packages

### 3. Efficient Development
- Test all packages with one command
- Analyze entire codebase at once
- Format all code consistently
- No need to `cd` between packages

### 4. Better CI/CD
- Single command for full test suite
- Workspace-aware linting and analysis
- Simplified build pipelines
- Faster CI runs (shared dependency cache)

### 5. Publishing Control
- Publish packages in correct order (dependencies first)
- Pre-publish validation across workspace
- Atomic publishing workflow

## Migration from Old Structure

### Before (Separate Packages)
```bash
# Setup
cd packages/gameframework && flutter pub get
cd ../engines/unity/dart && flutter pub get
cd ../engines/unreal/dart && flutter pub get
cd ../example && flutter pub get

# Test
cd packages/gameframework && flutter test
cd ../engines/unity/dart && flutter test
cd ../engines/unreal/dart && flutter test
```

### After (Monorepo)
```bash
# Setup
make bootstrap

# Test
make test
```

## Troubleshooting

### "Package not found" errors
```bash
# Re-bootstrap workspace
make clean-deep
make bootstrap
```

### "Version conflict" errors
```bash
# Check which packages have conflicts
make doctor

# Update dependencies
dart pub upgrade
```

### Test failures in specific package
```bash
# Test individual package
make test-package PKG=packages/gameframework

# Or use shortcut
make gameframework
```

### Workspace resolution issues
```bash
# Verify workspace configuration
cat pubspec.yaml

# Ensure all packages have resolution: workspace
grep "resolution: workspace" packages/*/pubspec.yaml
grep "resolution: workspace" engines/*/dart/pubspec.yaml
```

## Best Practices

### 1. Always Bootstrap After Git Operations
```bash
git pull
make bootstrap
```

### 2. Run Checks Before Committing
```bash
make lint
make test
```

### 3. Use Package-Specific Commands During Development
```bash
# When working on Unity plugin
make unity  # Faster than testing everything
```

### 4. Deep Clean When Switching Branches
```bash
git checkout feature-branch
make clean-deep
make bootstrap
```

### 5. Publish in Correct Order
```bash
# Always publish core framework first, then plugins
make publish-gameframework
make publish-unity
make publish-unreal
```

## References

- [Dart Workspaces Documentation](https://dart.dev/tools/pub/workspaces)
- [Flutter Monorepo Best Practices](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [Makefile Documentation](https://www.gnu.org/software/make/manual/make.html)

## Support

For issues or questions:
- GitHub Issues: https://github.com/xraph/gameframework/issues
- Discussions: https://github.com/xraph/gameframework/discussions
