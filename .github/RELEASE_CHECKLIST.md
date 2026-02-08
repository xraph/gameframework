# Release Checklist

Use this checklist when preparing a new release of GameFramework.

## Pre-Release

### 1. Version Planning

- [ ] Determine version number following [Semantic Versioning](https://semver.org/)
  - **MAJOR**: Breaking changes
  - **MINOR**: New features (backwards compatible)
  - **PATCH**: Bug fixes (backwards compatible)
- [ ] Check if this release includes breaking changes
- [ ] Review milestone/project board for included issues

### 2. Code Quality

```bash
# Run full quality checks
make ci
```

- [ ] All tests pass (`make test`)
- [ ] Code analysis passes (`make analyze`)
- [ ] Code formatting correct (`make format-check`)
- [ ] No linter warnings or errors

### 3. Version Updates

```bash
# Update all package versions
make version-bump VERSION=X.Y.Z
```

- [ ] Update `packages/gameframework/pubspec.yaml` version
- [ ] Update `engines/unity/dart/pubspec.yaml` version
- [ ] Update `engines/unreal/dart/pubspec.yaml` version
- [ ] Update dependency versions (Unity/Unreal → gameframework)
- [ ] Verify version consistency (`make version-check`)

### 4. Documentation

- [ ] Update `CHANGELOG.md` with release notes
  - Added features
  - Fixed bugs
  - Breaking changes
  - Deprecated features
  - Migration guide (if breaking changes)
- [ ] Update `README.md` if needed
- [ ] Update API documentation
- [ ] Update example app if needed
- [ ] Review all documentation for accuracy

### 5. Testing

- [ ] Run tests on all platforms
  - [ ] Android
  - [ ] iOS
  - [ ] macOS
  - [ ] Windows
  - [ ] Linux
- [ ] Test example app
- [ ] Test Unity integration
- [ ] Test Unreal integration
- [ ] Test WebGL builds (if Unity)
- [ ] Test AR Foundation (if Unity)

### 6. Validation

```bash
# Validate packages for pub.dev
make publish-dry-run
```

- [ ] All packages pass dry-run validation
- [ ] No warnings or errors
- [ ] Package scores look good (pub.dev analysis)
- [ ] Dependencies are correct

### 7. Final Review

- [ ] Review all commits since last release
- [ ] Ensure no sensitive data in commits
- [ ] Check for any TODO or FIXME comments
- [ ] Review breaking changes documentation
- [ ] Verify migration guide is complete

## Release

### 8. Commit and Tag

```bash
# Commit version changes
git add .
git commit -m "chore: release vX.Y.Z"

# Run final checks
make release-prepare

# Create tag
make release-tag VERSION=X.Y.Z
```

- [ ] Commit message follows convention
- [ ] All changes committed
- [ ] Tag created successfully

### 9. Push and Publish

```bash
# Push to trigger release
git push origin main --tags
```

- [ ] Push commits to main branch
- [ ] Push tags to trigger GitHub Actions
- [ ] Monitor GitHub Actions workflow
- [ ] Verify packages published to pub.dev
  - [ ] [gameframework](https://pub.dev/packages/gameframework)
  - [ ] [gameframework_unity](https://pub.dev/packages/gameframework_unity)
  - [ ] [gameframework_unreal](https://pub.dev/packages/gameframework_unreal)

### 10. GitHub Release

- [ ] GitHub release created automatically
- [ ] Release notes are correct
- [ ] Changelog included
- [ ] Assets attached (if any)
- [ ] Release marked as pre-release (if applicable)

## Post-Release

### 11. Verification

- [ ] All packages available on pub.dev
- [ ] Package versions correct
- [ ] Dependencies resolve correctly
- [ ] Download and test packages from pub.dev
- [ ] Check pub.dev package scores

### 12. Communication

- [ ] Announce release on GitHub Discussions
- [ ] Update documentation site (if applicable)
- [ ] Notify community channels
- [ ] Post on social media (if applicable)
- [ ] Update examples/tutorials

### 13. Monitoring

- [ ] Monitor for immediate issues
- [ ] Check GitHub issues for reports
- [ ] Monitor pub.dev downloads
- [ ] Review package health metrics

### 14. Cleanup

- [ ] Close completed milestone
- [ ] Update project boards
- [ ] Archive release branch (if used)
- [ ] Plan next release

## Emergency Rollback

If critical issues are discovered immediately after release:

```bash
# 1. Yank problematic version from pub.dev
dart pub global activate pana
dart pub publish --yank vX.Y.Z

# 2. Prepare hotfix
make version-bump VERSION=X.Y.Z+1

# 3. Fix issue and release patch
# Follow normal release process
```

- [ ] Identify issue
- [ ] Yank problematic version (if critical)
- [ ] Prepare hotfix
- [ ] Release patch version
- [ ] Notify users

## Version History

Track releases for reference:

| Version | Date | Type | Notes |
|---------|------|------|-------|
| 0.0.1 | 2026-01-31 | Initial | First release |
| | | | |

## Release Commands Quick Reference

```bash
# Version management
make version                    # Show current versions
make version-check              # Check version consistency
make version-bump VERSION=X.Y.Z # Bump all versions

# Quality checks
make ci                         # Run CI checks
make test                       # Run tests
make analyze                    # Run analysis
make format-check               # Check formatting

# Publishing
make publish-dry-run            # Validate packages
make publish-check              # Check pub.dev readiness
make release-prepare            # Run all pre-release checks
make release-tag VERSION=X.Y.Z  # Create release tag

# Package-specific
make gameframework              # Test gameframework
make unity                      # Test Unity plugin
make unreal                     # Test Unreal plugin
```

## Notes

- Always test thoroughly before releasing
- Never skip version validation checks
- Document breaking changes clearly
- Coordinate breaking changes with major versions
- Keep CHANGELOG.md up to date
- Monitor releases for issues

---

**Last Updated**: January 31, 2026
