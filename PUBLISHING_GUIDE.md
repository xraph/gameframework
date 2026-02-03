# Publishing Guide to pub.dev

This guide covers the steps to publish the Flutter Game Framework packages to pub.dev.

## Overview

The Flutter Game Framework consists of two packages:
1. **gameframework** - Core framework package
2. **gameframework_unity** - Unity engine plugin package

Both packages need to be published to pub.dev for public use.

---

## Pre-Publishing Checklist

### Package Validation Status

**gameframework (Core Package):**
- ✅ Package metadata complete
- ✅ LICENSE file (MIT)
- ✅ CHANGELOG.md updated
- ✅ README.md with badges
- ✅ Pub.dev dry-run passed (0 warnings)
- ✅ All tests passing (39/39)
- ✅ Static analysis clean
- ✅ Example project included
- ✅ Version: 0.4.0

**gameframework_unity (Unity Plugin):**
- ✅ Package metadata complete
- ✅ LICENSE file (MIT)
- ✅ CHANGELOG.md created
- ✅ README.md updated
- ✅ Documentation complete
- ⚠️ Dependency on gameframework (needs core published first)
- ✅ Version: 0.4.0

---

## Publishing Order

**IMPORTANT:** Packages must be published in this order:

1. **First:** Publish `gameframework` (core package)
2. **Second:** Update `gameframework_unity` to use hosted dependency
3. **Third:** Publish `gameframework_unity`

---

## Step 1: Publish Core Package (gameframework)

### 1.1 Pre-publish Verification

```bash
cd /Users/rexraphael/Work/xraph/gameframework

# Run tests
flutter test

# Run static analysis
flutter analyze

# Run dry-run
flutter pub publish --dry-run
```

Expected result: **0 warnings, 0 errors**

### 1.2 Publish to pub.dev

```bash
# Publish the package
flutter pub publish
```

You will be prompted to:
1. Confirm the package contents
2. Authenticate with Google account
3. Confirm the upload

### 1.3 Verify Publication

Visit: https://pub.dev/packages/gameframework

Check:
- ✅ Package appears on pub.dev
- ✅ Version 0.4.0 is live
- ✅ Documentation renders correctly
- ✅ Example code displays properly
- ✅ Badges show correct information

---

## Step 2: Update Unity Plugin Dependencies

### 2.1 Update pubspec.yaml

Edit: `engines/unity/dart/pubspec.yaml`

**Change from:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  gameframework:
    path: ../../../
```

**Change to:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  gameframework: ^0.4.0
```

### 2.2 Update Dependencies

```bash
cd engines/unity/dart
flutter pub get
```

### 2.3 Verify Tests Still Pass

```bash
# From project root
flutter test

# Verify everything still works
flutter analyze
```

---

## Step 3: Publish Unity Plugin (gameframework_unity)

### 3.1 Pre-publish Verification

```bash
cd /Users/rexraphael/Work/xraph/gameframework/engines/unity/dart

# Run dry-run
flutter pub publish --dry-run
```

Expected result: **0 warnings, 0 errors**

### 3.2 Publish to pub.dev

```bash
# Publish the package
flutter pub publish
```

### 3.3 Verify Publication

Visit: https://pub.dev/packages/gameframework_unity

Check:
- ✅ Package appears on pub.dev
- ✅ Version 0.4.0 is live
- ✅ Documentation renders correctly
- ✅ Depends on gameframework ^0.4.0

---

## Post-Publishing Tasks

### Update README.md Installation Instructions

The README already includes pub.dev installation instructions:

```yaml
dependencies:
  gameframework: ^0.4.0
  gameframework_unity: ^0.4.0
```

### Update Documentation Links

Verify all documentation links work:
- Main README
- Quick Start Guide
- Unity Plugin Guide
- API Documentation

### Create GitHub Release

1. Create a git tag:
   ```bash
   git tag -a v0.4.0 -m "Release v0.4.0 - Unity Integration Complete"
   git push origin v0.4.0
   ```

2. Create GitHub release:
   - Go to: https://github.com/xraph/gameframework/releases/new
   - Tag: v0.4.0
   - Title: "v0.4.0 - Production-Ready Unity Integration"
   - Description: Use content from CHANGELOG.md

### Announce Release

Consider announcing on:
- Flutter community forums
- Reddit (r/FlutterDev)
- Twitter/X
- LinkedIn
- Discord/Slack communities

---

## Package Scores

After publishing, monitor pub.dev scores:

### Target Scores
- **Pub Points:** 130/130 (aim for 100+)
- **Popularity:** Will grow over time
- **Likes:** User engagement metric

### Improving Scores

**For high pub points:**
- ✅ Follow Dart conventions
- ✅ Comprehensive documentation
- ✅ Complete example
- ✅ All platforms supported
- ✅ CI/CD setup (future)

---

## Continuous Maintenance

### Regular Updates

1. **Bug Fixes:** Patch versions (0.4.1, 0.4.2)
2. **New Features:** Minor versions (0.5.0, 0.6.0)
3. **Breaking Changes:** Major versions (1.0.0, 2.0.0)

### Version Strategy

Follow Semantic Versioning (semver):
- **PATCH** (0.4.x): Bug fixes, no API changes
- **MINOR** (0.x.0): New features, backward compatible
- **MAJOR** (x.0.0): Breaking changes

### Publishing Workflow

For each release:
1. Update CHANGELOG.md
2. Update version in pubspec.yaml
3. Run all tests
4. Run `flutter pub publish --dry-run`
5. Publish: `flutter pub publish`
6. Create git tag
7. Create GitHub release

---

## Troubleshooting

### "Package already exists"

If version already published:
- Increment version number
- Update CHANGELOG.md
- Republish

### "Invalid dependency"

Ensure:
- All dependencies use hosted sources (pub.dev)
- No path dependencies in published package
- Version constraints are correct

### "Documentation not rendering"

Check:
- Markdown syntax is correct
- Links use relative paths
- Images are included in package

### "Low pub points"

Improve:
- Add more documentation
- Follow Dart style guide
- Include comprehensive example
- Add more tests

---

## Current Package Status

### gameframework (Core)

**Status:** Ready for publication ✅

**Dry-run Results:**
```
Package has 0 warnings.
Total compressed archive size: 373 KB
```

**Key Metrics:**
- 39/39 tests passing
- 0 static analysis issues
- Complete documentation
- Production-ready

### gameframework_unity (Unity Plugin)

**Status:** Ready after core published ⚠️

**Requirements:**
- Core package must be published first
- Update dependency to `gameframework: ^0.4.0`
- Re-run dry-run validation

**Key Features:**
- Unity Android/iOS integration
- WebGL support
- AR Foundation tools
- Performance monitoring

---

## Next Steps

1. **Publish Core Package:**
   ```bash
   cd /Users/rexraphael/Work/xraph/gameframework
   flutter pub publish
   ```

2. **Update Unity Plugin:**
   ```bash
   # Edit engines/unity/dart/pubspec.yaml
   # Change path dependency to: gameframework: ^0.4.0
   ```

3. **Publish Unity Plugin:**
   ```bash
   cd engines/unity/dart
   flutter pub publish
   ```

4. **Create GitHub Release:**
   ```bash
   git tag -a v0.4.0 -m "Release v0.4.0"
   git push origin v0.4.0
   ```

5. **Monitor and Maintain:**
   - Watch for issues on GitHub
   - Respond to pub.dev reviews
   - Plan future updates

---

## Additional Resources

### Pub.dev Documentation
- [Publishing Packages](https://dart.dev/tools/pub/publishing)
- [Package Layout Conventions](https://dart.dev/tools/pub/package-layout)
- [Versioning](https://dart.dev/tools/pub/versioning)

### Flutter Documentation
- [Developing Packages](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [Publishing Packages](https://docs.flutter.dev/development/packages-and-plugins/developing-packages#publish)

### Best Practices
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Package Best Practices](https://dart.dev/guides/libraries/create-library-packages)

---

## Contact & Support

- **Repository:** https://github.com/xraph/gameframework
- **Issues:** https://github.com/xraph/gameframework/issues
- **Discussions:** https://github.com/xraph/gameframework/discussions

---

**Last Updated:** 2024-10-27
**Version:** 0.4.0
**Status:** Ready for Publication
