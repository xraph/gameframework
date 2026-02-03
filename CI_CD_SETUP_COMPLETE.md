# CI/CD Setup Complete

This document summarizes the complete CI/CD system that has been configured for automated package publishing to pub.dev.

## 📦 What Was Created

### GitHub Actions Workflows

1. **`.github/workflows/ci.yml`**
   - Runs on every push and PR to main/develop
   - Tests on Linux, macOS, and Windows
   - Validates code quality, formatting, and pub.dev requirements
   - Uploads test coverage to Codecov
   - Checks version consistency

2. **`.github/workflows/publish.yml`**
   - Triggers on version tags (e.g., `v1.0.0`)
   - Publishes packages in correct dependency order:
     1. `gameframework` (core) first
     2. `gameframework_unity` and `gameframework_unreal` in parallel
   - Creates GitHub releases automatically
   - Supports manual dispatch for selective publishing

### Documentation

1. **`.github/README.md`**
   - Overview of all workflows
   - Quick reference guide

2. **`.github/RELEASE_WORKFLOW.md`**
   - Comprehensive release process documentation
   - Setup instructions for pub.dev credentials
   - Troubleshooting guide
   - Security best practices

3. **`.github/RELEASE_CHECKLIST.md`**
   - Step-by-step release checklist
   - Quality assurance steps
   - Emergency rollback procedures

4. **`.github/SECURITY.md`**
   - Security policy
   - Vulnerability reporting process
   - Security best practices

### Issue & PR Templates

1. **`.github/ISSUE_TEMPLATE/bug_report.yml`**
   - Structured bug report form
   - Platform and version tracking

2. **`.github/ISSUE_TEMPLATE/feature_request.yml`**
   - Feature request form
   - Priority and use case tracking

3. **`.github/ISSUE_TEMPLATE/config.yml`**
   - Links to documentation and discussions

4. **`.github/pull_request_template.md`**
   - PR checklist and guidelines
   - Change type categorization

### Makefile Enhancements

Added release management commands to `Makefile`:

```bash
make version-check              # Check version consistency
make version-bump VERSION=X.Y.Z # Bump all package versions
make publish-dry-run            # Validate packages
make release-prepare            # Run all pre-release checks
make release-tag VERSION=X.Y.Z  # Create release tag
```

## 🚀 Quick Start

### Initial Setup (One-Time)

1. **Configure pub.dev credentials**:

```bash
# Generate credentials locally
dart pub token add https://pub.dev

# Extract credentials
cat ~/.pub-cache/credentials.json

# Add to GitHub:
# Settings → Secrets → Actions → New repository secret
# Name: PUB_CREDENTIALS
# Value: <paste credentials.json content>
```

2. **Verify setup**:

```bash
make ci                # Run CI checks
make publish-dry-run   # Validate packages
```

### Creating a Release

#### Simple Release (Recommended)

```bash
# 1. Bump version for all packages
make version-bump VERSION=1.0.0

# 2. Update CHANGELOG.md
vim CHANGELOG.md

# 3. Run pre-release checks
make release-prepare

# 4. Commit and tag
git add .
git commit -m "chore: release v1.0.0"
make release-tag VERSION=1.0.0

# 5. Push (triggers automatic publishing)
git push origin main --tags
```

#### Manual Release via GitHub UI

1. Go to **Actions** → **Publish to pub.dev**
2. Click **Run workflow**
3. Select package and options
4. Click **Run workflow**

## 📋 Package Publishing Order

The workflow automatically handles dependency order:

```
┌─────────────────┐
│  gameframework  │  (published first)
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐ ┌─────────┐
│  unity  │ │ unreal  │  (published in parallel)
└─────────┘ └─────────┘
```

## 🔍 Version Management

### Version Consistency

All packages must maintain consistent versions:

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

### Check Version Consistency

```bash
make version-check
```

### Bump All Versions

```bash
make version-bump VERSION=1.0.0
```

## 🧪 Testing & Validation

### Run All Tests

```bash
make test
```

### Run CI Checks

```bash
make ci
```

### Validate for pub.dev

```bash
make publish-dry-run
```

### Full Pre-Release Check

```bash
make release-prepare
```

## 🔄 CI/CD Workflow

### On Push/PR (ci.yml)

```
Push/PR → Run Tests → Analyze → Format Check → Validate pub.dev
                                                        ↓
                                                   Upload Coverage
```

### On Tag (publish.yml)

```
Tag v1.0.0 → Validate All → Publish gameframework → Wait 60s
                                         ↓
                              Publish unity & unreal
                                         ↓
                                 Create GitHub Release
```

## 📊 Monitoring

### GitHub Actions

- Navigate to **Actions** tab
- Monitor workflow runs
- View logs for debugging

### pub.dev

- [gameframework](https://pub.dev/packages/gameframework)
- [gameframework_unity](https://pub.dev/packages/gameframework_unity)
- [gameframework_unreal](https://pub.dev/packages/gameframework_unreal)

## 🛠 Makefile Commands

### Development

```bash
make bootstrap     # Install dependencies
make test          # Run all tests
make analyze       # Run static analysis
make format        # Format code
make format-check  # Check formatting
make lint          # Run all linting checks
```

### Release Management

```bash
make version                    # Show current versions
make version-check              # Check version consistency
make version-bump VERSION=X.Y.Z # Bump all versions
make publish-dry-run            # Validate packages
make release-prepare            # Run all pre-release checks
make release-tag VERSION=X.Y.Z  # Create release tag
```

### Package-Specific

```bash
make gameframework  # Test gameframework
make unity          # Test Unity plugin
make unreal         # Test Unreal plugin
```

### CI/CD

```bash
make ci      # Run CI checks
make check   # Run all quality checks
```

## 🔐 Security

### Best Practices

- ✅ Never commit credentials
- ✅ Use GitHub Secrets for sensitive data
- ✅ Rotate credentials annually
- ✅ Monitor security advisories
- ✅ Keep dependencies updated

### Reporting Vulnerabilities

See `.github/SECURITY.md` for security policy and reporting process.

## 🐛 Troubleshooting

### Publication Failed

1. Check GitHub Actions logs
2. Verify credentials in GitHub Secrets
3. Ensure version was incremented
4. Run `make publish-dry-run` locally

### Version Mismatch

```bash
# Check versions
make version-check

# Fix versions
make version-bump VERSION=1.0.0
```

### Tests Failed

```bash
# Run locally
make test

# Run specific package
make gameframework  # or unity, unreal
```

## 📚 Documentation

| File | Purpose |
|------|---------|
| `.github/README.md` | Workflows overview |
| `.github/RELEASE_WORKFLOW.md` | Complete release guide |
| `.github/RELEASE_CHECKLIST.md` | Step-by-step checklist |
| `.github/SECURITY.md` | Security policy |

## 🎯 Next Steps

1. **Set up credentials**: Add `PUB_CREDENTIALS` to GitHub Secrets
2. **Test workflow**: Create a test release with dry-run enabled
3. **Update CHANGELOG**: Document all changes since last release
4. **Create first release**: Follow the release process above
5. **Monitor**: Watch for issues and downloads on pub.dev

## 📦 Published Packages

Once released, packages will be available at:

- **gameframework**: https://pub.dev/packages/gameframework
- **gameframework_unity**: https://pub.dev/packages/gameframework_unity
- **gameframework_unreal**: https://pub.dev/packages/gameframework_unreal

## ✅ Verification

To verify the setup is correct:

```bash
# 1. Check all files exist
ls -la .github/workflows/
ls -la .github/ISSUE_TEMPLATE/

# 2. Validate workflow files
cat .github/workflows/ci.yml
cat .github/workflows/publish.yml

# 3. Run local checks
make ci
make version-check
make publish-dry-run

# 4. Test version bump (without committing)
make version-bump VERSION=0.0.2
git status  # Review changes
git restore .  # Undo if just testing
```

## 🎉 Summary

You now have a fully automated CI/CD pipeline that:

- ✅ Tests code on every push and PR
- ✅ Validates packages before publishing
- ✅ Publishes packages in correct dependency order
- ✅ Creates GitHub releases automatically
- ✅ Maintains version consistency
- ✅ Provides comprehensive documentation
- ✅ Includes quality gates and checks
- ✅ Supports manual and automatic releases

## 📞 Support

For issues or questions:

1. Check the documentation in `.github/`
2. Review [GitHub Actions logs](../../actions)
3. Open an issue using the provided templates
4. Refer to [pub.dev documentation](https://dart.dev/tools/pub/publishing)

---

**Created**: January 31, 2026  
**Status**: ✅ Ready for use  
**Next Action**: Set up `PUB_CREDENTIALS` in GitHub Secrets
