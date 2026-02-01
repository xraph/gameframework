# Release Workflow Guide

This document explains how to use the automated CI/CD pipeline for publishing packages to pub.dev.

## Overview

The repository contains three Flutter packages that are published to pub.dev:

1. **gameframework** - Core framework (must be published first)
2. **gameframework_unity** - Unity engine integration
3. **gameframework_unreal** - Unreal Engine integration

The CI/CD workflow automatically handles dependency ordering and publishes all packages when a version tag is pushed.

## Prerequisites

### 1. Setup pub.dev Credentials

Before you can publish packages, you need to configure pub.dev credentials in GitHub Secrets:

1. **Generate pub.dev credentials**:
   ```bash
   # Run this command locally to generate credentials
   dart pub token add https://pub.dev
   ```
   This will open a browser window for authentication.

2. **Extract credentials**:
   ```bash
   # On macOS/Linux
   cat ~/.pub-cache/credentials.json
   
   # On Windows
   type %APPDATA%\Pub\Cache\credentials.json
   ```

3. **Add to GitHub Secrets**:
   - Go to your GitHub repository
   - Navigate to Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `PUB_CREDENTIALS`
   - Value: Paste the entire contents of `credentials.json`
   - Click "Add secret"

### 2. Verify Package Configuration

Ensure all packages have correct metadata in their `pubspec.yaml`:

```yaml
name: package_name
description: Clear description under 180 characters
version: 0.0.1
homepage: https://github.com/xraph/gameframework
repository: https://github.com/xraph/gameframework
issue_tracker: https://github.com/xraph/gameframework/issues
```

## Release Process

### Automated Release (Recommended)

1. **Update Version Numbers**

   Update versions in all relevant packages:
   
   ```bash
   # packages/gameframework/pubspec.yaml
   version: 0.0.2
   
   # engines/unity/dart/pubspec.yaml
   version: 0.0.2
   gameframework: 0.0.2
   
   # engines/unreal/dart/pubspec.yaml
   version: 0.0.2
   gameframework: 0.0.2
   ```

2. **Update CHANGELOG.md**

   Add release notes:
   
   ```markdown
   ## [0.0.2] - 2026-01-31
   
   ### Added
   - New feature X
   - New feature Y
   
   ### Fixed
   - Bug fix A
   - Bug fix B
   
   ### Changed
   - Improvement C
   ```

3. **Commit and Tag**

   ```bash
   git add .
   git commit -m "chore: release v0.0.2"
   git tag v0.0.2
   git push origin main --tags
   ```

4. **Automatic Publishing**

   The workflow will automatically:
   - ✅ Validate all packages
   - ✅ Run tests
   - ✅ Publish `gameframework` first
   - ✅ Wait for availability on pub.dev
   - ✅ Publish `gameframework_unity` and `gameframework_unreal` in parallel
   - ✅ Create a GitHub Release with changelog

### Manual Release

You can manually trigger releases from GitHub Actions:

1. Go to **Actions** → **Publish to pub.dev**
2. Click **Run workflow**
3. Select options:
   - **Package**: Choose which package(s) to publish
   - **Dry run**: Enable to validate without publishing

### Dry Run (Testing)

To test the publish process without actually publishing:

```bash
# Test locally
cd packages/gameframework
dart pub publish --dry-run

cd ../../engines/unity/dart
dart pub publish --dry-run

cd ../../../engines/unreal/dart
dart pub publish --dry-run
```

Or use the manual workflow with "dry_run" enabled.

## Workflow Details

### CI Workflow (`ci.yml`)

Runs on every push and pull request to `main` or `develop`:

- ✅ Tests on Linux, macOS, and Windows
- ✅ Code analysis (`flutter analyze`)
- ✅ Code formatting check (`dart format`)
- ✅ Test coverage upload to Codecov
- ✅ Validates pub.dev requirements (`dart pub publish --dry-run`)
- ✅ Checks version consistency between packages

### Publish Workflow (`publish.yml`)

Triggers on:
- **Version tags** (e.g., `v0.0.1`, `v1.2.3`)
- **Manual dispatch** (via GitHub Actions UI)

Steps:
1. **Validate** - Run tests and analysis on all packages
2. **Publish gameframework** - Core package must be published first
3. **Publish engine plugins** - Unity and Unreal plugins published in parallel
4. **Create Release** - GitHub release with changelog

## Version Management

### Semantic Versioning

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 1.2.3)
  - **MAJOR**: Breaking changes
  - **MINOR**: New features (backwards compatible)
  - **PATCH**: Bug fixes (backwards compatible)

### Pre-release Versions

For beta/alpha releases:

```yaml
version: 1.0.0-beta.1
version: 1.0.0-alpha.2
```

The workflow will automatically mark these as pre-releases on GitHub.

### Version Dependency Rules

When releasing all packages together:

1. **Unity and Unreal plugins** must depend on the **same version** of `gameframework` being released
2. All packages should typically use the **same version number** for major releases
3. Patch releases can be independent if only one package is updated

Example for version 1.0.0:

```yaml
# packages/gameframework/pubspec.yaml
version: 1.0.0

# engines/unity/dart/pubspec.yaml
version: 1.0.0
dependencies:
  gameframework: 1.0.0  # Must match!

# engines/unreal/dart/pubspec.yaml
version: 1.0.0
dependencies:
  gameframework: 1.0.0  # Must match!
```

## Troubleshooting

### Publication Failed

If publication fails, check:

1. **Credentials**: Ensure `PUB_CREDENTIALS` secret is correctly set
2. **Version**: Ensure version is incremented (can't republish same version)
3. **Tests**: Ensure all tests pass
4. **Validation**: Run `dart pub publish --dry-run` locally

### Dependency Resolution

If engine plugins fail to resolve `gameframework` dependency:

1. Wait 1-2 minutes after publishing `gameframework`
2. Verify `gameframework` is live on pub.dev
3. The workflow has a 60-second wait built-in, but sometimes needs longer

### Version Mismatch

If the CI workflow reports version mismatches:

1. Ensure Unity and Unreal `pubspec.yaml` files reference the correct `gameframework` version
2. Update dependency versions to match the package being released

## Security Notes

- ⚠️ **Never commit credentials** to the repository
- ✅ Always use GitHub Secrets for `PUB_CREDENTIALS`
- 🔒 Credentials should have minimal scope (only pub.dev publishing)
- 🔄 Rotate credentials periodically (annually recommended)

## GitHub Actions Permissions

The workflows require these permissions:

- `contents: write` - For creating releases and tags
- `actions: read` - For reading workflow status
- Standard `GITHUB_TOKEN` permissions for releases

## Support

For issues with the release workflow:

1. Check [GitHub Actions logs](../../actions)
2. Verify [pub.dev package status](https://pub.dev/packages)
3. Review [pub.dev publishing documentation](https://dart.dev/tools/pub/publishing)
4. Open an issue in this repository

## Useful Commands

```bash
# Check current versions
make version-check

# Run all tests
make test

# Validate all packages
make validate

# Dry-run publish
make publish-dry-run

# Get dependencies for all packages
flutter pub get -C packages/gameframework
flutter pub get -C engines/unity/dart
flutter pub get -C engines/unreal/dart
```
